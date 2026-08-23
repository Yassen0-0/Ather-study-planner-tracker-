import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// The one weight each [AppHaptics] moment maps onto, named for the method
/// that fires it so a test failure reads as the call site, not as a number.
enum AppHapticCue { light, select, success, heavy }

/// The app's whole haptics vocabulary: four moments, four weights.
///
/// From `animation/06_motion_specs.md`, ملحق PH-04:
///
/// | Moment                                  | Method            |
/// |-----------------------------------------|-------------------|
/// | Touch-down on any Pressable             | [AppHaptics.light] |
/// | Picking a tab or a day                  | [AppHaptics.select] |
/// | Exam saved ✓ / chapter mastered / queue emptied | [AppHaptics.success] |
/// | Committing a deletion (exam / account)  | [AppHaptics.heavy] |
///
/// Callers are the feature teams; this class owns everything else:
///
/// * **The gate.** Every method no-ops unless the student's setting says
///   otherwise. It defaults to enabled — vibration ships on, like every other
///   app the students already use — and the setting lives in SharedPreferences
///   under `haptics_enabled`, wired through `hapticsEnabledProvider`.
/// * **No BuildContext, ever.** These are statics called from gesture
///   handlers deep inside widgets; there is nothing to watch a provider with.
///   Instead the provider *pushes*: every time `HapticsEnabledNotifier`
///   builds or changes it calls [configure], which is pre-initialised to the
///   real gate and replaced by tests that want to observe pushes. `main()`
///   seeds the same hook before the first frame so a student who disabled
///   vibration does not get it back on the next launch.
/// * **It never throws.** An unsupported platform answers by throwing —
///   synchronously or as a rejected future from the channel — and both are
///   swallowed. A missing motor is a "no", not a crash under a fingertip.
/// * **Reduce-motion leaves it alone**, deliberately and per the documented
///   decision in the spec: vibration is not visual motion, so the
///   reduce-motion rule ("final state immediately") has nothing to say here.
abstract final class AppHaptics {
  /// Wiring seam: called with the setting's current value whenever it loads
  /// or changes. Pre-initialised to apply to the internal gate, so production
  /// code can invoke it unguarded; tests replace it to observe pushes.
  static void Function(bool)? configure = _setEnabled;

  /// Dispatch seam: where a gated cue becomes a vibration. Defaults to the
  /// matching [HapticFeedback] call; unit tests replace it with a recorder,
  /// which is how the gate is verified end-to-end without touching a single
  /// platform channel. Typed `dynamic`-returning so replacements may be
  /// sync or async alike — [AppHaptics._fire] swallows either failure mode.
  @visibleForTesting
  static dynamic Function(AppHapticCue cue) send = _toPlatform;

  static bool _enabled = true;

  /// Press-down feedback for any Pressable.
  static void light() => _fire(AppHapticCue.light);

  /// Tab picked, day picked — the lightest "registered your choice".
  static void select() => _fire(AppHapticCue.select);

  /// Save ✓, chapter mastery, review queue emptied.
  static void success() => _fire(AppHapticCue.success);

  /// A deletion commitment: an exam, or the account itself.
  static void heavy() => _fire(AppHapticCue.heavy);

  static void _fire(AppHapticCue cue) {
    if (!_enabled) return;
    try {
      // A replaced [send] may reject asynchronously — outside any try/catch
      // this frame can run. Swallowed here too, so an unimplemented channel
      // stays a no-op no matter who dispatches it.
      final Object? sent = send(cue);
      if (sent is Future) {
        unawaited(sent.catchError((Object _) {}));
      }
    } catch (_) {
      // A platform that answers "no" by throwing is answered quietly.
    }
  }

  static void _setEnabled(bool enabled) => _enabled = enabled;

  static dynamic _toPlatform(AppHapticCue cue) {
    final Future<void> sent = switch (cue) {
      AppHapticCue.light => HapticFeedback.lightImpact(),
      AppHapticCue.select => HapticFeedback.selectionClick(),
      AppHapticCue.success => HapticFeedback.mediumImpact(),
      AppHapticCue.heavy => HapticFeedback.heavyImpact(),
    };
    // Channel failures surface asynchronously, outside the try/catch in
    // [_fire]; swallowed here so an unimplemented channel stays a no-op.
    unawaited(sent.catchError((Object _) {}));
  }
}
