import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ather/data/exam_draft_store.dart';

/// The draft store's own contract, unit-level: debounce timing, flush and
/// clear semantics, and the decode matrix (M11) -- including the wholesale
/// discard that keeps a corrupt draft from half-applying (C2).
///
/// Timing cases run under [testWidgets] so the binding's fake clock advances
/// the store's debounce without a real wait.
void main() {
  const lessonId = 7;
  final draft = ExamDraft(
    total: '20',
    groups: <ExamDraftGroup>[
      const ExamDraftGroup(count: '5', points: '2', correct: '3'),
    ],
  );

  late SharedPreferences preferences;
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    preferences = await SharedPreferences.getInstance();
  });

  ExamDraftStore store() => ExamDraftStore(preferences);

  group('key scheme', () {
    test('keys sit under the wipe prefix', () {
      // COUPLING: app_providers.dart wipes drafts by `kExamDraftKeyPrefix`
      // ('exam_draft_'); this is the same literal, kept equal by hand.
      expect(ExamDraftStore.keyPrefix, 'exam_draft_');
      expect(ExamDraftStore.keyFor(lessonId), 'exam_draft_$lessonId');
      expect(
        ExamDraftStore.keyFor(3).startsWith(ExamDraftStore.keyPrefix),
        isTrue,
      );
    });
  });

  group('debounced saves', () {
    testWidgets('nothing lands before the window closes', (tester) async {
      final s = store();
      s.scheduleSave(lessonId, draft);
      await tester.pump();
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNull);

      await tester.pump(kExamDraftWriteDelay - const Duration(milliseconds: 1));
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNull);

      await tester.pump(const Duration(milliseconds: 1));
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNotNull);
    });

    testWidgets('a burst collapses into its last state', (tester) async {
      final s = store();
      s.scheduleSave(lessonId, draft);
      await tester.pump(kExamDraftWriteDelay ~/ 2);
      s.scheduleSave(
        lessonId,
        const ExamDraft(total: '30', groups: <ExamDraftGroup>[]),
      );
      await tester.pump(kExamDraftWriteDelay);

      final raw = preferences.getString(ExamDraftStore.keyFor(lessonId))!;
      expect((jsonDecode(raw) as Map<dynamic, dynamic>)['total'], '30');
    });
  });

  group('flush and clear', () {
    testWidgets('flush writes immediately, before the debounce elapses', (
      tester,
    ) async {
      final s = store();
      s.scheduleSave(lessonId, draft);
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNull);

      await s.flush();

      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNotNull);
      // No debounce timer is left running behind us.
      await tester.pump(kExamDraftWriteDelay * 2);
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNotNull);
    });

    testWidgets('clear cancels a pending save and removes the key', (
      tester,
    ) async {
      final s = store();
      // An older write first, so removal has something to remove.
      await preferences.setString(
        ExamDraftStore.keyFor(lessonId),
        jsonEncode(<String, Object?>{'total': '1', 'groups': <Object?>[]}),
      );
      s.scheduleSave(lessonId, draft);
      await tester.pump(kExamDraftWriteDelay ~/ 2);

      await s.clear(lessonId);
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNull);

      // The cancelled debounce never resurrects it.
      await tester.pump(kExamDraftWriteDelay * 2);
      expect(preferences.getString(ExamDraftStore.keyFor(lessonId)), isNull);
    });

    testWidgets('clearAll takes every prefixed key and nothing else', (
      tester,
    ) async {
      final s = store();
      await preferences.setString('exam_draft_1', 'x');
      await preferences.setString('exam_draft_2', 'y');
      await preferences.setString('locale_code', 'ar');

      await s.clearAll();

      expect(preferences.getKeys(), <String>{'locale_code'});
    });
  });

  group('the decode matrix', () {
    ExamDraft? load(String raw) {
      preferences.setString(ExamDraftStore.keyFor(lessonId), raw);
      return store().load(lessonId);
    }

    test('a well-formed draft round-trips', () {
      final loaded = load(
        jsonEncode(<String, Object?>{
          'total': '20',
          'groups': <Object?>[
            <String>['5', '2', '3'],
            <String>['4', '1', ''],
          ],
        }),
      );
      expect(loaded!.total, '20');
      expect(loaded.groups, hasLength(2));
      expect(loaded.groups[1].correct, isEmpty);
    });

    test('truncated JSON is discarded', () {
      expect(load('{"total": "20", "groups": [["5","2"'), isNull);
    });

    test('non-JSON garbage is discarded', () {
      expect(load('not json at all'), isNull);
    });

    test('a non-map payload is discarded', () {
      expect(load(jsonEncode(<String>['a', 'b'])), isNull);
    });

    test('one malformed group entry discards the WHOLE draft (C2)', () {
      final loaded = load(
        jsonEncode(<String, Object?>{
          'total': '30',
          'groups': <Object?>[
            <String>['12', '1', '9'],
            <String>['6', '2'], // one field short
            <String>['12', '1', '7'],
          ],
        }),
      );
      expect(loaded, isNull);
    });

    test('a non-string field anywhere discards the whole draft', () {
      final loaded = load(
        jsonEncode(<String, Object?>{
          'total': '30',
          'groups': <Object?>[
            <Object?>['12', '1', 7],
          ],
        }),
      );
      expect(loaded, isNull);
    });

    test('a non-string total is discarded', () {
      final loaded = load(
        jsonEncode(<String, Object?>{
          'total': 20,
          'groups': <Object?>[
            <String>['5', '2', '3'],
          ],
        }),
      );
      expect(loaded, isNull);
    });

    test('an empty groups list has nothing worth showing', () {
      final loaded = load(
        jsonEncode(<String, Object?>{'total': '20', 'groups': <Object?>[]}),
      );
      expect(loaded, isNull);
    });

    test('an absent key loads as nothing', () {
      expect(store().load(lessonId), isNull);
    });
  });
}

