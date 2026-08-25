# Phase 2 — Dead-Code Cross-Review

Reviewer: phase-2 cross-reviewer (did not write the phase-1 report under review).
Input: [phase1/deadcode-auditor.md](../phase1/deadcode-auditor.md) · Needs map: [phase0/PRIORITIZED_NEEDS.md](../phase0/PRIORITIZED_NEEDS.md)
Method: every deletion candidate re-verified by hand with my own searches on `ai-audit/2026-08-25` @ `c9a28ec`. Read-only; no builds. Commands quoted verbatim; generated code excluded unless stated.

## Summary stats

| Metric | Count |
|---|---|
| Deletion candidates reviewed | 13 (+1 addition raised by this review = 14) |
| CONFIRMED-DEAD (proof attached) | 10 |
| KEEP / FALSE-POSITIVE | 0 |
| STALE (downgraded — see #4, #7, #11) | 3 |
| DUPLICATE-flagged (cross-phase1 overlap) | 2 (#3 → ai-slop S5; #5 → maintainability M10) |
| Dependency claims re-verified | 22 declared deps, all ≥1 direct import → "zero unused deps" **CONFIRMED** |

Dependency sweep command run (counts = files importing `package:<dep>/`):
`for d in flutter_riverpod drift drift_flutter go_router flutter_local_notifications timezone intl shared_preferences path_provider share_plus pdf crypto firebase_core firebase_auth google_sign_in local_auth cloud_firestore firebase_app_check firebase_crashlytics local_auth_platform_interface fake_cloud_firestore firebase_auth_mocks; do rg -l "package:$d/" lib test tool | wc -l; done`
→ 60/29/1/25/4/2/3/29/3/3/2/2/2/3/1/5/2/1/5/1/1/1 — all non-zero. Report's claim stands.

Entrypoint sweep: `rg -l "^void main\(" tool --iglob '*.dart'` → the four `_test.dart` harnesses only; `.github/workflows` runs `flutter test` + `tool/check_invariants.sh` only; no second Flutter target under `lib/`. No orphan targets.

---

## Per-item verdicts

### #1 `.auto-claude-status` → **CONFIRMED-DEAD** · P1 · Effort S · N-id: NEW
My proof: `git ls-files | grep auto-claude` → tracked. Content confirms `"active": true`, spec `001-crash-reporting-integration`, timestamp `2026-08-18T11:06:25`; feature is shipped (`lib/main.dart:42` calls `_initializeCrashlytics`, defined `lib/main.dart:172`). `grep -rn "auto-claude-status|auto-claude-security|claude_settings" lib test tool .github windows android pubspec.yaml docs RELEASING.md CLAUDE.md PROJECT.md` (audit docs filtered) → **0 hits**. Own commit in Phase 3 (commit C1 below).

### #2 `wt-session-a/`, `wt-session-b/` → **CONFIRMED-DEAD** · P1 · Effort M · N-id: NEW
My proof: `cat wt-session-{a,b}/.git` → `gitdir: C:/ather/.git/worktrees/wt-session-{a,b}` (dangling on Linux). `git worktree list` → both listed **prunable**, parked at `7cae5ab`. `git log --oneline master..exec/session-a` → **0**; `master..exec/session-b` → **0** (also checked against `main`: 0/0). Ignore/exclude coverage verified at `.gitignore:102-103` and `analysis_options.yaml:17-18`. Removal = filesystem/git-metadata op (`git worktree prune` → `git branch -D exec/session-a exec/session-b` → `rm -rf`), no content commit; a later tidy commit can drop the two ignore entries.

### #3 `tool/add_p5_arb.py`, `tool/add_p5_rich_arb.py`, `tool/fix_p3_arb.py` → **CONFIRMED-DEAD + DUPLICATE** (ai-slop-auditor.md §S5) · P1 · Effort S (+doc relocation) · N-id: NEW
My proof: `rg -n "add_p5|fix_p3" --hidden -g '!.git' -g '!docs/audit/**' .` outside the scripts themselves → hits **only** inside `.claude/worktasks/release-apk/` (itself stale-tree candidate #9) → zero live references. Not in CI: `rg -n "py|add_p5|fix_p3" .github/workflows/*.yml` → 0. Work-is-done check: `examVerdictWeak`, `examEveButton`, `reviewBodyDeclining` each present in **both** ARBs (`rg -c` → 1/1 or 2/2 per file). Coordinate: if deleted, first relocate `fix_p3_arb.py`'s PowerShell/ARB-encoding lesson into RELEASING.md (ai-slop S5 option (a)) — blocking precondition, else adopt their option (b) one-liner. Own commit (C2).

### #4 `public/index.html` version text → **STALE** (edit, not deletion — report's own framing agrees) · P1 · Effort S · N-id: **N2**
My proof: `grep -n "1\.7\.0" public/index.html` → lines 110, 167 ("Version 1.7.0"); `pubspec.yaml:5` → `version: 1.8.0+16`. Side-claim verified: `sha256sum public/ather-latest.apk dist/Ather-1.8.0-build15.apk` → 2 distinct hashes. Which artifact is canonical is an [OWNER] release decision — fold into N2 distribution work rather than a blind text bump.

### #5 `ExamDraftGroup` typedef → **CONFIRMED-DEAD + DUPLICATE** (maintainability-auditor.md M10) · P2 · Effort S · N-id: NEW
My proof: `rg -n -w "ExamDraftGroup|ReviewStateX|isOverdueAt" lib test tool android windows` → **exactly 3 lines, all declarations**: `review_cycle_service.dart:374,375,380`. Zero callers anywhere. Fold into commit C3 with #6.

### #6 `ReviewStateX.isOverdueAt` → **CONFIRMED-DEAD** · P2 · Effort S · N-id: NEW
Proof shared with #5 (same search). Doc-comment claim ("used by exam entry") is false on this branch: exam entry calls `ReviewCycleService.needsReview` directly (`exam_entry_screen.dart`, verified via `rg -n "ReviewCycleService.needsReview" lib/presentation/exam_entry/exam_entry_screen.dart`). The epitaph comment at `review_cycle_service.dart:357–368` is intentional narrative — **keep the comment, delete only lines 373–380**.

### #7 ARB key `subjectTemplateNote` → **STALE — HOLD deletion** · severity of getting this wrong: P1 · Effort S · N-id: NEW
The key **is dead on this branch** — my proof: `rg -n "subjectTemplateNote" lib test tool` excluding generated → only `app_en.arb:447`, `app_ar.arb:658` (declarations); screen lives at `lib/presentation/settings/subjects_screen.dart` (report's path `lib/presentation/subjects/…` was wrong) and uses `subjectTemplateAdd/Count` only.
**But the report missed this:** `git log -S subjectTemplateNote --all` surfaces commit **`3814367` "Show the template note, and drop a string nothing renders"** on branch `claude/session-a-data-export-1527f1` (pushed to origin, dated 2026-08-19, i.e. *newer* than the last common design work) which **renders the string**: adds `SettingsFootnote(l.subjectTemplateNote)` to subjects_screen. `git merge-base --is-ancestor 3814367 HEAD` → NOT an ancestor. This is precisely CLAUDE.md Rule 2 territory: another session's branch treats the key as alive. Deleting both ARB entries here would clobber that work on merge. **Action: owner rules on `claude/session-a-data-export-1527f1` first; only if that branch is rejected does C4 proceed (delete keys + regen, own commit).**

### #8 `.auto-claude-security.json`, `.claude_settings.json` → **CONFIRMED-DEAD** · P2 alone, ships with #1 as P1 pair · Effort S · N-id: NEW
My proof: tracked (`git ls-files`); grep across lib/test/tool/.github/windows/android/pubspec/docs/RELEASING/CLAUDE/PROJECT → **0 hits** (same sweep as #1). Commit C1 together with #1.

### #9 `.claude/worktrees/*` (7) + `.claude/worktasks/release-apk` → **CONFIRMED-DEAD** (untracked local purge) · P2 · Effort M · N-id: NEW
My proof: all registrations appear in `git worktree list` marked **prunable** (C:/ather gitdirs); sizes re-measured `du -sh` → 3.1G, 928M, 3.2M, 3.0M, 94M, 791M, 2.3G + 870M ≈ **8.1 GB**. Matches report.
⚠️ **Risk the report missed:** CLAUDE.md:43–49 sends agents hunting `android/key.properties` in exactly these directories. My check found copies at `.claude/worktasks/release-apk/android/key.properties` and 3 more under `.claude/worktrees/*`. The **live tree has its own** `android/key.properties` (exists; contents not read per CLAUDE.md), and no `*.jks` exists anywhere under `.claude/` (find verified) — so the purge cannot destroy the only password-file copy *on this machine*, but the storeFile target's keystore location could not be verified without reading secrets. **Purge requires owner sign-off + confirm the live copy loads before `rm`.** Filesystem op; no commit (ignore coverage unaffected).

### #10 `tool/render/**/*.png` incl. `failures/` → **CONFIRMED-DEAD** (untracked artifacts) · P2 · Effort S · N-id: NEW
My proof: `git ls-files tool/render` → only the three `*_test.dart`; `find tool/render -name "*.png"` → **51 files, all untracked** (`git status --porcelain tool/render` clean because ignored/untracked-local). The Dart harnesses stay (protected in phase-1's alive-but-looks-dead table; referenced by `docs/reviews/2026-08-11-technical-review.md` — the PNGs are regenerable outputs). At minimum delete `tool/render/failures/`. Filesystem op.

### #11 `dist/README.md` → **STALE** · P2 · Effort S · N-id: **N2**
My proof: headline reads "Ather 1.8.0+14 — the build to hand out"; `ls dist/` shows `Ather-1.8.0-build15.apk`; `pubspec.yaml:5` = +16. `dist/_quarantine-do-not-distribute/` must survive: `RELEASING.md:172–173` cites it as versionCode-offset evidence (verified). Fix-or-datestamp the README alongside #4 in the N2 release pass.

### #12 `sahm.iml`, `.idea/` → **CONFIRMED-DEAD** (untracked local state; no commit possible) · P2 · Effort S · N-id: NEW
My proof: `git ls-files "*.iml"` → empty; `git check-ignore -v sahm.iml .idea` → `.gitignore:16 (*.iml)`, `.gitignore:19 (.idea/)`. Deleting cannot affect any build/upgrade. Local rm only.

### #13 Empty `docs/audit/phase-{0,1,2}/` dirs → **CONFIRMED-DEAD** · P2 · Effort S · N-id: NEW
My proof: `find … -type f` → **0 files** in all three; populated trees are `phase0/`/`phase1/`/`phase2/` (this file lives in `phase2/`). Git tracks no empty dirs — pure local scaffolding noise. `rmdir`.

### Addition A1 (raised by this review, credit maintainability-auditor.md M10) — `databaseExecutorProvider`
`lib/presentation/providers/app_providers.dart:31-32`. My proof: `rg -n -w "databaseExecutorProvider" lib test tool` → **1 hit: the declaration**. Dead test-escape seam; the phase-1 deadcode report missed it. Add to commit C3. · P2 · Effort S · NEW.

---

## Workstream proposal

**Workstream name: `purge-dead-weight`** (Phase 3). Every numbered item below is its own explicit commit; untracked/local ops are listed separately so nobody wraps them into a content commit.

Deletion commits (tracked content, each independently revertible):
- **C1 — "Remove stale Windows-era agent state"**: `.auto-claude-status`, `.auto-claude-security.json`, `.claude_settings.json` (#1, #8).
- **C2 — "Remove spent l10n migration scripts"** (#3): **PRECONDITION FIRST** — relocate the PowerShell/ARB encoding lesson out of `fix_p3_arb.py`'s header into RELEASING.md (per ai-slop S5; coordinate with that workstream), then delete the three `.py` files.
- **C3 — "Drop dead review-cycle symbols and executor provider"**: `ExamDraftGroup`, `ReviewStateX.isOverdueAt` (`review_cycle_service.dart:373–380`), `databaseExecutorProvider` (`app_providers.dart:31–32`) (#5, #6, A1). Keep the 357–368 epitaph comment.
- **C4 — "Remove unused subjectTemplateNote strings + regen"** (#7): **BLOCKED pending owner ruling** on `claude/session-a-data-export-1527f1` (commit 3814367 renders the string). Execute only if that branch is rejected/abandoned.
- **C5 — "Site + dist version truth"** (#4, #11): `public/index.html:110,167`, `dist/README.md` refresh — fold into the **N2** distribution workstream after the owner picks the canonical APK; not a standalone blind edit.

Filesystem/git-metadata operations (no content commit; document each in the PR body):
- F1: `git worktree prune && git branch -D exec/session-a exec/session-b && rm -rf wt-session-a wt-session-b` (#2).
- F2: `.claude/worktrees/*` + `.claude/worktasks/release-apk` purge (~8.1 GB) (#9) — **owner sign-off required**; verify live `android/key.properties` resolves to a usable keystore first (CLAUDE.md Rule 1).
- F3: `rm -rf tool/render/failures` minimum; optionally all 51 regenerated PNGs (#10).
- F4: `rm sahm.iml; rm -rf .idea` (#12). F5: `rmdir docs/audit/phase-0 docs/audit/phase-1 docs/audit/phase-2` (#13).
- Follow-up tidy commit T1 (after F1): drop `wt-session-a/`+`wt-session-b/` from `.gitignore:102-103` and `analysis_options.yaml:17-18`.

Risks: (1) #7/C4 cross-branch conflict — resolved by HOLD, not by deletion; (2) F2 touches directories CLAUDE.md names as signing-key recovery locations — gated on owner; (3) all other deletions carry zero-reference proofs above and remain recoverable from git history.
