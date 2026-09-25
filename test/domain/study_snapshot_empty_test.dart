import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:flutter_test/flutter_test.dart';

/// D6: what "this device holds nothing" means.
///
/// Emptiness is a permission, not a description: it lets the account-switch
/// wipe skip its confirmation and lets the automatic restore write over the
/// device. So everything the student made has to count -- including a subject
/// they created and nothing else -- while the four seeded subjects, present on
/// every install, do not.
void main() {
  const seeded = <Subject>[
    Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
  ];
  const custom = Subject(
    id: 5,
    code: null,
    name: 'رياضيات',
    sortOrder: 4,
    archivedAt: null,
  );

  StudySnapshot snapshot({
    List<Subject> subjects = seeded,
    List<Chapter> chapters = const <Chapter>[],
  }) => StudySnapshot(
    subjects: subjects,
    chapters: chapters,
    lessons: const [],
    exams: const [],
    homework: const [],
  );

  test('the seeded subjects alone are empty', () {
    expect(snapshot().isEmpty, isTrue);
    expect(const StudySnapshot.empty().isEmpty, isTrue);
  });

  test('a custom subject with no chapters is not empty', () {
    expect(snapshot(subjects: <Subject>[...seeded, custom]).isEmpty, isFalse);
  });

  test('a custom subject in the recycle bin still counts', () {
    // Restorable from the bin, so still the student's data.
    final binned = Subject(
      id: 5,
      code: null,
      name: 'رياضيات',
      sortOrder: 4,
      archivedAt: null,
      deletedAt: DateTime(2026, 8, 1),
    );
    expect(snapshot(subjects: <Subject>[...seeded, binned]).isEmpty, isFalse);
  });

  test('a chapter is not empty, as before', () {
    expect(
      snapshot(
        chapters: <Chapter>[
          Chapter(id: 1, subjectId: 1, name: 'باب', createdAt: DateTime(2026)),
        ],
      ).isEmpty,
      isFalse,
    );
  });
}
