# Phase 2 — Cross-Review: Arabic Copy Audit

Reviewer: Phase 2 cross-reviewer (Arabic copy). Input: `docs/audit/phase1/arabic-copy-auditor.md`.
Base: `ai-audit/2026-08-25`. Method: every cited ARB line re-read in full; every Dart call site
opened; byte-level Unicode verification (python3) for the tanween-order and diacritics claims;
PROJECT.md policy lines read directly. No builds, no app runs, no code modified.

## Summary stats

| Metric | Count |
|---|---|
| Findings reviewed | 25 (F-01…F-25) |
| CONFIRMED | 23 |
| FALSE-POSITIVE | 1 (F-12) |
| STALE | 0 (all file:line references current) |
| DUPLICATE | 0 verdicts; 3 cross-report overlaps flagged for coordination (see dup sweep) |
| Explicit PASS items re-verified | F-25, numerals/dates verdict, hardcoded-Arabic inventory — all hold |
| Severity re-ranks | F-06 P1→P2, F-07 P1→P2, F-11 P1→P2 |
| Missed members of the F-01 plural family found by reviewer | 4 (G-1…G-4 below) |

**Headline agrees with the auditor: no P0.** The one systematic defect is real and verified
down to the placeholder types: seven-plus ARB keys type numbers as `String`, so no ICU plural can
ever fire. My byte-level checks **confirmed** both subtle claims the auditor made
(tanween ordering split 24/4 exactly as listed; `examSaveFailed`'s diacritics) — and the second of
those disproves their own finding F-12.

---

## Per-finding verdicts

Format: claim → VERDICT → evidence → exact current string → final severity · effort · N-id → corrected string (if applicable).

### A. Numbers without plurals

**F-01 `comebackLine`** — CONFIRMED.
Evidence: app_ar.arb:671 `"رجعت بعد {days} يوم — {count} درس عبر معاده."`; placeholders typed
`String` (arb :672-681); dashboard_screen.dart:167
`l.comebackLine(iso(_comebackDays!), iso(_comebackCount ?? 0))` — the `?? 0` makes the zero-case
(«0 درس عبر معاده») reachable. Grammar analysis correct: «بعد 2 يوم» must be يومين; «3 درس عبر
معاده» must be دروس. Proposed replacement is sound Arabic (dual verb agreement «درسان عبرا
معادهما», Egyptian =0 branch matches house voice).
Final: **P1 · M** (two plurals + retyping + codegen). N-id: NEW.
Cross-report overlap: same key as english-copy-auditor.md F-01 (en-side "1 days") — one coordinated fix, not a duplicate defect.

**F-02 `overdueByDays`** — CONFIRMED.
Evidence: app_ar.arb:175 `"متأخّر {days} يوم"`; String placeholder (:176-182); all five cited call
sites verified: lesson_screen.dart:194, chapter_screen.dart:539, review_center_screen.dart:328,
exam_eve_sheet.dart:103, dashboard_screen.dart:721. Highest-traffic-string assessment stands.
Final: **P1 · S** once retyping pattern established. N-id: NEW. Overlap with EN F-01 (same key).

**F-03 `dueInDays` / `dueInDaysLong`** — CONFIRMED.
Evidence: app_ar.arb:159 / :167, String placeholders; chapter_screen.dart:541
`l.dueInDaysLong(iso(summary.daysUntilDue ?? 0))` verified verbatim — plus an unlisted twin at
lesson_screen.dart:196 (`l.dueInDays(iso(summary.daysUntilDue ?? 0))`), so the false «بقي 0 يوم»
case has two entry paths. Proposed =0{أقل من يوم} is a good patch; consider a dedicated
«المراجعة النهارده» if product wants to name day-zero explicitly.
Final: **P1 · S**. N-id: NEW. Overlap with EN F-01 (same keys).

**F-04 `purgeCountsLine`** — CONFIRMED.
Evidence: app_ar.arb:721 `"{subjects} مادة · {chapters} باب · {lessons} درس · {exams} امتحان"`;
four String placeholders (:722-737); recycle_bin_screen.dart:95 and :242 pass raw ints via iso().
The aggravator is real and verified: recycle_bin_screen.dart:241 builds the *first* line of the
same dialog through correct ICU keys (`l.chapterCount(counts.chapters), l.examCountLabel(counts.exams)`),
then line 242 appends this hand-built broken line — one dialog, two grammars, verbatim.
Final: **P1 · M** (four plurals inline). N-id: NEW.

**F-05 `restoreCopyCounts`** — CONFIRMED.
Evidence: app_ar.arb:738 `"النسخة السحابية: {chapters} باب، {exams} امتحان"`; backup_screen.dart:88
raw ints. Data-replacement moment; grammar breaks for most values.
Final: **P1 · S**. N-id: NEW. Route through `chapterCount`/`examCountLabel` as proposed.

**F-06 `insightLessonNotReviewed`** — CONFIRMED.
Evidence: app_ar.arb:321 `"لم تراجع «{lesson}» منذ {days} يوم"`; analytics_screen.dart:208 raw int.
Re-rank: original P1 → **P2**: analytics insight cards are secondary-surface, meaning survives
the wrong tamyiz («منذ 3 يوم»). Effort **S**. N-id: NEW.

**F-07 `insightDiscipline`** — CONFIRMED.
Evidence: app_ar.arb:710 `"التزمت {onTime} من {examined} مراجعة في معادها."`;
analytics_screen.dart:212 raw ints; insights_generator.dart:73 comment does quote «التزمت 9 من 11
مراجعة في معادها» — accurate parenthetical (11+ legitimately takes singular).
Re-rank: P1 → **P2** (secondary surface, see F-06). Effort **S**. N-id: NEW.

**F-08 `examGroupLabel`** — CONFIRMED.
Evidence: app_ar.arb:230 `"{count} أسئلة × {points} درجة"`; exam_entry_screen.dart:602 raw ints.
count=1 → «1 أسئلة» is broken agreement visible during exam recording — main flow, keep **P1**.
Effort **S**. N-id: NEW.

**F-09 Missing `zero` on existing ICU plurals** — CONFIRMED.
Evidence: app_ar.arb:49 (`lessonCount`), :57 (`chapterCount`), :488 (`examCountLabel`),
:497 (`subjectCountLabel`) — all int-typed, none carries `=0`; count=0 falls to `other`
(«0 درس»). CLDR Arabic zero category exists; «لا دروس» proposal correct.
Final: **P2 · S**. N-id: NEW.

### B. Digits policy

**F-10 `authErrorPasswordShort`** — CONFIRMED.
Evidence: app_ar.arb:386 `"كلمة السر ٨ أحرف على الأقل"` — Arabic-Indic ٨ byte-verified; my
full-file scan found exactly two keys with Arabic-Indic digits, these are both of them. Policy:
PROJECT.md:322 «§3.16 Western digits (0123) in both locales»; PROJECT.md:1366 adds that
Arabic-Indic numerals "were asked for and not built". Direct contradiction, on the first-run auth
gate. Final: **P1 · S**. N-id: NEW (adjacent to N16's digit-system consistency theme).
Corrected: `"كلمة السر 8 أحرف على الأقل"`

**F-11 `passwordTooShort`** — CONFIRMED.
Evidence: app_ar.arb:432 `"كلمة السر ٤ أحرف على الأقل."` — byte-verified. Same policy violation,
but on the lock-screen settings path (rarer than auth gate). Re-rank: P1 → **P2 · S**. N-id: NEW (adjacent N16).
Corrected: `"كلمة السر 4 أحرف على الأقل."`

### C. Grammar & spelling

**F-12 `examSaveFailed`: «لم تَضِع» claimed ill-formed** — **FALSE-POSITIVE**.
Evidence (byte-level): app_ar.arb:253 `"تعذّر حفظ الامتحان. أرقامك لم تَضِع — حاول مرة أخرى."`
carries fatha on ت and **kasra under ض** (verified programmatically; only shadda/fatha/kasra
present in the line). With kasra, «لم تَضِع» can only be the jussive of ضاع/ضيع ("your numbers
did not get lost") — which is exactly the intended meaning and perfectly well-formed Arabic. It
would parse as وضَعَ ("put") only with fatha, i.e. «لم تَضَعْ». The diacritics were added
deliberately to disambiguate precisely the trap the auditor fell into when reading undiacritized
text. No action required. (If the register ratification under F-15 later moves exam-flow errors to
Egyptian, this string may be revisited for tone, not grammar.)

**F-13 Tanween order inconsistency** — CONFIRMED.
Evidence (byte-level): exactly 24 values carry alef-then-fathatan («اً») vs exactly 4
fathatan-then-alef outliers, at app_ar.arb:403 (`accountSwitchWipeMessage` …حسابًا),
:426 (`lockMethodBoth` معًا), :754 (`examEveTierWeakest` إتقانًا), :755 (`examEveTierNearestDue`
سقوطًا) — matching the report's list precisely. Normalize the 4 to the dominant form.
Final: **P2 · S**. N-id: NEW. Note: F-21 already rewrites :755 and F-15 touches none of these —
fold the :755 normalization into F-21's edit.

**F-14 Trailing-period inconsistency in auth errors** — CONFIRMED.
Evidence: app_ar.arb:390 (`"...ثم حاول مرة أخرى"` no period), :391 (same, no period) vs :575
(`commonSomethingWentWrong` identical sentence **with** period), :431/:432/:433 periods present,
:386 no period. Verified across all six. Pick convention and align.
Final: **P2 · S**. N-id: NEW.

### D. Register coherence

**F-15 Exam flow register flip + stranded «اترك»** — CONFIRMED.
Evidence: Egyptian verdict strings app_ar.arb:661-663 (`"عدّيت، مش متقن — امتحان تاني هو اللي
يرفعه."`, `"عشان تعدّي الحد: جيب {percentage} في اللي جاي."`) vs MSA discard dialog :254-257
(`"تترك الامتحان؟"`, `"ما كتبته سيضيع. لا يمكن التراجع."`, buttons `"اترك"`/`"أكمل"`). All
verified. The grammar point also holds: bare imperative «اترك» is transitive and objectless here.
Either direction is fine; pick and document. Proposed «هتسيب الامتحان؟»/«سيبه» acceptable.
Final: **P2 · S**. N-id: NEW.

**F-16 Chapter-report gate heavy MSA** — CONFIRMED.
Evidence: app_ar.arb:149 `"لإتقان الباب يجب أن يكون لكل درس امتحان، وأن يبلغ الإتقان {threshold}
على الأقل."` amid Egyptian siblings (:663, :690 «ذاكرتها كلها», :572 «خلص الطابور» — all
verified). Valid inconsistency; alternatively ratify MSA-for-rules as documented house style.
Final: **P2 · S**. N-id: NEW.

**F-17 Tagline vs thesis quote** — CONFIRMED.
Evidence: app_ar.arb:4 `"أنت لا تُنهي الدروس، بل تُتقنها"` vs PROJECT.md:56 blockquote
«إنت مش بتخلص الدروس... إنت بتتقنها» (read directly). Same sentence, opposite register; first-run
shows the MSA one while every design doc quotes the Egyptian one.
Final: **P2 · S**. N-id: **N13** (PROJECT.md ↔ shipped-reality reconciliation).

**F-18 Verification card mixed registers** — CONFIRMED.
Evidence: app_ar.arb:634 (`"بعتنالك رابط تأكيد على بريدك"`) and :638 (Egyptian note) vs :635
(`"لم يتم تأكيده"`) and :636 (`"إعادة إرسال رابط التأكيد"`) — all four verified; one card, two
registers. «لسه متأكدش» chip or full-MSA card both acceptable.
Final: **P2 · S**. N-id: NEW.

### E. Mixed-language leakage & bidi

**F-19 Parenthesized numbers mid-RTL-body** — CONFIRMED as latent hazard (not observed bug).
Evidence: app_ar.arb:260 `"مجموع الأسئلة ({assigned}) يجب أن يساوي العدد الكلي ({total})"` and
:682 `"آخر واجب ({date})"` — ASCII parens outside the isolated digit runs, verified. The auditor's
own framing ("hazard, not observed bug") is honest; UBA bracket pairing resolves the common case.
Fix cheaply while touching these keys anyway (drop parens or move inside isolation at call sites).
Final: **P2 · S**, lowest priority in queue. N-id: NEW.

### F. Wording quality

**F-20 `taskMarkedSurrendered` «مهمة مستسلكة»** — CONFIRMED.
Evidence: app_ar.arb:772 `"مهمة مستسلكة"`; family anchors :774 (`"استسلام"`), :777
(`"تراجع عن الاستسلام"`) — different root, no dictionary anchor, unverifiable coinage for the
student. «مستسلمة» or «مهمة استسلمت منها» keeps the taught root.
Final: **P2 · S**. N-id: NEW.

**F-21 `examEveTierNearestDue` «الأقرب سقوطًا»** — CONFIRMED.
Evidence: app_ar.arb:755, third due-date metaphor after «معاد» (:671, :710) and «موعد» (:98, :280,
:456) — terminology-table analysis verified against the file. «سقوط» reads ominous on the night-
before screen. `"الأقرب معاداً"` (note: apply F-13's dominant tanween order).
Final: **P2 · S**. N-id: NEW. Cross-report overlap: english-copy-auditor.md F-09 last bullet flags
the en value ("Closest to falling due" jargon) — rewrite both locales together.

**F-22 `examVerdictWeak` dangling «قبلها»** — CONFIRMED (borderline).
Evidence: app_ar.arb:661 `"درس ضعيف — دخل مراجعة الـ30 يوم، ذاكر تاني قبلها."` — referent
(المراجعة؟ الـ30 يوم؟) embedded in a compound noun phrase; momentary stumble, not gibberish.
Proposed «قبل ما توصل» is cleaner. Kept at **P2 · S** with the caveat that this is the weakest
confirmed finding in the set. N-id: NEW.

**F-23 `lessonsExaminedOf` «درس بامتحان»** — CONFIRMED.
Evidence: app_ar.arb:87 `"{examined} من {total} درس بامتحان"`, String placeholders. Two defects:
calque-ish construct («درس عليها امتحان» is the natural Egyptian form) **and** membership in the
plural family («3 من 5 درس» → دروس). Final: **P2 · S**. N-id: NEW.

**F-24 `subjectTemplateCount` =1 case government** — CONFIRMED.
Evidence: app_ar.arb:641 `"{count, plural, =1{باباً واحداً} =2{بابين} few{{count} أبواب}
other{{count} باباً}}"` rendered via subjectTemplateAdded :649 (`"تمت إضافة {count}"`, String
placeholder) at subjects_screen.dart:244 → «تمت إضافة باباً واحداً». After the masdar إضافة the
noun is genitive مضاف إليه: «باب واحد». Real case-government error. The missing explicit `many`
slot noted correctly (11–99 borrows `other`; happens to render acceptably here but should exist).
Final: **P2 · S**. N-id: NEW.

**F-25 Gender-address sweep: PASS** — VERIFIED NO-ACTION.
Spot-checked: masculine second person throughout; «كل دروسك في موعدها.» (:276) non-human plural
agreement correct. Claim stands.

---

## Reviewer additions — unflagged members of the F-01 family

The report calls the family "seven keys"; it is under-inclusive. Verified additional String-typed
count placeholders receiving raw ints through iso(), breaking tamyiz identically:

| # | Key (app_ar.arb) | Current string | Call site (verified) | Broken example |
|---|---|---|---|---|
| G-1 | `chaptersMasteredOf` :65 | `"أتقنت {mastered} من {total} باب"` | subject_screen.dart:149-151, dashboard_screen.dart:359-361 | «أتقنت 3 من 5 باب» → أبواب |
| G-2 | `chaptersOfShort` :76 | `"{mastered} من {total} باب"` | dashboard_screen.dart:602 | «3 من 5 باب» → أبواب |
| G-3 | `lessonsOnTimeOf` :98 | `"{onTime} من {total} درس في موعده"` | analytics_screen.dart:144 | «3 من 5 درس» → دروس |
| G-4 | `analyticsVelocity` :624 | `"{value} نقطة لكل دورة مراجعة"` | analytics_screen.dart:850 (passes signed number e.g. `+3`) | «+3 نقطة» → نقاط (3–10) |

Not defects (checked, grammatical for all values): `tasksDoneOf`/`tasksDayDone`/`reviewWaitingHeader`
(bare numbers, no count noun), `examPointsLine` (receives an isolated fraction «12 / 16», not a bare
int — borderline wording, no action now). Note dashboard_screen.dart:602 already passes an int
directly into `l.lessonCount(lessonTotal)` — proof the retyping pattern works at existing call sites.

## Duplicate sweep (vs docs/audit/phase1/english-copy-auditor.md)

No true duplicates (each report flags a *different* defect on the shared keys), but three
coordinated-fix pairs must land together because retyping a placeholder changes generated
signatures for **both** locales:

1. AR F-01/F-02/F-03 (ar tamyiz) ↔ **EN F-01** (`dueInDays`/`dueInDaysLong`/`overdueByDays`/`comebackLine`, "1 days left"). One commit fixes both languages.
2. AR F-04 ↔ **EN F-05** (`purgeCountsLine` separator glyphs in en value).
3. AR F-21 ↔ **EN F-09e** (`examEveTierNearestDue` both locales).

Also noted: EN F-01's claim that "Arabic happens to stay grammatical («بقي 1 يوم»)" is wrong for
values ≥2 — that error is exactly why this review exists.

---

## Workstream proposal

**Workstream name:** `ar-plurals-and-register-hardening`

**Exact file set**
- `lib/core/l10n/app_ar.arb` — all edits (F-01–F-09, F-10, F-11, F-13, F-14, F-16–F-24, G-1–G-4)
- `lib/core/l10n/app_en.arb` — coordinated ICU retypes for shared keys (EN F-01, F-05, F-09e)
- `lib/core/l10n/generated/*` — regenerated by `flutter gen-l10n`, never hand-edited
- Call sites dropping `iso()` where placeholders become `int`:
  `dashboard_screen.dart` (:167, :359, :602, :721), `lesson_screen.dart` (:194, :196),
  `chapter_screen.dart` (:539, :541), `review_center_screen.dart` (:91 stays, :328),
  `exam_eve_sheet.dart` (:103, :104), `recycle_bin_screen.dart` (:95, :242),
  `backup_screen.dart` (:88), `analytics_screen.dart` (:144, :208, :212, :850),
  `exam_entry_screen.dart` (:602), `subject_screen.dart` (:149), `subjects_screen.dart` (:244)
- Tests touching these strings (snapshot/widget tests referencing chips, purge dialog, comeback line)

**Ordered fix sequence**
1. **Plural family, high traffic first** (F-02, F-03 → F-01, G-1, G-2, G-3): retype placeholders
   `String`→`int`, write full six-category ICU sets ar+en simultaneously, drop `iso()` at call
   sites, regenerate. Pattern-setter commit; each later key is mechanical.
2. **Destructive/data moments** (F-04, F-05, F-08): same treatment; reuse existing
   `chapterCount`/`examCountLabel` ICU bodies verbatim inside `purgeCountsLine`/`restoreCopyCounts`.
   Add `=0` branches (F-09) to the four healthy ICU keys in the same commit.
3. **Policy digits** (F-10, F-11): two-character swaps, independent of codegen risk.
4. **Mechanical typography** (F-13 normalize 4 outliers, fold :755 into step 5; F-14 periods).
5. **Wording/register decisions needing one owner call each** (F-15, F-16, F-17→N13 doc edit,
   F-18, F-20, F-21, F-22, F-23, F-24, G-4): batch as string swaps after the owner picks
   direction per pair (Egyptian-vs-MSA per flow; tagline canon; سقوطًا replacement).
6. **Bidi hardening** (F-19): parens removal/isolation at the two keys, last, lowest risk.

**Risks**
- Placeholder retyping changes generated method signatures — compile errors surface every missed
  call site (good), but widget tests asserting old signatures break; update in same commit.
- ICU `few/many` boundaries differ between ar and en — never share a body across locales; keep
  en to `=1/other` per EN F-01.
- Register decisions (F-15/F-16/F-17) are owner taste; without a decision they will churn — get
  the two ratifications written into PROJECT.md before editing those strings (N13).
- `flutter gen-l10n` must run before analyze; CI runs `flutter analyze` and will catch drift.
