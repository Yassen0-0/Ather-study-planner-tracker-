# Maintainability Audit

Phase 1, read-only. Repo at commit d8ff4e0 (branch ai-audit/2026-08-25). ~112 Dart files under `lib/`.

Scope: duplication, god files, scattered policy numbers, missing/over abstractions, layering, naming, testability. Generated files (`*.g.dart`, `lib/core/l10n/generated/*`) excluded.

**Overall shape:** this codebase is well above average for its size. Layering is clean (nothing in `domain/` imports Flutter; nothing in `core/` imports domain/data; presentation reaches data only through the provider composition root), the sacred drift file is exemplary, and most large screens are already decomposed into private widget classes with real seams. The findings below are therefore mostly about **policy duplicated into a second copy that no test pins to the first**, plus a handful of hand-wired flows repeated per screen. No P0s found.

## Findings

### M1 — The mastery formula is re-implemented with literal weights inside InsightsGenerator · **P1**

- File:line: `lib/domain/services/insights_generator.dart:476-492` (esp. :491); authority at `lib/domain/services/mastery_calculator.dart:12-20`
- Evidence:
  ```dart
  // insights_generator.dart:491
  return latest.percentage * 0.7 + (previousTotal / previousCount) * 0.3;
  ```
  while the formula's home declares:
  ```dart
  // mastery_calculator.dart:18-19
  /// Changing either number rewrites every figure in the app at once -- a
  /// product decision, not a tweak.
  const double kRecentWeight = 0.7;
  const double kHistoryWeight = 0.3;
  ```
  The comment on `_masteryAt` itself admits the coupling: "The arithmetic is identical to `MasteryCalculator.lessonMastery`" (`:472-475`). This function feeds both the "you improved" insight and the entire analytics trajectory chart via `subjectMasteryAsOf` → `MasteryTrends`.
- Maintenance cost: changing the 70/30 weighting — explicitly framed as a live product decision — requires editing two files in two layers of the same service folder. Miss one and the dashboard says a lesson is at 65 while the trajectory chart and the insight card derive from the old weights, silently; nothing fails. The tests do not pin the copies together: `test/domain/insights_generator_test.dart` hardcodes expected values (`closeTo(50)`, `closeTo(90)`, `closeTo(15)`) derived from the *same duplicated literals*, so updating only `_masteryAt`'s neighbours leaves every insight test green against a stale formula. Note the contrast: `Summaries.dashboard`'s inline mean *does* have a parity contract test (`mastery_calculator_test.dart`, named in the source at `mastery_calculator.dart:126-131`) — this copy is the one that slipped through without one.
- Proposed fix: make `MasteryCalculator._masteryFromSorted` public as e.g. `masteryFromNewestFirst(List<ExamEntry>)` (documented "caller guarantees newest-first", matching what `examsFor` + date-filter already provide), and have `_masteryAt` filter then delegate. Add one parity test asserting `_masteryAt(exams, future)` ≡ `lessonMastery(exams)` over shared fixtures.
- Risk of fix: low. Pure refactor of a pure function; the performance note at `:462-470` (no defensive copy in the innermost loop) is preserved by delegation without copying. Existing insight/trajectory expectations are unchanged because the arithmetic is identical today.

### M2 — Mastery band boundaries re-implemented as raw literals in the exam wizard and the palette · **P1**

- File:line: `lib/presentation/exam_entry/exam_entry_screen.dart:647-659, 664-672, 804, 824-827`; `lib/core/theme/mastery_palette.dart:38,42`; authority at `lib/domain/entities/mastery.dart:1-26`
- Evidence — mastery.dart claims to be the single source of truth:
  ```dart
  // mastery.dart:3-5
  /// This is the single source of truth for the four bands. Every colour, label
  /// and threshold check in the app goes through here -- no screen re-implements
  /// `if (mastery < 50)`.
  ```
  and the wizard immediately re-implements it eight times:
  ```dart
  // exam_entry_screen.dart:647-659
  final String? verdict = switch (after) {
    < 50 => l.examVerdictWeak,
    < 70 => l.examVerdictPassed,
    _ => null,
  };
  final Color? verdictColor = switch (after) {
    < 50 => context.colors.wrong,
    < 70 => context.colors.textSecondary,
    _ => null,
  };
  ```
  plus `after < 70` again at `:670`, `:804`, `:824`, `:826` (where 70 is `kChapterMasteryThreshold`), and the palette does it twice more: `if (percentage < 50) return colors.wrong; if (percentage >= 90) return colors.rightText;` (`mastery_palette.dart:38,42`). Relatedly, the fill-vs-text colour demotion ("a verdict printed as body text uses `wrongText`, not `wrong`") is a per-call-site decision: private `_verdictText` at `analytics_screen.dart:169-170`, hand-inlined at `dashboard_screen.dart:409-415` and `status_chip.dart:42,71`.
