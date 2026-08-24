# Correctness Audit

Phase 1, read-only. Scope: `lib/domain/services`, `lib/data/repositories`, presentation
providers. Every finding carries concrete repro math. Phase-0 findings are not repeated;
two are deepened with new evidence.

## New findings

### C1 — Legacy null-uid first sign-in silently adopts the local curriculum into the new account's cloud backup

- **File:line:** `lib/presentation/providers/backup_gate.dart:68-104` (guard), with
  `lib/presentation/providers/backup_providers.dart:99-102` (owner check) and
  `backup_gate.dart:197-224` (auto-restore).
- **Failure scenario:** A phone used Ather before accounts shipped (Rule 1 upgrades make
  this the normal install path); it holds a full curriculum. `kLastAccountUidKey` is only
  ever written by the gate, so it is absent. Someone signs in with fresh account B:
  1. `_clearIfDifferentAccount`: `previous == null` -> lines 74-77 treat it as "first
     sign-in ever", write uid = B, return true. The wipe sheet is never shown; the
     non-empty-database check at line 83 is skipped entirely on this branch.
  2. `_restoreIfEmpty`: snapshot non-empty, so no auto-restore. Local data stays.
  3. Any snapshot emission arms `BackupSyncNotifier._schedule`; after 20 s `flush()` runs:
     `account.id == B`, `owner == B`, guard passes, and
     `StudyBackup.fromSnapshot(...)` uploads student A's entire record into B's cloud
     document.
  Harm chain: B's cloud copy is now A's curriculum. If B signs in on a new phone,
  auto-restore hands them A's exams as their own. When A re-signs in here, the gate sees
  `previous == B`, prompts, wipes — and A's only surviving copy lives in B's document,
  deletable by B. This is exactly the "one student's chapters end up in another student's
  cloud document" corruption the uid gate exists to prevent (backup_providers.dart:94-98),
  defeated by the one state (`previous == null`) its comment calls safe.
  Sub-case, same root: device holds tasks but no study rows; the emptiness check ignores
  tasks by design (backup_gate.dart:183-196), auto-restore lands, and
  `DriftTaskRepository.restoreTasks` (drift_task_repository.dart:208-230) deletes the local
  tasks and inserts the account's cloud tasks — silent replacement of the only copy.
