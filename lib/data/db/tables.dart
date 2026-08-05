import 'package:drift/drift.dart';

/// The four fixed subjects.
///
/// Only structural data lives here. Display names are in the ARB files (so the
/// ar/en toggle needs no migration) and icon/colour are presentation constants
/// keyed off [code]. The table exists mainly to give [Chapters] a real foreign
/// key to hang off.
@DataClassName('SubjectRow')
class Subjects extends Table {
  /// Stable, hand-assigned ids (1..4) rather than autoIncrement: the seed must
  /// be idempotent across launches and migrations.
  IntColumn get id => integer()();

  /// `SubjectCode.name` -- biology / physics / chemistry / english.
  TextColumn get code => text().withLength(min: 1, max: 24)();

  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// A chapter (باب), created and named by the student.
@DataClassName('ChapterRow')
class Chapters extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get subjectId =>
      integer().references(Subjects, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text().withLength(min: 1, max: 120)();

  /// Set when "أتقنت الباب" succeeds; null until then.
  DateTimeColumn get masteredAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}

/// A lesson (درس), created and named by the student.
@DataClassName('LessonRow')
class Lessons extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get chapterId =>
      integer().references(Chapters, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text().withLength(min: 1, max: 160)();

  /// Last time understanding was *proven*. Drives the 30-day decay cycle.
  /// Null means never examined -- which is not the same as overdue.
  DateTimeColumn get lastReviewedAt => dateTime().nullable()();

  /// Notification bookkeeping only, so the same overdue lesson does not post a
  /// reminder every single day. Not review state.
  DateTimeColumn get lastNotifiedAt => dateTime().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  // The five fixed study steps. Flat booleans rather than a child table: the
  // set is fixed at five with no add/remove, so a join would buy nothing.
  BoolColumn get watchedLesson =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get readNotes => boolean().withDefault(const Constant(false))();
  BoolColumn get didHomework => boolean().withDefault(const Constant(false))();
  BoolColumn get didExam => boolean().withDefault(const Constant(false))();
  BoolColumn get reviewedNotes =>
      boolean().withDefault(const Constant(false))();
}

/// A homework score. Self-assessment only -- never feeds mastery.
@DataClassName('HomeworkEntryRow')
class HomeworkEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get lessonId =>
      integer().references(Lessons, #id, onDelete: KeyAction.cascade)();

  IntColumn get score => integer()();
  IntColumn get maxScore => integer()();
  DateTimeColumn get createdAt => dateTime()();
}

/// A recorded exam -- the only input to mastery.
@DataClassName('ExamEntryRow')
class ExamEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get lessonId =>
      integer().references(Lessons, #id, onDelete: KeyAction.cascade)();

  BoolColumn get isReviewExam => boolean().withDefault(const Constant(false))();

  IntColumn get totalPossiblePoints => integer()();
  IntColumn get correctPoints => integer()();

  /// Denormalised from the question groups at write time -- read on every
  /// dashboard and chart query, and must stay historically stable.
  RealColumn get percentage => real()();

  DateTimeColumn get createdAt => dateTime()();
}

/// A task the student wrote for one specific day.
///
/// Deliberately unrelated to mastery. Nothing in `lib/domain/services/` reads
/// this table and it is **not** part of `StudySnapshot`: ticking a task proves
/// nothing about a lesson, and the app must never imply otherwise. It has no
/// foreign key for the same reason -- a task belongs to a date, not to a lesson.
@DataClassName('DailyTaskRow')
class DailyTasks extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Midnight local. Day precision, so a task written at 23:59 and one at 00:01
  /// belong to different days rather than sorting next to each other.
  DateTimeColumn get day => dateTime()();

  TextColumn get title => text().withLength(min: 1, max: 200)();

  BoolColumn get done => boolean().withDefault(const Constant(false))();

  /// Manual position within its day. Dense (0, 1, 2 ...) and rewritten wholesale
  /// on reorder -- a day holds a handful of rows, so fractional indices would be
  /// cleverness bought with nothing.
  IntColumn get sortOrder => integer()();

  DateTimeColumn get createdAt => dateTime()();
}

/// Questions on one exam sharing a point value, e.g. "3 أسئلة بدرجتين".
@DataClassName('ExamQuestionGroupRow')
class ExamQuestionGroups extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get examId =>
      integer().references(ExamEntries, #id, onDelete: KeyAction.cascade)();

  IntColumn get pointsPerQuestion => integer()();
  IntColumn get questionCount => integer()();
  IntColumn get correctCount => integer()();
}
