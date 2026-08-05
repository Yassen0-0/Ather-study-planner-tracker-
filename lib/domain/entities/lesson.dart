/// The five fixed study steps shown on a lesson.
///
/// Purely informational — ticking every box does **not** make a lesson mastered.
/// Only exams move mastery.
final class LessonChecklist {
  const LessonChecklist({
    this.watchedLesson = false,
    this.readNotes = false,
    this.didHomework = false,
    this.didExam = false,
    this.reviewedNotes = false,
  });

  final bool watchedLesson;
  final bool readNotes;
  final bool didHomework;
  final bool didExam;
  final bool reviewedNotes;

  static const int totalCount = 5;

  int get completedCount => <bool>[
    watchedLesson,
    readNotes,
    didHomework,
    didExam,
    reviewedNotes,
  ].where((done) => done).length;

  bool get isComplete => completedCount == totalCount;

  LessonChecklist copyWith({
    bool? watchedLesson,
    bool? readNotes,
    bool? didHomework,
    bool? didExam,
    bool? reviewedNotes,
  }) {
    return LessonChecklist(
      watchedLesson: watchedLesson ?? this.watchedLesson,
      readNotes: readNotes ?? this.readNotes,
      didHomework: didHomework ?? this.didHomework,
      didExam: didExam ?? this.didExam,
      reviewedNotes: reviewedNotes ?? this.reviewedNotes,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LessonChecklist &&
      other.watchedLesson == watchedLesson &&
      other.readNotes == readNotes &&
      other.didHomework == didHomework &&
      other.didExam == didExam &&
      other.reviewedNotes == reviewedNotes;

  @override
  int get hashCode => Object.hash(
    watchedLesson,
    readNotes,
    didHomework,
    didExam,
    reviewedNotes,
  );
}

/// A lesson (درس) the student created inside a chapter.
final class Lesson {
  const Lesson({
    required this.id,
    required this.chapterId,
    required this.name,
    required this.createdAt,
    this.checklist = const LessonChecklist(),
    this.lastReviewedAt,
    this.lastNotifiedAt,
  });

  final int id;
  final int chapterId;
  final String name;
  final DateTime createdAt;
  final LessonChecklist checklist;

  /// Last moment this lesson's understanding was *proven*.
  ///
  /// Set by a successful "أتقنت الباب" and by every exam submission. Null means
  /// the lesson has never been examined — which is **not** the same as overdue.
  final DateTime? lastReviewedAt;

  /// Bookkeeping only: when the review reminder for the current cycle was last
  /// posted, so the student is not notified about the same lesson every day.
  /// This is not review state — review state is derived from [lastReviewedAt].
  final DateTime? lastNotifiedAt;

  Lesson copyWith({
    String? name,
    LessonChecklist? checklist,
    DateTime? lastReviewedAt,
    DateTime? lastNotifiedAt,
  }) {
    return Lesson(
      id: id,
      chapterId: chapterId,
      name: name ?? this.name,
      createdAt: createdAt,
      checklist: checklist ?? this.checklist,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Lesson &&
      other.id == id &&
      other.chapterId == chapterId &&
      other.name == name &&
      other.createdAt == createdAt &&
      other.checklist == checklist &&
      other.lastReviewedAt == lastReviewedAt &&
      other.lastNotifiedAt == lastNotifiedAt;

  @override
  int get hashCode => Object.hash(
    id,
    chapterId,
    name,
    createdAt,
    checklist,
    lastReviewedAt,
    lastNotifiedAt,
  );
}
