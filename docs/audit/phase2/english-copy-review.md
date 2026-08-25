# Phase 2 — Cross-Review: English Copy + AR/EN Key Parity

Reviewer: phase-2 cross-reviewer (did not author the phase-1 report).
Scope reviewed: `docs/audit/phase1/english-copy-auditor.md` against
`lib/core/l10n/app_ar.arb`, `lib/core/l10n/app_en.arb` and cited Dart files.
All checks are static reads; key sets and placeholder inventories were extracted
mechanically (python3 json parse, independent of the phase-1 scripts).

## Summary stats

| Metric | Value |
|---|---|
| Findings in phase-1 report | 12 (F-01…F-12) |
| CONFIRMED | 12 |
| FALSE-POSITIVE / STALE / DUPLICATE | 0 / 0 / 0 |
| Verdicts with corrected evidence | 1 (F-08 — wrong supporting claim) |
| Severity re-ranks | 3 up (F-01 kept P1 but effort↑; F-03 escalated; F-02 down to P2) — net: F-02 P1→P2 |
| Mapped to N1–N25 | 0 (no phase-0 need covers l10n/copy) → all tagged NEW |

## Authoritative AR/EN parity result (mechanical, this session)

Parsed both .arb as JSON; compared non-@ message keys and brace-argument sets.

```
ar keys (non-@): 348    en keys (non-@): 348
missing in EN: (none)   extra in EN vs AR: (none)
placeholder-set mismatches across all 348 shared keys: 0
ICU plural keys: 6 on each side (chapterCount, examCountLabel, lessonCount,
shareCardLessonsAbove, subjectCountLabel, subjectTemplateCount); en legitimately
drops =2/few/many categories. Confirmed.
```

The phase-1 "naive brace-scan" false-positive explanation is verified: the five
flagged keys (`chapterCount`, `examCountLabel`, `lessonCount`,
`subjectCountLabel`, `subjectTemplateCount`) contain Arabic dual-form words as
ICU sub-message *bodies* (`=2{درسان}` etc.); they are not arguments. Argument
inventories are identical.

**Verdict: perfect 1:1 key parity. No parity drift exists today.** The only
latent parity liabilities are the @metadata gap (F-12) and meaning drift inside
shared values (F-03), not key structure.

### @key metadata gap (re-derived independently)

ar has 60 @blocks, en has 34 → **26 @keys absent from app_en.arb**, exactly
matching the phase-1 lists:

- With `placeholders` block in ar, absent in en (22): analyticsVelocity,
  chaptersMasteredOf, chaptersOfShort, dueInDays, dueInDaysLong,
  examErrorSumMismatch, examGroupLabel, examPointsLine, insightChapterWeak,
  insightLessonNotReviewed, insightStrongestSubject, insightSubjectImproved,
  lessonsExaminedOf, lessonsOnTimeOf, masteryCaptionWithExams, notReadyBody,
  overdueByDays, reviewNotificationBody, reviewNotificationEarlyBody,
  subjectTemplateAdded, trendDown, trendUp.
- Description-only (4): firstRunBody, tasksTitle, todayLabel, weekdaySaturday.
- Shared @keys with differing descriptions (2): shareCardLessonsAbove,
  statMastered.

No build impact while `l10n.yaml` keeps `template-arb-file: app_ar.arb`
(verified in l10n.yaml). app_en.arb alone is not codegen-valid.

## Per-finding verdicts

Severity rubric per instructions: P0 breaks build/l10n or crashes on placeholder
mismatch · P1 wrong/confusing English in main flows or parity drift beyond noise
· P2 polish. This is an Arabic-first product; stiff-but-correct en is not a finding.

---

