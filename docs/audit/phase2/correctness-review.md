# Correctness Cross-Review (Phase 2)

Reviewer role: correctness cross-review of `docs/audit/phase1/correctness-auditor.md`.
Every verdict below was re-traced through the actual control flow in this worktree
(`ai-audit/2026-08-25`). No builds, no app runs — static reading only.

## Summary stats

| Metric | Count |
|---|---|
| Findings reviewed | 6 numbered (C1–C6) + 5 silent catches + 2 deepened knowns |
| CONFIRMED | 13/13 traced claims confirmed as described |
| STALE | 0 |
| FALSE-POSITIVE | 0 |
| DUPLICATE / overlap | C6 UI-half overlaps data-auditor D-05 (kept — C6 adds the fatal-flush half) |
| Severity re-ranks | 1 upward: **C1 P1 → P0** |
| Hotspot needs re-verified still open | N4, N5, N6, N7, N8, N9 — all six stand unfixed |
| Test-honesty notes | Accepted as written (informational, no verdicts owed) |

---

## Per-finding verdicts

### C1 — Legacy null-uid first sign-in uploads the local curriculum into the new account's cloud backup

**Claim** → **CONFIRMED**, severity re-ranked **P0** (was P1). N-id: deepens **N4**.

Traced evidence:
- `kLastAccountUidKey` is written nowhere except `backup_gate.dart:75,102`
  (rg over `lib/`: only readers are `backup_gate.dart:70` and
  `backup_providers.dart:101`). A pre-accounts upgrade therefore arrives with the
  key absent — premise holds.
- `backup_gate.dart:74-77`: `previous == null || previous == uid` → writes uid and
  returns true **before** the emptiness read at line 83; the wipe sheet and the
  non-empty check are structurally unreachable on this branch. Confirmed.
- `_restoreIfEmpty` (`backup_gate.dart:210`) returns early on a non-empty snapshot,
  so nothing restores and the foreign data stays. Confirmed.
- Upload path: `flush()` owner check `backup_providers.dart:99-102` reads the key the
  gate just wrote (== B), passes; lines 121-122 await real streams; line 141 re-checks
  account == owner (both B); upload proceeds. Two independent triggers reach it within
  seconds: lifecycle pause (`backup_gate.dart:169-172` calls `flush()` directly) and
  the 20 s debounce (`backup_providers.dart:82-85`, listeners at 76-77). Nothing else
  guards it — `backup_providers.dart:124-137` documents that the empty-state guard was
  deliberately removed. Confirmed end-to-end.
- Sub-case verified: `StudySnapshot.isEmpty` = `chapters.isEmpty && lessons.isEmpty`
  (`study_snapshot.dart:69`) — tasks ignored by design; auto-restore then runs
  `restoreTasks` which **deletes all local tasks before inserting the cloud set**
  (`drift_task_repository.dart:208-230`, delete at :210). Silent replacement of the
  only copy. Confirmed.
- Note: security-auditor.md:192-193 cites `backup_gate.dart:68-104` as a strength
  ("writes the new uid only after the wipe commits") — true only for the
  different-account branch; not a duplicate, an blind spot in that report.

Minimal repro (student terms): a phone used Ather all year before logins existed
(Rule 1 upgrades make this the normal path), holding student A's full record. A hands
the phone to sibling B, who signs in with their own fresh account (login is mandatory,
N3). No wipe sheet appears; backgrounding the app once uploads A's entire curriculum
into **B's** cloud document. When A signs back in, the gate prompts, A confirms the
wipe — and since A never had a cloud copy, restore finds nothing: A's only surviving
record now lives in B's account, deletable by B via delete-account.

Fix (one line): on `previous == null && !(await snapshotProvider.future).isEmpty`,
run the same confirmed wipe sheet (or persist an upgrade marker so absent-key +
non-empty DB is distinguishable from a genuine first-ever sign-in).

**Severity: P0** (cross-account corruption → deterministic permanent loss chain).
**Effort: M.**

---

### C2 — Draft restore half-applies a partially corrupt groups array

