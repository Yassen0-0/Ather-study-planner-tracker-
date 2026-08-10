import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../domain/entities/study_snapshot.dart';
import '../../domain/services/review_cycle_service.dart';

/// Schedules the 30-day review reminders.
///
/// Reminders are **scheduled at each lesson's due moment** rather than polled
/// daily, so they fire with the app closed — which is the only way a decay
/// reminder is useful. A reconciliation pass on resume repairs any drift
/// (clock changes, reboots, exams recorded on another day).
class ReviewNotificationService {
  ReviewNotificationService(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

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

  /// Rebuilds the schedule from the current data.
  ///
  /// Cancels everything and re-schedules rather than diffing: the set is at most
  /// a few hundred lessons, and a full rebuild cannot leave a reminder for a
  /// lesson that was deleted or already re-examined.
  Future<void> reschedule({
    required StudySnapshot snapshot,
    required DateTime now,
    required bool enabled,
    required String Function(String lesson, String chapter) buildBody,
    required String title,
  }) async {
    if (!_initialised) return;

    await _plugin.cancelAll();
    if (!enabled || !permissionGranted) return;

    for (final lesson in snapshot.lessons) {
      final dueAt = ReviewCycleService.dueAt(lesson);
      if (dueAt == null) continue;

      // Already-overdue lessons are shown in red in-app and badged on the Review
      // tab; firing a notification for something that came due weeks ago would
      // be noise, not a reminder.
      if (!dueAt.isAfter(now)) continue;

      final chapter = snapshot.chapterById(lesson.chapterId);

      await _plugin.zonedSchedule(
        id: lesson.id,
        title: title,
        body: buildBody(lesson.name, chapter?.name ?? ''),
        scheduledDate: tz.TZDateTime.from(dueAt, tz.local),
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
        payload: '${lesson.id}',
      );
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
