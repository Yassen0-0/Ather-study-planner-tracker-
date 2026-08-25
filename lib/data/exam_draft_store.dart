import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How long a draft change waits before it is written.
///
/// The wizard used to encode-and-write on every keystroke; the burst a fast
/// typist produces collapses into this window's trailing edge instead (PF2).
/// Short enough that a killed process loses at most a beat, long enough to
/// cover the gaps between keystrokes.
const Duration kExamDraftWriteDelay = Duration(milliseconds: 400);

/// One question group's raw field text inside a wizard draft.
class ExamDraftGroup {
  const ExamDraftGroup({
    required this.count,
    required this.points,
    required this.correct,
  });

  final String count;
  final String points;
  final String correct;
}

/// A whole draft exactly as it round-trips through preferences: raw field
/// text, numbers unparsed. The wizard owns meaning; this file owns survival.
class ExamDraft {
  const ExamDraft({required this.total, required this.groups});

  final String total;
  final List<ExamDraftGroup> groups;
}

/// The exam wizard's draft persistence, lifted out of the widget State (M11)
/// so the durability contract lives in one testable place:
///
/// - [scheduleSave] debounces trailing-edge ([kExamDraftWriteDelay]); a
///   keystroke burst writes once, its last state (PF2).
/// - [flush] writes any pending change immediately. The wizard calls it at
///   every loss boundary the debounce cannot see coming: the app pausing or
///   being torn down, and step changes.
/// - [clear] forgets one lesson's draft, cancelling anything pending -- the
///   paper became a saved exam or a confirmed discard.
/// - [load] reads a draft back silently, discarding it **whole** if any part
///   fails its shape check (C2): a half-restored paper is one the student
///   cannot finish, because the fields that would complete it were the ones
///   lost.
///
/// ## Key-prefix coupling -- read before touching the scheme
///
/// Draft keys are `'exam_draft_$lessonId'`. The account wipe in
/// `app_providers.dart` (`wipeAccountPreferences`) deletes drafts **by
/// prefix** through its own constant `kExamDraftKeyPrefix`, which it cannot
/// share with this file: that constant lives in the presentation layer and
/// data must not reach up into it. The two literals must therefore stay
/// byte-equal by hand -- a key drifting off the prefix would let one
/// student's half-typed paper resurface under the next (D-01/N20).
class ExamDraftStore {
  ExamDraftStore(this._preferences);

  /// Must stay byte-equal to `kExamDraftKeyPrefix` in app_providers.dart --
  /// see the coupling note above.
  static const String keyPrefix = 'exam_draft_';

  static String keyFor(int lessonId) => '$keyPrefix$lessonId';

  final SharedPreferences _preferences;

  Timer? _timer;
  int? _pendingLessonId;
  ExamDraft? _pendingDraft;

  /// Queues [draft] for writing under [lessonId]'s key, restarting the
  /// debounce. Only the most recent call's payload survives.
  void scheduleSave(int lessonId, ExamDraft draft) {
    _pendingLessonId = lessonId;
    _pendingDraft = draft;
    _timer?.cancel();
    _timer = Timer(kExamDraftWriteDelay, () {
      unawaited(_writePending());
    });
  }

  /// Writes whatever is pending right now and stands down the timer. Fire at
  /// every boundary where the process might die without another keystroke.
  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    await _writePending();
  }

  /// Forgets a lesson's draft outright: cancels any queued write, then
  /// removes the key.
  Future<void> clear(int lessonId) async {
    if (_pendingLessonId == lessonId) {
      _pendingLessonId = null;
      _pendingDraft = null;
    }
    _timer?.cancel();
    _timer = null;
    await _preferences.remove(ExamDraftStore.keyFor(lessonId));
  }

  /// Removes every draft key. The account wipe reaches these keys by prefix
  /// on its own (see the coupling note above); this exists so a future wipe
  /// refactor can go through the store instead of the key scheme.
  Future<void> clearAll() async {
    _timer?.cancel();
    _timer = null;
    _pendingLessonId = null;
    _pendingDraft = null;
    final keys = _preferences
        .getKeys()
        .where((key) => key.startsWith(ExamDraftStore.keyPrefix))
        .toList(growable: false);
    for (final key in keys) {
      await _preferences.remove(key);
    }
  }

  /// Reads a previous session's draft back, or null when there is nothing
  /// trustworthy. Anything unreadable -- an older build's shape, truncated
  /// JSON, one group entry short -- discards the draft wholesale rather than
  /// half-applied.
  ExamDraft? load(int lessonId) {
    final String? raw = _preferences.getString(
      ExamDraftStore.keyFor(lessonId),
    );
    if (raw == null) return null;

    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final Object? total = decoded['total'];
    final Object? groups = decoded['groups'];
    if (total is! String || groups is! List) return null;

    final parsed = <ExamDraftGroup>[];
    for (final entry in groups) {
      if (entry is! List || entry.length != 3) return null;
      final Object? count = entry[0];
      final Object? points = entry[1];
      final Object? correct = entry[2];
      if (count is! String || points is! String || correct is! String) {
        return null;
      }
      parsed.add(
        ExamDraftGroup(count: count, points: points, correct: correct),
      );
    }
    // A draft whose groups all failed to read back has nothing worth showing.
    if (parsed.isEmpty) return null;

    return ExamDraft(total: total, groups: parsed);
  }

  Future<void> _writePending() async {
    final int? lessonId = _pendingLessonId;
    final ExamDraft? draft = _pendingDraft;
    _pendingLessonId = null;
    _pendingDraft = null;
    if (lessonId == null || draft == null) return;

    await _preferences.setString(
      ExamDraftStore.keyFor(lessonId),
      jsonEncode(<String, Object?>{
        'total': draft.total,
        'groups': <Object?>[
          for (final group in draft.groups)
            <String>[group.count, group.points, group.correct],
        ],
      }),
    );
  }
}
