import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/study_snapshot.dart';
import '../../domain/services/exam_reminder_service.dart';

/// Schedules the 3-day-before exam reminders.
///
/// Reminders are **scheduled at each exam's reminder moment** (3 days before
/// the exam date at 18:00) rather than polled daily, so they fire with the app
/// closed — which is the only way an exam preparation reminder is useful. A
/// reconciliation pass on resume repairs any drift (clock changes, reboots,
/// exams created or deleted on another day).
class ExamNotificationService {
  ExamNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'ather_exams';
  static const String _channelName = 'Exam reminders';

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
    required void Function(int examId) onExamTapped,
  }) async {
    if (_initialised) return;

    tz_data.initializeTimeZones();
    // The device's own zone, so "3 days before" lands at a sensible local hour
    // rather than drifting by the UTC offset.
    tz.setLocalLocation(tz.getLocation(await _resolveTimeZoneName()));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(
        appName: 'Ather',
        appUserModelId: 'com.ather.app',
        guid: 'a3e8f9b2-1c4d-4a7e-9f2b-3e6d8a1c5f40',
      ),
    );

    // v22 moved every argument to named parameters.
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        final examId = int.tryParse(payload);
        if (examId != null) onExamTapped(examId);
      },
    );

    _initialised = true;
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
  /// turning the reminder switch on, or creating their first scheduled exam —
  /// rather than on cold start, where a permission prompt arriving before any
  /// context is reliably denied.
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
  /// Null until the first successful pass, and cleared whenever a pass is
  /// abandoned part-way -- an unknown device state must never look like a
  /// matching one.
  String? _applied;

  /// Rebuilds the schedule from the current data.
  ///
  /// Cancels everything and re-schedules rather than diffing: the set is at most
  /// a few dozen exams, and a full rebuild cannot leave a reminder for an exam
  /// that was deleted or rescheduled.
  ///
  /// **But it only does that when something actually moved.** This is called on
  /// a five-second debounce after *any* change to the record, and again on
  /// every resume, and the work is one platform round-trip per exam plus an
  /// AlarmManager registration each. For a student with twenty scheduled exams
  /// that was twenty IPC calls and twenty alarm registrations, repeatedly, to
  /// arrive at the schedule that was already there. Renaming an exam, changing
  /// its notes or switching away and back all triggered a full rebuild.
  ///
  /// So the pass is fingerprinted first. Everything the schedule depends on
  /// goes into the fingerprint -- the exam ids, their reminder times, the
  /// bodies, and the enabled flag -- and an identical one returns before
  /// touching the platform at all.
  Future<void> reschedule({
    required StudySnapshot snapshot,
    required DateTime now,
    required bool enabled,
    required String Function(String examTitle, String subjectName) buildBody,
    required String title,
  }) async {
    if (!_initialised) return;

    final due = <({int id, DateTime at, String body})>[];
    if (enabled && permissionGranted) {
      for (final exam in snapshot.scheduledExams) {
        if (!ExamReminderService.shouldScheduleReminder(exam, now)) {
          continue;
        }

        final reminderAt = ExamReminderService.reminderDateFor(exam);

        final subject = snapshot.subjectById(exam.subjectId);
        due.add((
          id: exam.id,
          at: reminderAt,
          body: buildBody(exam.title, subject?.name ?? ''),
        ));
      }
    }

    final fingerprint = <String>[
      '$enabled',
      title,
      for (final d in due) '${d.id}@${d.at.millisecondsSinceEpoch}:${d.body}',
    ].join('|');
    if (fingerprint == _applied) return;

    // Cleared, not set, before the platform work: if any call below throws, the
    // device is in a state this object cannot describe, and claiming otherwise
    // would strand the student with a stale schedule no later pass would fix.
    _applied = null;

    await _plugin.cancelAll();
    if (due.isEmpty) {
      _applied = fingerprint;
      return;
    }

    for (final exam in due) {
      final reminderAt = exam.at;

      await _plugin.zonedSchedule(
        id: exam.id,
        title: title,
        body: exam.body,
        scheduledDate: tz.TZDateTime.from(reminderAt, tz.local),
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
        // Play treats as a restricted permission. An exam preparation reminder
        // does not justify that, and being delivered within the hour is fine.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '${exam.id}',
      );
    }

    // Only once every call above has landed.
    _applied = fingerprint;
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
