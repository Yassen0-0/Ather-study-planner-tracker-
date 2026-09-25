import 'package:ather/core/diagnostics/crash_reporting.dart';
import 'package:drift/drift.dart' show InvalidDataException;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// S4/S5: what a non-fatal report may carry off the phone, and that sending
/// one can never itself fail.
void main() {
  tearDown(() => nonFatalSinkForTesting = null);

  group('scrubbedDescription', () {
    test('a rejected companion keeps the reason, loses the row', () {
      // The shape drift really produces for a row it refuses.
      final error = InvalidDataException(
        'Sorry, ChaptersCompanion(id: Value.absent(), name: Value(باب سري '
        'للطالبة), subjectId: Value(1)) cannot be used for that because: '
        '• name: Must at most be 200 characters long.',
      );
      final scrubbed = ScrubbedError.of(error);

      expect(scrubbed.type, 'InvalidDataException');
      expect(scrubbed.toString(), isNot(contains('باب')));
      expect(scrubbed.toString(), isNot(contains('سري')));
      expect(scrubbed.toString(), contains('InvalidDataException'));
    });

    test('a failed statement loses its SQL and its parameters', () {
      final error = Exception(
        'SqliteException(2067): UNIQUE constraint failed: chapters.name\n'
        '  Causing statement: INSERT INTO chapters (name) VALUES (?), '
        "parameters: Private Chapter 'Ahmed'",
      );
      final text = scrubbedDescription(error);

      expect(text, contains('UNIQUE constraint failed: chapters.name'));
      expect(text, isNot(contains('INSERT')));
      expect(text, isNot(contains('Ahmed')));
    });

    test('quoted spans and non-ASCII text are removed wherever they are', () {
      final text = scrubbedDescription(
        StateError("no lesson named 'Cell structure' in الباب الأول"),
      );
      expect(text, isNot(contains('Cell structure')));
      expect(text, isNot(contains('الباب')));
      expect(text, contains('no lesson named'));
    });

    test('a Firebase error is its plugin and code, never its message', () {
      final text = scrubbedDescription(
        FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
          message: 'Missing permission for users/uid-123/backup/snapshot',
        ),
      );
      expect(text, '[cloud_firestore/permission-denied]');
    });

    test('a long message is capped', () {
      final text = scrubbedDescription(Exception('x' * 1000));
      expect(text.length, lessThanOrEqualTo(kMaxScrubbedLength));
    });
  });

  group('reportNonFatal', () {
    test('sends the scrubbed error, not the original', () {
      final sent = <ScrubbedError>[];
      String? sentReason;
      nonFatalSinkForTesting = (error, _, reason) {
        sent.add(error);
        sentReason = reason;
      };

      reportNonFatal(
        InvalidDataException('Sorry, TasksCompanion(title: Value(سر)) bad'),
        StackTrace.current,
        reason: 'write',
      );

      expect(sent.single.type, 'InvalidDataException');
      expect(sent.single.toString(), isNot(contains('سر')));
      expect(sentReason, 'write');
    });

    test('never throws, whatever goes wrong while reporting', () {
      nonFatalSinkForTesting = (_, _, _) => throw StateError('sink broke');
      expect(
        () => reportNonFatal(Exception('x'), StackTrace.current),
        returnsNormally,
      );
    });

    test('with no Firebase app it is a quiet no-op', () {
      // The state main() tolerates when Firebase.initializeApp fails; the
      // old direct calls threw here, from inside the caller's catch block.
      expect(Firebase.apps, isEmpty);
      expect(
        () => reportNonFatal(Exception('x'), StackTrace.current),
        returnsNormally,
      );
    });
  });
}
