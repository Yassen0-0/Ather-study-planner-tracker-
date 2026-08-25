# Phase 4 code review — WS2 reminders (N5, N6)

Reviewer: Phase 4 code reviewer (did not author the changes).
Range: `b23286f` (N5), `047208d` (N6). Branch `ai-audit/2026-08-25`.
Context: `docs/audit/verified-plan.md` WS2; rationale in
`docs/audit/phase2/correctness-review.md` N5/N6.

## Verdicts

| Commit | Fix | Verdict |
|---|---|---|
| `b23286f` | N5 — await real snapshot before rescheduling | **APPROVE** |
| `047208d` | N6 — log scheduler failures | **APPROVE-WITH-NITS** |

## Verification

### 1. N5 — loading fallback can no longer cancel/empty-fingerprint

Confirmed fixed. `_sync` now awaits `ref.read(snapshotProvider.future)` before
`service.reschedule(...)` (`lib/presentation/providers/notification_providers.dart:142`),
so the pass can never see the `?? StudySnapshot.empty()` fallback of
`snapshotValueProvider` (`app_providers.dart:154-155`). The fingerprint is
written only from a snapshot backed by real records
(`review_notification_service.dart:392-395`; dedupe short-circuit at :378).

**Error-path interplay with SnapshotFailed (c771d13):** if drift's first query
rejects, `snapshotProvider.future` completes with that error *inside* the try
block, so it lands in the catch (`notification_providers.dart:175-181`) — logged,
not unhandled. Critically, `reschedule` is never reached on that path: no
`cancelAll()`, no empty fingerprint persisted. The previously applied fingerprint
survives untouched, so alarms already registered keep firing while the read is
failed — consistent with `SnapshotFailed` being recoverable-by-design
(`app_providers.dart:188-195`). This is strictly better than pre-c771d13
behaviour for the scheduler, where a stream error surfaced as `.value == null`
→ empty → cancel-all.

### 2. N6 — catch logs with stack

Confirmed. `on Object catch (error, stack)` +
`debugPrint('Ather: review reminder sync failed -- $error\n$stack')`
(`notification_providers.dart:175-181`) matches the project convention byte-for-byte
in shape (`'Ather: ... -- $error\n$stack'`, cf. `backup_providers.dart:143`,
`write_guard.dart:43`). One log line per sync pass — not per lesson; the loop
lives inside `reschedule`, below the single catch. No spam vector: passes are
debounced/coalesced (:74, :109-112) and `_dirty` replays collapse into one retry
(:184-187).

### 3. Regression tests genuinely pin the race

Yes, both would fail on revert:

- Cold-start test (`test/data/review_notification_service_test.dart:559-624`)
  overrides `snapshotProvider` with a `StreamController` stream that has **not
  emitted** — the exact cold-start state. Asserts zero reschedule calls before
  *and* 6 s past the 5 s debounce (a reverted pass would have already run against
  the empty fallback by then), then emits real data and asserts the owed pass
  plans from lesson 7 and `cancelAllCount == 0`. Reverting to
  `snapshotValueProvider` makes the first assertion fail immediately.
- Log test (:627-668) injects a `_RefusingService` throwing from `initialise`
  and asserts the captured `debugPrint` carries `'Ather:'` and the error text.
  Reverting to bare `catch (_)` fails it.

The second commit's refactor of `pumpScheduler` to take the service as a
parameter keeps the first test intact; both suites still compile and pass.

### 4. Tests run locally

```
flutter test test/data/review_notification_service_test.dart --no-pub
00:00 +29: All tests passed!
```
(includes the 3 new tests: 2 cold-start-race + 1 failure-log)

```
flutter analyze lib/presentation/providers/notification_providers.dart \
  test/data/review_notification_service_test.dart --no-pub
No issues found!
```

### 5. Cross-check — deferred N19 timezone/resume path

No regression. Neither commit touches
`review_notification_service.dart:450-463` (offset guess) or
`refreshLocalLocation`-on-resume; the resume trigger itself
(`notification_providers.dart:105`) is unchanged and now benefits from N5
(resume pass also waits for real data instead of racing the fallback). Deferred
concern remains exactly as deferred.

## Issues

**P2 — `notification_providers.dart:142` — a permanently-hung snapshot future
pins `_running = true`.**
If `snapshotProvider.future` never settles (drift wedged rather than erroring),
the pass holds the `_running` guard indefinitely; later triggers only set
`_dirty` (:116-119) and no further sync runs until the future settles. The old
code could not hang here. Not worth blocking: a hung first query breaks every
screen, not just reminders, and any eventual settle/error replays via `_dirty`.
Optional hardening: race the await against a timeout and treat timeout as
"skip, leave schedule alone".

**P2 — `test/data/review_notification_service_test.dart:654-658` — log test
asserts prefix + message but not the stack.**
The convention under review is "error **and stack**"; the assertion checks
`contains('Ather:')` and `contains('platform refused')` only. A regression that
drops `\n$stack` from the format string would pass this test. One-line follow-up:
also assert the stack text appears (e.g. assert on a marker thrown inside a
nested frame, or match `contains('StateError')` plus a stack frame token).

Neither issue blocks either commit.
