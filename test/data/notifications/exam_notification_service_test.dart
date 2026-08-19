import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'package:ather/data/notifications/exam_notification_service.dart';
import 'package:ather/domain/entities/scheduled_exam.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';

import 'exam_notification_service_test.mocks.dart';

@GenerateMocks([FlutterLocalNotificationsPlugin])
void main() {
  late MockFlutterLocalNotificationsPlugin mockPlugin;
  late ExamNotificationService service;

  setUp(() {
    tz.initializeTimeZones();
    mockPlugin = MockFlutterLocalNotificationsPlugin();
    service = ExamNotificationService(mockPlugin);
  });

  group('ExamNotificationService', () {
    test('initialise sets up plugin correctly', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      int? tappedExamId;
      await service.initialise(
        onExamTapped: (id) => tappedExamId = id,
      );

      verify(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).called(1);

      expect(tappedExamId, isNull);
    });

    test('reschedule does nothing when not initialised', () async {
      when(mockPlugin.cancelAll()).thenAnswer((_) async {});

      await service.reschedule(
        snapshot: const StudySnapshot.empty(),
        now: DateTime(2026, 8, 19),
        enabled: true,
        buildBody: (title, subject) => '$title - $subject',
        title: 'Exam in 3 days',
      );

      verifyNever(mockPlugin.cancelAll());
    });

    test('reschedule does nothing when permission not granted', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await service.initialise(onExamTapped: (_) {});

      when(mockPlugin.cancelAll()).thenAnswer((_) async {});

      await service.reschedule(
        snapshot: const StudySnapshot.empty(),
        now: DateTime(2026, 8, 19),
        enabled: true,
        buildBody: (title, subject) => '$title - $subject',
        title: 'Exam in 3 days',
      );

      verify(mockPlugin.cancelAll()).called(1);
    });

    test('reschedule schedules reminders for upcoming exams', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await service.initialise(onExamTapped: (_) {});
      service.permissionGranted = true;

      when(mockPlugin.cancelAll()).thenAnswer((_) async {});
      when(mockPlugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});

      final subject = const Subject(
        id: 1,
        code: null,
        name: 'Biology',
        sortOrder: 0,
        archivedAt: null,
      );

      final exam = ScheduledExam(
        id: 100,
        subjectId: 1,
        date: DateTime(2026, 8, 25), // 6 days from now
        title: 'Biology Midterm',
        chapterIds: const [1, 2],
        createdAt: DateTime(2026, 8, 19),
      );

      final snapshot = StudySnapshot(
        subjects: [subject],
        chapters: const [],
        lessons: const [],
        exams: const [],
        homework: const [],
        scheduledExams: [exam],
      );

      await service.reschedule(
        snapshot: snapshot,
        now: DateTime(2026, 8, 19),
        enabled: true,
        buildBody: (title, subjectName) => '$title - $subjectName',
        title: 'Exam in 3 days',
      );

      verify(mockPlugin.cancelAll()).called(1);
      verify(mockPlugin.zonedSchedule(
        id: 100,
        title: 'Exam in 3 days',
        body: 'Biology Midterm - Biology',
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: '100',
      )).called(1);
    });

    test('reschedule skips past exams', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await service.initialise(onExamTapped: (_) {});
      service.permissionGranted = true;

      when(mockPlugin.cancelAll()).thenAnswer((_) async {});

      final subject = const Subject(
        id: 1,
        code: null,
        name: 'Biology',
        sortOrder: 0,
        archivedAt: null,
      );

      final pastExam = ScheduledExam(
        id: 100,
        subjectId: 1,
        date: DateTime(2026, 8, 10), // 9 days in the past
        title: 'Biology Midterm',
        chapterIds: const [1, 2],
        createdAt: DateTime(2026, 8, 5),
      );

      final snapshot = StudySnapshot(
        subjects: [subject],
        chapters: const [],
        lessons: const [],
        exams: const [],
        homework: const [],
        scheduledExams: [pastExam],
      );

      await service.reschedule(
        snapshot: snapshot,
        now: DateTime(2026, 8, 19),
        enabled: true,
        buildBody: (title, subjectName) => '$title - $subjectName',
        title: 'Exam in 3 days',
      );

      verify(mockPlugin.cancelAll()).called(1);
      verifyNever(mockPlugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      ));
    });

    test('reschedule skips exams too close to remind for', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await service.initialise(onExamTapped: (_) {});
      service.permissionGranted = true;

      when(mockPlugin.cancelAll()).thenAnswer((_) async {});

      final subject = const Subject(
        id: 1,
        code: null,
        name: 'Biology',
        sortOrder: 0,
        archivedAt: null,
      );

      final soonExam = ScheduledExam(
        id: 100,
        subjectId: 1,
        date: DateTime(2026, 8, 20), // Tomorrow (reminder would be in the past)
        title: 'Biology Quiz',
        chapterIds: const [1],
        createdAt: DateTime(2026, 8, 19),
      );

      final snapshot = StudySnapshot(
        subjects: [subject],
        chapters: const [],
        lessons: const [],
        exams: const [],
        homework: const [],
        scheduledExams: [soonExam],
      );

      await service.reschedule(
        snapshot: snapshot,
        now: DateTime(2026, 8, 19, 10, 0), // 10 AM
        enabled: true,
        buildBody: (title, subjectName) => '$title - $subjectName',
        title: 'Exam in 3 days',
      );

      verify(mockPlugin.cancelAll()).called(1);
      verifyNever(mockPlugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      ));
    });

    test('reschedule skips when disabled', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await service.initialise(onExamTapped: (_) {});
      service.permissionGranted = true;

      when(mockPlugin.cancelAll()).thenAnswer((_) async {});

      final subject = const Subject(
        id: 1,
        code: null,
        name: 'Biology',
        sortOrder: 0,
        archivedAt: null,
      );

      final exam = ScheduledExam(
        id: 100,
        subjectId: 1,
        date: DateTime(2026, 8, 25),
        title: 'Biology Midterm',
        chapterIds: const [1, 2],
        createdAt: DateTime(2026, 8, 19),
      );

      final snapshot = StudySnapshot(
        subjects: [subject],
        chapters: const [],
        lessons: const [],
        exams: const [],
        homework: const [],
        scheduledExams: [exam],
      );

      await service.reschedule(
        snapshot: snapshot,
        now: DateTime(2026, 8, 19),
        enabled: false, // Disabled
        buildBody: (title, subjectName) => '$title - $subjectName',
        title: 'Exam in 3 days',
      );

      verify(mockPlugin.cancelAll()).called(1);
      verifyNever(mockPlugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      ));
    });

    test('reschedule skips identical schedule (fingerprint match)', () async {
      when(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).thenAnswer((_) async => true);

      await service.initialise(onExamTapped: (_) {});
      service.permissionGranted = true;

      when(mockPlugin.cancelAll()).thenAnswer((_) async {});
      when(mockPlugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      )).thenAnswer((_) async {});

      final subject = const Subject(
        id: 1,
        code: null,
        name: 'Biology',
        sortOrder: 0,
        archivedAt: null,
      );

      final exam = ScheduledExam(
        id: 100,
        subjectId: 1,
        date: DateTime(2026, 8, 25),
        title: 'Biology Midterm',
        chapterIds: const [1, 2],
        createdAt: DateTime(2026, 8, 19),
      );

      final snapshot = StudySnapshot(
        subjects: [subject],
        chapters: const [],
        lessons: const [],
        exams: const [],
        homework: const [],
        scheduledExams: [exam],
      );

      // First reschedule
      await service.reschedule(
        snapshot: snapshot,
        now: DateTime(2026, 8, 19),
        enabled: true,
        buildBody: (title, subjectName) => '$title - $subjectName',
        title: 'Exam in 3 days',
      );

      verify(mockPlugin.cancelAll()).called(1);
      verify(mockPlugin.zonedSchedule(
        id: anyNamed('id'),
        title: anyNamed('title'),
        body: anyNamed('body'),
        scheduledDate: anyNamed('scheduledDate'),
        notificationDetails: anyNamed('notificationDetails'),
        androidScheduleMode: anyNamed('androidScheduleMode'),
        payload: anyNamed('payload'),
      )).called(1);

      // Second reschedule with identical data - should skip
      await service.reschedule(
        snapshot: snapshot,
        now: DateTime(2026, 8, 19),
        enabled: true,
        buildBody: (title, subjectName) => '$title - $subjectName',
        title: 'Exam in 3 days',
      );

      // No additional calls (initialize was called earlier during setup)
      verify(mockPlugin.initialize(
        settings: anyNamed('settings'),
        onDidReceiveNotificationResponse: anyNamed('onDidReceiveNotificationResponse'),
      )).called(1);
      verifyNoMoreInteractions(mockPlugin);
    });

    test('cancelAll cancels all scheduled notifications', () async {
      when(mockPlugin.cancelAll()).thenAnswer((_) async {});

      await service.cancelAll();

      verify(mockPlugin.cancelAll()).called(1);
    });
  });
}
