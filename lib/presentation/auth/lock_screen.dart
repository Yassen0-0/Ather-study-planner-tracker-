import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../core/auth/app_passcode.dart';
import '../../core/branding/ather_brand.dart';
import '../../core/haptics/app_haptics.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/error_banner.dart';
import '../providers/auth_providers.dart';

/// Covers the app until a fingerprint -- or the app's own password, or either
/// of the two when the student asked for both -- is presented.
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
///
/// ## The password half (T4)
///
/// When the chosen method includes the password, an obscured field stands
/// ready and nothing fires automatically -- typing over a sensor sheet that
/// popped itself would be noise. The sensor prompt stays a button away in the
/// `both` mode; each way in works exactly as it does alone. A wrong answer is
/// said plainly under the field with a light haptic, and the input is cleared
/// whichever way the attempt goes. It is never logged.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;

  late final TextEditingController _passcode = TextEditingController();

  /// Null until an attempt has actually failed, so the screen does not accuse
  /// the student of anything before they have done it.
  String? Function(L)? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Fires only where there is nothing to type into: the pure-biometric
      // cold start keeps today's behaviour of offering the prompt straight
      // away. With a field on screen the student picks their own moment.
      final method = ref.read(lockMethodProvider);
      final stored = ref.read(appPasscodeProvider);
      if (!(method.usesPassword && stored != null)) _prompt();
    });
  }

  @override
  void dispose() {
    _passcode.dispose();
    super.dispose();
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

  /// Checks the typed answer against the stored digest. The comparison is
  /// synchronous and cheap; the input is cleared whichever way it goes and is
  /// never logged anywhere.
  void _submitPasscode() {
    final stored = ref.read(appPasscodeProvider);
    final ok =
        stored != null && AppPasscode.verify(_passcode.text, stored.hash);
    _passcode.clear();

    if (ok) {
      ref.read(lockStateProvider.notifier).unlock();
      return;
    }
    // Registered-but-wrong: the lightest cue in PH-04's vocabulary.
    AppHaptics.light();
    setState(() {
      _message = (l) => l.wrongPassword;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final method = ref.watch(lockMethodProvider);
    final stored = ref.watch(appPasscodeProvider);

    // The field only stands up when the method asks for the password *and* a
    // credential exists for it. The second half is defensive: a method that
    // names a password no one ever set must fall back to the biometric path
    // rather than stand a door nobody has a key to.
    final offersField = method.usesPassword && stored != null;
    final keyboard = (stored?.digitsOnly ?? false)
        ? const TextInputType.numberWithOptions(decimal: false)
        : TextInputType.text;

    // The system back button is swallowed by LockAwareBackButtonDispatcher in
    // app.dart, not here. This screen is a gate rather than a route, so it has
    // neither a ModalRoute for a PopScope nor a Router ancestor for a
    // BackButtonListener -- both were tried; the second throws outright.
    return Scaffold(
      backgroundColor: context.colors.pageBackground,
      body: SafeArea(
        // The gate lives above the router's Navigator, so there is no Overlay
        // above it -- which a TextField refuses to live without. One local
        // overlay, exactly the size of the gate, is the cheapest answer that
        // stays inside this file.
        child: Overlay(
          initialEntries: <OverlayEntry>[
            OverlayEntry(
              builder: (_) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xxxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      // This screen is what a student actually sees on a cold start
                      // with the lock on -- the Android launch window hands straight
                      // over to it -- so the mark carries through from the splash
                      // rather than disappearing at the handover.
                      //
                      // It draws itself on (§SP-09): the gate remounts this screen
                      // every time the lock comes down, so a fresh State replays the
                      // beat on every appearance -- not only the first launch.
                      AtherMarkDrawOn(size: 108, label: l.appName),
                      const SizedBox(height: AppSpacing.xl),
                      // The wordmark, and nothing under it. Two lines of standing
                      // instructional text used to sit here explaining that the app
                      // is locked; the mark, the word "Ather" and a button labelled
                      // "Unlock" already say that, and a lock screen is read for a
                      // quarter of a second on every cold start. Only a *failed*
                      // attempt has anything left to tell the student, and that
                      // message takes the space the instructions used to hold.
                      Text(l.appName, style: AppTypography.lockWordmark),
                      if (offersField) ...<Widget>[
                        const SizedBox(height: AppSpacing.xxxl),
                        _PasswordField(
                          controller: _passcode,
                          hint: l.unlockWithPassword,
                          keyboardType: keyboard,
                          onSubmitted: (_) => _submitPasscode(),
                        ),
                        if (_message != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          ErrorBanner(message: _message!(l)!),
                        ],
                        const SizedBox(height: AppSpacing.xxl),
                        SizedBox(
                          width: 220,
                          child: PrimaryButton(
                            label: l.unlockWithPassword,
                            onTap: _submitPasscode,
                          ),
                        ),
                        if (method.usesBiometric) ...<Widget>[
                          const SizedBox(height: AppSpacing.md),
                          QuietPillButton(
                            label: l.lockUnlock,
                            onTap: _prompting ? () {} : _prompt,
                          ),
                        ],
                      ] else ...<Widget>[
                        if (_message != null) ...<Widget>[
                          const SizedBox(height: AppSpacing.xl),
                          ErrorBanner(message: _message!(l)!),
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
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The gate's one input, in the house field shape (the bare container +
/// [TextField] pair the name prompt uses): muted fill, no borders, hint text
/// carrying the instruction because the wordmark above already owns the page.
class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.hint,
    required this.keyboardType,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 48,
      alignment: AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: context.colors.muted,
        borderRadius: BorderRadius.circular(AppRadius.input),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: TextField(
        controller: controller,
        obscureText: true,
        keyboardType: keyboardType,
        textInputAction: TextInputAction.done,
        onSubmitted: onSubmitted,
        style: AppTypography.body,
        cursorColor: context.colors.textPrimary,
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          hintText: hint,
          hintStyle: AppTypography.body.copyWith(
            color: context.colors.textNoData,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}
