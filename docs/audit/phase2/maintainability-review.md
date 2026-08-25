# Phase 2 — Cross-Review: Maintainability

Reviewer: phase-2 cross-reviewer (did not author the reviewed report).
Input: `docs/audit/phase1/maintainability-auditor.md` (findings M1–M12).
Base verified against current tree at `c9a28ec` (code identical to `d8ff4e0`; only audit docs committed since — no staleness expected or found).
Method: every cited file:line opened and read; cross-greps run; dup sweep against `architecture-auditor.md`, `ai-slop-auditor.md`, `deadcode-auditor.md`; needs mapped to `docs/audit/phase0/PRIORITIZED_NEEDS.md`.
Read-only discipline kept: no file under `lib/`, `test/` touched.

## Summary stats

| Metric | Count |
|---|---|
| Findings reviewed | 12 |
| CONFIRMED | 9 |
| CONFIRMED (partial duplicate) | 2 (M6, M10) |
| DUPLICATE | 1 (M5) |
| FALSE-POSITIVE | 0 |
| STALE | 0 |
| Severity re-ranks | 1 downgrade (M1 P1→P2), rest upheld |

No finding was killed outright. One central evidence claim (M1's "nothing fails") is factually wrong and forces a severity downgrade. Two findings are substantially owned by other reports. The original report's quality is high: line cites were accurate to within ±1 line in every case I checked.

---

## Per-finding verdicts

### M1 — Mastery formula re-implemented with literal weights in InsightsGenerator · **CONFIRMED, downgraded P1 → P2**

- Claim: `_masteryAt` duplicates the 70/30 formula with raw literals (`insights_generator.dart:491`) while `kRecentWeight`/`kHistoryWeight` (`mastery_calculator.dart:12-20`) declare it product policy; tests hardcode expectations from the duplicated literals so "nothing fails" on drift.
- Evidence checked:
  - Duplication is real: `lib/domain/services/insights_generator.dart:491` reads `latest.percentage * 0.7 + (previousTotal / previousCount) * 0.3`; constants live at `lib/domain/services/mastery_calculator.dart:12,20`; the private `_masteryFromSorted` funnel is at `mastery_calculator.dart:79-89`. The "identical arithmetic" self-admission sits at `insights_generator.dart:472-475`.
  - **Report's cost story is wrong on one point:** `test/domain/insights_generator_test.dart:633-647` ("the last point equals the subject mastery shown everywhere else") pins `trajectory.points.last.mastery` to `MasteryCalculator.subjectMasteryOf(snap, 1)` over a non-degenerate fixture (50/90/72). Changing either copy's weight alone **fails this test loudly**. The claim "The tests do not pin the copies together … nothing fails" overlooked it.
  - What remains true: insight-delta tests (`:111`, `:219`, `:308`) do hardcode values from the literals, and parity covers only a trajectory endpoint, not intermediate points nor the insight path directly.
- Why downgrade: the headline risk (silent divergence between dashboard figure and trajectory chart) is already guarded by an existing test. What survives is ordinary duplication with a documented delegation seam — hygiene, not an active hazard.
- Severity + effort: **P2 / S**.
- N-id: NEW.
- Fix: expose `masteryFromNewestFirst(List<ExamEntry>)` from `MasteryCalculator`, delegate from `_masteryAt`, add a full-fixture parity test (endpoint pin already exists at `insights_generator_test.dart:633-647`; extend to all points).

### M2 — Band boundaries re-implemented as raw literals in wizard and palette · **CONFIRMED**

- Claim: `<50`/`<70`/`≥90` appear as raw literals in exam_entry_screen.dart (8×) and mastery_palette.dart (2×), violating `mastery.dart`'s own "single source of truth" doc claim.
- Evidence checked:
  - `lib/domain/entities/mastery.dart:3-5`: "Every colour, label and threshold check in the app goes through here -- no screen re-implements `if (mastery < 50)`." The claim is false as written.
  - `lib/presentation/exam_entry/exam_entry_screen.dart:647-659` (two switch blocks on `< 50`/`< 70` for verdict label and colour), `:670`, `:804`, `:824`, `:826` (`after < 70`). Verified by read + rg.
  - `lib/core/theme/mastery_palette.dart:38` (`percentage < 50`), `:42` (`percentage >= 90`).
  - No test pins these literals to `MasteryBand`: `rg 'MasteryBand|MasteryPalette' test/design_invariants_test.dart` → zero hits; only consumer of `fromPercentage` outside entities is `summaries.dart` (3 sites) — so routing wizard/palette through the band follows existing usage.
  - Text-grade demotion per call site confirmed: `_verdictText` at `lib/presentation/analytics/analytics_screen.dart:169-170`; inline `wrongText` at `lib/presentation/dashboard/dashboard_screen.dart:409-415` (this one carries its own documented owner decision — treat as a second call site, not a copy-paste error); `lib/core/widgets/status_chip.dart:42,71` (report omitted the `core/widgets/` path; content matches).
- Cost story holds: moving the weak edge touches 3 files across domain/presentation/core with zero guard, and the false doc comment actively instructs the next agent that a guard exists. Unlike M1, nothing pins this today.
- Severity + effort: **P1 / S–M** (upheld — policy numbers scattered across layers with a lying source-of-truth comment and no parity test; the one duplication class in this codebase with no safety net).
- N-id: NEW (same screen as N9/N10 but different defect).
- Fix: switch wizard verdicts on `MasteryBand.fromPercentage(after)`; make `MasteryPalette.resolve` branch on the band (weak→wrong, excellent→rightText, else neutral); add `textFor(colors, resolved)` beside `fill()` (which at `mastery_palette.dart:65-66` already models exactly this pattern); delete `_verdictText`; add a palette-vs-band unit test.

### M3 — Add/rename/delete entity flow hand-wired per screen · **CONFIRMED**

- Claim: showEditSheet→showNamePrompt→runWrite and confirmDestructive→runWrite→pop wiring copied across 5 screens.
- Evidence checked:
  - Rename+delete wiring verbatim apart from identifiers: `chapter_screen.dart:83-119` vs `lesson_screen.dart:46-85` (read side by side — identical shape incl. the pop-on-success gating comment at `lesson_screen.dart:83-85`), `tasks_screen.dart:69-102` (onRename :74, confirm :90).
  - Add-prompt copies: `subject_screen.dart:36-54` (read: showNamePrompt→runWrite→createChapter), `dashboard_screen.dart:564-567` (createSubject), plus tasks/dashboard cites.
  - Subjects variant: `lib/presentation/settings/subjects_screen.dart:151-224` (path differs from report's bare filename; content matches, incl. the deliberate no-confirmation delete comment block at ~:201-218).
  - Name-length policy claim: `maxLength: 80` exists only at `prompts.dart:102`; repositories trim independently (`drift_study_repository.dart:145,164,209,285`). Confirmed.
- Severity + effort: **P2 / M**.
- N-id: NEW (loosely adjacent to N10's lesson-template work — same screens benefit if entity scaffolding shrinks first).
- Fix: `runEntityEditFlow(...)` helper in `presentation/common/`; migrate chapters/lessons/tasks first, leave the settings subjects sheet special-cased.

### M4 — Backup payload assembly duplicated (cloud sync vs file export) · **CONFIRMED**

- Evidence checked: `backup_providers.dart:121-152` (flush: `.future` awaits ×2, events read, `StudyBackup.fromSnapshot`) vs `export_providers.dart:64-71` (`_buildBackup`: same three steps). Both carry near-identical `.future` rationale essays (`:104-119` vs `:55-63`). Growth-vector claim verified: `app_providers.dart:255-256` documents profile fields riding the existing blob.
- Cost story holds: next payload change must land twice; no test compares the two paths' outputs. Tests named exist: `test/widget/backup_flush_test.dart`, `test/data/export/data_export_test.dart` cover each side separately.
- Severity + effort: **P2 / S**.
- N-id: NEW, but implement alongside **N4** (the empty-record upload guard lives in this exact flush block — one edit session, two needs).
- Fix: extract `buildStudyBackup(Ref ref)` owning the three awaits + `fromSnapshot`; both notifiers call it.

### M5 — Account-deletion wipe sequence written twice in SettingsScreen · **DUPLICATE** (of architecture-auditor.md F-02)

- Evidence checked and correct: `settings_screen.dart:733-740` (`_deleteEverything`: flush→clear→clearTasks→deleteCloudData→deleteAccount) and `:744-759` (`_retryWithPassword`: same minus flush), divergence documented at `:743`. `test/widget/delete_account_test.dart` exists.
- Duplicate rationale: architecture report F-02 (P1) covers these exact lines **plus** the third wipe pair in `backup_gate.dart:91-92` and proposes the stronger fix (an account-cleanup orchestrator owning the sequence), whereas M5 proposes an in-screen closure helper that would leave backup_gate's copy out. Defer to F-02 wholesale; M5 adds nothing except a weaker remedy.
- Severity: inherits F-02's P1. Effort: S–M inside the architecture workstream.
- N-id: **N20-adjacent** (N20 adds another wipe obligation — clearing `exam_draft_*` prefs keys — which is precisely the "new store appears, find N lists by memory" cost both reports describe).
- Fix: as F-02 — single orchestrator; do not implement M5's narrower variant separately.

### M6 — Share/rasterise error scaffolding ×3; PdfExportService bypasses provider seam · **CONFIRMED (partial duplicate)**

- Evidence checked:
  - Scaffolding triplication real and verbatim-shaped: `chapter_screen.dart:186-213`, `dashboard_screen.dart:228-256` (read both: guard→overlay/direction capture→try/catch→debugPrint+debugPrintStack→failed toast→finally busy-clear), and the larger variant `chapter_report_screen.dart:50-121`.
  - `const PdfExportService()` confirmed at `chapter_report_screen.dart:96`; sibling seam `dataExportServiceProvider` at `export_providers.dart:8-10`.
- Duplicate portion: the PdfExportService seam half is **exactly architecture-auditor.md F-01 (P1)** — same file:lines, same fix (`pdfExportServiceProvider` beside `dataExportServiceProvider`). Credit and ownership go to F-01.
- Unique portion retained by this report: the share-scaffolding triplication and its load-bearing capture-before-await rule. Not found in any other phase1 report.
- Severity + effort: **P2 / S–M** (scaffolding half; the seam half rides F-01's P1).
- N-id: NEW.
- Fix: `runShareAction(context, {action, failureMessage})` helper in `presentation/share/` (where `shareMasteryCard` lives); provider registration handled under F-01.

### M7 — Subject filter chip row implemented twice · **CONFIRMED**

- Evidence checked: `analytics_screen.dart:269-306` (`_FilterRow`) vs `lib/presentation/review_center/review_center_screen.dart:146-193` (`_SubjectChips`) — identical chrome (SizedBox height 38, horizontal ListView, all-chip, per-subject chips with `AppSpacing.xs` gaps); twin `int? _subjectFilter` state (`analytics_screen.dart:44`, `review_center_screen.dart:46`); the twin-admitting doc comment verified at `review_center_screen.dart:139-140`. Which-subjects rules genuinely differ per screen, so only chrome should be lifted — report says exactly this.
- Severity + effort: **P2 / S**.
- N-id: NEW.
- Fix: parameterised `SubjectFilterChips` in `presentation/common/`; screens keep their subject-selection rules.

### M8 — "المادة · الباب" crumb assembled inline ×3 · **CONFIRMED**

- Evidence checked: `review_center_screen.dart:130-137`, `dashboard_screen.dart:680-685`, `lesson_screen.dart:108-112` — same `[if != null …].join(' · ')` three times, greppable only via `' · '`. Proposed home exists: `lib/presentation/common/subject_presentation.dart`.
- Severity + effort: **P2 / S (trivial)**.
- N-id: NEW.
- Fix: `String locationCrumb(L l, StudySnapshot snapshot, {int? subjectId, int? chapterId})` in subject_presentation.dart.

### M9 — Stale docs claiming subjects are fixed and undeletable · **CONFIRMED**

- Evidence checked:
  - `subject_screen.dart:28-30`: "Subjects are fixed and cannot be added, renamed or deleted…" — present verbatim, contradicted five ways in the same tree: repository mutators at `drift_study_repository.dart:127,154,168,177,189`; `_AddSubjectButton` at `dashboard_screen.dart:190,525`; settings header "Subject management lives here now" at `settings_screen.dart:53-54`; schema v3 note at `app_database.dart:37-39`; seed-incident warning at `app_database.dart:135-141`.
  - PROJECT.md §1 lines 67-68 still: "Exactly four subjects, fixed and seeded, with no subject-management UI."
- This is the documentation leg of phase0 **N13** ([DOC] reconcile PROJECT.md with shipped reality). Not a duplicate of another phase1 report, but N13 owns the PROJECT.md side; this finding supplies the screen-header cite.
- Severity + effort: **P2 / S** (prose only; explicitly no schema/seed touch — zero migration risk).
- N-id: **N13**.
- Fix: rewrite `subject_screen.dart:28-30` to describe the screen only; fold the v3 pivot into N13's PROJECT.md reconciliation.

### M10 — Dead indirection seams · **CONFIRMED (partial duplicate)**

- Evidence checked:
  - `ExamDraftGroup` typedef at `review_cycle_service.dart:378-380`: rg across lib/test/tool finds only its declaration. **Half-DUPLICATE of deadcode-auditor.md #5**, which proves the same thing and schedules deletion in its commit D.
  - `databaseExecutorProvider` at `app_providers.dart:31-32`: rg across lib/test/tool finds only the declaration; tests override `databaseProvider.overrideWithValue(db)` (verified `exam_wizard_test.dart:487`). This half is unique to this report (architecture-auditor.md:23 mentions the symbol only to clear it of layering blame). Note the deadcode report does NOT list it — worth adding there or deleting here.
- Severity + effort: **P2 / S (trivial)**. Deleting the provider also frees the `QueryExecutor` import at `app_providers.dart:3`.
- N-id: NEW.
- Fix: delete both declarations; coordinate with deadcode commit D for the typedef so nobody deletes it twice.

### M11 — Wizard draft persistence protocol embedded in widget State · **CONFIRMED**

- Evidence checked: draft block spans `exam_entry_screen.dart:110-247` as claimed — key scheme `:119` (`exam_draft_$lessonId`), tolerant decoder `:131-171` (FormatException swallow, shape checks, empty-groups bail — all read and confirmed), keystroke-frequency `_persistDraft` `:183-203`, `_clearDraft` `:207-209`. File is 1254 lines (wc -l). Decode rules are private to State — no unit seam exists; widget tests exercise them incidentally.
- Overlap note: same file as architecture F-05 (god-screen), different remedy (F-05 lifts widgets; M11 extracts the store). Complementary, not duplicate — sequence F-05's widget split and M11's store extraction as separate commits on the same file to avoid conflicts.
- Related: N20 needs to clear these exact keys on account wipe — an `ExamDraftStore.clearAll()` gives N20 a place to hook instead of key-scheme knowledge leaking into settings.
- Severity + effort: **P2 / M**.
- N-id: **N20-adjacent**, otherwise NEW.
- Fix: extract pure `ExamDraftStore(save/load/clear/clearAll)` taking SharedPreferences; State keeps wiring; unit-test the decode matrix directly.

### M12 — Repository interleaves CRUD, snapshot, restore machinery in 1138 lines · **CONFIRMED**

- Evidence checked: `drift_study_repository.dart` = 1138 lines (wc -l). Region map verified: snapshot builder `:79`, six-stream combine `:33` via `_combineLatest6` `:1056-1138` with `kSnapshotCoalesceWindow` `:1054`, `restore` `:619-753`, `_readCustomSubjectData` `:762-808`, `_reinsertCustomSubjectData` `:817-906`, `_PreservedCustomData` `:1006`, `clear()` `:917`. Restore region is genuinely self-contained behind `_PreservedCustomData` — the proposed seam exists in the code, just not in the file layout.
- Migration-risk ruling: the fix (part-file split or collaborator extraction) moves Dart code only; it does not touch `schemaVersion`, tables, or transaction bodies. **Not Rule-1-risky**, provided the instruction "do not touch any statement inside the transaction bodies" is treated as a hard gate. Prefer the part-file variant (`part 'study_restore.dart';`) — zero visibility changes, zero constructor churn in `drift_study_repository_test.dart`.
- Bonus: moving `_combineLatest6`/`kSnapshotCoalesceWindow` out of the repository also un-fuses the ai-slop S1 doc-comment tangle at the same lines — flag the coordination.
- Severity + effort: **P2 / M–L**.
- N-id: NEW (becomes more valuable if M4/N4/N15 grow the backup payload and restore semantics change).
- Fix: split restore machinery into a part-file `study_restore.dart`; relocate stream plumbing to `data/db/`.

---

## Re-ranked severity table

| # | Verdict | Final sev | Effort | N-id | Dup sweep |
|---|---|---|---|---|---|
| M1 | CONFIRMED (cost claim corrected) | **P2** ↓ | S | NEW | — |
| M2 | CONFIRMED | **P1** | S–M | NEW | — |
| M3 | CONFIRMED | P2 | M | NEW | — |
| M4 | CONFIRMED | P2 | S | NEW (~N4) | — |
| M5 | DUPLICATE | (F-02 P1) | S–M | N20-adj | arch F-02 |
| M6 | CONFIRMED (partial dup) | P2 (+F-01 P1 half) | S–M | NEW | arch F-01 |
| M7 | CONFIRMED | P2 | S | NEW | — |
| M8 | CONFIRMED | P2 | S | NEW | — |
| M9 | CONFIRMED | P2 | S | **N13** | — |
| M10 | CONFIRMED (half dup) | P2 | S | NEW | deadcode #5 (typedef half) |
| M11 | CONFIRMED | P2 | M | N20-adj | arch F-05 same-file, complementary |
| M12 | CONFIRMED | P2 | M–L | NEW | ai-slop S1 same lines, coordinate |

Counts: 0 × P0 (agreed with the original report — no god-file blocks a known P0 fix) · 1 × P1 (M2) · 11 × P2-equivalent.

## Workstream proposal

**Workstream name:** `policy-single-sourcing` — collapse the app's defining numbers and payload/wipe sequences into their declared homes, then the mechanical dedups.

**File set an implementer owns:**
- `lib/domain/services/mastery_calculator.dart`, `lib/domain/services/insights_generator.dart`
- `lib/domain/entities/mastery.dart`, `lib/core/theme/mastery_palette.dart`
- `lib/presentation/exam_entry/exam_entry_screen.dart`
- `lib/presentation/providers/backup_providers.dart`, `lib/presentation/providers/export_providers.dart`
- `lib/presentation/analytics/analytics_screen.dart`, `lib/presentation/review_center/review_center_screen.dart`, `lib/presentation/dashboard/dashboard_screen.dart`, `lib/presentation/lesson/lesson_screen.dart`, `lib/presentation/chapter/chapter_screen.dart`, `lib/presentation/tasks/tasks_screen.dart`, `lib/presentation/subject/subject_screen.dart`, `lib/presentation/settings/subjects_screen.dart`
- `lib/data/repositories/drift_study_repository.dart` (+ new part-file `study_restore.dart`)
- Tests touched: `test/domain/insights_generator_test.dart`, new band/palette parity test, `test/widget/exam_wizard_test.dart` (draft-store wiring), existing suites stay green.

**Ordered fix sequence:**
1. M2 band single-sourcing (P1, no guard today): route wizard verdicts + palette through `MasteryBand.fromPercentage`, add parity test, fix the false `mastery.dart:3-5` doc. Behaviour-identical numerically.
2. M1 delegation: public `masteryFromNewestFirst`, `_masteryAt` delegates, extend parity beyond trajectory endpoint. Pure-function refactor.
3. M4 payload assembler + M6 share helper (independent, small): `buildStudyBackup(Ref)`; `runShareAction`. Coordinate M6's provider half with arch F-01 (one commit serves both).
4. M7 chips, M8 crumb, M10 deletions (mechanical, trivial): lift `SubjectFilterChips`, `locationCrumb`, delete typedef (with deadcode commit D) + executor provider. M9 prose fix lands here too under N13.
5. M11 draft store extraction (own commit; pairs with N20's clear-on-wipe).
6. M12 part-file split (last; largest surface, zero behaviour change, no schemaVersion touch).

Deliberately excluded from this workstream: M5 (owned by arch F-02's AccountCleanup service) and F-05's widget split of exam_entry_screen (architecture workstream; sequence before or after step 5, never concurrently — same file).

**Risks:**
- Migration risk: none of the six steps touches `app_database.dart`, `schemaVersion`, or transaction bodies; state this in every PR description.
- Step 1/2 touch the most-tested pure functions in the repo — keep arithmetic byte-equal and let existing suites prove it; the danger is "improving" a boundary while moving it.
- Steps 4–5 reshuffle files other audit workstreams also edit (exam_entry_screen, review_center, dashboard) — merge-order with the architecture workstream's F-05 split must be agreed before either starts.
- M12's split must be `part`-file form; the collaborator form changes test constructors and invites drive-by edits inside restore transactions.
