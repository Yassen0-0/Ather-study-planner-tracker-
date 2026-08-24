import 'package:ather/data/notifications/review_notification_service.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

/// Fixed reference point, as in `review_notification_service_test.dart`.
final DateTime kAnchor = DateTime(2026, 6, 1);

Lesson lessonWith({required int id, required DateTime? lastReviewedAt}) {
  return Lesson(
    id: id,
    chapterId: 1,
    name: 'درس',
    createdAt: DateTime(2026, 1, 1),
    lastReviewedAt: lastReviewedAt,
  );
}

StudySnapshot snapshotOf(List<Lesson> lessons) {
  return StudySnapshot(
    subjects: const [],
    chapters: [
      Chapter(
        id: 1,
        subjectId: 1,
        name: 'باب',
        createdAt: DateTime(2026, 1, 1),
      ),
    ],
    lessons: lessons,
    exams: const [],
    homework: const [],
  );
}

/// A plugin that counts instead of talking to a platform channel.
///
/// Only the three members [ReviewNotificationService] calls are overridden;
/// constructing the real class is harmless as long as none of its channel
/// methods run.
final class _CountingPlugin implements FlutterLocalNotificationsPlugin {
  int cancelAllCalls = 0;
  final List<int> scheduledIds = <int>[];

  /// Set to make every registration throw, simulating a platform that refuses
  /// part-way through a rebuild.
  Object? scheduleFailure;

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    final response = onDidReceiveNotificationResponse;
    if (response != null) {
      // Kept reachable so the field is not flagged unused; the service under
      // test never taps a notification in these tests.
      _tapSink = response;
    }
    return true;
  }

  // Touchpoint for [initialize]'s callback, kept out of the hot path.
  // ignore: unused_field
  DidReceiveNotificationResponseCallback? _tapSink;

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
  }

  @override
  Future<void> zonedSchedule({
    required int id,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    DateTimeComponents? matchDateTimeComponents,
    String? title,
    String? body,
    String? payload,
  }) async {
    final failure = scheduleFailure;
    if (failure != null) throw failure;
    scheduledIds.add(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  final oneLesson = snapshotOf([lessonWith(id: 7, lastReviewedAt: kAnchor)]);
  final twoLessons = snapshotOf([
    lessonWith(id: 7, lastReviewedAt: kAnchor),
    lessonWith(id: 8, lastReviewedAt: kAnchor),
  ]);

  Future<ReviewNotificationService> coldPass(
    _CountingPlugin plugin,
    SharedPreferences preferences,
  ) async {
    // A fresh instance standing in for a fresh process: nothing in memory
    // survives between passes except what went through [preferences].
    final service = ReviewNotificationService(
      plugin,
      preferences: preferences,
    );
    await service.initialise(onLessonTapped: (_) {});
    await service.refreshPermission();
    return service;
  }

  Future<void> reschedule(
    ReviewNotificationService service,
    StudySnapshot snapshot,
    bool enabled,
  ) {
    return service.reschedule(
      snapshot: snapshot,
      now: kAnchor,
      enabled: enabled,
      title: 'title',
      buildBody: (lesson, chapter) => 'due:$lesson/$chapter',
      buildEarlyBody: (lesson, chapter) => 'early:$lesson/$chapter',
    );
  }

  test('a cold start whose stored fingerprint matches pays zero platform '
      'calls', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    // The run that builds the schedule.
    final firstPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(firstPlugin, preferences),
      oneLesson,
      true,
    );

    expect(firstPlugin.cancelAllCalls, 1);
    expect(firstPlugin.scheduledIds, hasLength(2));
    expect(preferences.getString(ReviewNotificationService.kAppliedFingerprintKey), isNotNull);

    // The next launch reads the same storage and finds nothing moved.
    final secondPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(secondPlugin, preferences),
      oneLesson,
      true,
    );

    expect(secondPlugin.cancelAllCalls, 0, reason: 'no reason to cancel');
    expect(secondPlugin.scheduledIds, isEmpty);

    // A later pass over changed data still gets through the dedupe.
    await reschedule(
      await coldPass(secondPlugin, preferences),
      twoLessons,
      true,
    );

    expect(secondPlugin.cancelAllCalls, 1);
    expect(secondPlugin.scheduledIds, hasLength(4));
  });

  test('a pass that fails half-way clears the stored fingerprint', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    final goodPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(goodPlugin, preferences),
      oneLesson,
      true,
    );
    expect(preferences.getString(ReviewNotificationService.kAppliedFingerprintKey), isNotNull);

    // Different data forces the rebuild path, and the platform then refuses.
    final failingPlugin = _CountingPlugin()
      ..scheduleFailure = Exception('platform refused');
    final failingService = await coldPass(failingPlugin, preferences);

    await expectLater(
      reschedule(failingService, twoLessons, true),
      throwsException,
    );
    expect(preferences.getString(ReviewNotificationService.kAppliedFingerprintKey), isNull);

    // And the next honest pass therefore rebuilds rather than trusting a
    // record for a device state nobody can describe.
    final recoveryPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(recoveryPlugin, preferences),
      twoLessons,
      true,
    );

    expect(recoveryPlugin.cancelAllCalls, 1);
    expect(recoveryPlugin.scheduledIds, hasLength(4));
  });

  test('an emptied queue persists its fingerprint too, so sign-out stays '
      'empty across restarts', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    // Signed in with reminders owed: the schedule gets built.
    final signedInPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(signedInPlugin, preferences),
      oneLesson,
      true,
    );
    expect(signedInPlugin.scheduledIds, hasLength(2));

    // Signing out empties the queue -- and records having done so.
    final signedOutPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(signedOutPlugin, preferences),
      oneLesson,
      false,
    );

    expect(signedOutPlugin.cancelAllCalls, 1);
    expect(signedOutPlugin.scheduledIds, isEmpty);
    expect(preferences.getString(ReviewNotificationService.kAppliedFingerprintKey), isNotNull);

    // So the next launch does not cancel anything again to arrive at an
    // emptiness it already recorded.
    final nextLaunchPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(nextLaunchPlugin, preferences),
      oneLesson,
      false,
    );

    expect(nextLaunchPlugin.cancelAllCalls, 0);
    expect(nextLaunchPlugin.scheduledIds, isEmpty);
  });
}