**Claim** → **CONFIRMED**. N-id: NEW (adjacent to N20's draft-key cleanup, D-01).

Traced evidence: `exam_entry_screen.dart:127-171`. The contract comment at :127-128
promises "ignored wholesale rather than half-applied"; the loop instead `continue`s
past individual entries at :148 (`entry.length != 3`) and :152 (non-string fields),
then applies whatever survived if `drafts.isNotEmpty` (:162-170). Repro math checks:
draft `[["12","1","9"],["6","2"],["12","1","7"]]` + total "30" → step 2 shows
24/30 and Next refuses (:313-320); with total "20" it validates clean and saves a
short paper as complete. Reachable via version-skew drafts (the comment itself names
"an older build") or any truncation that keeps the JSON parseable (a mid-list
corruption does not throw at :136-140).

Repro: process death mid-write leaves one group entry short; next open of the wizard
for that lesson shows 2 of 3 groups with a sum-mismatch the student cannot resolve
because they entered the paper complete.

Fix: two-pass decode; discard the whole draft if any entry fails its shape check.
**Severity: P2. Effort: S.**

---

### C3 — hasScheduledReviewsProvider counts archived/deleted subjects' lessons

**Claim** → **CONFIRMED**. N-id: NEW (sibling of the archived-silence invariant).

Traced evidence: `notification_providers.dart:47-52` walks
`snapshotValueProvider.lessons` — the flat table including archived/binned rows
(`study_snapshot.dart:52` vs the filtered `activeLessons` at :105-115).
`planReminders` walks `snapshot.activeLessons` (`review_notification_service.dart:222-225`)
and schedules nothing for them. `_NotificationsWarning` gates the "blocked" banner on
this provider (`settings_screen.dart:591-592`). An examined lesson under an archived
subject keeps its `lastReviewedAt`, so the banner fires while zero alarms exist.

Repro: archive Physics (4 examined lessons), revoke the OS permission → Settings
claims reminders are blocked; grant permission → still zero alarms scheduled, no
warning either way is ever accurate about reality.

Fix: use `activeLessons`. **Severity: P2. Effort: S.**

---

### C4 — Comeback banner counts lessons under archived/deleted subjects

**Claim** → **CONFIRMED**. N-id: NEW.

Traced evidence: `dashboard_screen.dart:110` iterates `snapshot.lessons`; the same
file's visible review surface derives from active-only summaries. The two filters at
:116-120 both pass for a lesson examined 10 days before a 40-day absence
(`needsReview` true at 50 days; `calendarDaysBetween(last, storedDay)` = 10 < 30),
so the count includes lessons the rest of the app is forbidden to show.

Repro: archive Physics (8 examined lessons) mid-trip; return after 40 days → banner
says «١١ درس» fell due; the queue below shows the 3 active ones.

Fix: iterate `snapshot.activeLessons`. **Severity: P2. Effort: S.**

---

### C5 — Display rounds half-up but colour classifies the raw double

**Claim** → **CONFIRMED**. N-id: NEW.

Traced evidence: display path rounds — `formatting.dart:34-38` (`value.round()`),
used by `AnimatedPercentage` (`animated_percentage.dart:36,47`) which receives its
colour from `MasteryPalette.resolve` computed on the raw value
(`chapter_screen.dart:528-533` paired with :579-584). Classification thresholds are
strict on the raw double: `< 50` red, `>= 90` green
(`mastery_palette.dart:38,42`), band boundaries identical
(`mastery.dart:21-26`). So 49.583 renders "50%" in the weak-red; 89.6 renders "90%"
in plain black while the documented band for the printed number is متفوق.
The precedent claim also verifies: velocity rounds *before* the sign decision
(`analytics_screen.dart:829-837`).

Repro: one exam, 119/240 points → step 4 and every later screen print "50%" painted
red until the next exam moves the raw value off the boundary window.

Fix: classify from the rounded value at one choke point (round in
`percent`/`percentLabel` callers' colour resolution, or floor the displayed value).
**Severity: P2** (systematic near every boundary; ±0.5 windows land there routinely
with weighted figures). **Effort: M** (every AnimatedPercentage/MasteryPalette call
site, but mechanical).

---

### C6 — Drift watch error renders an empty curriculum app-wide; backgrounding during it reports fatal

**Claim** → **CONFIRMED** (UI half **DUPLICATE** of data-auditor D-05 — same files,
same root; the flush→fatal half is new evidence and justifies keeping it separate).

Traced evidence:
- Errors forward: `drift_study_repository.dart:1111` (`onError: controller.addError`).
- Error collapses to empty: `app_providers.dart:154-156` `.value ?? empty` — Riverpod 3
  `.value` is null on AsyncError (the file's own comment at :153 documents the 3.x
  semantics), so every `snapshotValueProvider` reader renders first-run emptiness.
  Nothing distinguishes error from loading despite the comment at :150-152 sanctioning
  only the transient-frame trade.
- Fatal escape: debounce wraps `unawaited(flush())` (`backup_providers.dart:84`) and the
  lifecycle call (`backup_gate.dart:171`) awaits nothing; inside `flush()`, the awaits
  at `backup_providers.dart:121-122` sit **outside** the try that starts at :144, so a
  rejected `snapshotProvider.future` escapes unhandled → `main.dart:198-200`
  (`PlatformDispatcher.onError` → `recordError(..., fatal: true)`). `SyncState` never
  leaves idle. All verified line-by-line.
- The disk-failure premise matches write_guard.dart:48-50 ("a failing disk -- the
  commonest real failure on the cheap phones this app runs on").

Repro: SQLite read hiccup during a watch re-query (disk full) → dashboard shows the
first-run card and 0-of-0 stats while the record sits intact; backgrounding the app
files a **fatal** crash report for what is a recoverable read failure.

Fix: branch on `snapshotProvider.hasError` to render an explicit error state (per
D-05's fix), and move the two `.future` awaits inside `flush()`'s try.
**Severity: P2. Effort: M.**

---

## Deepened known findings

- **Timezone offset-guess narrowing** → **CONFIRMED as a correct refinement of N19.**
  Traced: `_resolveTimeZoneName` maps ±02/+03 → Africa/Cairo, else UTC
  (`review_notification_service.dart:450-463`); delivery survives because
  `tz.TZDateTime.from(at, tz.local)` preserves the instant (:404); the residual defect
  is fingerprint churn — `fingerprintOf` hashes `at.millisecondsSinceEpoch`
  (:317-326), so a zone change re-hashes the same wall schedule and pays one full
  cancel-and-rebuild; and non-Egypt +02/+03 zones (e.g. Palestine) inherit Cairo's
  transition calendar, landing cross-transition reminders an hour off. Reasoning
  sound; severity stays inside N19's P2.
- **C1/N4 relationship statement** → verified accurate: phase-0's empty-upload hazard
  (`backup_providers.dart:124-141`, guard deliberately absent) and C1's mis-attribution
  share the upload path; a "restore-check-completed-this-session" gate closes both.

## Silent catches (all five quoted and verified)

1. `settings_screen.dart:566-570` — CONFIRMED: `catch (_) { // A platform that cannot be asked…}` no log; folded into "not allowed".
2. `exam_entry_screen.dart:401-404` — CONFIRMED: `catch (_) { // A refused or unavailable permission never blocks a save. }` no log.
3. `backup_gate.dart:142-148` — CONFIRMED: debugPrint-only; fail direction safe (no wipe).
4. `app_haptics.dart:78,94` — CONFIRMED: sync `catch (_) {}` plus async `catchError((Object _) {})`; zero telemetry by explicit design comment (:34-36) — acceptable, but worth a debugPrint for parity.
5. `app_providers.dart:155` — CONFIRMED: the UI half of C6.

All P2, effort S each (one-line logs or explicit states).

## Hotspot re-verification (needs-map items the report did not restate)

- **N5 (cancel-on-loading race)** — STANDS, unfixed, race confirmed real:
  `_ReviewSchedulerState.initState` posts `_sync()` after the first frame
  (`notification_providers.dart:88`); `_sync` reads `snapshotValueProvider`
  (:133), which is `StudySnapshot.empty()` until drift's first emission;
  `planReminders(empty)` returns [] and the stored fingerprint (seeded real at
  :120) mismatches → `cancelAll()` + empty fingerprint persisted
  (`review_notification_service.dart:392-397`). Every cold start holds **zero**
  alarms for ~5 s (debounce :74) plus query time; a due instant falling inside the
  window is lost permanently (overdue reminders are never posted retroactively,
  :253). Repro: open the app briefly right before a reminder's due moment → alarm
  gone. Belongs in the workstream; regression test:
  `test/data/review_notification_service_test.dart`. Effort S (await
  `snapshotProvider.future` in `_sync` like `flush()` already does).
- **N6** — silent catch still bare at `notification_providers.dart:164-167`. Stands.
- **N7** — stands (= C6/D-05).
- **N8** — sticky selected day confirmed: keep-alive notifier seeded once
  (`task_providers.dart:32-42`), `_add` writes to `ref.read(selectedTaskDayProvider)`
  (`tasks_screen.dart:44,55-60`), no day-change reseed anywhere. Stands.
- **N9** — blank correct-count still saves all-wrong: step-3 validation checks only
  `correctValue > countValue` (`exam_entry_screen.dart:322-325`); blank parses to 0
  (`_GroupDraft.correctValue`, :71). Stands.
- **N4** — stands (see C1).

---

## Workstream proposal

**Workstream: "sync-integrity-first correctness fixes"**

Ordered fix sequence (data-integrity before UX):

1. **C1 + N4** — account/backup attribution gate
   Files: `lib/presentation/providers/backup_gate.dart`,
   `lib/presentation/providers/backup_providers.dart`
   Fix order: (a) prompt-on-null-previous+non-empty-DB in `_clearIfDifferentAccount`;
   (b) refuse upload until a restore check completed successfully this session
   (session flag set where `_restoreIfEmpty` finishes, consulted in `flush()`).
   Risk: touches the most destructive flow; must stay inert on fresh installs and on
   same-uid returns. Regression tests: `test/widget/account_switch_gate_test.dart`
   (legacy-device sign-in shows sheet; decline blocks upload),
   `test/widget/backup_flush_test.dart` (upload blocked pre-check),
   `test/data/backup_restore_test.dart` (tasks-only device not silently replaced).
2. **N5 + N6** — reminder scheduler honesty
   Files: `lib/presentation/providers/notification_providers.dart`
   Fix: await `snapshotProvider.future` in `_sync` before rescheduling; log the
   catch. Regression test: `test/data/review_notification_service_test.dart`
   (cold-start pass against loading fallback schedules nothing AND cancels nothing).
3. **C6 / N7 (+ silent catch 5)** — error state instead of empty
   Files: `lib/presentation/providers/app_providers.dart`,
   `lib/presentation/providers/backup_providers.dart` (awaits into try),
   dashboard/review empty-state sites.
   Regression tests: `test/widget/backup_flush_test.dart` (AsyncError → no fatal,
   SyncState.failed), `test/data/snapshot_load_test.dart`.
4. **C2 + N9 (+ silent catch 2)** — wizard input integrity
   File: `lib/presentation/exam_entry/exam_entry_screen.dart`
   Regression test: `test/widget/exam_wizard_test.dart` (partially corrupt draft
   discarded wholesale; blank correct-count blocks Next with banner).
5. **C3 + C4** — archived-subject silence invariant
   Files: `lib/presentation/providers/notification_providers.dart` (:47-52),
   `lib/presentation/dashboard/dashboard_screen.dart` (:110).
   Regression tests: `test/data/review_notification_service_test.dart`,
   `test/widget/dashboard_p3_test.dart`.
6. **N8** — selected-day write target
   Files: `lib/presentation/providers/task_providers.dart`,
   `lib/presentation/tasks/tasks_screen.dart`. Regression test:
   `test/widget/tasks_test.dart`.
7. **C5** — round-then-classify choke point
   Files: `lib/core/l10n/formatting.dart`, `lib/core/theme/mastery_palette.dart`,
   AnimatedPercentage call sites. Regression test:
   `test/domain/mastery_concepts_test.dart` (49.583 → "50%" neutral; 89.6 → "90%" per
   printed-value band).

Risks: item 1 is the only high-blast-radius change (wipe prompt UX + Firestore rules
interplay — coordinate with security-review's account findings); items 2–3 change
timing/error paths covered by widget tests that pump fake time (debounce tests must
move with the await); item 7 changes rendered output within ±0.5 of boundaries and may
touch pinned design-invariant suites.
