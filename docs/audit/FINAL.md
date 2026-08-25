# Ather AI Audit — FINAL Report

Branch `ai-audit/2026-08-25`, base `053f079` (verified plan) → HEAD `f4ad0ae`.
Pipeline: Phase 0 (4 evaluators → 25-item needs list) · Phase 1 (10 domain audits, ~113 findings)
· Phase 2 (10 independent cross-reviews: 94 confirmed, 2 false positives killed, 4 stale, 13 dups merged
→ verified plan with waves + file ownership) · Phase 3 (10 workstreams, 41 commits) ·
Phase 4 (7 code reviewers + consistency + copy-parity + regression; loop closed after 3 fix rounds).

## Final state

- **Tests: 684/684 green** (65/67 suites at last full run; both stragglers fixed by `e0d6dcf`/`f4ad0ae`)
- `flutter analyze`: zero issues · `tool/check_invariants.sh`: all 9 hold
- AR/EN parity: **348 = 348 keys**, 0 placeholder mismatches, gen-l10n reproduces committed output byte-exact
- Rule 1 untouched: no schemaVersion/migration/applicationId/versionCode/pubspec changes anywhere in range
- Reviewer verdicts: 0 REJECT survived; all P1 findings fixed and re-verified

## What was wrong → what changed (by theme)

1. **Data-loss class (the P0)** — C1: a phone that predated accounts handed to a second student skipped
   the wipe gate entirely and would upload student A's entire record into B's cloud doc.
   Fixed data-driven (`191303d`); N4 empty-upload-overwrites-cloud guard (`147654b`); D-02 restore joined
   into one transaction so process death can't strand half-state (`92815b7`); failed auto-restore now
   surfaces on the sync card instead of `on BackupException {}` (`f240a1f`); every backup cycle now
   degrades SKIP-safe when reads fail (`e81724f`).
2. **Silent failures** — reminders cancelled against a loading fallback on every cold start (N5) +
   silent catch (N6): `b23286f`/`047208d`. Stream errors collapsing to fake-empty screens (N7/C6):
   four-state SnapshotRead + settle-gating (`c771d13`). Wizard blank correct-count recorded all-wrong
   silently (N9): advance gate (`4cbe908`). Malformed drafts discarded whole (`d36e794`).
3. **Account hygiene** — one shared `wipeAccountPreferences()` covers draft/profile/lock/uid/download
   keys for delete-everything AND account switch (D-01/SEC-04/F-02, `b6a1a90`) — previously hand-duplicated
   and already divergent.
4. **Copy correctness (Arabic-first)** — ICU plurals were String-typed fakes producing «رجعت بعد 0 يوم»,
   "1 days left", dual/tamyiz breaks in the highest-traffic chips; digits policy violations («٨ أحرف» vs
   spec'd Western); tanween order normalized to 48:0. Atomic both-locale migration, every branch pinned
   (`7d90366`, `504a8bd`, tests `5bede70`/`b172cba`, `plurals_test.dart`).
5. **Input integrity** — NumberField stripped decimal separators into wrong scores → reject-with-evidence
   (integer end-to-end domain, `171c7e6`); invisible-char-only names passed validation (`bc5c2f6`);
   band thresholds single-sourced + pinned (`8d2914f`); sticky yesterday-day task writes re-seeded at day
   change (`754305f`); keystroke draft writes debounced with lifecycle flushes (`01f8c7d`); subject names
   >60 chars crashed into a generic toast loop (interloper fix kept after hard review, `fa92b50`).
6. **UX polish** — review badge red reserved for overdue; accent tier gets its contract foreground in
   dark mode (`95aaed3`, `ffebfd6`); reads error states wired (`c771d13`).
7. **Weight removed** — spent l10n scripts (after relocating their PowerShell lesson to RELEASING.md),
   Windows-era agent-state files, dead review-cycle symbols + orphaned imports, dangling wt-session
   stubs, 51 stale render PNGs, .gitignore tidy. Deletion safety: every item carried fresh zero-reference
   sweeps by the reviewer AND implementer; two candidates deliberately NOT deleted (worktrees holding
   key.properties copies → owner; `subjectTemplateNote` → rendered by unmerged pushed commit `3814367`).
8. **Truth restoration** — router auth-gate truth table under test for the first time (11 cases);
   misattached/misleading doc blocks corrected; 3 stale cross-references introduced mid-audit caught by
   the consistency pass and fixed.

Audit-introduced regressions found by our own reviewers and closed: wipe-sheet-absorbs-test-taps
(5 suites), dark-mode contrast P1, boot-fixture timer, student_flow teardown hang, 3 doc-rots.

## Remaining backlog (ordered)

**P1**
1. Router deep-link UX: destination dropped on sign-out redirect; no return-to-original post-login
   (`router.dart:168-169`; pinned by `router_redirect_test.dart`).
2. [OWNER] Security chain before any marketing push: App Check budget alert → drain metric → enforce
   Auth+Firestore together; deploy firestore.rules and verify parity with repo.
3. [OWNER] Crashlytics initializes unconditionally in release while privacy copy claims "no crash
   reporting" in BOTH languages — decide: consent-gate Crashlytics or rewrite copy.
4. [OWNER] Product coherence: mandatory login gate contradicts the offline-first thesis (N3).

**P2** — snapshot await timeout hardening; step-2 tally ListenableBuilder; en `=0` plural branches
("0 days overdue" false facts); settings_screen migrate to SnapshotRead; draft-prefix equality pin;
Cf-set completeness in name validator; paste `"25\n"` trim; @metadata mirror; format-dialect spots;
restore() inline repository construction; N19 timezone-on-resume; N15 backup-ceiling load test;
N21 analytics empty state; N18 shared not-found body; M12 repository split; v5→v6 index migration
as its OWN release with Rule-1 migration test.

**Roadmap (competitor-derived)**: lesson-level curriculum templates (activation cliff is THE gap),
reboot-proof reminders + widget, faster exam entry, past-paper library, adaptive intervals,
parent share/export, tutor kit.

## Next 5 moves (owner's perspective)

1. **Ship**: pick up N2 — signed release APK via RELEASING.md (invariants now enforce the four
   upgrade rules), deploy the written-but-undeployed site. The app is materially safer than any
   build that preceded this audit.
2. **One device day closes three owner items**: reminder delivery across reboot (N11), Arabic chapter
   PDF shaping (N12, hide row if broken), mid-range motion profile numbers (N25).
3. **Security chain (P1 #2) then flip App Check to enforced** — do it before the site sends traffic.
4. **Decide the login question (P1 #4)**: local-first with sign-in raised only for backup matches the
   thesis and dissolves the activation cliff alongside lesson-level templates (roadmap #1).
5. **Reconcile PROJECT.md with shipped reality (N13)** — free subjects vs paid table, third-entry door,
   Windows claim — then start roadmap #3 (fast exam-entry), since entry speed is the product's currency.

## Provenance

Full paper trail: `docs/audit/phase0/` (needs list), `phase1/` (10 audits), `phase2/` (10 cross-reviews +
`verified-plan.md`), `phase4/` (per-workstream reviews, consistency, copy-final, regression).
