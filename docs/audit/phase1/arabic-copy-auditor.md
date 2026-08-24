# Arabic Copy Audit

Phase 1, read-only. Scope: `lib/core/l10n/app_ar.arb` (348 keys, full parity with
`app_en.arb` — 348/348, no orphan keys either side), plus every Dart surface that
renders or bypasses it. Voice reference: PROJECT.md:56 «إنت مش بتخلص الدروس...
إنت بتتقنها». Digits policy: PROJECT.md §3.22/§3.16 (Western digits in both locales).

**Headline: no P0.** The l10n discipline is unusually good — bidi isolates on every
number (`lib/core/l10n/formatting.dart`), notifications and export labels all route
through the ARB, punctuation is genuinely Arabic (، ؟ … only). The systemic defect is
**one family**: seven ARB keys take a number as a bare `String` placeholder and hand-build
«X يوم / X درس / X مراجعة» with no ICU plural, so 1, 2 and 3–10 all render with the wrong
count-noun. That family is this report's core.

---

## Terminology decisions table

| Term (concept) | Chosen form | Where violated |
|---|---|---|
| chapter | «باب» | Consistent everywhere (never «فصل»). ✅ Only `pdf_export_service.dart:40` uses «الفصل الأول» inside an English comment — not user-facing. |
| lesson | «درس» | Consistent. ✅ Never mixed with «مهمة» (tasks are a separate concept, consistently «مهمة»). |
| exam | «امتحان» | Consistent; zero occurrences of «اختبار» in the ARB. ✅ |
| review cycle / due date | **three competing words**: «المعاد» (`comebackLine` «عبر معاده», `insightDiscipline` «في معادها»), «موعد» (`lessonsOnTimeOf`, `reviewNotificationBody` «حان وقت مراجعة», `subjectsArchivedNote`), «سقوط» (`examEveTierNearestDue` «الأقرب سقوطًا») | Pick one for the deadline concept. Recommendation: «المعاد» — it is the word already carrying the mechanic in the two most voice-defining strings, and «سقوط» reads like failure-by-another-name on the exam-eve sheet. Violators to rewrite: app_ar.arb:755, :98, :611. |
| mastery threshold | «حد الإتقان» / «الحد» | Consistent (`shareCardLessonsAbove`, `examNeedToCross`). ✅ |
| study vs review | «مذاكرة» ≠ «مراجعة» | Kept apart correctly («خطوات المذاكرة» vs «وقت المراجعة»). ✅ |
| proven state | «أثبتَ/مُثبت» (coined from the product term) | Consistent across `shareCardLessonsAbove`, `examEveTierUnsettled`, `summaries.dart` docs. ✅ Deliberate coinage — do not "fix". |
| notes = الملازم | «الملازم» (Egyptian school word) | `checklistReadNotes`, `checklistReviewedNotes`. ✅ In-voice. |
| transliterated tech | «درايف»، «واتساب» (`exportWhereNote`) | Acceptable for the audience; keep, but record as the sanctioned list — nothing else may transliterate ad hoc. |
| surrender | «استسلام» family | `surrenderTask`, `undoSurrender` consistent. ⚠️ `taskMarkedSurrendered` «مهمة مستسلكة» uses a different root («استسلك») that appears nowhere else and in no dictionary — see F-20. |

---

## Findings

### A. Numbers without plurals (the systematic family) — audit item 2

Every finding below quotes the exact current string. All placeholders here are typed
`String` in the ARB and receive raw ints through `iso()` at call sites, so no plural
logic can ever apply.

