import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/platform/secure_window.dart';
import '../../data/auth/firebase_auth_repository.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import 'app_providers.dart';

/// Overridden in tests with a fake so no test ever talks to Firebase.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(FirebaseAuth.instance),
);

/// The account stream. Starts from the session Firebase restored from disk, so
/// the first frame already knows the answer — the app never shows a spinner
/// waiting on a network round trip it does not need.
final accountProvider = StreamProvider<Account?>(
  (ref) => ref.watch(authRepositoryProvider).watchAccount(),
);

/// The resolved account. Falls back to the synchronously available cached
/// session while the stream's first event is still in flight.
final accountValueProvider = Provider<Account?>((ref) {
  final async = ref.watch(accountProvider);
  return async.value ?? ref.watch(authRepositoryProvider).currentAccount;
});

final isSignedInProvider = Provider<bool>(
  (ref) => ref.watch(accountValueProvider) != null,
);

/// Whether the app should ask the student to verify their address.
///
/// True only when there is an account and it is unverified -- so it is false
/// while signed out, and false for a Google account, which arrives verified.
///
/// **This gates a prompt, never access.** See [Account.isEmailVerified]: the
/// database is local and the auth gate already stands in front of it, so
/// blocking an unverified student would cost them their exam history to
/// enforce something the app does not depend on.
final needsEmailVerificationProvider = Provider<bool>((ref) {
  final account = ref.watch(accountValueProvider);
  return account != null && !account.isEmailVerified;
});

// --- Biometric app lock ------------------------------------------------------

const String _kLockEnabledKey = 'app_lock_enabled';

final localAuthProvider = Provider<LocalAuthentication>(
  (ref) => LocalAuthentication(),
);

/// Whether this device can actually ask for a fingerprint.
///
/// Checked before the lock is ever offered: a switch that turns on a lock the
/// device cannot satisfy would lock the student out of their own data.
final biometricsAvailableProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(localAuthProvider);
  try {
    if (!await auth.isDeviceSupported()) return false;
    final enrolled = await auth.getAvailableBiometrics();
    return enrolled.isNotEmpty;
  } catch (_) {
    // An unsupported platform (Windows desktop, an emulator with no sensor)
    // reports by throwing. That is a "no", not a crash.
    return false;
  }
});

/// Whether the student asked for the fingerprint lock. Off by default: an app
/// that starts demanding biometrics nobody enabled feels broken, not secure.
class AppLockNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kLockEnabledKey) ?? false;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kLockEnabledKey, enabled);
  }
}

final appLockEnabledProvider = NotifierProvider<AppLockNotifier, bool>(
  AppLockNotifier.new,
);

/// Whether the lock screen is currently covering the app.
///
/// Starts locked so the very first frame after launch is the lock, never a
/// glimpse of the dashboard behind it.
class LockStateNotifier extends Notifier<bool> {
  /// `read`, deliberately, not `watch`.
  ///
  /// Watching re-runs `build` whenever the preference changes and resets the
  /// state to its result — so turning the switch **on** in Settings dropped the
  /// lock screen over the app on the spot, fired a fingerprint prompt, and left
  /// a student who cancelled it shut out of their own work with the back button
  /// already swallowed (see `LockAwareBackButtonDispatcher`). The preference
  /// decides what happens on the *next* launch and on the next `lock()`, which
  /// is all it was ever meant to decide.
  @override
  bool build() => ref.read(appLockEnabledProvider);

  void unlock() => state = false;

  /// Called when the app returns from the background.
  void lock() {
    if (ref.read(appLockEnabledProvider)) state = true;
  }
}

final lockStateProvider = NotifierProvider<LockStateNotifier, bool>(
  LockStateNotifier.new,
);

/// Re-locks the app when it goes to the background.
///
/// Locks on `paused`, not on `resumed`: by the time the app is resumed its
/// content has already been composited, and on Android the task-switcher
/// thumbnail was captured while it was still visible.
class AppLockObserver extends ConsumerStatefulWidget {
  const AppLockObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockObserver> createState() => _AppLockObserverState();
}

class _AppLockObserverState extends ConsumerState<AppLockObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Before the first frame the platform could snapshot. The lock preference
    // is read from disk synchronously at startup, so this is already the right
    // answer on a cold start rather than a correction made after the dashboard
    // has been drawn once.
    SecureWindow.set(secure: ref.read(appLockEnabledProvider));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(lockStateProvider.notifier).lock();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Follows the switch. Turning the lock on has to take effect on the window
    // straight away: the student may background the app in the next second, and
    // the thumbnail Android keeps is the one drawn before they do.
    ref.listen<bool>(
      appLockEnabledProvider,
      (_, enabled) => SecureWindow.set(secure: enabled),
    );
    return widget.child;
  }
}