- Maintenance cost: the band edges are product policy (PROJECT.md §4: `<50 ضعيف · 50–69 متوسط · 70–89 كويس · ≥90 متفوق`). Moving the weak boundary from 50 to 40 — exactly the kind of decision an owner iterates on — means touching three files (`mastery.dart`, `exam_entry_screen.dart`, `mastery_palette.dart`); miss the wizard and step 4 calls a 45% paper «متوسط» while every other screen calls it «ضعيف», on the one screen a student sees seconds after the bad exam. The claim in mastery.dart's own doc comment is false as written, which is worse than having no claim: it tells the next agent a check exists that does not.
- Proposed fix: route all three sites through `MasteryBand.fromPercentage`: wizard verdicts become a `switch (MasteryBand.fromPercentage(after))`; `MasteryPalette.resolve` branches on the band (weak → wrong, excellent → rightText, else neutral). Add the text-grade demotion beside it (e.g. `MasteryPalette.textFor(colors, resolved)`) and delete `_verdictText`. Extend `test/design_invariants_test.dart` or a small unit test asserting palette and band cannot disagree.
- Risk of fix: low. Boundaries are numerically identical today; goldens and the existing band tests cover settled frames. The only care point is that `resolve` collapses medium/good into one branch — expressing that as `case medium || good` keeps behaviour byte-equal.

### M3 — The add/rename/delete entity flow is hand-wired per screen, five-plus copies · **P2**

- File:line:
  - edit-sheet wiring: `lesson_screen.dart:46-88`, `chapter_screen.dart:83-119`, `tasks_screen.dart:63-102`, variant sheet at `subjects_screen.dart:151-224`
  - rename prompt+write: `lesson_screen.dart:57-71`, `chapter_screen.dart:90-104`, `tasks_screen.dart:74-88`, `subjects_screen.dart:263-278`
  - add prompt+write: `subject_screen.dart:36-54`, `chapter_screen.dart:63-81`, `subjects_screen.dart:98-110`, `dashboard_screen.dart:555-573`, `tasks_screen.dart:42-61`
- Evidence (the same ~15 lines, four times verbatim apart from identifiers):
  ```dart
  // chapter_screen.dart:90-104 — also lesson_screen.dart:57-71, tasks_screen.dart:75-87
  onRename: () async {
    final name = await showNamePrompt(
      context,
      title: l.renameChapter,
      hint: l.chapterNameHint,
      initialValue: summary.chapter.name,
    );
    if (name == null || !context.mounted) return;
    await runWrite(
      context,
      () => ref.read(studyRepositoryProvider)
          .renameChapter(chapterId: chapterId, name: name),
    );
  },
  ```
  The primitives themselves are excellent (`showNamePrompt`, `showEditSheet`, `confirmDestructive`, `runWrite` in `prompts.dart` / `write_guard.dart`) — what is duplicated is the wiring around them.
- Maintenance cost: any change to the flow's contract fans out across five files. Example: enforcing one name-length policy (today `maxLength: 80` lives only in the prompt at `prompts.dart:102`, unknown to the four rename call sites and the repository trims independently) means editing every site; adding a sixth entity type (e.g. a sub-unit under a chapter) copies another ~60 lines of scaffold. It also already shows hairline drift: subjects delete *without* confirmation (`subjects_screen.dart:201-218`, deliberately) while lessons/chapters/tasks confirm — correct per design, but nothing names the difference, so each new entity re-decides it from scratch.
- Proposed fix: one helper in `presentation/common/`, e.g. `Future<void> runEntityEditFlow(context, ref, {title, initial, renameLabel, deleteLabel, deleteConfirmMessage?, required Future<void> Function(String newName) rename, required Future<void> Function() delete})` wrapping showEditSheet→prompt→runWrite and confirmDestructive→runWrite→pop-on-success. Migrate the three identical sites first; leave the subject sheet special-cased.
- Risk of fix: low-medium. Behaviour-preserving for chapters/lessons/tasks; context-mounting and pop-on-success ordering must be preserved (the comments at `lesson_screen.dart:83-85` encode why pop is gated on success).