**F-01 · `comebackLine` (app_ar.arb:671)** — P1 — risk: dashboard greeting for every returning student
- Current: `"رجعت بعد {days} يوم — {count} درس عبر معاده."`
- Call site: `dashboard_screen.dart:167` → `l.comebackLine(iso(_comebackDays!), iso(_comebackCount ?? 0))`
- Problem: both slots break. days=2 → «بعد 2 يوم» (must be يومين); count=3 → «3 درس عبر معاده» (must be «دروس عبرت معادها»); count=0 → «0 درس عبر معاده» states a positive fact about zero lessons.
- Proposed replacement:
  `"رجعت بعد {days, plural, =1{يوم واحد} =2{يومين} few{{days} أيام} other{{days} يوماً}} — {count, plural, =0{ما حدش عبر معاده} =1{درس واحد عبر معاده} =2{درسان عبرا معادهما} few{{count} دروس عبرت معادها} other{{count} درساً عبر معاده}}"`
  (placeholders retyped `int`; en stays as-is).

**F-02 · `overdueByDays` (app_ar.arb:175)** — P1 — risk: highest-traffic string in the app (lesson chip `lesson_screen.dart:194`, chapter row `chapter_screen.dart:539`, review queue `review_center_screen.dart:328`, exam-eve sheet `exam_eve_sheet.dart:103`, dashboard `dashboard_screen.dart:721`)
- Current: `"متأخّر {days} يوم"`
- Problem: days=1 → «متأخّر 1 يوم»; days=2 → «متأخّر 2 يوم»; days=3–10 → «متأخّر N يوم» instead of أيام.
- Proposed replacement: `"متأخّر {days, plural, =1{يوم واحد} =2{يومان} few{{days} أيام} other{{days} يوماً}}"`

**F-03 · `dueInDays` (app_ar.arb:159) and `dueInDaysLong` (app_ar.arb:167)** — P1 — risk: same surfaces as F-02
- Current: `"بقي {days} يوم"` / `"بقي {days} يوم على المراجعة"`
- Problem: same broken tamyiz for 1/2/3–10. Additionally `chapter_screen.dart:541` passes `iso(summary.daysUntilDue ?? 0)` — if the null guard ever fires the student reads «بقي 0 يوم على المراجعة», a false statement, not merely ugly Arabic.
- Proposed replacement: `"بقي {days, plural, =0{أقل من يوم} =1{يوم واحد} =2{يومان} few{{days} أيام} other{{days} يوماً}}"` and the long form with the same plural head + « على المراجعة».

**F-04 · `purgeCountsLine` (app_ar.arb:721)** — P1 — risk: permanent-delete dialog, worst possible place for broken grammar
- Current: `"{subjects} مادة · {chapters} باب · {lessons} درس · {exams} امتحان"`
- Call site: `recycle_bin_screen.dart:95` and `:242`, all four args raw ints via `iso()`.
- Problem: «3 مادة · 5 باب · 12 درس · 8 امتحان» — every noun wrong for most values.
- Aggravating: the *same dialog* line above it (`recycle_bin_screen.dart:241`) builds `{chapters}`/`{exams}` through the correct ICU keys `chapterCount`/`examCountLabel`. One dialog, two grammars.
- Proposed replacement: retype the four placeholders `int` and inline the same plural sets already used by `subjectCountLabel` (:497), `chapterCount` (:57), `lessonCount` (:49), `examCountLabel` (:488) — e.g. `{chapters, plural, =1{باب واحد} =2{بابان} few{{chapters} أبواب} many{{chapters} باباً} other{{chapters} باب}}`.

**F-05 · `restoreCopyCounts` (app_ar.arb:738)** — P1 — risk: restore confirmation, data-replacement moment
- Current: `"النسخة السحابية: {chapters} باب، {exams} امتحان"`
- Call site: `backup_screen.dart:88`, raw ints.
- Problem: «النسخة السحابية: 4 باب، 12 امتحان».
- Proposed replacement: same treatment as F-04 (route through `chapterCount`/`examCountLabel`).

