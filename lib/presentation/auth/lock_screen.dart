import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/branding/ather_logo.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../providers/auth_providers.dart';

/// Covers the app until a fingerprint — or the device's own PIN — is presented.
///
/// ## What the lock does and does not release on
///
/// The lock is a privacy convenience over data already behind the device's own
/// lock, so it must not trap a student behind a sensor that can never answer.
/// **That is not the same as releasing whenever an attempt fails**, which is
/// what this screen used to do: every exception, including a cancelled prompt
/// and a too-many-attempts lockout, ran the same `unlocked = true` branch. A
/// student could press back on the system prompt and land on the dashboard, so
/// the lock was decorative.
///
/// The rule now: **only a device that can never authenticate releases the
/// lock**, and that is decided from the platform's own capability codes rather
/// than inferred from a failed attempt. A refusal, a cancellation or a lockout
/// keeps the lock on and offers the button again.
///
/// A student is still not trapped: [biometricOnly] is false, so the OS offers
/// the device PIN or pattern as a fallback on the same prompt.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;

  /// Null until an attempt has actually failed, so the screen does not accuse
  /// the student of anything before they have done it.
  String? Function(L)? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  /// The codes that mean *this device can never answer*, and nothing else.
  ///
  /// Deliberately a short allow-list rather than "anything unexpected". The enum
  /// documents itself as open to new values, so a `default` that released would
  /// hand every future failure code a way past the lock. `uiUnavailable` — the
  /// modern spelling of the `no_fragment_activity` misconfiguration in §3.18 —
  /// is deliberately absent: releasing on it is exactly how it stayed hidden.
  static bool _cannotEverAuthenticate(LocalAuthExceptionCode code) =>
      code == LocalAuthExceptionCode.noBiometricHardware ||
      code == LocalAuthExceptionCode.noBiometricsEnrolled ||
      code == LocalAuthExceptionCode.noCredentialsSet;

  Future<void> _prompt() async {
    if (_prompting || !mounted) return;
    setState(() {
      _prompting = true;
      _message = null;
    });

    final auth = ref.read(localAuthProvider);
    final reason = L.of(context).lockReason;

    var unlocked = false;
    String? Function(L)? message;

    try {
      unlocked = await auth.authenticate(
        localizedReason: reason,
        // False on purpose: the device PIN or pattern is an acceptable answer,
        // and it is what keeps "never release on failure" from trapping anyone.
        biometricOnly: false,
        // Survives the system backgrounding the app to show the sensor sheet;
        // without it the attempt fails the moment the prompt appears on some
        // Android builds.
        persistAcrossBackgrounding: true,
      );
      // A plain `false` is a refusal or a cancellation -- including the back
      // button on the system prompt. The lock stays on.
      if (!unlocked) message = (l) => l.lockRefused;
    } on LocalAuthException catch (error) {
      if (_cannotEverAuthenticate(error.code)) {
        // No sensor, nothing enrolled, no device passcode. Holding a student's
        // own study record hostage behind a sensor that will never say yes is
        // the one outcome worse than not locking.
        debugPrint('Ather lock: device cannot authenticate -- ${error.code}');
        unlocked = true;
      } else {
        // Cancelled, locked out, misconfigured, or something the enum gained
        // after this was written. Stay locked and say so.
        //
        // Logged rather than swallowed: this branch once hid a real
        // misconfiguration (the activity was not a FragmentActivity, so the
        // prompt could never appear) behind behaviour that looked exactly like
        // "this device has no fingerprint".
        debugPrint('Ather lock: attempt failed -- $error');
        unlocked = false;
        message =
            error.code == LocalAuthExceptionCode.temporaryLockout ||
                error.code == LocalAuthExceptionCode.biometricLockout
            ? (l) => l.lockLockedOut
            : (l) => l.lockRefused;
      }
    }

    if (!mounted) return;
    if (unlocked) {
      ref.read(lockStateProvider.notifier).unlock();
    } else {
      setState(() {
        _prompting = false;
        _message = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

    // The system back button is swallowed by LockAwareBackButtonDispatcher in
    // app.dart, not here. This screen is a gate rather than a route, so it has
    // neither a ModalRoute for a PopScope nor a Router ancestor for a
    // BackButtonListener -- both were tried; the second throws outright.
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // This screen is what a student actually sees on a cold start
                // with the lock on -- the Android launch window hands straight
                // over to it -- so the mark carries through from the splash
                // rather than disappearing at the handover.
                const AtherGlyph(size: 108),
                const SizedBox(height: AppSpacing.xl),
                // The wordmark, and nothing under it. Two lines of standing
                // instructional text used to sit here explaining that the app
                // is locked; the mark, the word "Ather" and a button labelled
                // "Unlock" already say that, and a lock screen is read for a
                // quarter of a second on every cold start. Only a *failed*
                // attempt has anything left to tell the student, and that
                // message takes the space the instructions used to hold.
                Text(l.appName, style: AppTypography.lockWordmark),
                if (_message != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    _message!(l)!,
                    textAlign: TextAlign.center,
                    style: AppTypography.style(
                      size: 14,
                      weight: AppTypography.semiBold,
                      color: context.colors.wrong,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: 220,
                  child: PrimaryButton(
                    label: l.lockUnlock,
                    onTap: _prompting ? null : _prompt,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