- **Severity:** P1.
- **Proposed fix:** On `previous == null` AND a non-empty local database, run the same
  confirmed wipe sheet (or persist a migration marker at upgrade time so "absent key +
  non-empty DB" is distinguishable from a genuinely empty first-ever sign-in).
- **Risk:** Touches the most destructive flow in the app. Scope the prompt to absent-key +
  non-empty DB so it fires once per upgraded device and never for fresh installs.

### C2 — Draft restore applies a subset of groups, contradicting its documented wholesale rejection

- **File:line:** `lib/presentation/exam_entry/exam_entry_screen.dart:127-171`
  (`_restoreDraft`; per-entry skips at lines 148 and 152).
- **Failure scenario:** The comment promises unreadable drafts are "ignored wholesale
  rather than half-applied". The code skips individual entries instead. Draft
  `{"total":"30","groups":[["12","1","9"],["6","2"],["12","1","7"]]}` (middle entry lost an
  element): entry[1] fails `entry.length != 3` and is dropped; the wizard opens with 2
  groups; step 2 shows `24 / 30` and Next refuses with sum-mismatch for a paper the student
  entered complete. Worse variant: if the total field was also truncated to the surviving
  groups' sum (`20`), step 2 validates clean and a short paper saves as complete: original
  3x10 questions with 17 correct = 56.7% becomes 17 of 20 possible = **85%** recorded.
- **Severity:** P2 (silent score inflation needs double corruption; visible case is a
  confusing half-restored draft).
- **Proposed fix:** Two-pass decode into a temp list; if any entry fails its shape check,
  discard the whole draft before touching `_groups`.
- **Risk:** Trivially low; strictly narrows what is accepted.

### C3 — hasScheduledReviewsProvider counts archived/deleted subjects' lessons, so Settings warns about reminders that cannot exist

- **File:line:** `lib/presentation/providers/notification_providers.dart:47-52`.
- **Failure scenario:** All examined lessons sit under an archived subject.
  `planReminders` walks `snapshot.activeLessons` (review_notification_service.dart:225)
  and correctly schedules nothing. But this provider reads
  `snapshot.lessons.any((l) => l.lastReviewedAt != null)` -> true, so
  `_NotificationsWarning` (settings_screen.dart:579-599) renders "reminders blocked"
  whenever the OS permission is off. Repro: 1 archived subject, 4 examined lessons,
  permission revoked -> warning shown; actual scheduled alarms = 0 even when permission is
  granted. Same for lessons under deleted subjects sitting in the bin.
- **Severity:** P2 (false claim on the honesty surface built to explain the switch).
- **Proposed fix:** Use `activeLessons` like every other reader of review state.
- **Risk:** None.

### C4 — Comeback banner counts lessons under archived/deleted subjects

- **File:line:** `lib/presentation/dashboard/dashboard_screen.dart:109-122`.
- **Failure scenario:** Archive Physics holding 8 examined lessons last proven 10 days
  before leaving; active subjects hold 3 examined lessons. Away 40 days. On return all 11
  satisfy `needsReview(lesson, now)`, and all 11 pass the
  `calendarDaysBetween(last, storedDay) >= kReviewCycleDays` filter (10 < 30 at leave), so
  the line claims «١١ درس» fell due during the absence while the screen below shows 3 red
  rows — the other 8 are invisible everywhere by product rule (archived subjects are silent
  in queue, notifications, insights).
- **Severity:** P2.
- **Proposed fix:** Iterate `snapshot.activeLessons`.
- **Risk:** None.

### C5 — Display rounds half-up but band/colour classify the raw value: "50%" painted red, "90%" painted plain

- **File:line:** `lib/core/l10n/formatting.dart:34-38` (`value.round()`) vs
  `lib/domain/entities/mastery.dart:21-26` and `lib/core/theme/mastery_palette.dart:36-43`
  (thresholds applied to the raw double). Paired at e.g.
  `lib/presentation/chapter/chapter_screen.dart:528-583` and every AnimatedPercentage row.
- **Failure scenario:** One exam, 119 of 240 points: percentage = 49.583...
  - Colour: `resolve(percentage: 49.583...) < 50` -> red;
  - Text: `percent(49.583...)` rounds -> "50%".
  The student reads 50% — defined as متوسط/neutral — in the failure colour. Mirror:
  mastery 89.6 prints "90%" in plain black while the band table calls 90 متفوق (green);
  velocity display already handles this exact class by rounding *before* the sign decision
  (analytics_screen.dart:829-837) — mastery colouring does not.
- **Severity:** P2 (systematic contradiction between number and verdict near every
  boundary; window is ±0.5 around 50/70/90 and weighted figures land there routinely).
- **Proposed fix:** Classify the displayed value: round once at a single choke point and
  resolve colour/band from the rounded value (or floor the displayed value so it can never
  cross the threshold the colour used).
- **Risk:** Low; rendered output changes only within ±0.5 of boundaries.

### C6 — A drift watch error renders an empty curriculum app-wide, and backgrounding during it throws unhandled into Crashlytics as fatal

- **File:line:** `lib/presentation/providers/app_providers.dart:154-156`,
  `lib/data/repositories/drift_study_repository.dart:1111` (`onError:
  controller.addError`), `lib/presentation/providers/backup_providers.dart:84`
  (`unawaited(flush())`) and `121-122` (awaits outside the try that starts at line 144).
- **Failure scenario:** A transient SQLite failure during a watch re-query (disk full /
  I/O error — the exact case write_guard.dart:48-50 names as common on target phones):
  1. The combined stream forwards the error; `snapshotProvider` enters AsyncError.
  2. Every screen reads `snapshotValueProvider`; `.value` is null on AsyncError, so the
     fallback yields `StudySnapshot.empty()`. Dashboard shows the first-run card and "—" /
     0-of-0 stats: the app claims the record is gone while it sits intact one layer down.
     The loading-fallback was documented as a trade for transient frames (comment lines
     150-152); nothing sanctions extending it to error states.
  3. Backgrounding now fires `flush()` from the lifecycle listener; line 121 awaits
     `snapshotProvider.future` OUTSIDE any try, the future completes with the stream error,
     and since `_schedule()` wrapped the call in `unawaited(...)`, main.dart:198-200 records
     it `fatal: true`. A recoverable read failure becomes a fatal crash report, and
     `SyncState` never leaves idle.
- **Severity:** P2 (no data loss; app-wide false emptiness plus fatal-noise channel).
- **Proposed fix:** Distinguish loading from error at the read site (render an explicit
  error state, not empty), and move the two `.future` awaits inside `flush()`'s try /
  wrap `flush()` bodies so background flushes cannot escape as fatal reports.
- **Risk:** Low.

## Deepened known findings (new evidence only)

- **Failed offline auto-restore then empty upload overwrites backup**
  (phase-0: backup_gate.dart:212-224 / backup_providers.dart:124-141): deepened, not
  superseded, by C1. Phase 0 established the empty-upload hazard after a failed download;
  C1 shows the same upload path also mis-*attributes* data whenever
  `kLastAccountUidKey` is absent, because the owner check (lines 99-102) compares against a
  key written unconditionally on the null-previous branch. Any fix for one must consider
  the other: gating uploads on "a restore check has completed successfully this session"
  would close both.
- **Timezone offset-guess drift** (phase-0: review_notification_service.dart:450-463):
  new evidence narrows the blast radius. For an unmapped zone (e.g. UTC+5),
  `tz.local` resolves to UTC while `reminder.at` carries +05 wall-clock components;
  `tz.TZDateTime.from(at, tz.local)` preserves the instant, so the alarm still fires at
  18:00 local (13:00Z == 18:00+05). The residual defect is fingerprint churn, not delivery:
  `fingerprintOf` stores `at.millisecondsSinceEpoch` computed under the old offset, so
  after travel the same wall schedule hashes differently and every resume pays a full
  cancel-and-rebuild until the stored fingerprint catches up. Also: mapping every +02/+03
  device to Africa/Cairo is wrong for non-Egypt zones whose transition calendar differs
  (e.g. Palestine +02/+3 with different shift dates), where a reminder anchored across the
  foreign transition lands an hour off — the exact harm class the phase-0 note describes,
  now with the mechanism named.

## Silent catches (new ones only)

Phase-0's six (notification_providers.dart:34-36 and 164-167; backup_gate.dart:220-223;
auth_providers.dart:67-70; review_notification_service.dart:460-461;
exam_entry_screen.dart:138-140) are excluded.

