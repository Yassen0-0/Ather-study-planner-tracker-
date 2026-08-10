import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/generated/app_localizations.dart';
import '../core/theme/app_spacing.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/reduced_motion.dart';
import '../presentation/auth/lock_screen.dart';
import '../presentation/providers/app_providers.dart';
import '../presentation/providers/auth_providers.dart';
import '../presentation/providers/backup_gate.dart';
import '../presentation/providers/notification_providers.dart';
import 'router.dart';

/// Locales the app ships. Arabic is first and is the fallback -- Ather is an
/// Arabic product with an English option, not the other way round.
const List<Locale> kSupportedLocales = <Locale>[Locale('ar'), Locale('en')];

/// Built once and kept for the app's lifetime. Rebuilding a [GoRouter] on every
/// locale change — or on every auth event — would reset every navigation stack,
/// so the auth gate is handed callbacks rather than a watched value.
final routerProvider = Provider<GoRouter>((ref) {
  final router = createRouter(
    isSignedIn: () => ref.read(authRepositoryProvider).currentAccount != null,
    accountChanges: ref.read(authRepositoryProvider).watchAccount(),
  );
  // Disposing the router disposes its refresh listenable, which is what cancels
  // the account subscription underneath. The provider lives for the life of the
  // app, so this only ever runs when a `ProviderScope` is torn down -- which is
  // every widget test, and a stream left listening there leaks across tests.
  ref.onDispose(router.dispose);
  return router;
});

/// Swallows the system back button while the lock screen is up.
///
/// The lock is a gate above the router rather than a route (see [_LockGate]),
/// which is what lets it cover bottom sheets and the exam wizard — but it also
/// means a back press has nothing to pop *it*, so the press fell straight
/// through to the router underneath and the student landed on the dashboard.
/// The lock was decorative.
///
/// Neither of the usual guards works from up there: `PopScope` needs a
/// `ModalRoute` and `BackButtonListener` needs a `Router` ancestor. The
/// dispatcher is the one place above the router that sees the press, so it is
/// where the lock is enforced.
class LockAwareBackButtonDispatcher extends RootBackButtonDispatcher {
  LockAwareBackButtonDispatcher(this._isLocked);

  final bool Function() _isLocked;

  @override
  Future<bool> didPopRoute() async {
    // `true` means "handled" -- the press stops here and pops nothing.
    if (_isLocked()) return true;
    return super.didPopRoute();
  }
}

/// Built once and kept: a [BackButtonDispatcher] that is swapped out mid-flight
/// loses the callbacks the router registered on it.
final backButtonDispatcherProvider = Provider<BackButtonDispatcher>((ref) {
  return LockAwareBackButtonDispatcher(
    // Read, not watched: this is asked at the moment of the press, so it must
    // reflect the state then rather than whenever the provider was last built.
    () => ref.read(lockStateProvider) && ref.read(isSignedInProvider),
  );
});

class AtherApp extends ConsumerWidget {
  const AtherApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Ather',
      debugShowCheckedModeBanner: false,
      // Both themes are always supplied; `themeMode` picks between them, and
      // ThemeMode.system hands the choice to the OS. The student's preference
      // lives in themeModeProvider, which reads it back from disk on launch --
      // so this rebuilds into the right theme on the first frame rather than
      // flashing light and correcting itself.
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: kSupportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        L.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // The router's three parts are passed individually rather than as
      // `routerConfig`, because GoRouter hard-codes its own
      // `RootBackButtonDispatcher` and MaterialApp.router forbids supplying a
      // dispatcher alongside a config. Swallowing the back press while locked
      // needs our own — see LockAwareBackButtonDispatcher.
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
      backButtonDispatcher: ref.watch(backButtonDispatcherProvider),
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Caps runaway system font scaling. The design's dense number rows
        // (a 30px figure beside a 16px "/ 100") break apart past ~1.3x, and a
        // student who cannot read the score is worse off than one reading it
        // slightly smaller.
        maxScaleFactor: 1.3,
        // Mounted inside the router's builder so these sit below Localizations
        // -- the scheduler needs L.of(context) for notification text, and the
        // lock screen for its prompt.
        child: AppLockObserver(
          child: ReviewScheduler(
            child: BackupSyncGate(
              child: _LockGate(child: child ?? const SizedBox.shrink()),
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the lock screen over everything while the app is locked.
///
/// A gate rather than a route: the lock has to cover whatever the student was
/// last looking at, including modal sheets and the exam wizard, and a route
/// would leave those composited underneath.
///
/// It only applies to a signed-in student — locking the login screen behind a
/// fingerprint would be a door in front of a door.
class _LockGate extends ConsumerWidget {
  const _LockGate({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locked = ref.watch(lockStateProvider);
    final signedIn = ref.watch(isSignedInProvider);
    final showLock = locked && signedIn;

    // Fade only, 200ms. The first thing a student sees after unlocking should
    // be their number, not a transition -- and a gate is not a navigation, so
    // nothing here slides or scales.
    return AnimatedSwitcher(
      // 200ms: the lock is leaving, so it borrows the exit duration rather than
      // the 220ms push. Signing in gets the longer one, in router.dart.
      duration: prefersReducedMotion(context) ? Duration.zero : AppMotion.exit,
      switchInCurve: AppMotion.standard,
      switchOutCurve: AppMotion.standard,
      child: showLock
          ? const LockScreen(key: ValueKey<bool>(true))
          : KeyedSubtree(key: const ValueKey<bool>(false), child: child),
    );
  }
}