### M4 — Backup payload assembly duplicated between cloud sync and file export · **P2**

- File:line: `lib/presentation/providers/backup_providers.dart:121-153`; `lib/presentation/providers/export_providers.dart:64-71`
- Evidence (both build "snapshot + tasks + events" the same way):
  ```dart
  // backup_providers.dart:121-152 (flush)
  final snapshot = await ref.read(snapshotProvider.future);
  final tasks = await ref.read(tasksProvider.future);
  ...
  final events = await ref.read(studyRepositoryProvider).readEvents();
  await ref.read(backupRepositoryProvider)
      .upload(StudyBackup.fromSnapshot(snapshot, tasks, events: events));

  // export_providers.dart:64-71 (_buildBackup)
  final snapshot = await ref.read(snapshotProvider.future);
  final tasks = await ref.read(tasksProvider.future);
  final events = await ref.read(studyRepositoryProvider).readEvents();
  return StudyBackup.fromSnapshot(snapshot, tasks, events: events);
  ```
  Both carry near-identical essays on why `.future` must be used instead of the value providers.
- Maintenance cost: `StudyBackup` grew once already (events joined in v4 of the format). The next growth — profile fields (already anticipated in `app_providers.dart:255-256`: "it rides in the existing StudyBackup blob"), or any new table — must be added in both places; forgetting export produces a cloud backup that contains data the student's own file export omits (or vice versa), and neither failure has a test that compares the two paths.
- Proposed fix: extract `buildStudyBackup(Ref ref)` (or a small `BackupPayloadAssembler` provider) owning the three awaits + `fromSnapshot`, called by both notifiers. The `.future` rationale gets written once.
- Risk of fix: low. Same awaits, same order; `backup_flush_test.dart` and `data_export_test.dart` cover both consumers.

### M5 — Account-deletion wipe sequence written twice in SettingsScreen · **P2**

- File:line: `lib/presentation/settings/settings_screen.dart:733-740` and `:744-759`
- Evidence:
  ```dart
  // _deleteEverything (:733-740)
  await ref.read(backupSyncProvider.notifier).flush();
  await ref.read(studyRepositoryProvider).clear();
  await ref.read(taskRepositoryProvider).clearTasks();
  await ref.read(backupRepositoryProvider).deleteCloudData();
  await repository.deleteAccount();

  // _retryWithPassword (:744-759) — same sequence minus the flush
  await ref.read(studyRepositoryProvider).clear();
  await ref.read(taskRepositoryProvider).clearTasks();
  await ref.read(backupRepositoryProvider).deleteCloudData();
  await repository.deleteAccountWithPassword(_reauthPassword!);
  ```
- Maintenance cost: this is the most destructive sequence in the app and it exists twice. When a third store appears (the pattern is already: study repo, task repo, cloud mirror), whoever adds it must remember both lists; getting one wrong leaves a half-wiped device whose retry path then finishes the job differently than the first attempt would have. The two copies have *already* diverged once (flush present/absent) — documented, but the divergence is exactly the kind of context that gets lost.
- Proposed fix: one `Future<void> _wipeDeviceAndCloud({required Future<void> Function() deleteAccount})` taking the account-deletion step as a closure; both paths pass their variant.
- Risk of fix: low. Ordering is preserved by construction; `delete_account_test.dart` already asserts the order and will catch a regression.

### M6 — Share/rasterise error scaffolding triplicated, and PdfExportService bypasses the provider seam · **P2**

- File:line: `chapter_screen.dart:186-213`; `dashboard_screen.dart:228-256`; `chapter_report_screen.dart:50-121` (direct instantiation at `:96`)
- Evidence (three copies of busy-guard + overlay/direction capture + try/catch + debugPrint + failed toast):
  ```dart
  // dashboard_screen.dart:228-256, likewise chapter_screen.dart:190-212
  if (_sharing) return;
  final l = L.of(context);
  final overlay = Overlay.of(context, rootOverlay: true);
  final direction = Directionality.of(context);
  setState(() => _sharing = true);
  try {
    await shareMasteryCard(...);
  } on Object catch (error, stack) {
    debugPrint('Ather: progress card failed -- $error');
    debugPrintStack(stackTrace: stack);
    if (mounted) {
      showAtherToastOn(overlay, direction, l.shareCardError, tone: ToastTone.failed);
    }
  } finally { if (mounted) setState(() => _sharing = false); }
  ```
  And the report screen news up its dependency directly:
  ```dart
  // chapter_report_screen.dart:96
  const service = PdfExportService();
  ```
  while its sibling `DataExportService` goes through `dataExportServiceProvider` (`export_providers.dart:8-10`).