### F-01 · String-typed day/count strings break en plural at count==1
- Claim: `dueInDays`/`dueInDaysLong`/`overdueByDays`/`comebackLine` render "1 days left", "1 days overdue", "1 lessons came due".
- **VERDICT: CONFIRMED.**
- Evidence: values verified verbatim at app_en.arb:103,104,105,460; placeholders
  typed `"String"` (@dueInDays app_ar.arb:160-166 incl. `"type": "String"` line
  163; @overdueByDays :176-180 line 179; @comebackLine :672). Callers pass raw
  ints wrapped in `iso()`: lib/presentation/lesson/lesson_screen.dart:194,196;
  lib/presentation/chapter/chapter_screen.dart:539,541;
  lib/presentation/dashboard/dashboard_screen.dart:721 and :167;
  lib/presentation/subject/exam_eve_sheet.dart:103-104. Fields are ints
  (lib/domain/services/exam_eve_service.dart:44-45). days==1 is a routine state,
  so "1 days left"/"1 lessons came due" ships on main flows.
- Final severity+effort: **P1, M** (ICU conversion forces placeholder retyping
  String→int, which changes generated signatures; see Workstream risks).
- N-id: NEW.
- Corrected strings (en side of the joint fix):
  - `dueInDays`: `{days, plural, =1{1 day left} other{{days} days left}}`
  - `dueInDaysLong`: `{days, plural, =1{1 day until review} other{{days} days until review}}`
  - `overdueByDays`: `{days, plural, =1{1 day overdue} other{{days} days overdue}}`
  - `comebackLine`: `Back after {days, plural, =1{1 day} other{{days} days}} — {count, plural, =1{1 lesson came due} other{{count} lessons came due}} meanwhile.`

### F-02 · can't vs cannot split in destructive confirms
- Claim: 7 identical closing sentences, two contraction registers; the two
  `can't` instances sit on exam deletion/discard.
- **VERDICT: CONFIRMED** (counts verified mechanically: exactly 7 keys carry
  the undo sentence; exactly 2 use `can't` — examDeleteConfirm app_en.arb:127,
  examDiscardBody:150; cannot: deleteChapterConfirm:74, deleteLessonConfirm:75,
  authDeleteAccountConfirm:212, binPurgeConfirm:289, binEmptyAllConfirm:303,
  accountSwitchWipeMessage:219).
- Re-rank: **P1→P2**. Both forms are correct English; nothing is confusing or
  wrong — pure register consistency. Effort S.
- N-id: NEW. Fix: "This cannot be undone." ×2.

### F-03 · privacy copy drift: en adds sentences ar does not make
- Claim: en adds "The app works offline most of the time anyway." to
  privacyNoCollectBody and "Keep going." to reviewEmptyBody.
- **VERDICT: CONFIRMED** (values verified: app_en.arb:233 vs app_ar.arb:417;
  app_en.arb:162 vs app_ar.arb:276).
- **ESCALATION beyond the phase-1 finding:** the auditor's proposed rewrite
  ("No third-party analytics or crash reporting.") would preserve a claim that
  is **false as shipped in both languages**: Firebase Crashlytics is initialized
  unconditionally in release builds (lib/main.dart:172-199:
  `FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;` +
  PlatformDispatcher.onError recordError; kDebugMode gate only). The AR source
  of truth makes the same false claim («لا تحليلات ولا تقارير أخطاء لجهة
  خارجية», app_ar.arb:417). This needs an owner decision (disclose Crashlytics
  or remove it) before any copy edit; it is not solvable by translation parity.
- Final severity+effort: **P1 (misleading shipped copy on the privacy screen),
  S for the string edit / M including disclosure redesign.**