**F-06 · `insightLessonNotReviewed` (app_ar.arb:321)** — P1 — risk: analytics insight card
- Current: `"لم تراجع «{lesson}» منذ {days} يوم"`
- Call site: `analytics_screen.dart:208`, raw int.
- Problem: days=1 → «منذ 1 يوم» (should be «منذ يوم واحد»), days=2 → «منذ 2 يوم» (يومين).
- Proposed replacement: `"لم تراجع «{lesson}» {days, plural, =1{منذ يوم واحد} =2{منذ يومين} few{منذ {days} أيام} other{منذ {days} يوماً}}"`

**F-07 · `insightDiscipline` (app_ar.arb:710)** — P1 — risk: analytics discipline card
- Current: `"التزمت {onTime} من {examined} مراجعة في معادها."`
- Call site: `analytics_screen.dart:212`, raw ints.
- Problem: examined=3–10 keeps the singular — «التزمت 8 من 10 مراجعة» must be «مراجعات». (The code comment at `insights_generator.dart:73` quotes «9 من 11» — the one case that happens to work.)
- Proposed replacement: `"{examined, plural, =1{{onTime} من مراجعة واحدة في معادها} =2{{onTime} من مراجعتين في معادها} few{{onTime} من {examined} مراجعات في معادها} other{{onTime} من {examined} مراجعة في معادها}}"`

**F-08 · `examGroupLabel` (app_ar.arb:230)** — P1 — risk: exam-entry step 2/3 rows, seen once per question group
- Current: `"{count} أسئلة × {points} درجة"`
- Call site: `exam_entry_screen.dart:602`, raw ints.
- Problem: count=1 → «1 أسئلة» (broken); points=3–10 → «5 درجة» (should be درجات).
- Proposed replacement: `"{count, plural, =1{سؤال واحد} =2{سؤالان} few{{count} أسئلة} other{{count} سؤالاً}} × {points, plural, =1{درجة واحدة} =2{درجتان} few{{points} درجات} other{{points} درجة}}"`

**F-09 · Missing `zero` category on the existing ICU plurals (app_ar.arb:49, :57, :488, :497)** — P2
- Current (example): `"lessonCount": "{count, plural, =1{درس واحد} =2{درسان} few{{count} دروس} many{{count} درساً} other{{count} درس}}"`
- Problem: count=0 falls to `other` → «0 درس» / «0 امتحان». Arabic CLDR has a zero category; «لا دروس» / «لا امتحانات» is the natural reading.
- Proposed replacement: add `=0{لا دروس}` / `=0{لا أبواب}` / `=0{لا امتحانات}` / `=0{لا مواد}` respectively. Low urgency because zero counts are mostly hidden by empty-states today.

### B. Digits policy (§3.16) — audit item 3

Verified clean elsewhere: **no `DateFormat`/`NumberFormat`/intl anywhere** in `lib/`
(grep across the repo, generated files excluded); all dates go through
`dateLabel()` → `yyyy/mm/dd` Western digits wrapped in U+2066/U+2069 isolates
(`formatting.dart:44-48`); percent/fraction helpers isolate too; numeric fields even
rewrite Arabic-Indic input back to Western (`ather_controls.dart:416-454`). Which makes
the two violations stand out:

**F-10 · `authErrorPasswordShort` (app_ar.arb:386)** — P1 — risk: direct contradiction of owner policy §3.16 (PROJECT.md:322)
- Current: `"كلمة السر ٨ أحرف على الأقل"`
- Problem: Arabic-Indic ٨ renders a digit system the app otherwise refuses everywhere, inside an error next to Western-digit content.
- Proposed replacement: `"كلمة السر 8 أحرف على الأقل."`

**F-11 · `passwordTooShort` (app_ar.arb:432)** — P1 — same policy violation
- Current: `"كلمة السر ٤ أحرف على الأقل."`
- Proposed replacement: `"كلمة السر 4 أحرف على الأقل."`

### C. Grammar & spelling — audit item 1

