# Phase 4 — WS7 entry-task code review (2026-08-25)

Reviewer: phase-4 reviewer (not author). Range: 008d11a, 4cbe908+f7a5f43, d36e794,
8d2914f+e325917, 01f8c7d, 754305f on `ai-audit/2026-08-25`. Plan: verified-plan.md WS7;
rationale: phase2/{correctness,maintainability,performance}-review.md.

## Verdicts

| Commit(s) | Finding | Verdict |
|---|---|---|
| 008d11a | PF1 rebuild guard | **APPROVE-WITH-NITS** (P2 stale tally) |
| 4cbe908 + f7a5f43 | N9 blank-count gate | APPROVE |
| d36e794 | C2 discard-on-malformed | APPROVE |
| 8d2914f + e325917 | M2 band constants | APPROVE |
| 01f8c7d | PF2 ExamDraftStore | **APPROVE-WITH-NITS** (pinning nit) |
| 754305f | N8 day re-seed | APPROVE |

## Per-commit evidence

**PF1 (008d11a)** — Guard is the one-liner phase2 prescribed
(`if (_error != null) setState(...)`, exam_entry_screen.dart:204). Error-banner path is
safe: with a banner standing, first keystroke clears + rebuilds; no stale banner over
changed text. **But a stale-UI regression exists where no banner stands**: step 2's live
tally reads `_assigned/_totalValue` in build (exam_entry_screen.dart:552-567) with no
controller listenable; pre-PF1 the unconditional setState re-rendered it per keystroke,
post-PF1 it freezes until some other rebuild. Empirically confirmed: probe test typed a
group count on step 2 and `iso('1 / 4')` was absent after pumps; reverting only the guard
line restores per-keystroke rendering (mechanism identical to the documented PF1 finding).
P2 — exam_entry_screen.dart:560-567 vs :557-559 comment ("turns green the moment the
groups add up" now false). Fix: wrap the tally Text in `ListenableBuilder` merged on the
step-2 controllers (the pattern 4cbe908 briefly introduced).

**N9 (4cbe908→f7a5f43)** — Final shape gates inside `_next`, the single advance choke
point (`if (!_step3Complete) return;`, exam_entry_screen.dart:326); button/keyboard have
no other path to `_save` (NumberField wires no onSubmitted). Blank → parse-null → blocked;
typed `'0'` passes (`int.tryParse != null`, :212-213); whitespace-only blocks.
Supersession is sound: 4cbe908's `_step3Complete` also required `correct <= countValue`,
so an exceeds-count kept the button disabled and `_next` never ran — the banner died.
f7a5f43 narrows completeness to "a number was typed", restoring the exceeds banner
(pinned by 'N9 parity' test). Red→green proven by mutation: removing the gate line fails
'a blank correct count cannot silently record an all-wrong paper' (blank advanced to a
0% summary). Silent refusal is deliberate and documented (:322-325): no dialog, no delay,
entry speed untouched.

**C2 (d36e794)** — Shape failures now `return` (whole-draft discard), not `continue`
(exam_entry_screen.dart was :148/:152, now via store). Post-PF2 the matrix lives once in
`ExamDraftStore.load` (exam_draft_store.dart:120-165) and covers: truncated JSON, non-JSON
garbage, non-map payload, short group entry, non-string field anywhere, non-string total,
empty groups, absent key — all unit-pinned (exam_draft_store_test.dart:123-203) plus the
widget-level truncated-draft test (exam_wizard_test.dart:552+). Mutation verified:
flipping either `return` back to skip fails the WHOLE-draft test.

**M2 (8d2914f+e325917)** — Constants at mastery.dart:37-40 (50/70/90), same `<`
comparisons as `fromPercentage` had at baseline 053f079 (verified side-by-side), so AT the
edges behavior is byte-identical: 50→medium, 70→good, 90→excellent; palette's old
`>= 90` ≡ band==excellent for every double including negatives/>100. All five wizard
`after < 70` sites now read `belowGood`; palette branches on band. Remaining `< 50`-style
literals in lib are doc comments only. Pinned from both sides: constant values, inclusive-
lower edge table (49.999/50/69.999/70/89.999/90), and dense palette-vs-band parity in both
themes (mastery_band_test.dart). e325917 drops real analyzer nits. Nit (P3):
kChapterMasteryThreshold=70 (mastery.dart:44) could read kGoodBandLowerEdge — defensible
to keep separate if the policies may diverge; say so if so.

**PF2 (01f8c7d)** — 400ms trailing debounce (exam_draft_store.dart:10-13,47-57); flushes
at paused/detached (:139-146), dispose (:104-106), back (:265-267) and advance (:337-338)
— every loss boundary the timer can't see. `clear` cancels pending then removes, no
resurrection (exam_draft_store_test.dart:89-107). Wipe contract intact: app_providers.dart
:290/:311 still deletes by `kExamDraftKeyPrefix`; account_switch_gate_test.dart:355 pins
drafts gone after switch. Pinning test exists (exam_draft_store_test.dart:32-41) and both
literals are byte-equal `'exam_draft_'`. Nit (P2): the pin asserts only the store's own
literal — import `kExamDraftKeyPrefix` there and assert equality so the hand-coupling is
machine-checked, not just commented.

**N8 (754305f)** — `build() => dayOf(ref.watch(nowValueProvider))`
(task_providers.dart:36). nowValueProvider moves only at date boundaries (midnight timer
+1s; resume suppressed when day unchanged, app_providers.dart:96-113), so an explicit
same-day pick survives every same-day rebuild; only a real boundary re-seeds. Test drives
`nowProvider` via a manual StreamController — deterministic, no wall-clock/timer flake —
and proves the post-midnight "+" writes into the new today, not the abandoned pick
(tasks_test.dart:569+). Suite passes.

## Issues

- **P2 exam_entry_screen.dart:560-567** — step-2 tally frozen between rebuilds under the
  PF1 guard (stale count shown while typing; its own comment now false). Wrap in a
  controller-driven ListenableBuilder.
- **P2 exam_draft_store_test.dart:35** — prefix pin doesn't reference
  `kExamDraftKeyPrefix`; assert equality to lock the D-01/N20 wipe coupling.
- **P3 exam_entry_screen.dart:212-213** — typed-0-stays-valid is implemented but unpinned
  (no test enters '0' as a correct count and saves).
- **P3 mastery.dart:44** — 70 duplicated across kChapterMasteryThreshold and
  kGoodBandLowerEdge (see M2 note).

## Test results (all `flutter test --no-pub`, pubspec untouched)

- test/domain/mastery_band_test.dart + test/data/exam_draft_store_test.dart — **21 passed**
- test/widget/exam_wizard_test.dart — **17 passed**
- test/widget/tasks_test.dart — **13 passed**
- flutter analyze --no-pub — No issues found
- Mutation checks (temporary, reverted, tree clean): N9 gate removal → blank test red;
  C2 skip-instead-of-return → whole-draft test red; PF1 guard removal → tally probe green
  (regression reproduced).

## UX regression watch (#8)

No dialog, no banner latency, no disabled-button ambiguity: a blank correct count simply
does nothing on Next, and the moment any digit is typed the flow proceeds exactly as
before (pinned by tests that needed only a single extra pump). Fast entry is unslowed.
The one watch item is the P2 stale tally above — cosmetic liveness, not speed or safety.