- N-id: NEW (do NOT apply phase-1's proposed rewrite verbatim).

### F-04 · ASCII "--" vs em dash
- Claim: 9 later-batch keys use `--`; 19 older keys use "—".
- **VERDICT: CONFIRMED.** Mechanical recount: exactly 19 em-dash keys, exactly 9
  double-hyphen keys, and the 9 match the listed set one-for-one (trendSteady
  :183, examVerdictWeak :450, examVerdictPassed :451, comebackLine :460,
  checklistAllDone :479, tasksDayDone :480, examEveTierUnsettled :542,
  reviewBodyDeclining :545, reviewBodyWeak :553).
- **P2, S.** NEW. Fix: replace `--` with `—`. Note F-01 rewrites comebackLine
  and F-09 touches three of these keys — do dash normalization inside those
  rewrites to avoid double edits.

### F-05 · purgeCountsLine separator glyph
- Claim: ar uses middots; en uses spaced full stops.
- **VERDICT: CONFIRMED** (app_en.arb:510 `"{subjects} subjects . {chapters}
  chapters …"` vs app_ar.arb:721 `·`). **P2, S.** N-id: NEW.
- Overlap note: arabic-copy-auditor.md F-04 targets the same key for broken
  Arabic plurals — different defect, same line; fix atomically together.

### F-06 · "I mastered this chapter" button label
- Claim: first-person button among imperative siblings.
- **VERDICT: CONFIRMED** ("I mastered this chapter", app_en.arb:96; rendered via
  PrimaryButton at lib/presentation/chapter/chapter_screen.dart:507; siblings
  viewChapterReport/notReadyGate at :503-509). Judgment call, not an error —
  but the label-register mismatch is real. **P2, S.** NEW. Fix: "Master the chapter".

### F-07 · deleteTaskConfirm drops noun, idiom swap
- **VERDICT: CONFIRMED** (app_en.arb:383 "It will be removed from this day for
  good." vs ar :570 naming the task and نهائياً). Only confirm without the noun.
  **P2, S.** NEW. Fix: "The task will be deleted from this day permanently."

### F-08 · Remove vs Delete split in exam family
- Claim: exams say Remove while everything else says Delete; claims this is
  "contradicted by examDeleteConfirm's deletion framing".
- **VERDICT: CONFIRMED, with corrected evidence.** The inconsistency is real
  (examDelete :126 "Remove exam", toastExamDeleted :128, examRemoveGroup :142 vs
  حذف in ar) — but the cited contradiction is wrong: examDeleteConfirm en (:127)
  says "**removed** from the record", which actually *supports* the Remove
  framing within the exam family. The real inconsistency is cross-family only.
  Recommendation flips: keeping "Remove" is defensible if documented in an
  @description; renaming to Delete would then require touching :126/:127/:128/
  :142 together. **P2, S–M.** NEW.

### F-09 · register pass (5 strings)
Verified individually, all values match the quotes:
- homeworkInvalid (:122) — CONFIRMED, P2, S, NEW. Rewrite accepted.
- exportErrorShare (:406) — CONFIRMED, P2, S, NEW. "Couldn't open the share sheet".
- examVerdictPassed (:451) — CONFIRMED, P2, S, NEW. Also carries a `--` (F-04 overlap).
- examNeedToCross (:452) — CONFIRMED as idiom risk, P2, S, NEW. Mild; either rewrite offered works.
- examEveTierNearestDue (:544) — CONFIRMED, P2, S, NEW. Used as tier chip
  (exam_eve_sheet.dart:85). Coordination: arabic-copy-auditor.md F-21 renames
  the ar value «الأقرب سقوطًا»→«الأقرب معادًا»; change both sides in one commit.

### F-10 · hardcoded Android channel name
- **VERDICT: CONFIRMED** (`static const String _channelName = 'Review reminders';`
  at lib/data/notifications/review_notification_service.dart:69). Shown in OS
  notification settings. **P2, M** (channel rename semantics need the
  new-channel-id migration check). NEW.

### F-11 · seeded curriculum content is Arabic under en locale
- **VERDICT: CONFIRMED as a documented-exception candidate** (Arabic chapter
  names for biology/physics/chemistry at
  lib/domain/services/curriculum_templates.dart:56-83; `_english` Units/The
  Novel :86-97). Deliberate domain content, not chrome. Mitigation (note in
  subjectTemplateNote, both locales — value exists both sides, verified) is
  reasonable. **P2, S.** NEW (adjacent to N10's template work).

### F-12 · metadata hygiene: 26 @keys absent from app_en.arb
- **VERDICT: CONFIRMED.** My independent derivation matches the 22+4 split and
  exact key lists (see parity section above). No build impact under current
  l10n.yaml. **P2, M.** NEW. Fix: mirror @blocks into app_en.arb in the same
  commit as any value edits.

## Dup sweep vs docs/audit/phase1/arabic-copy-auditor.md

No true duplicates (that report audits the Arabic side). Overlapping keys where
both reports touch the same string with different-language defects — must be
fixed in single atomic commits:

| Key(s) | EN finding | AR finding | Relation |
|---|---|---|---|
| dueInDays, dueInDaysLong, overdueByDays, comebackLine | F-01 (en plural) | ar F-01/F-02/F-03 (tamyiz plurals) | related, not duplicate — merge into one ICU workstream |
| purgeCountsLine | F-05 (middots) | ar F-04 (plurals) | related |
| examEveTierNearestDue | F-09 (jargon) | ar F-21 («سقوطًا») | coordinate rename |
| examVerdictPassed / examNeedToCross / examDiscardBody / accountSwitchWipeMessage | F-09/F-02/F-04 | ar dialect/register list (:123,:136,:137) | read both before editing |
| privacyNoCollectBody | F-03 | — (not flagged in ar report) | unique to this report, escalated above |

Note: arabic-copy-auditor.md F-01 says "(placeholders retyped int; **en stays
as-is**)" — that instruction is wrong for en; en must convert too or "1 days
left" survives. This review supersedes that parenthetical.

## Workstream proposal

**Workstream name:** `arb-plurals-and-en-copy-hygiene`

**Exact file set:**
- lib/core/l10n/app_ar.arb
- lib/core/l10n/app_en.arb
- lib/core/l10n/generated/* (regenerate via flutter gen-l10n after edits)
- Call sites of retyped placeholders (drop the now-unneeded `iso()` wrap):
  lesson_screen.dart:194,196 · chapter_screen.dart:539,541 ·
  dashboard_screen.dart:167,721 · exam_eve_sheet.dart:103-104 ·
  recycle_bin_screen.dart:95,242 · backup_screen.dart:88 (+ any
  chapterCount/subjectCountLabel-family callers)
- lib/data/notifications/review_notification_service.dart (F-10, optional/deferred)
- Owner input required before step 2 (privacy claim)

**Ordered fix sequence:**
1. **Owner gate first (blocking):** resolve privacyNoCollectBody vs shipped
   Crashlytics (main.dart:172-199). Do not apply phase-1's rewrite until decided.
2. **Atomic ICU plural migration, both arb files in one commit** (merges EN
   F-01 with AR F-01…F-05): retype placeholders int; install plural sets for
   dueInDays, dueInDaysLong, overdueByDays, comebackLine, purgeCountsLine,
   restoreCopyCounts (and ar-side chapterCount family alignment); update call
   sites; regenerate l10n.
3. **Register/consistency batch (single both-language commit):** cannot
   unification (F-02), dash normalization (F-04, folded into rewritten keys),
   middot separator (F-05), deleteTaskConfirm noun (F-07), masterChapter label
   (F-06), F-09 five strings incl. coordinated examEveTierNearestDue rename
   (ar F-21), F-08 decision recorded in @descriptions.
4. **Metadata parity commit:** mirror the 26 missing @blocks into app_en.arb (F-12).
5. **Deferred:** localized channel name (F-10) behind a channel-id migration
   check; subjectTemplateNote curriculum note (F-11).

**Risks:**
- Every .arb edit MUST touch app_ar.arb and app_en.arb atomically — the repo
  currently has perfect 1:1 parity (verified above); partial commits reintroduce
  drift. PRs should include a mechanical key-diff check.
- Retyping String→int placeholders changes generated method signatures; every
  caller dropping `iso()` loses explicit LRI/PDI bidi wrappers
  (formatting.dart:27). Verify number rendering inside RTL paragraphs after
  migration (gen-l10n emits numeric placeholders inline; spot-check ar chips).
- ICU `plural` requires int-typed placeholders in gen-l10n; do not attempt
  plural syntax with String types (codegen failure).
- Privacy copy is blocked on the owner decision; editing it before the decision
  risks shipping a second false statement.
