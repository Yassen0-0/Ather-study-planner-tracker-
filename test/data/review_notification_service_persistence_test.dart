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
    final service = ReviewNotificationService(plugin, preferences: preferences);
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

  // C2: the applied fingerprint used to be persisted and trusted on the next
  // cold start. A Force Stop deletes an app's alarms without telling it, so
  // the next launch matched yesterday's record, skipped the rebuild, and the
  // reminders were gone for good. Every process now rebuilds once.
  test('every cold start rebuilds, even when nothing moved', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();

    final firstPlugin = _CountingPlugin();
    await reschedule(await coldPass(firstPlugin, preferences), oneLesson, true);
    expect(firstPlugin.cancelAllCalls, 1);
    expect(firstPlugin.scheduledIds, hasLength(2));

    // Force stop, then a launch: same data, fresh process. The alarms may be
    // gone and nothing says so -- the schedule is registered again.
    final secondPlugin = _CountingPlugin();
    await reschedule(
      await coldPass(secondPlugin, preferences),
      oneLesson,
      true,
    );
    expect(secondPlugin.cancelAllCalls, 1);
    expect(secondPlugin.scheduledIds, hasLength(2));
  });

  test('within one process an identical pass still costs nothing', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final plugin = _CountingPlugin();
    final service = await coldPass(plugin, preferences);

    await reschedule(service, oneLesson, true);
    await reschedule(service, oneLesson, true);

    expect(
      plugin.cancelAllCalls,
      1,
      reason:
          'the dedupe is what makes '
          'resume and every debounced write cheap',
    );
    expect(plugin.scheduledIds, hasLength(2));

    // Changed data still gets through.
    await reschedule(service, twoLessons, true);
    expect(plugin.cancelAllCalls, 2);
    expect(plugin.scheduledIds, hasLength(6));
  });

  test('a pass that fails half-way is rebuilt by the next one', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final plugin = _CountingPlugin()
      ..scheduleFailure = Exception('platform refused');
    final service = await coldPass(plugin, preferences);

    await expectLater(reschedule(service, oneLesson, true), throwsException);

    // Same data, platform healthy again: an unknown device state never counts
    // as the one asked for.
    plugin.scheduleFailure = null;
    await reschedule(service, oneLesson, true);
    expect(plugin.cancelAllCalls, 2);
    expect(plugin.scheduledIds, hasLength(2));
  });

  test(
    'a fingerprint an earlier build stored is removed, never trusted',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();

      // Learn the exact fingerprint a pass over this data produces...
      final fingerprint = ReviewNotificationService.fingerprintOf(
        reminders: ReviewNotificationService.planReminders(
          snapshot: oneLesson,
          now: kAnchor,
          enabled: true,
          buildBody: (lesson, chapter) => 'due:$lesson/$chapter',
          buildEarlyBody: (lesson, chapter) => 'early:$lesson/$chapter',
        ),
        enabled: true,
        title: 'title',
      );
      // ...and leave it where 1.10.0 would have: a perfect match.
      await preferences.setString(
        ReviewNotificationService.kAppliedFingerprintKey,
        fingerprint,
      );

      final plugin = _CountingPlugin();
      await reschedule(await coldPass(plugin, preferences), oneLesson, true);

      expect(plugin.cancelAllCalls, 1);
      expect(plugin.scheduledIds, hasLength(2));
      expect(
        preferences.getString(ReviewNotificationService.kAppliedFingerprintKey),
        isNull,
      );
    },
  );
}
