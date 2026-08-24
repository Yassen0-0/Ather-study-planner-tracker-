# English Copy Audit

Phase 1, read-only. Scope: `lib/core/l10n/app_ar.arb` (source of truth) vs `app_en.arb`,
plus dart-side hardcoded strings and locale resolution. All mechanical lists below are
actual python3 output (scripts preserved at `/tmp/opencode/arb_diff.py`,
`/tmp/opencode/terms.py`, `/tmp/opencode/hardcoded.py` during the audit session).

## Key-parity diff (exact lists from mechanical comparison)

### Key sets
```
ar count (non-@): 348
en count (non-@): 348

=== MISSING IN EN (present only in app_ar.arb) ===
(none)

=== EXTRA IN EN / MISSING IN AR (present only in app_en.arb) ===
(none)
```

**Verdict: perfect 1:1 key parity.**

### Placeholder mismatches (message text)
A naive brace-scan flags 5 keys; inspection shows all five are **false positives**: the
regex caught Arabic dual-form words that sit inside ICU sub-message braces (`=2{درسان}`),
not real arguments. The real argument inventory (`{count}` etc.) is identical in both files.

```
chapterCount: ar=['count', 'بابان'] en=['count']      <- 'بابان' is =2{} body text, not an arg
examCountLabel: ar=['count', 'امتحانان'] en=['count'] <- same
lessonCount: ar=['count', 'درسان'] en=['count']       <- same
subjectCountLabel: ar=['count', 'مادتان'] en=['count']<- same
subjectTemplateCount: ar=['count', 'بابين'] en=['count'] <- same
```

### Placeholder metadata blocks (@key placeholders)
22 keys carry a `placeholders` declaration in app_ar.arb with **no @key at all in
app_en.arb**. Harmless today because `l10n.yaml` names `app_ar.arb` as the template,
but it means app_en.arb alone is not codegen-valid:

```
analyticsVelocity, chaptersMasteredOf, chaptersOfShort, dueInDays, dueInDaysLong,
examErrorSumMismatch, examGroupLabel, examPointsLine, insightChapterWeak,
insightLessonNotReviewed, insightStrongestSubject, insightSubjectImproved,
lessonsExaminedOf, lessonsOnTimeOf, masteryCaptionWithExams, notReadyBody,
overdueByDays, reviewNotificationBody, reviewNotificationEarlyBody,
subjectTemplateAdded, trendDown, trendUp
```

### Metadata divergence (@key descriptions)
Descriptions present in ar but missing entirely from en (4):
```
firstRunBody, tasksTitle, todayLabel, weekdaySaturday
```
Description text differs between files (en paraphrased the Arabic quotes out — acceptable,
listed for completeness) (2):
```
shareCardLessonsAbove, statMastered
```

### ICU plural structure
Same 6 plural keys both sides. English legitimately drops `=2/few/many` (not English
categories). No key uses prose plurals where ICU plurals are needed on the en side —
except the four String-typed day/count strings flagged as F-01 below.

## Terminology table (ar | en | consistent? | violating keys)

Mechanical cross-tab: for every key containing an Arabic stem, the English value was
checked for its locked term family and for foreign alternatives.

| ar stem | locked en term | consistent? | violating keys |
|---|---|---|---|
| باب | chapter | YES (no unit/section/module anywhere) | — |
| درس | lesson | YES | — |
| مادة | subject | YES (no "course") | — |
| امتحان | exam | YES (no test/quiz) | — |
| مراجعة | review | YES (no revision/revisit) | — |
| إتقان | mastery/master | YES | — |
| مهمة | task | MOSTLY | deleteTaskConfirm (en says only "It", drops the noun; see F-07) |
| واجب | homework | YES (no assignment) | — |

Reverse direction (en term present where ar lacks the stem): all hits are grammatical
morphology noise (e.g. أتقنت الباب → "Chapter mastered"), not terminology drift.
**باب=chapter everywhere; باب is never "unit" in UI copy.** The only "Unit" strings in the
codebase are seeded curriculum *content* for the English subject
(`curriculum_templates.dart:87-97`), which is correct domain vocabulary, not chrome.

## Findings

