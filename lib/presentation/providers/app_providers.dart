import 'dart:async';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/clock/clock.dart';
import '../../data/db/app_database.dart';
import '../../data/repositories/drift_scheduled_exam_repository.dart';
import '../../data/repositories/drift_study_repository.dart';
import '../../domain/entities/study_snapshot.dart';
import '../../domain/repositories/scheduled_exam_repository.dart';
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

final scheduledExamRepositoryProvider = Provider<ScheduledExamRepository>(
  (ref) => DriftScheduledExamRepository(ref.watch(databaseProvider)),
);

/// The app's time source.
///
/// Overridden with a [MutableClock] in tests and by the debug time-travel tool,
/// which is the only reason the 30-day cycle can be verified in seconds.
final clockProvider = Provider<Clock>((ref) => const SystemClock());

/// Re-emits when the *day* changes, so date-derived UI (overdue counts, "5 days
/// left") stays honest without the student relaunching the app.
///
/// It used to tick every sixty seconds, and every tick was expensive out of all
/// proportion to what it changed. `nowValueProvider` feeds `dashboardProvider`,
/// which recomputes every summary for the whole curriculum, which rebuilds every
/// screen watching it *and* `AppShell` — the widget holding the app's one
/// `BackdropFilter`. Sixty times an hour, forever, to re-render numbers that are
/// identical until midnight.
///
/// Everything downstream is derived from whole days (`daysSinceReview`,
/// `daysUntilDue`, `daysOverdue`, the week strip), so the only moment any of it
/// can change is a date boundary. The timer therefore sleeps until just after
/// the next midnight and re-arms from there — one emission a day rather than
/// 1,440.
/// **A timer alone is not enough, and this was found on a real phone.** A
/// [Timer] measures *elapsed* time; the wall clock can move without any time
/// elapsing at all — the device wakes from doze, the network corrects the clock,
/// the student crosses a timezone or changes the date by hand. The timer sleeps
/// straight through every one of those. Moving a test device thirty days forward
/// left the app still rendering "باقي 62 يوم" against the date it had booted on,
/// because nothing had told it the day had changed.
///
/// So there are two triggers: the midnight timer, and **app resume** — which is
/// the moment a device that was asleep, or a clock that was corrected, comes
/// back. Resume only emits when the *day* actually differs, so the ordinary case
/// of switching away and back costs nothing.
///
/// (The sixty-second poll this replaced had no such hole, because it re-read the
/// clock constantly. That is the trade: one emission a day instead of 1,440, at
/// the price of having to name every moment the day can change.)
///
/// A real [Timer] behind a controller rather than `async*` with a delay: a
/// generator's pending `Future.delayed` cannot be cancelled, so it would
/// outlive the provider and trip "a Timer is still pending" in any widget test
/// that did not override this.
final nowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  late final StreamController<DateTime> controller;
  Timer? timer;
  DateTime? lastDay;

  DateTime dayOnly(DateTime t) => DateTime(t.year, t.month, t.day);

  void emit() {
    if (controller.isClosed) return;
    final now = clock.now();
    lastDay = dayOnly(now);
    controller.add(now);
  }

  void scheduleNextDay() {
    final now = clock.now();
    // One second past midnight, so the value that arrives is unambiguously the
    // new day even if the timer fires a hair early.
    final nextDay = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    timer?.cancel();
    timer = Timer(nextDay.difference(now), () {
      if (controller.isClosed) return;
      emit();
      scheduleNextDay();
    });
  }

  // Cheap: one check per resume, and an emission only if the date really moved.
  final lifecycle = AppLifecycleListener(
    onResume: () {
      if (controller.isClosed) return;
      if (lastDay != null && dayOnly(clock.now()) == lastDay) return;
      emit();
      // The remaining wait was measured against the old day; re-arm from the
      // new one or the next midnight lands in the wrong place.
      scheduleNextDay();
    },
  );

  controller = StreamController<DateTime>(
    onListen: () {
      emit();
      scheduleNextDay();
    },
    onCancel: () {
      timer?.cancel();
      return controller.close();
    },
  );

  ref.onDispose(() {
    lifecycle.dispose();
    timer?.cancel();
    if (!controller.isClosed) controller.close();
  });

  return controller.stream;
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
const String _kProfileNameKey = 'profile_name';
const String _kProfileYearKey = 'profile_year';

/// The uid whose data is currently on this device.
///
/// Public because two places have to agree on it: `BackupSyncGate` wipes the
/// device when a *different* account signs in, and `BackupSyncNotifier` refuses
/// to upload until the stored uid and the signed-in uid match. Both exist to
/// stop one student's curriculum reaching another student's cloud document.
const String kLastAccountUidKey = 'last_account_uid';

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

/// The student's own name, and the year they are sitting.
///
/// **Stored on the device and nowhere else.** It would have been easy to put
/// this in the account, where it would follow a student to a new phone -- and
/// that is exactly why it is worth writing down why it is not there.
///
/// The account currently knows one thing about a student: their email. That is
/// a genuinely strong position, and the privacy policy says so in plain words.
/// A name and a school year are personal data about someone who is very often
/// a minor; syncing them would put that data on a server, change what the
/// policy has to say, change the Play Data safety answers, and add a row to
/// everything the deletion path has to reach. The thing bought in exchange is
/// not having to retype a name once, on a phone the student is already setting
/// up.
///
/// If this is ever reversed, it rides in the existing `StudyBackup` blob rather
/// than a second document, and the delete-account sequence already wipes that.
class ProfileNameNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(_kProfileNameKey) ?? '';

  Future<void> set(String name) async {
    final trimmed = name.trim();
    state = trimmed;
    await ref
        .read(sharedPreferencesProvider)
        .setString(_kProfileNameKey, trimmed);
  }
}

final profileNameProvider = NotifierProvider<ProfileNameNotifier, String>(
  ProfileNameNotifier.new,
);

/// Which year of Thanaweya Amma. 0 means the student has not said.
///
/// A plain int rather than an enum because it is a number the student picks
/// from three, and nothing in the app branches on it -- it is shown back to
/// them and nothing more. The day it starts driving behaviour is the day it
/// should become an enum.
class ProfileYearNotifier extends Notifier<int> {
  @override
  int build() =>
      ref.watch(sharedPreferencesProvider).getInt(_kProfileYearKey) ?? 0;

  Future<void> set(int year) async {
    state = year;
    await ref.read(sharedPreferencesProvider).setInt(_kProfileYearKey, year);
  }
}

final profileYearProvider = NotifierProvider<ProfileYearNotifier, int>(
  ProfileYearNotifier.new,
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
