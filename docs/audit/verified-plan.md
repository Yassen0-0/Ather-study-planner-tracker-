# Verified Execution Plan — Phase 2 output

Base: `ai-audit/2026-08-25` @ `afa82fc`. Inputs: 10 phase-1 reports, 10 independent cross-reviews
(`docs/audit/phase2/`). Every surviving finding was re-confirmed against current code by a reviewer
who did not write it.

## Aggregate verdicts

| Metric | Count |
|---|---|
| Findings reviewed across all reports | ~113 |
| CONFIRMED | 94 |
| FALSE-POSITIVE (killed) | 2 — data D-04 (no producer for subset premise), ar F-12 («لم تَضِع» is correct jussive) |
| STALE / already fixed | 4 — deadcode #4/#7(partial)/#11, security SEC-03 (min password now 8) |
| DUPLICATE / overlap flagged | 13 (merged below) |
| P0 after re-rank | **1** — correctness C1 |

## The one P0

**C1 — account-switch wipe bypass on legacy devices.** A phone without `kLastAccountUidKey`
(written only at `backup_gate.dart:75,102`) + second student signs in → `previous == null` branch at
`backup_gate.dart:74-77` skips emptiness check and wipe sheet → owner check passes
(`backup_providers.dart:99-102`) → backgrounding uploads student A's entire record into B's cloud
doc; A's later confirmed wipe leaves restore empty. Repro: pre-accounts phone handed to a sibling.

## Execution waves (file ownership is exclusive per wave)

### Wave 1 (parallel, disjoint file sets)

**WS1 `sync-integrity`** [P0 C1 · N4 · D-01 · D-02 · N14 · SEC-04 · arch F-02]
Owns: `lib/data/**backup*`, `lib/data/repositories/drift_study_repository.dart`,
`drift_task_repository.dart`, `lib/presentation/settings/settings_screen.dart`,
`lib/presentation/providers/auth_providers.dart`, `lib/presentation/providers/app_providers.dart`
(wipe helper only), tests `account_switch_gate_test/backup_flush_test/backup_restore_test`.
Order: C1 gate fix → N4 upload guard → D-01 draft-key purge in `wipeAccountPreferences()` →
D-02 join restore into one transaction (+tests move with it) → N14 surface restore failure →
F-02/SEC-04 dedupe wipe sequence. FORBIDDEN: editing `exam_entry_screen.dart` (import its
constants only), any `schemaVersion` change.

**WS2 `reminders`** [N5 · N6]
Owns: `notification_providers.dart`, `review_notification_service.dart`,
`review_notification_service_test.dart`.
N5: await `snapshotProvider.future` before cancel/fingerprint (pattern exists at
`backup_providers.dart:104-121`). N6: log inside the silent catch (`notification_providers.dart:164-167`).

**WS3 `router-gate-test`** [arch F-07]
Owns: new `test/app/router_redirect_test.dart` only. Truth table of `router.dart:164-170`.
May NOT edit router code; report any bug found instead.

**WS4 `de-slop-safe`** [ai-slop S2 · S3 · S4]
Owns: `app_shell.dart` (:120-121 duplicate comment), `analysis_options.yaml`
(scaffold prose :1-9/:22-34/:36-37; `include:`/`analyzer.exclude` byte-identical),
format hunk in `widget_test.dart`. S1 deferred to Wave 2 (file conflict with WS1).

**WS5 `purge-dead-weight`** [deadcode confirmed-dead list]
Deletion commits, each listed explicitly:
a) relocate PowerShell encoding lesson → `RELEASING.md` FIRST, then delete
   `tool/{add_p5,add_p5_rich,fix_p3}_arb.py`; b) `.auto-claude-status`,
   `.auto-claude-security.json`, `.claude_settings.json`; c) `wt-session-a/b`
   (run `git worktree prune`, verify list first); d) dead symbols in
   `review_cycle_service.dart` only (`ExamDraftGroup`, `ReviewStateX.isOverdueAt`);
