import 'package:drift/drift.dart';

/// The student's subjects: four seeded on a fresh install, plus any they add.
///
/// Display names for the seeded four are in the ARB files (so the ar/en toggle
/// needs no migration) and their icons are presentation constants keyed off
/// [code]. A subject the student created cannot use either -- nobody can
/// translate a name they invented -- so it carries its own [name] and the
/// sentinel code `custom`.
@DataClassName('SubjectRow')
class Subjects extends Table {
  /// Hand-assigned rather than autoIncrement: the seed writes 1..4 at fixed
  /// ids so it is idempotent across launches and migrations, and a chapter
  /// never ends up pointing at a renumbered subject. New subjects take
  /// `max(id) + 1`, computed in the repository.
  IntColumn get id => integer()();

  /// `SubjectCode.name` -- biology / physics / chemistry / english -- or
  /// `custom` for a subject the student added.
  TextColumn get code => text().withLength(min: 1, max: 24)();

  /// The student's own name for a subject they created. Null for the seeded
  /// four, whose names are translated rather than stored.
  TextColumn get name => text().withLength(min: 1, max: 60).nullable()();

  /// Set when the student **archives** a subject: puts it away deliberately,
  /// because they are done with it. Nothing under it is touched.
  DateTimeColumn get archivedAt => dateTime().nullable()();

  /// Set when the student **deletes** a subject. Also touches nothing under it
  /// -- the row simply stops being visible anywhere and moves to the recycle
  /// bin, where it can be restored or destroyed for real.
  ///
  /// The two columns are separate because archiving and deleting are different
  /// intentions, not two words for hiding: archive is "I am done with this",
  /// trash is "I did not mean to have this". Collapsing them into one flag
  /// would force one list to answer both questions.
  ///
  /// The actual cascade -- the one that takes every chapter, lesson and exam
  /// underneath -- happens only when the bin is emptied.
  DateTimeColumn get deletedAt => dateTime().nullable()();

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

  /// Midnight UTC of one calendar day -- the canonical key produced by
  /// `dayOf`. Day precision, so a task written at 23:59 and one at 00:01
  /// belong to different days rather than sorting next to each other; anchored
  /// to UTC so the key survives the yearly move between +3 and +2 instead of
  /// meaning "this day" only under the offset it was written with.
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

/// The capture-only study event log -- the answer to "what did this student
/// do, and when?", which until version 4 had no home at all: checklist flags
/// were booleans overwritten in place and task ticks carried no date, so any
/// daily statistics a future feature might want were not merely missing but
/// **underivable**. Every day this table waits is history nobody can get back,
/// which is why it ships while nothing reads it.
///
/// Deliberately outside [StudySnapshot]: readers would put it on every screen's
/// rebuild path for data no screen shows. The two writers below are its only
/// members -- captured, never yet read.
@DataClassName('StudyEventRow')
class StudyEvents extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// [StudyEvent.typeChecklist] or [StudyEvent.typeTaskDone]. A string rather
  /// than an enum column so a future kind can be written by an older reader's
  /// backup without failing it -- the same reasoning as subject codes.
  TextColumn get type => text()();

  /// The lessonId or taskId the event is about, decided by [type]. No foreign
  /// key on purpose: the referenced row can be deleted while its history
  /// remains, and that is the point of a log.
  IntColumn get refId => integer()();

  DateTimeColumn get at => dateTime()();
}