Severity: P0 = broken/misleading shipped copy · P1 = wrong grammar or meaning drift ·
P2 = polish/consistency.

---

### F-01 · P1 — English plural broken when count == 1 (String-typed day/count strings)
- arb key/file:line: `dueInDays` app_en.arb:103 · `dueInDaysLong`:104 · `overdueByDays`:105 · `comebackLine`:460
- current text: `"{days} days left"` · `"{days} days until review"` · `"{days} days overdue"` · `"Back after {days} days -- {count} lessons came due meanwhile."`
- problem: placeholders are typed `String`; callers pass raw integers with no singular
  special-case (`lesson_screen.dart:194-196`, `chapter_screen.dart:539-541`,
  `dashboard_screen.dart:721`, `exam_eve_sheet.dart:103-104`, `dashboard_screen.dart:167`).
  A student one day from review sees **"1 days left"**, **"1 days overdue"**, and after one
  day away **"1 lessons came due meanwhile."** Arabic happens to stay grammatical
  («بقي 1 يوم»), so this is an en-only defect. These four are exactly the strings that need
  `{days, plural, =1{1 day} other{{days} days}}` ICU forms.
- proposed rewrite: convert to ICU plurals:
  `dueInDays`: `{days, plural, =1{1 day left} other{{days} days left}}`;
  `dueInDaysLong`: `{days, plural, =1{1 day until review} other{{days} days until review}}`;
  `overdueByDays`: `{days, plural, =1{1 day overdue} other{{days} days overdue}}`;
  `comebackLine`: `Back after {days, plural, =1{1 day} other{{days} days}} -- {count, plural, =1{1 lesson came} other{{count} lessons came}} due meanwhile.`
- risk: low (codegen re-run; callers unchanged since placeholder name stays).

### F-02 · P1 — can't vs cannot split across the identical destructive-confirm sentence
- arb key/file:line: `examDeleteConfirm` app_en.arb:127, `examDiscardBody`:150 vs
  `deleteChapterConfirm`:74, `deleteLessonConfirm`:75, `authDeleteAccountConfirm`:212,
  `binPurgeConfirm`:289, `binEmptyAllConfirm`:303, `accountSwitchWipeMessage`:219
- current text: "This can't be undone." vs "It cannot be undone." / "This cannot be undone."
- problem: the same closing sentence, seven times, uses two contraction registers. The
  informal one sits on exam deletion; the formal one on everything else.
- proposed rewrite: pick **cannot** everywhere (matches the privacy page's plain-formal
  register) — change the two `can't` instances to "This cannot be undone."
- risk: none.

### F-03 · P1 — privacy copy drift: en adds a claim ar does not make
- arb key/file:line: `privacyNoCollectBody` app_en.arb:233 (ar:417); same pattern in
  `reviewEmptyBody` app_en.arb:162 (ar:276)
- current text: en ends "…No third-party analytics or crash reporting. **The app works offline most of the time anyway.**" / "Every lesson is on time. **Keep going.**"
- problem: sentences added in en that do not exist in the source of truth. On the privacy
  screen specifically, extra unreviewed claims are legal surface area, and "most of the time"
  hedges a guarantee the ar copy states cleanly elsewhere. `reviewEmptyBody`'s addition is
  benign but breaks the parity discipline this file otherwise keeps.
- proposed rewrite: `privacyNoCollectBody`: "No ads. No tracking. No selling data. No third-party analytics or crash reporting."
  `reviewEmptyBody`: keep "Keep going." only if the owner wants it in ar too — otherwise drop.
- risk: none.

### F-04 · P2 — ASCII double-hyphen "--" where the rest of the file uses an em dash
- arb key/file:line: app_en.arb — `trendSteady`:183, `examVerdictWeak`:450,
  `examVerdictPassed`:451, `comebackLine`:460, `checklistAllDone`:479, `tasksDayDone`:480,
  `examEveTierUnsettled`:542, `reviewBodyDeclining`:545, `reviewBodyWeak`:553
- current text: e.g. "Steady -- both halves sit at the same level"; "Weak lesson -- it entered the 30-day review."
- problem: 9 later-batch keys render literal `--`; the 19 older dash-using keys use "—".
  Two dash glyphs for the same job reads as machine-appended batches.