- Maintenance cost: the capture-before-await rule (why the overlay and direction are grabbed first) is load-bearing and currently re-typed at each site; a fourth share surface copies it again, and one day one copy will forget it. The direct `PdfExportService()` is inconsistent wiring: it cannot be stubbed via provider override in a widget test, so report-export tests must either hit real PDF code or skip the path — a seam the rest of the app deliberately keeps open.
- Proposed fix: a `runShareAction(BuildContext, WidgetRef, {required Future<void> Function() action, required String failureMessage})` helper owning guard/capture/toast/busy; register `pdfExportServiceProvider` alongside `dataExportServiceProvider` and read it in the report screen.
- Risk of fix: low. Mechanical extraction; the three callers keep their distinct success messages. Tests unaffected except gaining the ability to stub the PDF service.

### M7 — Subject filter chip row implemented twice · **P2**

- File:line: `analytics_screen.dart:269-306` (`_FilterRow`) vs `review_center_screen.dart:146-193` (`_SubjectChips`)
- Evidence (identical skeleton: `SizedBox(height: 38)`, horizontal `ListView`, "all" chip, per-subject chips with `AppSpacing.xs` gaps):
  ```dart
  // review_center_screen.dart:171-191
  return SizedBox(
    height: 38,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: <Widget>[
        AtherFilterChip(
          label: l.analyticsAllSubjects,
          selected: selected == null,
          onTap: () => onSelect(null),
        ),
        for (final subject in subjects) ...<Widget>[
          const SizedBox(width: AppSpacing.xs),
          AtherFilterChip(
            label: subject.label(l),
            selected: selected == subject.id,
            onTap: () => onSelect(subject.id),
          ),
        ],
      ],
    ),
  );
  ```
  Both screens also carry the same `int? _subjectFilter` state with the same null-sentinel meaning (`analytics_screen.dart:44-46`, `review_center_screen.dart:45-46`). The review-center copy's doc comment even introduces itself as "The analytics screen's filter row, given one job here" (`:139`).
- Maintenance cost: a styling or semantics change to filtering (height, adding a count badge, swapping the sentinel for a dedicated "all" id) edits two screens; they are one comment away from drifting, and the comment is the only thing recording that they are twins.
- Proposed fix: move a parameterised `SubjectFilterChips` (taking `List<Subject> chips`, `int? selected`, callback) into `presentation/common/`. Each screen keeps its own rule for *which* subjects appear (all active vs queue-derived) — only the chrome is shared.
- Risk of fix: low. Pure widget lift; both screens' tests assert chip behaviour and will verify parity.

### M8 — "المادة · الباب" breadcrumb assembled inline in three places · **P2**

- File:line: `review_center_screen.dart:130-137` (`_crumb`); `dashboard_screen.dart:680-685` (`_NextCard`); `lesson_screen.dart:109-112`
- Evidence:
  ```dart
  // review_center_screen.dart:133-136 — also dashboard_screen.dart:682-685, lesson_screen.dart:109-112
  return <String>[
    if (subject != null) subject.label(l),
    if (chapter != null) chapter.name,
  ].join(' · ');
  ```
- Maintenance cost: three hand-rolled copies of one display rule. Changing the separator, dropping the subject when it equals the header, or localising the join order means finding all three (they sit in three different files with no shared name to grep for beyond `' · '`).
- Proposed fix: `String locationCrumb(L l, StudySnapshot snapshot, {int? subjectId, int? chapterId})` in `presentation/common/subject_presentation.dart` (which already exists as the home of subject display rules).
- Risk of fix: trivial.

### M9 — Stale documentation claims subjects are fixed and undeletable · **P2**

- File:line: `lib/presentation/subject/subject_screen.dart:28-30`; context: `app_database.dart:37-39` (schema v3 added name/archive/delete columns), `dashboard_screen.dart:513-525`, `settings_screen.dart:53-55`, PROJECT.md §1
- Evidence:
  ```dart
  // subject_screen.dart:28-30
  /// One subject: its overall figure, then the chapters the student built inside
  /// it. Subjects are fixed and cannot be added, renamed or deleted, so this
  /// screen has no subject-level actions at all.
  ```
  This contradicts the codebase it sits in: `createSubject`/`renameSubject`/`setSubjectArchived`/`setSubjectDeleted`/`purgeSubject` exist in the repository (`drift_study_repository.dart:127-194`), the dashboard carries `_AddSubjectButton` (`dashboard_screen.dart:525`), and Settings hosts full subject management plus a recycle bin. PROJECT.md §1 still says "Exactly four subjects, fixed and seeded, with no subject-management UI".