1. `lib/presentation/settings/settings_screen.dart:566-570` — `requestPermission()` throw
   is swallowed with no log and folded into "not allowed"; indistinguishable from a refusal
   in diagnostics.
2. `lib/presentation/exam_entry/exam_entry_screen.dart:401-404` — same swallow on the
   post-save permission ask; a platform-channel regression here is invisible.
3. `lib/presentation/providers/backup_gate.dart:142-148` — failure to show the account-switch
   wipe confirmation is debugPrint-only; production gets no signal that a destructive-flow
   safety prompt could not render (fail direction is safe: no wipe).
4. `lib/core/haptics/app_haptics.dart:78,94` — platform-channel send failures are swallowed
   twice (sync catch + async catchError); a permanently broken vibrator channel produces no
   telemetry.
5. `lib/presentation/providers/app_providers.dart:155` — `.value ?? empty` converts
   AsyncError into an empty curriculum with no trace (the UI half of C6).

## Test-honesty notes

- Strong overall: domain tests assert behaviour against hand-computed numbers with tight
  tolerances (`closeTo(28, 0.001)` velocity cases), tie-break determinism is pinned via
  id ordering, and the "old spike" test (insights_generator_test.dart:771-815) asserts both
  that the climb exists and that today's rate is zero — it cannot pass vacuously. Fixtures
  build snapshots through the real `DriftStudyRepository`, so mocks do not mirror bugs.
- Gap (masks C2): nothing tests `_restoreDraft` against a partially corrupt groups array;
  the wholesale-rejection contract is prose only. A test feeding a 3-entry list with one
  malformed entry would have failed against current code.
- Gap (masks C3/C4): no test asserts `hasScheduledReviewsProvider` or the comeback counter
  exclude archived/deleted subjects, although the equivalent scoping IS tested for the
  review queue — the suite encodes "archived means silent" per-feature rather than as one
  shared invariant.
- Gap (DST claims untested): comments across review_cycle_service.dart and
  insights_generator.dart justify calendar-day arithmetic via Egypt's DST shifts, but zero
  tests mention DST/timezones (rg across test/: no hits) and every fixture runs under the
  test runner's local zone (UTC in CI). `_reminderOn`'s component arithmetic across a real
  transition (e.g. Cairo 2026-04-24) is asserted nowhere; the DST-safety argument currently
  rests on reading, not evidence.
- Minor: `widget_test.dart`/design-invariant suites pin implementation details (dashboard
  subject-mark absence is enforced by test), which is fine for owner decisions but should
  not be imitated for logic under test.