- proposed rewrite: replace `--` with `—` in all nine.
- risk: none.

### F-05 · P2 — separator glyph drift: periods instead of middots in the purge count line
- arb key/file:line: `purgeCountsLine` app_en.arb:510 (ar:721)
- current text: `"{subjects} subjects . {chapters} chapters . {lessons} lessons . {exams} exams"`
- problem: ar uses `·`; en uses spaced full stops, which render as stray sentence dots:
  "4 subjects . 12 chapters . 30 lessons . 18 exams".
- proposed rewrite: `"{subjects} subjects · {chapters} chapters · {lessons} lessons · {exams} exams"`
- risk: none.

### F-06 · P2 — "I mastered this chapter" as a button label
- arb key/file:line: `masterChapter` app_en.arb:96 (used as a primary button,
  `chapter_screen.dart:507`)
- current text: "I mastered this chapter"
- problem: first person inside a button reads like a status sentence; every sibling action
  is imperative ("Log exam", "Save result"). The ar «أتقنت الباب» carries celebration tone
  that "I…" flattens into awkwardness.
- proposed rewrite: "Master the chapter"
- risk: low (label length shrinks; no layout dependence known).

### F-07 · P2 — task noun dropped and idiom swapped in delete-task confirm
- arb key/file:line: `deleteTaskConfirm` app_en.arb:383 (ar:570)
- current text: "It will be removed from this day for good."
- problem: only confirm in the app whose English omits the object's noun (task), and "for
  good" is the lone idiomatic register in a family that elsewhere says "permanently"/"cannot be undone".
- proposed rewrite: "The task will be deleted from this day permanently."
- risk: none.

### F-08 · P2 — Remove vs Delete split inside the exam family
- arb key/file:line: `examDelete` app_en.arb:126, `toastExamDeleted`:128, `examRemoveGroup`:142
- current text: "Remove exam" / "Exam removed — mastery recalculated" / "Remove group"
- problem: ar uses حذف (delete) uniformly; en softens exams to "Remove" while chapters,
  lessons, subjects, tasks use "Delete". If the soften-to-remove distinction is deliberate
  (exam leaves the record, nothing is destroyed), it is undocumented and contradicted by
  `examDeleteConfirm`'s deletion framing.
- proposed rewrite: either "Delete exam"/"Exam deleted" to match ar lockstep, or keep Remove
  and record the intent in an @description. Recommend the former.
- risk: low.

### F-09 · P2 — stiff/translated residue (register pass)
- arb key/file:line + current text + problem + rewrite:
  - `homeworkInvalid` app_en.arb:122 — "The score must be between zero and the total, and the total above zero" — rule stated as legalese; ar:209 is blunt. Rewrite: "Score must be between 0 and the total, and the total above 0".
  - `exportErrorShare` app_en.arb:406 — "The share sheet would not open" — past-conditional stiffness; Rewrite: "Couldn't open the share sheet".
  - `examVerdictPassed` app_en.arb:451 — "You passed, not mastered -- another exam is what raises it." — dangling "not mastered", unidiomatic cleft. Rewrite: "You passed — not mastered yet. Another exam is what raises it."
  - `examNeedToCross` app_en.arb:452 — "To cross the line: score {percentage} on the next one." — "cross the line" idiom means something else in English. Rewrite: "To clear the bar: score {percentage} on the next one." (or "...to reach the threshold:")
  - `examEveTierNearestDue` app_en.arb:544 — "Closest to falling due" — jargon pile-up for a tier chip. Rewrite: "Due soonest".
- risk: none; pure string swaps.

### F-10 · P2 — Android notification channel name hardcoded English
- file:line: `lib/data/notifications/review_notification_service.dart:69`
- current text: `static const String _channelName = 'Review reminders';`
- problem: shown verbatim in the OS notification settings for Arabic-first students; the
  only user-visible English bypassing ARB outside seeded content.
- proposed fix: localize at initialise time via `L.of(context)` (channel name is set once;
  if changing post-publish requires a new channel id, note the migration).
- risk: medium — channel rename semantics on Android; needs the new-channel-id caveat checked.

