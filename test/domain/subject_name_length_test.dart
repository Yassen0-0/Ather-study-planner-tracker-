import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The prompt that feeds `subjects.name` must not accept more than the column
/// holds.
///
/// `showNamePrompt` caps every name in the app at 80 characters by default.
/// `subjects.name` holds 60. For the life of the prompt the three subject call
/// sites used the default, so a name of 61 to 80 characters passed the field,
/// reached drift, and threw `InvalidDataException` inside `createSubject` --
/// which `runWrite` reported as the generic "something went wrong" toast. The
/// student retyped the same name and got the same nothing.
///
/// Chapters (120), lessons (160) and task titles (200) all sit above the
/// prompt's default, which is why subjects were the only ones that broke.
void main() {
  late AppDatabase db;
  late DriftStudyRepository repository;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repository = DriftStudyRepository(db);
  });

  tearDown(() async => db.close());

  test('a name at the column limit is accepted', () async {
    final id = await repository.createSubject(
      name: 'ا' * kSubjectNameMaxLength,
    );
    final snapshot = await repository.readSnapshot();
    expect(snapshot.subjectById(id)?.name?.length, kSubjectNameMaxLength);
  });

  test('one character past the limit is refused by the column', () async {
    // Not a wish for this to throw -- it is the constraint the prompt's cap
    // exists to stay inside. If this ever stops throwing, the column grew and
    // `kSubjectNameMaxLength` is stale.
    await expectLater(
      repository.createSubject(name: 'ا' * (kSubjectNameMaxLength + 1)),
      throwsA(isA<Exception>()),
    );
  });

  test('the prompt default would have overshot the column', () {
    // The regression in one line: 80 is what `showNamePrompt` allows when a
    // caller does not say otherwise, and it is more than this column takes.
    // That is why the three subject call sites pass the limit explicitly.
    const promptDefault = 80;
    expect(
      promptDefault > kSubjectNameMaxLength,
      isTrue,
      reason: 'subjects must pass maxLength: kSubjectNameMaxLength explicitly',
    );
  });
}