- Maintenance cost: CLAUDE.md Rule 2 instructs agents to trust documents over their assumptions, and PROJECT.md is declared "the design source of truth". An agent told "read PROJECT.md first" and then reading this screen's header receives three contradictory answers about whether subjects are mutable; the cheapest outcome is a wasted pass, the expensive one is "fixing" the recycle bin or re-adding seed-on-open (which `_seedSubjects`' comment at `app_database.dart:135-141` documents as a past incident with real blast radius). The newer files know the truth; the two entry-point documents do not.
- Proposed fix: rewrite `subject_screen.dart:28-30` to describe the screen only ("this screen performs no writes; management lives in Settings → Subjects"); update PROJECT.md §1/§4 to record the v3 pivot (four seeds remain on fresh install; students may add, archive, bin) the way §3.31 recorded the delete-exam pivot.
- Risk of fix: none — prose only. Do not touch schema or seed logic.

### M10 — Dead indirection seams: unused typedef and unused test-escape provider · **P2**

- File:line: `lib/domain/services/review_cycle_service.dart:378-380`; `lib/presentation/providers/app_providers.dart:31-32`
- Evidence:
  ```dart
  // review_cycle_service.dart:378-380
  /// Re-exported so callers touching review logic do not also need to import
  /// the exam entity just for [DraftQuestionGroup].
  typedef ExamDraftGroup = DraftQuestionGroup;
  ```
  Zero references anywhere in `lib/` or `test/` besides the declaration — the wizard imports `DraftQuestionGroup` from the entity directly (`exam_entry_screen.dart:27,363-370`).
  ```dart
  // app_providers.dart:31-32
  /// Escape hatch for tests that want to supply their own executor.
  final databaseExecutorProvider = Provider<QueryExecutor?>((ref) => null);
  ```
  Zero references in `test/` — every test overrides `databaseProvider.overrideWithValue(db)` directly (e.g. `test/widget/exam_wizard_test.dart:487`).
- Maintenance cost: each is a small lie of intent. The typedef promises a caller pattern that never happened, so readers waste a hop looking for the "callers touching review logic" it serves. The executor provider advertises a second way to swap the database that nothing exercises — the next person writing a test must discover by reading riverpod docs that overriding `databaseProvider` is the real mechanism, and the unused provider implies the alternative is supported when it is untested.
- Proposed fix: delete both (and the `QueryExecutor` import at `app_providers.dart:3` if it becomes unused).
- Risk of fix: none — provably unreferenced at this commit.

### M11 — ExamEntryScreen embeds a SharedPreferences JSON persistence protocol inside widget State · **P2**

- File:line: `lib/presentation/exam_entry/exam_entry_screen.dart:110-247` (draft block: key scheme `:119`, restore `:129-171`, persist `:183-203`, clear `:207-209`)
- Evidence:
  ```dart
  // exam_entry_screen.dart:183-202
  void _persistDraft() {
    if (_saving) return;
    unawaited(
      ref.read(sharedPreferencesProvider).setString(
            _draftKey,
            jsonEncode(<String, Object?>{
              'total': _total.text,
              'groups': <Object?>[
                for (final group in _groups)
                  <String>[group.count.text, group.points.text, group.correct.text],
              ],
            }),
          ),
    );
  }
  ```
  Restore mirrors it with a hand-rolled decoder tolerant of truncation and old shapes (`:135-162`). This is the file's third concern alongside the step machine (`_next`/`_back`/`_save`) and four steps of UI — 1254 lines total, the largest non-generated file in `lib/`.
