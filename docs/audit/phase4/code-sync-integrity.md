# Phase 4 code review — WS1 code-sync-integrity (C1 · N4 · D-01/SEC-04/F-02 · D-02 · N14 · hold-on-error)

Reviewer: Phase 4 code-reviewer (read-only pass). Branch `ai-audit/2026-08-25`.
Range: 191303d, 147654b, b6a1a90, 92815b7, f240a1f, e81724f.
Plan: docs/audit/verified-plan.md WS1. Rationale: docs/audit/phase2/{correctness,data,security}-review.md.

## Verdict table

| Commit | Item | Verdict |
|---|---|---|
| 191303d | C1 legacy null-uid gate | **APPROVE** |
| 147654b | N4 empty-upload hold | **APPROVE** |
| b6a1a90 | D-01 + SEC-04 + arch F-02 shared wipe | **APPROVE** |
| 92815b7 | D-02 joined restore transaction | **APPROVE-WITH-NITS** |
| f240a1f | N14 surfaced restore failure | **APPROVE** |
| e81724f | hold cycles when reads fail (C6 follow-through) | **APPROVE-WITH-NITS** |

No P0 or P1 findings. Two P2 nits (below). Rule 1 clean.

---

## 1. C1 — 191303d — APPROVE

Decision flow traced end-to-end in lib/presentation/providers/backup_gate.dart:

- Same-uid early return is now exact (`previous == uid`, backup_gate.dart:77-80) — the
  `previous == null` disjunct is gone.
- Null falls through to the data-driven decision: honest emptiness read via
  `snapshotProvider.future` (backup_gate.dart:103-105), non-empty ⇒ confirmed sheet
  (:113-118), wipe + `wipeAccountPreferences` + uid rewrite strictly in that order
  (:120-137). Crash mid-wipe leaves either the old uid or none — never the new one
  claiming a consent nobody gave (comment :135-136 matches the code order).
- No path uploads A's record into B's doc:
  - Decline/refusal ⇒ uid stays old/absent ⇒ `flush()` owner check
    (lib/presentation/providers/backup_providers.dart:103-106) refuses every upload;
    lifecycle pause and debounce both funnel through it.
  - Consent ⇒ device wiped before the uid rewrite, so what flush later uploads under
    B is emptiness or B's own restored copy.
- Regression test is genuine: `SharedPreferences.setMockInitialValues({})`
  (test/widget/account_switch_gate_test.dart:233-234) with a seeded database and an
  unsigned-in-then-Google auth fake — asserts sheet appears, wipe lands, uid written
  (:244-258). Against the old code (`previous == null || previous == uid`) the sheet
  assertion fails immediately; the test is not a tautology.
- Empty-device silent hand-over preserved (:208-222 test) — intended UX per plan.

## 2. N4 — 147654b — APPROVE

Guard: flush refuses when record is empty AND no successful restore ever completed
(backup_providers.dart:174-185); marker written only after `restore()` fully completes
(:238-246). Orderings reasoned through:

- Fresh install + new account, no cloud doc: download returns null, no marker, local
  stays empty — held uploads are a no-op (there is nothing to send). First real work
  makes the record non-empty, which bypasses the guard entirely — pinned by
  'a populated record uploads without any marker'
  (test/widget/backup_flush_test.dart:334-350). No deadlock.
- Offline fresh sign-in over an existing cloud doc: empty held ⇒ newer cloud copy
  protected (test :307-330); next online launch auto-restores and sets the marker.
- Manual restore then intentional emptying: Settings' delete-everything flushes first
  (pre-delete state reaches the cloud), then deletes cloud + account, then wipes prefs
  including the marker (settings_screen.dart:755-764) — no stale-marker trap; a
  recreated account starts unmarked, which is correct.
- Marker lost (crash between transaction commit and setInt): local record is non-empty,
  which the guard does not touch. Fail-safe direction.
- Gate switch wipes the marker with the rest of the prefs (app_providers.dart:333) —
  B cannot inherit A's "informed" state.

Nit (P2, not blocking): the marker condition's formatting splits oddly across lines
(backup_providers.dart:176-179); analyzer-clean, cosmetic only.

## 3. Shared wipe — b6a1a90 — APPROVE

Coverage audit (`rg 'setString|setStringList|setBool|setInt'` over lib/, 16 sites):

- Account-scoped keys all reach `wipeAccountPreferences`
  (lib/presentation/providers/app_providers.dart:308-335): drafts by prefix (:310-315),
  profile name/year (:316-317), all four lock keys made public for exactly this
  (auth_providers.dart:51-54, 116-118; app_providers.dart:318-321), uid (:327),
  download marker (:328).
- Keys deliberately kept are named and justified in the doc comment (locale, theme,
  notifications, haptics — device choices, app_providers.dart:301-303). Remaining
  writers checked and acceptable: dashboard `last_open_day` (device day marker,
  dashboard_screen.dart:54,102) and the reminder fingerprint
  (review_notification_service.dart:442 — compared against current data each pass, so
  a stale value self-heals into a reschedule; leaks nothing).
- Draft-prefix coupling documented **both sides**: producer
  `ExamDraftStore.keyPrefix` (lib/data/exam_draft_store.dart:53-65, with the
  byte-equality warning and the layering reason) and wiper `kExamDraftKeyPrefix`
  (app_providers.dart:283-290). Two literals total; no third.