**F-12 · `examSaveFailed` (app_ar.arb:253)** — P1 — risk: error path shown exactly when the student is anxious
- Current: `"تعذّر حفظ الامتحان. أرقامك لم تَضِع — حاول مرة أخرى."`
- Problem: «لم تَضِع» is not a well-formed passive of ضاع — as written it parses as "your numbers did not put" (فَتَح of وضَعَ). The English ("Your numbers are still here") shows the intent.
- Proposed replacement: `"تعذّر حفظ الامتحان. أرقامك لسه مكانها — حاول مرة أخرى."` (in-voice; MSA alternative: «أرقامك ما زالت محفوظة».)

**F-13 · Tanween order inconsistency file-wide (audit item 6, typography)** — P2
- Dominant form (27×): alef-first «درساً، سؤالاً، واحداً، نهائياً…»
- Outliers (4×): tanween-first — `"accountSwitchWipeMessage": "…تخص حسابًا آخر…"` (:403), `"lockMethodBoth": "الاثنين معًا"` (:426), `"examEveTierWeakest": "الأضعف إتقانًا"` (:754), `"examEveTierNearestDue": "الأقرب سقوطًا"` (:755).
- Problem: two Unicode orderings of the same orthography in one file; some fonts shift the tanween mark between them.
- Proposed replacement: normalize the 4 outliers to the file's dominant «...اً» form (حساباً، معاً، إتقاناً، سقوطاً) — or the reverse everywhere; pick one and enforce.

**F-14 · Trailing-period inconsistency in auth errors (app_ar.arb:390-391 vs :575)** — P2
- Current: `"authErrorTooManyAttempts": "محاولات كثيرة. انتظر قليلاً ثم حاول مرة أخرى"` and `"authErrorGeneric": "تعذّر إتمام العملية. حاول مرة أخرى"` — no final period; `"commonSomethingWentWrong"` (:575) says the identical sentence **with** one; `passwordMismatch/wrongPassword` end with periods, `authErrorPasswordShort` does not.
- Proposed replacement: pick one convention (recommend: no final period on toast/snackbar errors, period on body copy) and align all six auth/password error strings.

### D. Register coherence (Egyptian ↔ MSA) — audit items 1 & 7

The mix itself is documented and fine. What fails the bar is flipping **inside one flow/screen**:

