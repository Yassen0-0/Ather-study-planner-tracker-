import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/clock/clock.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/drift_study_repository.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/repositories/study_repository.dart';
import '../../domain/services/insights_generator.dart';
import '../../domain/services/review_cycle_service.dart';

/// Written manually rather than with `riverpod_generator`: that package requires
/// `analyzer ^13`, `drift_dev` requires an older analyzer, and pub cannot solve
/// both. Drift's codegen is non-negotiable, so the providers are hand-written.

// --- Infrastructure ---------------------------------------------------------

/// Overridden in tests with `NativeDatabase.memory()`.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Escape hatch for tests that want to supply their own executor.
final databaseExecutorProvider = Provider<QueryExecutor?>((ref) => null);

final studyRepositoryProvider = Provider<StudyRepository>(
  (ref) => DriftStudyRepository(ref.watch(databaseProvider)),
);

/// The app's time source.
///
/// Overridden with a [MutableClock] in tests and by the debug time-travel tool,
/// which is the only reason the 30-day cycle can be verified in seconds.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Re-emits every minute so date-derived UI (overdue counts, "5 days left")
/// stays honest without the user relaunching the app.
///
/// Deliberately coarse: review state changes on a *daily* boundary, so polling
/// faster would burn frames to display the same number.
final nowProvider = StreamProvider<DateTime>((ref) async* {
  final clock = ref.watch(clockProvider);
  yield clock.now();
  yield* Stream<void>.periodic(
    const Duration(minutes: 1),
  ).map((_) => clock.now());
});

// --- Core data --------------------------------------------------------------

/// The single source of truth every screen reads from.
///
/// Backed by drift's `.watch()`, so any write anywhere refreshes every screen
/// at once — no screen ever invalidates a cache by hand.
final snapshotProvider = StreamProvider<StudySnapshot>(
  (ref) => ref.watch(studyRepositoryProvider).watchSnapshot(),
);

/// Snapshot without the async wrapper, for widgets already inside an
/// `AsyncValue.when`. Falls back to empty rather than throwing, so a transient
/// loading frame cannot crash a screen.
// Riverpod 3.x removed `valueOrNull`; `AsyncValue.value` is itself nullable.
final snapshotValueProvider = Provider<StudySnapshot>(
  (ref) => ref.watch(snapshotProvider).value ?? const StudySnapshot.empty(),
);

/// Current time, resolved. Falls back to the clock directly on the first frame.
final nowValueProvider = Provider<DateTime>(
  (ref) => ref.watch(nowProvider).value ?? ref.watch(clockProvider).now(),
);

// --- Derived views ----------------------------------------------------------

final reviewQueueProvider = Provider<List<ReviewItem>>((ref) {
  return ReviewCycleService.buildReviewQueue(
    ref.watch(snapshotValueProvider),
    ref.watch(nowValueProvider),
  );
});

final insightsProvider = Provider<List<Insight>>((ref) {
  return InsightsGenerator.generate(
    ref.watch(snapshotValueProvider),
    ref.watch(nowValueProvider),
  );
});

// --- Settings ---------------------------------------------------------------

/// Overridden in `main()` once `SharedPreferences` has loaded.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider not overridden'),
);

const String _kLocaleKey = 'locale_code';
const String _kNotificationsKey = 'notifications_enabled';
const String _kThemeModeKey = 'theme_mode';

/// Selected UI locale, persisted.
///
/// Riverpod 3.x removed `StateProvider`, so this is a [Notifier].
class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final code = ref.watch(sharedPreferencesProvider).getString(_kLocaleKey);
    return Locale(code == 'en' ? 'en' : 'ar');
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kLocaleKey, locale.languageCode);
  }

  Future<void> toggle() =>
      set(state.languageCode == 'ar' ? const Locale('en') : const Locale('ar'));
}

final localeProvider = NotifierProvider<LocaleNotifier, Locale>(
  LocaleNotifier.new,
);

/// Whether the student wants review reminders. Independent of the OS-level
/// permission — this is the in-app preference.
class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kNotificationsKey) ?? true;

  Future<void> set(bool enabled) async {
    state = enabled;
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNotificationsKey, enabled);
  }
}

final notificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
      NotificationsEnabledNotifier.new,
    );

/// Light, dark, or whatever the phone is set to. Persisted.
///
/// [ThemeMode.system] is the default, and is what an unset preference reads
/// back as: a student who has never opened this setting should get the app in
/// the mode they already chose for their phone, not an opinion of ours.
///
/// Stored as the enum's `name` rather than its index so reordering
/// [ThemeMode] -- a framework enum we do not control -- cannot silently
/// reinterpret everyone's saved choice.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final String? saved = ref
        .watch(sharedPreferencesProvider)
        .getString(_kThemeModeKey);
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == saved,
      orElse: () => ThemeMode.system,
    );
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kThemeModeKey, mode.name);
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