- Maintenance cost: the draft format is a storage protocol (per-lesson keys accumulate in prefs; the decode rules decide what a truncated or older-format draft does) but it can only be tested by pumping the whole wizard — there is no unit seam where "restore these bytes into these fields" runs without Flutter binding, and the format's edge cases (empty groups list, non-string entries, `FormatException`) are exercised only incidentally through `exam_wizard_test.dart`. Any change to what the draft saves (e.g. adding the step position, or the lesson's expected-total hint) edits protocol code in the middle of UI code.
- Proposed fix: extract an `ExamDraftStore` (pure class: `save(int lessonId, ExamDraft)`, `load(int lessonId) -> ExamDraft?`, `clear(int lessonId)`, taking `SharedPreferences` + json codec), leaving the State calling it. Unit-test the store directly; the widget tests keep covering the wiring.
- Risk of fix: low. Behaviour-preserving move; the deliberate silences ("no toast, ignore unreadable shapes wholesale") migrate as documented behaviour of the store. Keep the keystroke-frequency write (`:175-182`) semantics identical.

### M12 — DriftStudyRepository interleaves CRUD, snapshot assembly and the destructive restore/preserve machinery in one 1138-line file · **P2**

- File:line: `lib/data/repositories/drift_study_repository.dart` — restore region `:618-906` (`restore` `:619-753`, `_readCustomSubjectData` `:762-808`, `_reinsertCustomSubjectData` `:817-906`), id-remap helpers `:908-914`, mappers `:936-1000`, stream combiner `:1042-1138`
- Evidence: a single class implements subjects/chapters/lessons/exams/homework CRUD (`:124-614`), the six-stream snapshot builder (`:79-122`), the transactional restore that deletes-and-reinserts everything with cross-device id remapping (`:618-906`), account wipe (`:916-934`), row mappers, and a hand-rolled `_combineLatest6` with coalescing timer (`:1056-1138`). The restore half alone is ~340 lines whose correctness story (preserve custom-subject subtrees, reallocate ids past the backup's max, rewrite every foreign key) is unrelated to the CRUD half.
- Maintenance cost: this file is adjacent to the repo's one sacred invariant (Rule 1 migrations). Anyone verifying a schema bump must diff through restore machinery to reach the write paths that constrain migrations; conversely, changes to restore semantics (e.g. backup format growth, M4) land in a file whose other 700 lines invite unrelated merge conflicts. The seams exist — the restore region is already self-contained behind `_PreservedCustomData` — they are just not reflected in the file layout.
- Proposed fix: split into `drift_study_repository.dart` (interface + CRUD + snapshot) and `study_restore.dart` (restore + preserve/reinsert + `_PreservedCustomData`), either as a part-file of the same library or a collaborator taking `(AppDatabase, Clock)`. Move `_combineLatest6`/`kSnapshotCoalesceWindow` to `data/db/` where other stream plumbing would look for it.
- Risk of fix: low-medium. Part-file split is zero-risk (no visibility changes); a collaborator split touches test constructors (`drift_study_repository_test.dart` builds the repository directly). Do not touch any statement inside the transaction bodies — the ordering comments (`:616-643`) are load-bearing.

## Summary

| # | Finding | Sev | Files affected |
|---|---|---|---|
| M1 | Mastery formula re-implemented with literal 0.7/0.3 in insights/trajectories | P1 | 2 (+tests) |
| M2 | Band boundaries `<50`/`<70`/`≥90` re-implemented in wizard (8×) and palette | P1 | 3 |
| M3 | Add/rename/edit entity flow hand-wired in 4–5 screens | P2 | 5 |
| M4 | Backup payload assembly duplicated (cloud vs file export) | P2 | 2 |
| M5 | Account-wipe sequence written twice in SettingsScreen | P2 | 1 |
| M6 | Share error scaffolding ×3; PdfExportService bypasses provider seam | P2 | 3 |
| M7 | Subject filter chip row duplicated (analytics vs review center) | P2 | 2 |
| M8 | "Subject · chapter" crumb built inline ×3 | P2 | 3 |
| M9 | Stale docs claiming subjects are fixed (screen header + PROJECT.md §1) | P2 | 2 (prose) |
| M10 | Dead indirection: unused `ExamDraftGroup` typedef, unused executor provider | P2 | 2 |
| M11 | Wizard draft-persistence protocol embedded in widget State | P2 | 1 |
| M12 | Repository mixes CRUD/snapshot/restore in 1138 lines; restore is a ready seam | P2 | 1 |

**Counts: 0 × P0 · 2 × P1 · 10 × P2.**

Both P1s are the same disease at the core: the app's defining numbers (70/30 weighting, band edges) exist in a second untested copy. Everything else is contained duplication with existing primitives to build on. Layering, naming, migration discipline, and test harness design (fakes in `test/support/`, real-app boot with overridden providers) need no remediation.