- Settings dedupe (arch F-02): `_runDeletion` single body, prefs wiped strictly after
  account deletion succeeds (settings_screen.dart:755-777) — a failed attempt keeps the
  student's name and lock (SEC-04 requirement). Both entries (plain + re-auth retry)
  route through it.
- Gate path calls the same helper before the uid rewrite (backup_gate.dart:127);
  between remove(uid) and the rewrite, flush sees no owner and refuses — commented as
  the safe direction (app_providers.dart:326-327).
- Test seeds both draft shapes plus every key and asserts prefix-scoped survival rules
  (account_switch_gate_test.dart:319-367).

## 4. D-02 — 92815b7 — APPROVE-WITH-NITS

- One boundary truly wraps both halves: `restoreEverything` runs `restoreWorld` +
  `restoreTasksWithin` inside a single `_db.transaction`
  (lib/data/repositories/drift_study_repository.dart:771-779).
- Nested-transaction misuse: none. Neither core calls `transaction()` itself —
  `restoreWorld` extracted transaction-free (:629-759) and `restoreTasksWithin` issues
  plain statements/batch that join the outer zone (drift_task_repository.dart:218-240,
  semantics stated in the comment at drift_study_repository.dart:775-776). No savepoint
  reliance anywhere; the standalone wrappers each own exactly one transaction
  (:623-627; drift_task_repository.dart:208-210).
- Containment of `restoreTasksWithin`: sole production caller is `restoreEverything`;
  documented as not-for-general-use (drift_task_repository.dart:216-218). Standalone
  `restore`/`restoreTasks` remain for existing callers (versioned-file tests in
  test/data/backup_restore_test.dart); zero other production callers (grep).
- Rollback direction pinned by two real-SQLite tests: orphaned lesson rolls back both
  halves (:266-320) and duplicate task ids roll back a fully valid curriculum
  (:322-368). Either would fail if the join regressed to two transactions — the second
  is exactly the direction the old shape could not protect.

Nits (both P2):
1. `BackupSyncNotifier.restore` constructs `DriftStudyRepository(databaseProvider)`
   inline instead of going through `studyRepositoryProvider`
   (backup_providers.dart:233-236) because `restoreEverything` is not on the domain
   interface. Conscious (the updated test comment owns it,
   test/widget/backup_flush_test.dart:331-334) and functionally identical — same db
   instance — but it silently bypasses any future provider override. If WS ever adds a
   repository interface revision, move `restoreEverything` onto it.
2. `DriftStudyRepository` now imports `drift_task_repository.dart` (data-layer mutual
   import is only one-way today — task repo does not import study — so no cycle, but
   the coupling direction should stay watched; comment at drift_study_repository.dart:16-18).

## 5. N14 — f240a1f — APPROVE

- `reportFailure` lands the failure on the same card state a failed upload produces
  (backup_providers.dart:217-223); gate's catch reports with the specific
  `BackupFailure` (backup_gate.dart:297-304) plus debugPrint per house convention.
- Test asserts concrete state (`SyncStatus.failed` + `BackupFailure.offline`,
  account_switch_gate_test.dart:374-401), not just absence of exception. Would fail if
  the swallow returned.

## 6. Hold-on-error — e81724f — APPROVE-WITH-NITS

All four wrapped sites degrade SKIP-safe (no upload/wipe on failed read) and every site
logs:

| Site | Degrades to | Logged | Card |
|---|---|---|---|
| Switch-check emptiness read (backup_gate.dart:104-112) | hold whole hand-over, uid untouched | debugPrint | see nit |
| Auto-restore first read (:255-266) | skip restore, nothing written | debugPrint | `reportFailure(unknown)` |
| Post-download re-read (:283-294) | skip restore, cloud copy intact | debugPrint | `reportFailure(unknown)` |
| flush reads (:137-149) | hold cycle, no upload | debugPrint | status failed + unknown |

None guesses "empty"; none proceeds on unknown; all fire-and-forget paths are guarded so
no unhandled zone error escapes (C6). Tests drive real error streams through the real
gate and real notifier and assert bytes did not move, uid unchanged, download count 0
(account_switch_gate_test.dart:455-486; backup_flush_test.dart:281-303).

Nit (P2): the switch-check hold is the one site that does not reach the sync card —
`_clearIfDifferentAccount` returns false and `_restoreIfEmpty` returns at
backup_gate.dart:239 before any `reportFailure`, so a held hand-over looks like a normal
idle card while its three siblings report. Consistency with N14 would argue for a
report here too; defensible either way (the hand-over may resolve next launch and the
student has bigger news than sync), hence P2 not P1.

## 7. Rule 1

`git diff 053f079..HEAD -- pubspec.yaml android/ lib/data/db/app_database.dart` →
**empty**. No schemaVersion, migration, applicationId, or versionCode movement in the
range. D-02 explicitly needed none (transaction scope only, same tables).

## 8. Test execution (run by reviewer)

```
flutter test test/widget/account_switch_gate_test.dart \
             test/widget/backup_flush_test.dart \
             test/data/backup_restore_test.dart --no-pub
→ 00:02 +31: All tests passed!

flutter analyze --no-pub → No issues found!
```

Assertion quality spot-check: no tautologies found. C1 test fails against the old
early-return; N4 tests pin all three directions (hold / populated-bypasses /
post-restore emptiness flows); D-02 tests pin rollback in both half-failure orders
against a real NativeDatabase; N14/C6 tests assert concrete SyncState values.