e) untracked `tool/render/*.png` incl. `failures/` (filesystem rm, not a commit);
f) `.gitignore` tidy.
BLOCKED ([OWNER]): `.claude/worktrees/*` pruning (holds key.properties copies),
`subjectTemplateNote` deletion (rendered by unmerged pushed commit `3814367`).

### Wave 2 (after WS1; WS8 parallel-safe with WS6/WS7)

**WS6 `reads-error-surface`** [N7 · C6] Owns: `app_providers.dart` stream error states +
settle-gated empty-state sites in dashboard/review screens; also removes declaration-only
`databaseExecutorProvider` (`app_providers.dart:31-32`).

**WS7 `entry-task-integrity`** [N9 · C2 · M2 · PF1 · PF2 · N8 · N20(copy half)]
Owns: `exam_entry_screen.dart`, new `lib/data/exam_draft_store.dart`, `task_providers.dart`,
`tasks_screen.dart`, `mastery.dart`, `mastery_calculator.dart`, `mastery_palette.dart`,
`insights_generator.dart`, `lock_screen.dart`, wizard/mastery tests.
Order: PF1 setState guard → N9 blank correct-count banner → M2 single-source band constants
(+pinning tests) → PF2 draft-store extraction with debounce + lifecycle flushes →
N8 day-change re-seed/target-day label → N20 lockout copy.

**WS8 `de-slop-finish`** [S1] Owns: doc-block fix `drift_study_repository.dart:1042-1056`.

### Wave 3 (after Wave 2 frees shared call sites)

**WS9 `l10n-plurals-copy`** [ar F-01–F-08,F-10,G-1..G-4 · en F-01,F-02 · N16 partial]
Merged AR+EN workstreams — both reviews touch identical ICU keys; ONE agent owns
`app_ar.arb` + `app_en.arb` atomically (parity verified 348=348 today), regenerated l10n,
and the ~16 call sites (dashboard/lesson/chapter/exam_eve/recycle_bin/backup/analytics/
exam_entry). String→int placeholder retypes drop iso() bidi wrappers — re-add consciously.
EXCLUDED pending owner ruling: privacy copy rewrite (Crashlytics initializes unconditionally
in release, `main.dart:172-199`, contradicts `privacyNoCollectBody` in BOTH languages).

**WS10 `small-p2-hardening`** (capacity-permitting): N16 NumberField decimal handling
(`ather_controls.dart`), N17 invisible-char names (`prompts.dart`), N21 analytics empty state,
N22 badge color semantics (`app_shell.dart`), N18 shared not-found body
(`lesson_screen.dart`+`router.dart`+new widget), N23 recycle-bin warning (copy via WS9 keys).

## Deferred backlog (ordered, not this pass)

1. v5→v6 index migration (`chapters(subject_id)`, `study_events(at,id)`) — own release,
   Rule-1 migration test mandatory (data D-03 + perf PF3).
2. M12 repository part-file split; arch F-01/F-05 presentation moves & exam_entry split.
3. N19 timezone refresh on resume; N15 backup-ceiling load test; N10 lesson-level templates.
4. Roadmap: reboot-proof reminders/widget, fast exam-entry, past-paper library, adaptive
   intervals, parent share, tutor kit.

## Owner decisions required (not agent-executable)

N2 distribution channel · N3 login-gate vs offline-first thesis · SEC-01 App Check enforcement +
budget alert + rules deploy parity · N11 reminder delivery across reboot on device · N12 PDF
shaping check · N13 PROJECT.md reconciliation · N24 Windows claim · worktree pruning sign-off ·
`subjectTemplateNote` ruling · Crashlytics-vs-privacy-copy ruling.

## Phase 4 gates

Per-workstream code-reviewer (diff vs plan) + regression-tester (analyze, full tests, launch) +
consistency-reviewer + copy-reviewer (AR/EN parity must still be exact post-WS9). Any reject →
fresh implementer → re-review.