### F-11 · P2 — locale==en still surfaces Arabic via seeded curriculum content
- file:line: `lib/domain/services/curriculum_templates.dart:31-97`
- current behavior: under an English locale, tapping "Add the standard chapters" on
  biology/physics/chemistry seeds Arabic-only chapter names (e.g. «الوراثة») into an
  otherwise English UI. (The English-subject template correctly seeds "Unit 1..8, The Novel".)
- problem: data-level ar-under-en path. Deliberate for the Egyptian curriculum (the real
  textbook names are Arabic), so this is a documented-exception candidate, not a bug — but
  it is currently documented nowhere user-facing; an en student gets untranslatable rows.
- proposed mitigation: leave content as-is; add a one-line note in `subjectTemplateNote`
  (both locales) that template names come from the national curriculum and can be renamed.
- risk: none if documentation-only.

### F-12 · P2 — metadata hygiene: 26 @keys absent from app_en.arb
- covered mechanically above (22 placeholder blocks + 4 descriptions). No build impact
  while `template-arb-file: app_ar.arb` (l10n.yaml). Risk materializes only if someone
  flips the template or ships en.arb standalone.
- proposed fix: mirror the @blocks into app_en.arb (copy descriptions verbatim or translate).

### Explicitly clean (audited, no finding)
- **Bidi/RTL marks in en values:** zero control characters (U+200E/F, U+2066-2069, U+202A-C) found in any app_en.arb value. Numbers arriving via `iso()` carry LRI…PDI wrappers, which are harmless inside LTR paragraphs (formatting.dart:15-27 does this by design).
- **Arabic script in en values:** only `settingsLanguageArabic` = "العربية" — the correct endonym, keep.
- **Cultural artifacts:** no "May Allah…", religious formulas, or Egyptian-dialect leakage in en (dialect strings like لسه/عشان/دي are rendered into standard English throughout).
- **Capitalization:** consistent sentence case across buttons, titles, toasts in en; no Title Case mixing found.
- **Terminology:** باب=chapter, درس=lesson, مادة=subject, امتحان=exam, إتقان=mastery hold in 100% of shared keys (mechanical section B empty).
- **Locale resolution:** `kSupportedLocales = [ar, en]` (app.dart:19), explicit `locale:` wiring, standard global delegates; `localeProvider` maps anything ≠ en to ar (app_providers.dart:222). Font Readex Pro serves both scripts. Notifications take their strings from `L.of(context)` at schedule time (notification_providers.dart:124,149-156). No fallback path renders ar UI chrome under en except F-11's seeded data.
- **Hardcoded sweep false-positive classes excluded from inventory below:** imports, route patterns, Firebase error codes (already mapped to ARB keys in firebase_auth_repository.dart:274-286), SQL fragments in generated drift code, debug/log messages, semantic keys ('day-picker-drag-transform'), filenames.

## Hardcoded-English inventory

User-visible or near-user-visible:

| # | Location | Literal | Verdict |
|---|---|---|---|
| 1 | lib/data/notifications/review_notification_service.dart:69 | `'Review reminders'` (Android channel name) | **F-10 — should be localized** |
| 2 | lib/domain/services/curriculum_templates.dart:87-97 | `'Unit 1'…'Unit 8'`, `'The Novel'` | intentional seeded content (English-subject curriculum); see F-11 |
| 3 | lib/app/app.dart:82 | `title: 'Ather'` | brand name, valid in both locales |
| 4 | lib/data/notifications/review_notification_service.dart:97 | `appName: 'Ather'` (Windows init) | brand name |

Developer-facing only (logged/asserted, never drawn): `firebase_options.dart:21-50`
(setup error strings), `backup_gate.dart:144` (log), `widget_raster.dart:143` (exception),
`collapsing_removal.dart:107` (assert), `app_providers.dart:198` (assert),
`study_backup.dart:248` (exception), PdfExportException names
(pdf_export_service.dart:19), Firebase error-code strings mapped through ARB
(firebase_auth_repository.dart:274-286), Firestore codes
(firestore_backup_repository.dart:237-239), `'Africa/Cairo'` timezone id
(review_notification_service.dart:457).

Total raw quoted-literal candidates scanned: 202; after excluding imports/codes/SQL/dev
strings: 4 items above.
