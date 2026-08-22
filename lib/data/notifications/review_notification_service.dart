import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/study_snapshot.dart';
import '../../domain/services/review_cycle_service.dart';

/// One reminder as it will be registered with the platform.
///
/// A plain value so the scheduling *decisions* -- which lessons, at what
/// moments, in what order, and how many survive the cap -- can be asserted in a
/// unit test without a platform channel anywhere near it.
final class ScheduledReminder {
  const ScheduledReminder({
    required this.id,
    required this.lessonId,
    required this.at,
    required this.body,
    required this.isEarly,
  });

  /// The platform notification id. **Not** the lesson id: a lesson now holds
  /// two reminders, so the id is `lessonId * 2` for the due-day one and
  /// `lessonId * 2 + 1` for the early one.
  ///
  /// Doubling rather than adding a fixed offset (`lessonId + 1000000`) because
  /// an offset is only collision-free while every lesson id stays below it, and
  /// nothing enforces that -- an id past the offset would silently cancel some
  /// other lesson's reminder, which is a bug that only appears on the phone of
  /// a student who has recorded a great deal. Doubling has no such ceiling
  /// short of 32-bit overflow.
  final int id;

  /// The lesson this is about. Carried separately from [id] because it is what
  /// goes in the payload -- tapping either reminder must open the lesson.
  final int lessonId;

  final DateTime at;
  final String body;

  /// True for the [ReviewCycleService.kEarlyReminderDays] warning, false for
  /// the due-day reminder.
  final bool isEarly;
}

/// Schedules the 30-day review reminders.
///
/// Reminders are **scheduled at each lesson's due moment** rather than polled
/// daily, so they fire with the app closed — which is the only way a decay
/// reminder is useful. A reconciliation pass on resume repairs any drift
/// (clock changes, reboots, exams recorded on another day).
class ReviewNotificationService {
  /// [preferences] carries the store the applied-fingerprint persists through
  /// (see [_applied]). Optional so tests can run the service with no store --
  /// the dedupe then behaves exactly as it did when it was memory-only.
  ReviewNotificationService(this._plugin, {SharedPreferences? preferences})
     : _storedPrefs = preferences;

  final FlutterLocalNotificationsPlugin _plugin;

  final SharedPreferences? _storedPrefs;

  static const String _channelId = 'sahm_review';
  static const String _channelName = 'Review reminders';

  bool _initialised = false;

  /// True once the OS has granted permission (or the platform does not gate it).
  ///
  /// Read back from the OS by [refreshPermission] rather than only ever set by
  /// [requestPermission]. It used to be the latter, and because nothing called
  /// `requestPermission`, this stayed `false` for the life of the app and
  /// [reschedule] returned early every single time — so no reminder was ever
  /// scheduled on any device. A flag that can only be set by a call that does
  /// not exist is indistinguishable from a feature that was never wired.
  bool permissionGranted = false;