**F-15 · Exam flow: verdicts Egyptian, discard dialog formal MSA** — P2 — risk: same 30-second user journey
- Step-4 result screen: `"examVerdictPassed": "عدّيت، مش متقن — امتحان تاني هو اللي يرفعه."` (:662), `"examNeedToCross": "عشان تعدّي الحد: جيب {percentage} في اللي جاي."` (:663) — deep Egyptian.
- Interrupt the same flow mid-entry and the dialog is fusha: `"examDiscardTitle": "تترك الامتحان؟"`, `"examDiscardBody": "ما كتبته سيضيع. لا يمكن التراجع."`, buttons `"اترك"`/`"أكمل"` (:254-257).
- Proposed pair (keep the MSA dialog if that's the house style for destructive confirmations — but then say so): at minimum `"examDiscardTitle"` → `"هتسيب الامتحان؟"` and `"examDiscardLeave"` → `"سيبه"` to match the flow around it; note also that bare «اترك» is a transitive verb stranded without its object.

**F-16 · Chapter-report gate: heavy MSA beside colloquial siblings** — P2
- `"notReadyBody": "لإتقان الباب يجب أن يكون لكل درس امتحان، وأن يبلغ الإتقان {threshold} على الأقل."` (:149) sits on screens whose every live string is Egyptian («جيب {percentage} في اللي جاي», «خلص الطابور», «ذاكرتها كلها»).
- Proposed replacement: `"عشان الباب يتقفل محتاج إن كل درس يبقى عليه امتحان، والإتقان يوصل {threshold} على الأقل."` (Or ratify MSA as the register for rules/explanations and document it — currently it is undocumented and uneven.)

**F-17 · Tagline disagrees with the thesis quote (voice pair)** — P2 — audit item 7
- Thesis voice (PROJECT.md:56): «إنت مش بتخلص الدروس... إنت بتتقنها»
- Shipped: `"appTagline": "أنت لا تُنهي الدروس، بل تُتقنها"` (:4)
- Same sentence, opposite register. One of them is canonical; right now first-run shows MSA while every design doc quotes Egyptian.
- Proposed resolution: either ship «إنت مش بتخلص الدروس... إنت بتتقنها» as `appTagline` or amend PROJECT.md to bless the fusha rendering. Do not leave both.

**F-18 · Profile verification block mixes registers within one card** — P2
- `"authVerificationSent": "بعتنالك رابط تأكيد على بريدك"` (:634, Egyptian) and `"authVerificationNote": "تأكيد بريدك يخليك تقدر تسترجع حسابك لو نسيت كلمة السر…"` (:638) sit directly under status chip `"authEmailUnverified": "لم يتم تأكيده"` (:635) and button `"authResendVerification": "إعادة إرسال رابط التأكيد"` (:636, both MSA).
- Proposed replacement for the chip: «لسه متأكدش» — or move the whole card to MSA. Either direction; consistency within the card is the requirement.

### E. Mixed-language leakage & bidi — audit item 6

Clean overall: zero ASCII `,` `?` inside Arabic values (grep-verified); `؟` used 7×;
single-glyph ellipsis `…` only in `backupSaving` (:539), no `...` anywhere; `%` never
typed raw into ARB strings — always produced by `percent()`/`percentLabel()` which wrap
it in directional isolates so it lands after the digits in RTL. Accepted Latin/tech
terms: `Google`, `PDF`, `JSON`, `Firebase`, `Firestore` (privacy copy — correct as
product names), `English` in `settingsLanguageEnglish` (:512, self-reference, correct),
`you@example.com` hint (:377, correct).

**F-19 · Parenthesized numbers in RTL bodies** — P2 (hazard, not observed bug)
- `"examErrorSumMismatch": "مجموع الأسئلة ({assigned}) يجب أن يساوي العدد الكلي ({total})"` (:260) and `"lastHomeworkDated": "آخر واجب ({date})"` (:682) put digits inside ASCII parentheses mid-sentence. Bidi mirroring handles the common case, but these pass through `iso()`? No — they arrive as pre-formatted strings; only the *inner* helper output is isolated, and here the parentheses sit outside the isolation run, which can strand a paren on the wrong side with certain leading characters.
- Proposed replacement: move the parens inside the isolated value at the call sites, or drop them: `"مجموع الأسئلة الموزَّعة {assigned} يجب أن يساوي العدد الكلي {total}"`.

### F. Wording quality

**F-20 · `taskMarkedSurrendered`: «مهمة مستسلكة» (app_ar.arb:772)** — P2 — risk: coined word with no anchor
- Problem: the rest of the family is «استسلام»/«تراجع عن الاستسلام» (:774, :777); «مستسلكة» is a different, non-standard root that no student will parse (استسلَك is not productive Arabic). Neither PROJECT.md nor any doc defines it.
- Proposed replacement: `"مهمة استسلمت منها"` (badge/a11y label context) — keeps the surrender root the rest of the feature already teaches.

**F-21 · `examEveTierNearestDue`: «الأقرب سقوطًا» (app_ar.arb:755)** — P2
- Problem: «سقوط» introduces a third due-date metaphor (see terminology table) and reads ominous on the night-before screen.
- Proposed replacement: `"الأقرب معاداً"` (or «معاده الأقرب»).

**F-22 · `examVerdictWeak`: dangling antecedent (app_ar.arb:661)** — P2
- Current: `"درس ضعيف — دخل مراجعة الـ30 يوم، ذاكر تاني قبلها."`
- Problem: «قبلها» has no clear referent (المراجعة؟ الـ30 يوم؟); en says "before then".
- Proposed replacement: `"درس ضعيف — دخل مراجعة الـ30 يوم، ذاكر تاني قبل ما توصل."`

**F-23 · `lessonsExaminedOf`: odd construct (app_ar.arb:87)** — P2
- Current: `"{examined} من {total} درس بامتحان"`
- Problem: «درس بامتحان» is not idiomatic for "lessons that have an exam"; reads as "lesson with-an-exam" calque.
- Proposed replacement: `"{examined} من {total} درس عليها امتحان"` — or make total an int plural key as in F-04.

**F-24 · `subjectTemplateCount` =1 case wrong case-government (app_ar.arb:641)** — P2
- Current: `"{count, plural, =1{باباً واحداً} =2{بابين} few{{count} أبواب} other{{count} باباً}}"`
- Used only as `"subjectTemplateAdded": "تمت إضافة {count}"` (:649) → «تمت إضافة باباً واحداً». After the masdar إضافة the tamyiz should be «باب واحد» (accusative tanween here reads as object-of-a-different-verb).
- Proposed replacement: `"{count, plural, =1{باب واحد} =2{بابين} few{{count} أبواب} many{{count} باباً} other{{count} باب}}"` (also adds the missing `many` slot — currently 11–99 silently borrows `other`, which happens to be identical, but should exist explicitly).

**F-25 · Gender-address sweep: PASS** — audit item 1
- All second-person verbs masculine singular throughout (أتقنت، أنجزت، شاهدت، حللت، راجعت، عدّيت، التزمت، رجعت، جيب، استنى). Feminine forms appear only as third-person agreement with feminine nouns («لم تبدأ بعد» ← المادة, «تحسّنت» ← المادة, «ثابتة/ضعيفة» ← الدرجات) — all correct. Non-human plural agreement done right where it matters: `"reviewEmptyBody": "كل دروسك في موعدها."` (:276). No action.

---

## Hardcoded-Arabic inventory — audit item 4

Grep: `[\x{0600}-\x{06FF}]` over all of `lib/**/*.dart`, generated files excluded,
then filtered to quoted literals (comments stripped). Result — **no user-facing Arabic
string bypasses the ARB**:

| Location | Content | Verdict |
|---|---|---|
| `lib/domain/services/curriculum_templates.dart:53-80` | 28 curriculum chapter names («الدعامة والحركة في الكائنات الحية», «التيار الكهربي وقانون أوم», …) | Legitimate **data**, not UI copy — seed rows inserted into the student's own database, deliberately un-l10n'd per the file's own rationale (lines 17-18: the book is in Arabic). Keep. |
| `lib/presentation/settings/settings_screen.dart:491`, `lib/presentation/settings/profile_screen.dart:209`, `lib/presentation/common/subject_presentation.dart:44` | `'؟'` avatar fallback initial | UI glyph, single char, locale-neutral for Arabic-first app. Keep. |
| `lib/core/widgets/ather_controls.dart:427-428` | `'٠'`/`'۰'` as code-point comments in the digit-normalizing TextInputFormatter | Not copy — it is the code that *enforces* §3.16. Keep. |
| Comments in `summaries.dart`, `review_cycle_service.dart`, `drift_study_repository.dart`, `insights_generator.dart`, `exam_eve_service.dart`, `tables.dart`, `dashboard_screen.dart:156` | Arabic inside doc comments quoting UI strings | Non-user-facing. Keep. |

Notification/export surfaces (the usual bypass suspects) all verified going through l10n:
reminder title/bodies at `notification_providers.dart:149-162` (`reviewNotificationTitle`,
`reviewNotificationBody`, `reviewNotificationEarlyBody`, `reviewBodyDeclining`,
`reviewBodyWeak`); share-card labels at `mastery_card.dart:240-243`; PDF report is
rasterized Flutter widgets precisely because the `pdf` package cannot shape Arabic
(`pdf_export_service.dart:36-43`) — so its text inherits the ARB by construction. PDF
filename embeds the student's own chapter name (`buildFilename`) — user content, allowed.

## Numerals/dates verdict — audit item 3

PASS with F-10/F-11 exceptions. Single formatting choke-point (`formatting.dart`),
no intl date machinery to mis-localize, dates as `yyyy/mm/dd` Western digits in
directional isolates, day-picker day-of-month isolated (`day_picker.dart:144-146`),
input formatter scrubs Arabic-Indic keystrokes.

---

## Truncation-risk list — audit item 5

| # | Surface | Constraint (file:line) | At-risk strings | Assessment |
|---|---|---|---|---|
| T-1 | Dashboard three-up stat cards | `_Stat` label: `maxLines: 1, overflow: TextOverflow.ellipsis` (`dashboard_screen.dart:476-479`); column ≈101dp on a 360dp phone (three `Expanded` + gaps, :399-443); font 14px semiBold (`app_typography.dart:199-200`) | «دروس متراكمة» (`statLessonsRemaining` :29), «يحتاج مراجعة» (`statNeedsReview` :33) — 12 chars each ≈85-100px before padding | **Likely ellipsis at default scale on ≤360dp devices, certain at 1.2×+**. These are permanent labels, red-painted by owner decision. Fix: allow `maxLines: 2` (card is 72dp tall, comment says the row stacks three sizes in it) or shorten to «متراكمة»/«مراجعة»/«متفوق». |
| T-2 | Day-picker pills | Cells measured with TextPainter and floored at kMinTarget; row shows only what fits, 3–7 cells (`day_picker.dart:311-366`, :521-531); label `Text(label, maxLines: 1, softWrap: false)` :554 | Longest: «ثلاثاء 28», «أربعاء 28» | **Safe by construction** — cells size to content, count adapts. Documenting as PASS against the ~41px worry inherited from the old strip (ARB description :15). |
| T-3 | Exam-eve row status | Unexpanded `statusText` left of chevron, lesson name is the `Expanded` + ellipsis (`exam_eve_sheet.dart:160-190`) | «متأخّر 30 يوم» (~13 chars @13px controlLabel) | Status never truncates; wide values squeeze the *lesson name* instead. Acceptable, monitor. |
| T-4 | Review-queue reason line | Full-width `Expanded`, maxLines:1 ellipsis (`review_center_screen.dart:343-358`) | «متأخّر N يوم», «مستواك ينخفض» | Safe (whole column width). |
| T-5 | Share-card lessons-above footer | Card fixed 360dp wide, inner ≈312dp after padding; footer `Text` centered, **no maxLines** (`mastery_card.dart:79-134`); textScaler forced 1.0 (:235) | `shareCardLessonsAbove` many-case «12 درساً أثبتَها فوق حد الإتقان» ≈30 chars | Wraps to two lines, card grows (`mainAxisSize.min`). Safe. |
| T-6 | MiniBadge chips | `badgeLabel` 11px bold (`app_typography.dart:218-219`); used trailing in lesson/chapter rows with upstream Expanded+ellipsis | «مراجعة» (:212), «أضعف درس» (:369) | Short enough; upstream rows absorb pressure. Safe. |
| T-7 | Bottom nav | `tabLabel` 11px, 4 tabs (`app_shell.dart:75-100`) | «الرئيسية» | Fits. Safe. |

---

## What is already right (do not regress)

- `formatting.dart` — one choke-point, LRI/PDI isolates on every number, Western-only digits, documented bidi reasoning.
- ICU plurals, when used, are textbook-correct Arabic: `lessonCount`/:49 and `chapterCount`/:57 carry all six categories with proper dual/tamyiz; `binPurgeConfirm` composes them.
- Arabic punctuation discipline: ، ؟ … only; no ASCII leakage (grep-clean).
- Notifications, PDF, share-card, backup, bin — every destructive or out-of-app surface routes copy through the ARB.
- Curriculum templates kept as domain data with a written rationale, plus fuzzy-matching normalization for ة/ه, أ/ا, ى/ي typos (`drift_study_repository.dart:223-251`).
