import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/branding/ather_logo.dart';
import '../../core/l10n/generated/app_localizations.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../providers/auth_providers.dart';

/// Covers the app until a fingerprint is presented.
///
/// Two things this screen deliberately does **not** do:
///
/// * It never traps the student. If biometrics stop working — sensor failure, a
///   wipe of enrolled prints, a device restore — the lock releases rather than
///   holding their study data hostage behind a sensor that will not answer.
///   The lock is a privacy convenience, not a security boundary; the data is
///   already behind the OS's own device lock.
/// * It shows nothing of the app behind it. The prompt is raised on the first
///   frame, so the dashboard is never briefly visible.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  bool _prompting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prompt());
  }

  Future<void> _prompt() async {
    if (_prompting || !mounted) return;
    setState(() => _prompting = true);

    final auth = ref.read(localAuthProvider);
    final reason = L.of(context).lockReason;

    var unlocked = false;
    try {
      unlocked = await auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        // Survives the system backgrounding the app to show the sensor sheet;
        // without it the attempt fails the moment the prompt appears on some
        // Android builds.
        persistAcrossBackgrounding: true,
      );
    } catch (error, stack) {
      // No sensor, no enrolled print, or the platform refused. Releasing the
      // lock is the honest outcome -- see the class comment.
      //
      // Logged rather than swallowed: this same branch once hid a real
      // misconfiguration (the activity was not a FragmentActivity, so the
      // prompt could never appear) behind behaviour that looked exactly like
      // "this device has no fingerprint".
      debugPrint('Ather lock: biometric prompt unavailable -- $error\n$stack');
      unlocked = true;
    }

    if (!mounted) return;
    if (unlocked) {
      ref.read(lockStateProvider.notifier).unlock();
    } else {
      setState(() => _prompting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);

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
                const AtherGlyph(size: 56),
                const SizedBox(height: AppSpacing.xxxl),
                Text(l.lockTitle, style: AppTypography.today),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l.lockBody,
                  textAlign: TextAlign.center,
                  style: context.text.secondary.copyWith(height: 1.6),
                ),
                const SizedBox(height: AppSpacing.xxxl),
                SizedBox(
                  width: 240,
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