  Future<void> initialise({
    required void Function(int lessonId) onLessonTapped,
  }) async {
    if (_initialised) return;

    tz_data.initializeTimeZones();
    // The device's own zone, so "30 days later" lands at a sensible local hour
    // rather than drifting by the UTC offset.
    tz.setLocalLocation(tz.getLocation(await _resolveTimeZoneName()));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: 'Ather',
        appUserModelId: 'com.ather.app',
        guid: 'f2a7c4d1-9b3e-4c8a-8f6d-1e5b7a9c2d40',
      ),
    );

    // v22 moved every argument to named parameters.
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final lessonId = int.tryParse(payload);
        if (lessonId != null) onLessonTapped(lessonId);
      },
    );

    _initialised = true;

    // Seed the applied-fingerprint from storage. This is the whole point of
    // persisting it: `_applied` used to start every cold run as null, and null
    // never matches anything, so the first pass after every launch paid a full
    // `cancelAll()` plus one registration per reminder to rebuild a schedule
    // that was already on the device and had not moved overnight.
    _applied = _storedPrefs?.getString(kAppliedFingerprintKey);
  }

  /// Reads the current permission back from the OS, showing nothing.
  ///
  /// Called on every sync, so a student who granted the permission last month —
  /// or who is on a build below Android 13, where it is granted at install —
  /// gets their reminders scheduled without ever being asked again. It also
  /// picks up a permission *revoked* in system settings, which would otherwise
  /// leave the app scheduling into a void and reporting success.
  Future<bool> refreshPermission() async {
    if (!Platform.isAndroid) {
      permissionGranted = true;
      return true;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    permissionGranted = await android?.areNotificationsEnabled() ?? false;
    return permissionGranted;
  }

  /// Asks for permission at a moment when its value is obvious — the student
  /// turning the reminder switch on, or recording the exam that starts the very
  /// first 30-day clock — rather than on cold start, where a permission prompt
  /// arriving before any context is reliably denied.
  ///
  /// Returns the granted state. Android only prompts once per install; after a
  /// refusal this resolves to `false` immediately, which is why the caller must
  /// treat a `false` as "say so in the UI", not "ask again".
  Future<bool> requestPermission() async {
    if (Platform.isAndroid) {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      permissionGranted =
          await android?.requestNotificationsPermission() ?? false;
      return permissionGranted;
    }
    permissionGranted = true;
    return true;
  }

  /// What the schedule currently on the device is made of, so an identical
  /// rebuild can be skipped entirely.
  ///
  /// Seeded from [kAppliedFingerprintKey] in storage when [initialise] runs,
  /// and written back through on every change, because a fingerprint that
  /// lived only in memory died with every process: each cold run then paid
  /// `cancelAll()` plus one platform round-trip per reminder for a schedule
  /// that had not changed while the app was closed.
  ///
  /// Null until the first successful pass, and cleared -- here *and* in
  /// storage -- whenever a pass is abandoned part-way. An unknown device state
  /// must never look like a matching one, and after a process death mid-rebuild
  /// only a cleared record keeps the next cold start honest.
  String? _applied;

  /// The SharedPreferences key [_applied] is stored under.
  static const String kAppliedFingerprintKey = 'review_schedule_fingerprint';

  /// The most alarms this app will ever hold registered at once.
  ///
  /// Android's per-app ceiling is around 500. Past it, registrations do not
  /// throw -- they are dropped, and the student loses reminders with nothing
  /// anywhere reporting that they did. So the ceiling has to be respected here
  /// rather than discovered there.
  ///
  /// 400 leaves headroom for the fact that a lesson now holds *two* alarms:
  /// this is a count of alarms, not of lessons, so 400 covers 200 lessons in
  /// the worst case where every one of them is far enough out to still be
  /// holding its early warning.
  ///
  /// Dropping the far ones rather than the near ones costs nothing: the pass
  /// re-runs on every resume and on every change to the record, so a lesson
  /// beyond the window is scheduled as soon as it comes into range, which is
  /// long before it falls due.
  static const int kMaxScheduledAlarms = 400;

  /// Decides what the schedule should be, without touching the platform.
  ///
  /// Pure, and public for that reason: everything that can be wrong about a
  /// reminder -- the moment, the body, the id, whether an already-past one was
  /// dropped, which ones survive [kMaxScheduledAlarms] -- is decided here and
  /// can be asserted directly.
  ///
  /// The result is sorted by [ScheduledReminder.at] ascending and truncated to
  /// [kMaxScheduledAlarms], so the alarms that survive are the soonest ones.
  static List<ScheduledReminder> planReminders({
    required StudySnapshot snapshot,
    required DateTime now,
    required bool enabled,
    required String Function(String lesson, String chapter) buildBody,
    required String Function(String lesson, String chapter) buildEarlyBody,
  }) {
    if (!enabled) return const <ScheduledReminder>[];

    final due = <ScheduledReminder>[];
    // `activeLessons`, not `lessons`: a subject the student archived or
    // deleted must stop reminding them about itself. Its lesson names are
    // what a reminder's body is made of, and they land on a lock screen.
    for (final lesson in snapshot.activeLessons) {
      final dueAt = ReviewCycleService.dueAt(lesson);
      if (dueAt == null) continue;

      final chapter = snapshot.chapterById(lesson.chapterId);
      final chapterName = chapter?.name ?? '';

      // The early warning, [kEarlyReminderDays] before the due day. Skipped
      // when it is already behind us -- a lesson examined 28 days ago is due in
      // two and its warning was owed last week; posting it now would announce a
      // deadline that has effectively arrived, which is the due-day reminder's
      // job and says something different.
      final earlyAt = ReviewCycleService.earlyReminderAt(lesson);
      if (earlyAt != null && earlyAt.isAfter(now)) {
        due.add(
          ScheduledReminder(
            id: lesson.id * 2 + 1,
            lessonId: lesson.id,
            at: earlyAt,
            body: buildEarlyBody(lesson.name, chapterName),
            isEarly: true,
          ),
        );
      }

      // Already-overdue lessons are shown in red in-app and badged on the
      // Review tab; firing a notification for something that came due weeks
      // ago would be noise, not a reminder.
      if (!dueAt.isAfter(now)) continue;

      due.add(
        ScheduledReminder(
          id: lesson.id * 2,
          lessonId: lesson.id,
          at: dueAt,
          body: buildBody(lesson.name, chapterName),
          isEarly: false,
        ),
      );
    }

    // Soonest first, so the cap below keeps the reminders that matter next.
    // Tie-broken on id because two lessons examined on the same day fall due at
    // the same instant, and an order that depends on nothing would make the
    // fingerprint below differ between two identical passes.
    due.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.id.compareTo(b.id);
    });

    if (due.length > kMaxScheduledAlarms) {
      return due.sublist(0, kMaxScheduledAlarms);
    }
    return due;
  }

  /// What a pass would put on the device, as one comparable string.
  ///
  /// **Both** of a lesson's moments are in [reminders] and therefore in here.
  /// Without that, adding or moving an early warning would leave the
  /// fingerprint identical to the previous pass, [reschedule] would take its
  /// early return, and the new reminder would silently never be registered --
  /// the dedupe suppressing the very change it was asked to apply.
  static String fingerprintOf({
    required List<ScheduledReminder> reminders,
    required bool enabled,
    required String title,
  }) => <String>[
    '$enabled',
    title,
    for (final r in reminders)
      '${r.id}@${r.at.millisecondsSinceEpoch}:${r.body}',
  ].join('|');

  /// Rebuilds the schedule from the current data.
  ///
  /// Cancels everything and re-schedules rather than diffing: the set is at most
  /// a few hundred lessons, and a full rebuild cannot leave a reminder for a
  /// lesson that was deleted or already re-examined.
  ///
  /// **But it only does that when something actually moved.** This is called on
  /// a five-second debounce after *any* change to the record, and again on
  /// every resume, and the work is one platform round-trip per lesson plus an
  /// AlarmManager registration each. For a student with eighty lessons that was
  /// eighty IPC calls and eighty alarm registrations, repeatedly, to arrive at
  /// the schedule that was already there. Renaming a chapter, ticking a
  /// checklist box or switching away and back all triggered a full rebuild.
  ///
  /// So the pass is fingerprinted first. Everything the schedule depends on
  /// goes into the fingerprint -- every reminder id, the moment each one fires,
  /// the bodies, and the enabled flag -- and an identical one returns before
  /// touching the platform at all. The comparison survives cold starts: the
  /// fingerprint of the last successful pass is persisted, so a run that finds
  /// the same schedule it left on the device yesterday does no platform work
  /// at all.
  Future<void> reschedule({
    required StudySnapshot snapshot,
    required DateTime now,
    required bool enabled,
    required String Function(String lesson, String chapter) buildBody,
    required String Function(String lesson, String chapter) buildEarlyBody,
    required String title,
  }) async {
    if (!_initialised) return;

    final due = planReminders(
      snapshot: snapshot,
      now: now,
      // A revoked OS permission is the same as the switch being off: there is
      // nothing to schedule into.
      enabled: enabled && permissionGranted,
      buildBody: buildBody,
      buildEarlyBody: buildEarlyBody,
    );

    final fingerprint = fingerprintOf(
      reminders: due,
      enabled: enabled,
      title: title,
    );
    if (fingerprint == _applied) return;

    // Cleared, not set, before the platform work: if any call below throws, the
    // device is in a state this object cannot describe, and claiming otherwise
    // would strand the student with a stale schedule no later pass would fix.
    // The stored copy is cleared first too, and deliberately before the
    // platform calls: a process dying between `cancelAll()` and the last
    // registration must not leave tomorrow's cold start reading yesterday's
    // fingerprint for a device that no longer matches it. Clearing costs at
    // worst one extra rebuild; trusting a stale record silently drops
    // reminders.
    _applied = null;
    await _writeStoredFingerprint(null);

    await _plugin.cancelAll();
    if (due.isEmpty) {
      _applied = fingerprint;
      await _writeStoredFingerprint(fingerprint);
      return;
    }

    for (final reminder in due) {
      await _plugin.zonedSchedule(
        id: reminder.id,
        title: title,
        body: reminder.body,
        scheduledDate: tz.TZDateTime.from(reminder.at, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          windows: WindowsNotificationDetails(),
        ),
        // Inexact deliberately: exact alarms need SCHEDULE_EXACT_ALARM, which
        // Play treats as a restricted permission. A study reminder does not
        // justify that, and being delivered within the hour is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        // The lesson, not the notification id -- tapping either of a lesson's
        // two reminders opens that lesson.
        payload: '${reminder.lessonId}',
      );
    }

    // Only once every call above has landed.
    _applied = fingerprint;
    await _writeStoredFingerprint(fingerprint);
  }

  /// Mirrors [_applied] into storage, or removes the record when it is null.
  ///
  /// A failed write propagates: the caller's catch treats the pass as failed,
  /// and the failure direction is the safe one -- memory already holds the new
  /// state, so later passes this run skip correctly, while a cold start that
  /// reads a stale or absent record pays one rebuild rather than trusting a
  /// schedule that may not be there.
  Future<void> _writeStoredFingerprint(String? fingerprint) async {
    final prefs = _storedPrefs;
    if (prefs == null) return;
    if (fingerprint == null) {
      await prefs.remove(kAppliedFingerprintKey);
    } else {
      await prefs.setString(kAppliedFingerprintKey, fingerprint);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();

  /// Best-effort local zone lookup. Falls back to UTC rather than throwing --
  /// a wrong-by-hours reminder is far better than a crash on launch.
  Future<String> _resolveTimeZoneName() async {
    try {
      final offset = DateTime.now().timeZoneOffset;
      // Egypt is the target market; map its offset directly and fall back to
      // UTC elsewhere rather than pulling in a native timezone plugin.
      if (offset == const Duration(hours: 2) ||
          offset == const Duration(hours: 3)) {
        return 'Africa/Cairo';
      }
      return 'UTC';
    } catch (_) {
      return 'UTC';
    }
  }
}
