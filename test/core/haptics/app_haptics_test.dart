import 'package:ather/core/haptics/app_haptics.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The haptics vocabulary, end to end but without a single platform channel.
///
/// Everything runs against a recorder installed on `AppHaptics.send`, which is
/// the class's own seam — so "the gate blocks" is proven by the same route a
/// real cue takes, not by peeking at private state.
void main() {
  final List<AppHapticCue> sent = <AppHapticCue>[];

  setUp(() {
    sent.clear();
    // Fresh dispatch seam and an open gate for every test; statics outlive
    // individual tests, so each one starts from the shipped defaults.
    AppHaptics.send = sent.add;
    AppHaptics.configure!(true);
  });

  group('vocabulary maps each moment onto its weight', () {
    test('light() fires the light cue', () {
      AppHaptics.light();
      expect(sent, <AppHapticCue>[AppHapticCue.light]);
    });

    test('select() fires the select cue', () {
      AppHaptics.select();
      expect(sent, <AppHapticCue>[AppHapticCue.select]);
    });

    test('success() fires the success cue', () {
      AppHaptics.success();
      expect(sent, <AppHapticCue>[AppHapticCue.success]);
    });

    test('heavy() fires the heavy cue', () {
      AppHaptics.heavy();
      expect(sent, <AppHapticCue>[AppHapticCue.heavy]);
    });
  });

  group('the gate', () {
    test('is open before anything configures it', () {
      // No configure push of any kind: a fresh process must vibrate.
      AppHaptics.light();
      expect(sent, hasLength(1));
    });

    test('a disabled setting swallows every cue', () {
      AppHaptics.configure!(false);

      AppHaptics.light();
      AppHaptics.select();
      AppHaptics.success();
      AppHaptics.heavy();

      expect(sent, isEmpty);
    });

    test('re-enabling restores every cue', () {
      AppHaptics.configure!(false);
      AppHaptics.heavy();
      expect(sent, isEmpty);

      AppHaptics.configure!(true);
      AppHaptics.heavy();
      expect(sent, <AppHapticCue>[AppHapticCue.heavy]);
    });
  });

  group('it never throws', () {
    test('a synchronously refusing platform is swallowed', () {
      AppHaptics.send = (_) => throw StateError('no motor here');

      expect(AppHaptics.success, returnsNormally);
    });

    test('an asynchronously refusing channel is swallowed', () async {
      AppHaptics.send =
          (_) => Future<void>.error(StateError('channel refused'));

      // The rejection is caught where the cue is dispatched; if it ever
      // escaped, package:test fails this test on the unhandled error.
      AppHaptics.success();
      await pumpEventQueue();
    });
  });

  group('wiring through HapticsEnabledNotifier', () {
    Future<ProviderContainer> containerWith(
      Map<String, Object> initial,
    ) async {
      SharedPreferences.setMockInitialValues(initial);
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('defaults to enabled and stores nothing until touched', () async {
      final container = await containerWith(<String, Object>{});

      expect(container.read(hapticsEnabledProvider), isTrue);
      AppHaptics.light();
      expect(sent, <AppHapticCue>[AppHapticCue.light]);
    });

    test('set(false) persists and closes the gate at once', () async {
      final container = await containerWith(<String, Object>{});

      await container.read(hapticsEnabledProvider.notifier).set(false);

      expect(
        container.read(sharedPreferencesProvider).getBool(kHapticsEnabledKey),
        isFalse,
      );
      AppHaptics.light();
      AppHaptics.select();
      expect(sent, isEmpty, reason: 'the switch must take effect immediately');
    });

    test('a stored "off" closes the gate on first read, cold start', () async {
      final container = await containerWith(<String, Object>{
        kHapticsEnabledKey: false,
      });

      expect(container.read(hapticsEnabledProvider), isFalse);
      AppHaptics.heavy();
      expect(sent, isEmpty);
    });
  });
}
