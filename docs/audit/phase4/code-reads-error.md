# Phase 4 — code review: reads error surface (WS6 / N7 / C6)

Reviewed commit `c771d13` ("reads surface loading/settled-empty/failed instead of
collapsing to empty") on `ai-audit/2026-08-25`, plus the follow-up hazard commit
`e81724f`. Reviewer did not author the change. Semantics verified against the
resolved **riverpod 3.4.2** sources (`~/.pub-cache/hosted/pub.dev/riverpod-3.4.2`),
not from memory.

**VERDICT: APPROVE-WITH-NITS.** The commit does what it claims; every issue found
is P2 or belongs to another wave's commit (one P1 branch-level test regression is
pin-pointed below and is *not* this commit's).

---

## 1. State model (`app_providers.dart:165-210`) — CORRECT, two semantic notes

Sealed `SnapshotRead` → Loading / Ready / Empty / Failed; classifier at :202-210.
Traced per-state against riverpod 3.4.2:

| Stream event | Element state | Classifier | Correct? |
|---|---|---|---|
| first load | `AsyncLoading`, no value | Loading | yes |
| data | `AsyncData` | Ready / Empty via `isEmpty` | yes |
| error before any value | `AsyncError`, `_value == null` | Failed (`error!` safe behind `hasError && !isLoading`) | yes |
| error after a value | `AsyncError` **carrying previous value** | Ready(stale) — see note B | see B |

Self-heal holds: drift's `.watch()` keeps running after an error, so the next good
re-query re-classifies to Ready/Empty with no student action.

**Note A (P2, comment vs code).** The doc (:199-201) claims a re-subscription keeps
the previous value on screen "rather than flapping back to a spinner". It does not:
`settled = async.isLoading ? null : async.value` (:204) discards the stale value of
a reload-with-value state (riverpod builds these via `copyWithPrevious`,
`element.dart:61-70` + `async_value.dart:745-771`), so any invalidate — e.g.
`ref.invalidate(snapshotProvider)` at `backup_gate.dart:134` — shows one gated
blank frame, not stale content. Behavior is *safe* (no false-empty), but the
comment documents the opposite of the code. Fix if kept: test `async.hasValue`
before `isLoading`.

**Note B (P2, narrower failure surface than documented).** A stream error emitted
*after* data routes through `onValue(AsyncError)` → `asyncTransition` →
`AsyncError.copyWithPrevious(previous)` (`element.dart:269-271`,
`async_value.dart:867-871`), so the state carries the stale snapshot and the
classifier's value-first branch returns **Ready(stale), never SnapshotFailed**.
Consequence: the failure card fires only when the *first* emission fails
(cold-start failing disk — the primary C6 scenario). Mid-session hiccups hold
stale content silently until self-heal. Harm class closed either way (never
false-empty), but `SnapshotFailed`'s doc overpromises; worth one sentence.

## 2. Settle-gating — VERIFIED in both screens

- `dashboard_screen.dart:180-200`: Failed → `_ReadFailedCard` (:329-347); Loading →
  renders *neither* `_FirstRunCard` nor overall/stats cards; only settled Empty may
  show first-run copy. Share button and comeback line are independently gated on
  `!dashboard.isEmpty`.
- `review_center_screen.dart:85-97`: Failed → `EmptyState(commonSomethingWentWrong)`;
  Loading → `SizedBox.shrink()`; the green "all caught up" celebration is reachable
  only in the settled branch — false congratulation suppressed.
- Covered by new tests, all passing: `dashboard_p3_test.dart:413,433` and the
  classifier group at :323-368 (Failed/Loading/Empty/Ready).

## 3. `databaseExecutorProvider` removal — CLEAN

`rg -w databaseExecutorProvider` across the repo excluding docs: **zero matches**
(exit 1). Only prose references remain in audit docs.

## 4. Integration hazard (unawaited-rejection class) — CLOSED

Every consumer awaiting `.future` on snapshot/task providers, with protection:

| Site | Protection |
|---|---|
| `backup_providers.dart:140-141` | try :139 / `on Object` catch :142-149 → hold + SyncState.failed (**e81724f**) |
| `backup_gate.dart:105` | try :104 / catch :106-112 → hand-over held, uid stays recorded |
| `backup_gate.dart:257` | try :256 / catch :258-266 → restore held, N14 surface |
| `backup_gate.dart:285` | own nested try :284 / catch :286-294 (deliberately outside the outer BackupException-only catch) |
| `notification_providers.dart:142` | inside try :126, `on Object` catch + finally (:176-186) |
| `export_providers.dart:65-66` | `_buildBackup` awaited inside `share()`'s try :40, `on Object` :48-52 |

No other `.future` awaits exist under `lib/`; `snapshotReadProvider` is a plain
`Provider` (no `.future`) and nothing awaits one. **No unprotected sites remain.**

Nit (P2): `dashboard_p3_test.dart` `bootScreen` doc (~:383-391) still says the gate
"awaits `snapshotProvider.future` outside its try ... not fixed here" — stale since
e81724f.

## 5. ~20 non-migrated `snapshotValueProvider` readers — ACCEPTABLE TRANSITIONAL

~26 live lib references (exam_eve_sheet :31; recycle_bin :43; subjects :53,:96;
settings :125,:132,:136,:690; review_center :52; derived providers app_providers
:221,:228,:245; notification :49; summary :64,:89,:99,:109; navigation :32;
lesson :102; exam_entry :630; dashboard `_NextCard` :710; chapter_report :124,:143;
analytics :86,:186; chapter :218,:310).

Judgment: acceptable as a transitional state, not a silent trap, because (a)
mid-session errors carry the stale value (note B), so these readers keep rendering
real content through a hiccup; (b) on cold-start failure they briefly show zeroed
cosmetics that self-correct or sit beside screens that now say failed — the same
frames that, pre-fix, showed a false first-run card and false celebration. One
reader deserves priority when migration resumes: `settings_screen.dart:690` reads
`isEmpty` off the fallback next to delete-account (only weakens an offline warning;
fail direction benign, but it is decision-adjacent). Track the sweep to completion.

## 6. Tests + baseline comparison — claim VERIFIED FALSE

HEAD (`b172cba`): `flutter test dashboard_p3_test review_center_p3_test --no-pub`
→ +10 −4. New N7/C6 cases pass. Failing:

```
dashboard_p3_test:    adding a subject lands you inside the new subject
review_center_p3_test:a waiting header counts the queue, and only when there is one
review_center_p3_test:subject chips narrow the queue and let it back out
review_center_p3_test:the card is the one way into the exam -- no second button
```

Baseline check per instructions: throwaway worktree at **053f079**
(`git worktree add --detach`; copied `.dart_tool/package_config.json`
(+package_graph.json, required by flutter) from main checkout; pubspec\*
byte-untouched, verified empty `git status`). Same suites → **+9, All tests
passed!** Byte-for-byte failure-set comparison: baseline ∅ vs HEAD {4} → the
"pre-existing-at-baseline" claim is **FALSE** as stated against 053f079.

Attribution bisect (deterministic runs, logs kept in `/tmp/opencode/bisect-*.log`,
worktree since removed): parent-of-range 7002fec **good** → first bad commit =
**191303d** ("gate account switch on local data, not just the recorded uid",
C1 wave). Failures byte-identical at 191303d, c771d13, 01f8c7d and HEAD — i.e.
they *are* pre-existing relative to c771d13 (its parent already failed), but were
introduced by an earlier wave commit and are not caused or worsened by c771d13.
Mechanism: p3 boots sign in over a seeded non-empty record with mock prefs lacking
`kLastAccountUidKey`; 191303d's data-driven gate now treats null-previous as
hand-over and posts the wipe-confirmation bottom sheet post-frame, which absorbs
every nav tap (`_RenderBottomSheetLayoutWithSizeListener` in the hit path,
bisect log line 58). Test-only hygiene fix owed by the C1 wave owner (seed the uid
key or override the gate in the boot helpers).

`flutter analyze --no-pub`: No issues found.

---

## Issue ledger

- **P1 (branch-level; NOT this commit)** — 4 nav-tap failures in
  dashboard/review-center p3 suites, introduced by `191303d`, falsely reported as
  pre-existing-at-baseline (053f079 passes clean). Required fix (other owner):
  seed `kLastAccountUidKey`/override `BackupSyncGate` in the p3 boots.
- **P2** — `app_providers.dart:199-201` comment contradicts code: reload-with-stale
  maps to Loading (:204), not stale-on-screen.
- **P2** — `SnapshotFailed` unreachable for post-data errors (riverpod carries the
  previous value into `AsyncError`, element.dart:269-271); document or accept.
- **P2** — stale test doc in `dashboard_p3_test.dart` bootScreen (gate awaits now
  guarded since e81724f).
- Transitional (tracked): ~20 `snapshotValueProvider` readers; migrate
  `settings_screen.dart:690` first.
