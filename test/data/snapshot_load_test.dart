import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';


import 'package:ather/data/db/app_database.dart';
import 'package:ather/data/repositories/drift_study_repository.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/services/mastery_calculator.dart';
import 'package:ather/domain/services/summaries.dart';

import '../support/year_fixture.dart';

// The whole point of this file is to leave numbers in the CI log: the
// `[P2-07]` lines printed below are the baseline record AUDIT_PLAN P2-07
// asks the repository to keep. Here printing is the feature, not a leftover.
// ignore_for_file: avoid_print

/// P2-07 -- the load test the audit plan asks for before deciding whether
/// `_buildSnapshot` must leave the UI isolate (`Isolate.run`, effort L).
///
/// What this file does:
///
/// 1. Plants a full school year (600 lessons / 3000 exams / two question
///    groups per exam) through the *real* write path --
///    `DriftStudyRepository.restore(StudyBackup...)` -- into an in-memory
///    SQLite database. No raw SQL anywhere.
/// 2. Asserts the record survives at volume: row counts, and `overallMastery`
///    equal to the hand-computed 82.5 (worked out in `year_fixture.dart`).
///    If any layer drops or duplicates rows at scale, 82.5 stops being 82.5.
/// 3. Times the three costs the audit's P1 finding is about, three runs each,
///    and prints the averages prefixed `[P2-07]` so CI keeps a greppable,
///    dated baseline in its log (a baseline number recorded in the repo).
///
/// **How to read the numbers -- and how not to.** These run on desktop-class
/// CI hardware, JIT-debug mode, with SQLite in memory on the *same* isolate.
/// They measure the shape of the cost (does it explode? does it grow with the
/// record?), not what a student's phone feels. The device truth comes from the
/// DevTools recipe in the closing comment below. That is why the assertions
/// are deliberately soft: guards against outright explosion only, never a
/// performance budget enforced with `expect`. A budget here would fail CI on
/// a slow runner for reasons that say nothing about the app.
void main() {
  late AppDatabase db;
  late DriftStudyRepository repo;

  setUpAll(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = DriftStudyRepository(db);

    final sw = Stopwatch()..start();
    await repo.restore(buildYearBackup());
    sw.stop();
    // Context, not a measurement target: restore is a one-off migration-style
    // write, not the per-keystroke path P1 is about.
    print(
      '[P2-07] fixture restored ($kFixtureLessonCount lessons / '
      '$kFixtureExamCount exams) in ${sw.elapsedMilliseconds} ms',
    );
  });

  tearDownAll(() async => db.close());

  test('the year-sized record restores intact and sums to 82.5', () async {
    final snapshot = await repo.readSnapshot();

    expect(snapshot.subjects, hasLength(kFixtureSubjects));
    expect(snapshot.chapters, hasLength(kFixtureChapterCount));
    expect(snapshot.lessons, hasLength(kFixtureLessonCount));
    expect(snapshot.exams, hasLength(kFixtureExamCount));

    // Two realistic question groups per exam -- the wizard never writes a
    // bare exam, so the load test should not carry bare exams either. The
    // denormalised percentage must also agree with its groups (closeTo:
    // earned/possible*100 carries float noise the stored literal does not).
    var groupCount = 0;
    for (final exam in snapshot.exams) {
      groupCount += exam.groups.length;
      expect(exam.groups, isNotEmpty);
      expect(
        ExamEntry.percentageOf(exam.groups),
        closeTo(exam.percentage, 1e-9),
      );
    }
    expect(groupCount, kFixtureExamCount * 2);
    expect(snapshot.homework, hasLength(kFixtureLessonCount));

    final dash = Summaries.dashboard(snapshot, kFixtureNow);
    expect(dash.totalChapters, kFixtureChapterCount);
    expect(dash.masteredChapters, 0, reason: 'no chapter was ever closed');
    expect(dash.overdueCount, kFixtureOverdueCount);
    expect(dash.upcomingReviews, kFixtureUpcomingReviews);
    expect(dash.lessonsRemaining, 0, reason: 'every lesson examined at 82.5');

    // The hand-computed number. closeTo because the 0.7/0.3 weights are not
    // exact binary fractions -- the result carries a few ulps of noise.
    expect(dash.overallMastery, closeTo(kFixtureOverallMastery, 1e-6));
    // And the official standalone interface agrees with what the student sees.
    expect(
      MasteryCalculator.overallMastery(snapshot),
      closeTo(kFixtureOverallMastery, 1e-6),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('measured costs at year size, averaged over three runs', () async {
    Future<void> settle() => Future<void>.delayed(kSnapshotCoalesceWindow * 3);

    final warmup = await repo.readSnapshot();
    Summaries.dashboard(warmup, kFixtureNow);
    // One unmeasured pass so the first measured rep is not paying JIT
    // warm-up. Warm-up is methodology, not one of the three reported runs.
    await repo.watchSnapshot().first.timeout(const Duration(minutes: 1));
    await settle();

    final readMs = <double>[];
    final dashboardMs = <double>[];
    final watchMs = <double>[];

    for (var rep = 1; rep <= 3; rep++) {
      // (a) The SQL reads plus `_buildSnapshot` -- the mapping, grouping and
      // sorting work the audit flags as O(all rows) on the UI isolate.
      var sw = Stopwatch()..start();
      final snapshot = await repo.readSnapshot();
      sw.stop();
      readMs.add(sw.elapsedMilliseconds.toDouble());
      expect(snapshot.exams, hasLength(kFixtureExamCount));

      // (b) The pure summary pass every write triggers while the dashboard
      // lives (AppShell keeps `dashboardProvider` alive -- audit section 1).
      sw
        ..reset()
        ..start();
      Summaries.dashboard(snapshot, kFixtureNow);
      sw.stop();
      dashboardMs.add(sw.elapsedMilliseconds.toDouble());

      // (c) First emission on the watch path: stream setup + six initial
      // SELECTs + the 16 ms coalesce window + `_buildSnapshot`. The window is
      // part of what any listener pays, so it stays inside the measurement.
      sw
        ..reset()
        ..start();
      final emitted =
          await repo.watchSnapshot().first.timeout(const Duration(minutes: 1));
      sw.stop();
      watchMs.add(sw.elapsedMilliseconds.toDouble());
      expect(emitted.lessons, hasLength(kFixtureLessonCount));

      await settle();
    }

    double avg(List<double> xs) {
      var total = 0.0;
      for (final x in xs) {
        total += x;
      }
      return total / xs.length;
    }

    String runs(List<double> xs) =>
        xs.map((x) => x.toStringAsFixed(1)).join(' / ');

    print(
      '[P2-07] (a) readSnapshot -> _buildSnapshot : '
      'runs ${runs(readMs)} ms | avg ${avg(readMs).toStringAsFixed(1)} ms',
    );
    print(
      '[P2-07] (b) Summaries.dashboard            : '
      'runs ${runs(dashboardMs)} ms | avg ${avg(dashboardMs).toStringAsFixed(1)} ms',
    );
    print(
      '[P2-07] (c) watchSnapshot first emission   : '
      'runs ${runs(watchMs)} ms | avg ${avg(watchMs).toStringAsFixed(1)} ms '
      '(includes the ~16 ms coalesce window)',
    );

    // Explosion guards, nothing more. Read the real numbers from the CI log
    // above and compare them against previous runs there; these thresholds
    // exist so a catastrophic regression fails loudly instead of silently
    // re-baselining. They are orders of magnitude above any honest budget.
    expect(avg(readMs), lessThan(5000),
        reason: 'snapshot build exploded at year size');
    expect(avg(dashboardMs), lessThan(5000),
        reason: 'dashboard summary exploded at year size');
    expect(avg(watchMs), lessThan(5000),
        reason: 'watch path exploded at year size');
  });

  // Measuring on hardware that matters -- the recipe AUDIT_PLAN P2-07 and
  // `.audit/04-performance.md` section 2 prescribe, which no CI run can
  // replace:
  //
  // 1. `flutter run --profile` on a **real** device, ideally a cheap Android
  //    one -- that is the population this product serves.
  // 2. Plant this same year-sized record on the device (restore the backup
  //    this fixture builds, via the settings backup-import path).
  // 3. Open DevTools > Performance, start recording.
  // 4. Tick a lesson checklist checkbox **10 consecutive times**; note the
  //    longest frame build time during the burst.
  // 5. Repeat on a small record (fresh install). **The difference between
  //    the two is the P1 number** -- the cost that grows with the record.
  // 6. For attribution, temporarily (never commit this) wrap the body of
  //    `_buildSnapshot` in `Timeline.startSync('buildSnapshot')` /
  //    `finishSync` and read its slice in the trace; do the same around
  //    `Summaries.dashboard` if step 4 still looks heavy after moving the
  //    build off-thread.
  // 7. Decision rule from the plan: if the recorded frames exceed budget,
  //    move `_buildSnapshot` to `Isolate.run` inside `_combineLatest6`
  //    (effort L); otherwise record the baseline here and stop. Either way,
  //    paste the device numbers next to the CI averages this test prints --
  //    the ratio is the honest mobile/desktop correction factor.
}
