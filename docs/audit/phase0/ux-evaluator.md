# UX Evaluation

Evaluator: UX-EVALUATOR (phase 0, read-only). Method: walked every `*_screen.dart` under
`lib/presentation/`, its widgets/providers, `lib/app/router.dart`, `lib/app/app.dart`,
`lib/core/widgets/`, and PROJECT.md §1, §3.19–3.31, §6–7. All strings quoted are real ARB
values from `lib/core/l10n/app_ar.arb`. Anything not read directly in code is marked UNVERIFIED.
Line numbers refer to files as of this checkout.

---

## Flow map

| # | Flow | Entry → steps → dead ends found |
|---|------|-------------------------------|
| 1 | First launch | Sign-in gate (`router.dart:164-170`) → dashboard. Zero-chapter student sees `_FirstRunCard` («ابدأ من هنا» / «الإتقان يُحسب من امتحاناتك وحدها، لا من إنهاء الدرس.» + «افتح أول مادة») replacing the two summary cards (`dashboard_screen.dart:182-183`). Four seeded subjects render below with «لم تبدأ بعد» subtitles. Card auto-dismisses on first chapter — no dismiss button by design. **Dead end:** the card names no path; the student must discover subject → «+ إضافة باب» → chapter → «+ إضافة درس» → lesson CTA chain themselves (see F1). |
| 2 | Building curriculum | Dashboard «افتح أول مادة» or subject row → subject screen (empty state «لا توجد أبواب بعد» + dashed «+ إضافة باب», `subject_screen.dart:90-97`) → name sheet → chapter card → chapter screen (empty «لا توجد دروس بعد» + «+ إضافة درس», `chapter_screen.dart:348-355`) → name sheet → lesson row → lesson screen. ~7 taps + 2 typed names to first examable lesson. Rename/delete live behind header pencils (`prompts.dart:150-187`). Works, but each creation is one-name-per-sheet; bulk setup (a real syllabus has ~12 chapters × ~5 lessons) has no fast path (F2). |
| 3 | Recording an exam | Three entries: dashboard up-next pill «امتحن» (`dashboard_screen.dart:735-739`), review-centre row tap (`review_center_screen.dart:334`), lesson sticky CTA (`lesson_screen.dart:159-169`; labels «ابدأ الامتحان» / «سجّل نتيجة امتحان» / «سجّل امتحان المراجعة»). Full-screen modal route, 4 steps (عدد الأسئلة الكلي → درجات الأسئلة → إجاباتك الصحيحة → النتيجة), segment bar M-14, live tally turning green, validation banners («مجموع الأسئلة (X) يجب أن يساوي العدد الكلي (Y)» etc.), draft survives process death (`exam_entry_screen.dart:119-209`), discard confirm, save → toast «حُفظ الامتحان — بدأ عدّاد المراجعة من جديد» + haptic, lands on lesson. Step 4 shows count-up %, before→after cards, verdict lines («درس ضعيف…» / «عشان تعدّي الحد: جيب X% في اللي جاي.»). Solid. Traps: T1 (blank correct = 0), T2 (digit filter). |
| 4 | Review loop | Tab badge = queue length (`app_shell.dart:52-54`) → review centre: header «دروس المراجعة المستنياك: N», 14-day collapse radar, subject chips, rows sorted overdue→weak→declining. Row tap opens wizard directly (no lesson detour — deliberate, `review_center_screen.dart:26-35`). Empty queue = `EmptyState.success` «لا شيء يحتاج مراجعة» / «كل دروسك في موعدها.» with no button. Notifications deep-link to the exact lesson (`notification_providers.dart:183-191`). Trap: M1 (false success flash during load), F3 (red badge on non-emergency reasons). |
| 5 | Tasks | Tab → day picker pills (measured count, «اليوم» landmark, green edge marker, §3.29 implemented in `day_picker.dart`) → count line «أنجزت X من Y» / «… — يومك خلص.» → reorderable rows (tap=done w/ strike ink, slashed-circle=surrender w/ zigzag + confirm, pencil=edit/delete). Add via dashed «+ إضافة مهمة». Empty day: «لا مهام لهذا اليوم»; just-cleared day: celebration «خلص الطابور» / «ما بقي شيء مخطط لهذا اليوم.» Traps: F4 (stale selected day), tasks land on the *selected* day silently. |
| 6 | Analytics | Insights card (structured variants, translated live), subject filter chips, always-unfiltered subject bars (SP-05 growth), trajectory lines (fixed 0..100 axis), chapter bars, weakest-5 lessons, discipline card. Empty: single line «لا توجد بيانات كافية بعد» — but only when there are zero chapters AND zero lessons (`analytics_screen.dart:148-156`); see M4. Weakest lessons are the only tappable rows. |
| 7 | Settings | Cog in every root header → grouped list: account header + backup row (last-saved date), preferences group (subjects, recycle bin when non-empty, export, language sheet «العربية/English», theme, notifications toggle, haptics, lock + methods + password), notifications-blocked warning banner, about/privacy, then sign-out & delete-account rows. Delete account: offline-warning variant, re-auth sheet, ordered teardown (`settings_screen.dart:679-759`). Delete-exam correction path (§3.31) implemented on the lesson's history card (`lesson_screen.dart:582-689`). Locale switch applies instantly via `localeProvider`. Divergence D1 (doc vs code on subjects) noted below. |
| 8 | Errors/loading | Only two spinners exist, both inside busy buttons (`buttons.dart:97`, `settings_list.dart:177`). All writes funnel through `runWrite` → failure toast «تعذّر إتمام العملية. حاول مرة أخرى.» (`write_guard.dart:40-73`). Reads have **no** error surface: `snapshotValueProvider` collapses stream errors to `StudySnapshot.empty()` (`app_providers.dart:154-156`) — see M1–M3. |
| 9 | Desktop | `Breakpoints` (<600 compact, ≥600 roomy) consumed in exactly one place: `AtherScreen` caps content at 520 and centres (`ather_scaffold.dart:124,179-184`). Matches §6's "same layout with room around it". Wizard self-caps at 520 (`exam_entry_screen.dart:443`), login at 480 (`login_screen.dart:147`). Glass bar falls back to opaque card on non-mobile (`app_shell.dart:174-187`), per §3.19 platform gate. DayPicker measures its width (`day_picker.dart:31-36`). Sheet max-width behaviour on wide windows UNVERIFIED. |

---

## Friction findings

### F1 — First-run card states the philosophy but never the path
- **Flow:** first launch.
- **Evidence:** `dashboard_screen.dart:286-315` (`_FirstRunCard`); strings `app_ar.arb:39-44` — «ابدأ من هنا», «الإتقان يُحسب من امتحاناتك وحدها، لا من إنهاء الدرس.», button «افتح أول مادة».
- **What the user experiences today:** the card teaches *why* mastery counts exams, then drops the student on أحياء with «لا توجد أبواب بعد» and a dashed add button. Nothing says the ladder is subject → chapter → lesson → exam, nor that the exam is the point. The dashboard's own comment admits this was "the longest path in the app … with no signposting" (`dashboard_screen.dart:172-175`) and then ships one button of it.
- **Severity:** P2 (the empty states downstream do carry add-buttons, so nobody is stuck — they just don't know the destination).
- **Fix:** extend `firstRunBody` with the three steps («افتح المادة ← أضف باباً ← أضف دروسك ← سجّل أول امتحان»), or put a micro-caption on the subject/chapter empty states pointing at the next rung.
- **Risk:** copy-only; none.

### F2 — Curriculum building is strictly one-name-per-sheet
- **Flow:** building curriculum.
- **Evidence:** `subject_screen.dart:36-54` and `chapter_screen.dart:63-81` both go through `showNamePrompt` (`prompts.dart:18-29`) for a single text line; `curriculum_templates.dart:1-10` holds "the standard chapter structure of the four seeded subjects, as data" yet no screen offers to apply it (grep: referenced only from settings/subjects import tree — no template-apply UI found).
- **What the user experiences today:** a Thanaweya syllabus is ~12 chapters × ~4–6 lessons per subject; entering it means dozens of sheet-open/type/save cycles. A pre-built template exists in the domain layer with no door to it.
- **Severity:** P2 (heavy one-time cost at exactly the moment a new student decides whether the app is worth it).
- **Fix:** an optional "استخدم قالب الباب القياسي" row on the seeded subjects' empty state that batch-creates the template chapters; keep manual as default.
- **Risk:** low; purely additive, must respect CollapsingList entrance budget (cap 6 stagger already handles lists).

### F3 — Review tab badge paints "weak"/"declining" in the alarm colour
- **Flow:** review loop.
- **Evidence:** badge source is `reviewQueueProvider.select(length)` (`app_shell.dart:52-54`); the queue includes `ReviewReason.lowMastery` and `ReviewReason.declining` (`review_center_screen.dart:327-331`); badge colour is `context.colors.wrong` (`app_shell.dart:511`).
- **What the user experiences today:** a permanently red "3" on the tab for lessons that are merely weak or gently declining — the same red as overdue decay. §3.27 reserves red for "the red pen"; here a habit problem wears an emergency. Inside the screen the declining reason is correctly greyed (`review_center_screen.dart:360-366`), so tab and contents disagree.
- **Severity:** P2.
- **Fix:** badge counts only `overdue` items (what the notification contract treats as owed), or badge goes neutral/accent with red reserved for overdue-only queues.
- **Risk:** changes a number students may have internalised; pair with a release-note line.

### F4 — Tasks: the selected day is sticky across sessions and the add button doesn't say where it writes
- **Flow:** tasks.
- **Evidence:** `SelectedTaskDayNotifier.build()` seeds once via `ref.read(clockProvider)` (`task_providers.dart:32-42`); the provider is not autoDispose and is not reset on day-change/resume; `_add` writes to `selectedTaskDayProvider` (`tasks_screen.dart:44-45,57-59`); the only day signal near the list is the header title flipping to `dateLabel(selected)` (`tasks_screen.dart:176-189`).
- **What the user experiences today:** a student who browsed Saturday, closes the app, reopens Wednesday and taps «+ إضافة مهمة» creates a task dated Saturday. The header says so in small text, but the add control — the thing they touched — carries no day. Unfinished tasks deliberately don't roll over (§3.22), so the task is effectively invisible the moment they leave the screen.
- **Severity:** P1 (silent loss of the thing they just entered; the exact "tap did something other than what I meant" class the app works hard to avoid elsewhere).
- **Fix:** (a) re-seed selection to today on `nowProvider` day-change when the selected day is in the past, and/or (b) label the add button with the target day when it isn't today («+ إضافة مهمة (السبت)»).
- **Risk:** re-seeding fights a student intentionally planning tomorrow — gate the reset on *past* days only.

### F5 — Numeric fields silently swallow Arabic-Indic digits
- **Flow:** exam wizard, homework, everywhere numbers are typed.
- **Evidence:** `NumberField` formatters `FilteringTextInputFormatter.allow(RegExp(r'[0-9]'))` (`ather_controls.dart:386-398`).
- **What the user experiences today:** an Arabic keyboard offering ١٢٣ rejects each keystroke with no feedback — the field looks broken. Display-side Western digits (§3.16) are a display rule; applying it as a silent *input* filter punishes the RTL-primary audience.
- **Severity:** P2 (frequency depends on keyboard; impact is a dead-looking field).
- **Fix:** accept `[٠-٩۰-۹0-9]` and normalise on change, or show the error banner when input is filtered.
- **Risk:** trivial normalisation; keep stored values Western.

### F6 — Review-centre row offers no way to the lesson
- **Flow:** review loop.
- **Evidence:** whole-card onTap → wizard only (`review_center_screen.dart:333-334`); the rationale is documented (`review_center_screen.dart:26-35`).
- **What the user experiences today:** to peek at the checklist/history before re-sitting, the student must cancel the wizard (confirm-discard dialog), back out, and find the lesson via dashboard → subject → chapter. The crumb text identifies it but doesn't navigate.
- **Severity:** P2 (deliberate trade-off, but the escape hatch costs 4+ taps and a discard warning).
- **Fix:** long-press or a secondary quiet affordance on the row → lesson screen; keep tap = exam.
- **Risk:** contradicts the screen's own "one action, one target" rule — needs an owner decision recorded like §3.28.

### F7 — PROJECT.md §1 contradicts shipped subject management
- **Flow:** settings/curriculum.
- **Evidence:** PROJECT.md §1: "Exactly four subjects, fixed and seeded, with no subject-management UI." Code: `_AddSubjectButton` on the dashboard (`dashboard_screen.dart:525-573`), full archive/delete/recycle-bin screen (`subjects_screen.dart:36-60`), custom-subject entities (`lib/domain/entities/subject.dart:45-109`).
- **What the user experiences today:** a richer model than the docs claim (fine for users, hazardous for future contributors — CLAUDE.md Rule 2 exists precisely because of such drift).
- **Severity:** P2 (documentation defect with product-decision blast radius).
- **Fix:** update §1 to describe seeded-four-plus-custom, archive vs delete vs bin.
- **Risk:** none.

---

## Missing states (empty/error/loading)

### M1 — Loading renders as a false "success" on the review tab
- **Evidence:** `snapshotValueProvider` falls back to `StudySnapshot.empty()` while the drift stream's first frame is in flight (`app_providers.dart:154-156`); `review_center_screen.dart:80-84` branches on `queue.isEmpty` straight to `EmptyState.success(title: l.reviewEmptyTitle, body: l.reviewEmptyBody)` — «لا شيء يحتاج مراجعة» / «كل دروسك في موعدها.»
- **What the user experiences today:** on a cold start a student with five overdue lessons sees the green tick and "nothing needs review" for one or more frames before the real queue snaps in. The screen asserts the opposite of the truth using its most celebratory shape.
- **Severity:** P1.
- **Fix:** watch `snapshotProvider` and render `AsyncValue.isLoading` as a quiet placeholder (or nothing) before branching on emptiness.
- **Risk:** minimal; local SQLite is fast but cold-start + big DB is real on the low-end phones this app targets.

### M2 — Same fallback flashes the first-run card at existing students
- **Evidence:** `dashboardProvider` derives from the same fallback (`summary_providers.dart:62-67`); `dashboard.isEmpty` ⇒ `totalChapters == 0` (`summaries.dart:202`) ⇒ `_FirstRunCard` (`dashboard_screen.dart:182-183`). The comeback logic carefully waits for the snapshot (`dashboard_screen.dart:72-81`) but the card branch does not.
- **What the user experiences today:** a returning student with a year of data glimpses «ابدأ من هنا» and four untouched subjects before their real numbers arrive.
- **Severity:** P2.
- **Fix:** hold the empty-vs-data decision until `snapshotProvider` has emitted once (same pattern the comeback resolver already uses).
- **Risk:** a one-frame blank instead of a one-frame lie — acceptable.

### M3 — A failed snapshot stream is indistinguishable from an empty curriculum
- **Evidence:** `AsyncValue.value ?? const StudySnapshot.empty()` (`app_providers.dart:154-156`) discards the error branch; grep finds no `.whenOrNull(error:)`/`hasError` consumer for `snapshotProvider` anywhere under `lib/presentation`. `runWrite` (`write_guard.dart:27-79`) covers writes only.
- **What the user experiences today:** if `watchSnapshot()` ever errors (disk corruption, migration fault), every screen quietly renders the empty-curriculum world — review says «كل دروسك في موعدها», analytics says «لا توجد بيانات كافية بعد» — while their data exists on disk. For this app, whose entire promise is that the number is trustworthy, silent-empty is the worst failure mode available.
- **Severity:** P1 (low probability, maximal harm, zero visibility — including to Crashlytics, since nothing catches it).
- **Fix:** one top-level listener on `snapshotProvider` that surfaces a persistent error banner + retry, and gates the empty-states on `!hasError`.
- **Risk:** needs a designed error shape; the toast system already exists for delivery.

### M4 — Analytics has no state for "curriculum built, zero exams"
- **Evidence:** the closing empty line requires `chapters.isEmpty && lessons.isEmpty` (`analytics_screen.dart:148-156`); `lessons` for `_WeakestCard` is filtered to `hasExam` (`analytics_screen.dart:72-77`) and the trajectory card requires `hasTrend` (`analytics_screen.dart:127`).
- **What the user experiences today:** a student who built 3 chapters and sat nothing sees: subject bars of grey "—" columns, chapter bars of empty tracks labelled «متوسط الامتحانات: —» upstream (`chapter_screen.dart:432-442` equivalent here), discipline «0 من 0» with a "—" rate — three cards of nothing, and the one sentence that explains why («لا توجد بيانات كافية بعد») suppressed because chapters aren't empty.
- **Severity:** P2.
- **Fix:** switch the condition to "no exam anywhere in scope" and render `EmptyState` (action variant) pointing at the up-next card / «امتحن».
- **Risk:** none.

### M5 — Backup status lies for one frame («لم تُحفظ نسخة بعد» while loading)
- **Evidence:** `backupMetadataProvider` is a FutureProvider read as `.value` (`backup_screen.dart:127`); status falls through to `l.backupNever` when `lastSavedAt ?? cloud?.updatedAt` is null (`backup_screen.dart:143-147`); Settings row does the same (`settings_screen.dart:112`).
- **What the user experiences today:** a student with a healthy cloud backup who opens Settings/Backup cold may glimpse «لم تُحفظ نسخة بعد» before the metadata resolves — the scariest sentence in the app, flashed wrongly.
- **Severity:** P2.
- **Fix:** render an indeterminate dash until the FutureProvider settles.
- **Risk:** none.

### M6 — Unknown/invalid ids render a titled-blank screen forever
- **Evidence:** `chapterSummaryProvider`/`lessonSummaryProvider`/`subjectSummaryProvider` return null when the snapshot lacks the id (`summary_providers.dart:85-113`); screens respond with `AtherHeader(title: '', onBack: …)` and `children: const []` — `chapter_screen.dart:303-308`, `lesson_screen.dart:95-100`, `subject_screen.dart:61-66`, `chapter_report_screen.dart:136-141`. The router manufactures id `-1` for unparseable paths by design (`router.dart:345-354`).
- **What the user experiences today:** a malformed desktop URL or restored deep link lands on a screen with an empty title, no body, no message — just a back chevron. During initial load every detail screen passes through this same titled-blank frame.
- **Severity:** P2 (dead end is escapable via back, but it's an unexplained void; the router comment claims "every screen already handles an id that matches no row" — handling here means *rendering nothing*, which is not a state a user can read).
- **Fix:** one shared "not found" body («هذا العنصر لم يعد موجوداً») with a back button, shown when loading has settled and the id is still unknown.
- **Risk:** none.

### M7 — Homework history has no viewer, by omission
- **Evidence:** §3.31 removed `deleteHomework` "if a homework history is ever shown, the delete comes back with the UI that needs it"; the lesson screen shows only `latestHomeworkPercentage` (`lesson_screen.dart:364,407-425`).
- **What the user experiences today:** recording a new homework silently supersedes the old score with no way to see the previous one — consistent with the documented rule, noted here so the audit trail is complete. No action required.
- **Severity:** informational.

---

## Dead ends & traps

### T1 — Leaving a "correct answers" field blank records all-wrong without asking
- **Evidence:** step 3 builds a `NumberField` per group (`exam_entry_screen.dart:592-621`); validation only checks `correctValue > countValue` (`exam_entry_screen.dart:322-326`); `int.tryParse('') ?? 0` (`exam_entry_screen.dart:71`).
- **What the user experiences today:** a two-group paper where the student fills group 1, skips group 2's field, saves — the exam commits counting 0 correct for group 2. No banner, no preview flag on step 4 (the result simply comes out low, and the verdict line tells them they're weak — a false verdict manufactured by a skipped field).
- **Severity:** P1 (it corrupts the one number the product exists to keep trustworthy; §3.31 had to build an entire delete path for precisely this class of mistake).
- **Fix:** treat any blank correct-field as a validation error («اكتب عدد الإجابات الصحيحة لكل مجموعة») at Next, mirroring step 2's `examErrorGroupInvalid`.
- **Risk:** none; pure validation.

### T2 — Exam-delete affordance is invisible ink
- **Evidence:** the history row's only delete signal is a 14px tertiary-coloured × glyph (`lesson_screen.dart:674-679`); tapping the row opens `confirmDestructive` (`lesson_screen.dart:632-634`).
- **What the user experiences today:** §3.31's headline fix — "an uncorrectable number is the worst defect available" — is guarded by the least legible control in the app. The confirm sheet prevents accidents, but discovery is the bottleneck: a student with a mistyped 30/3 has no word telling them correction is possible.
- **Severity:** P2.
- **Fix:** caption under the history title («اضغط على أي امتحان لحذفه وتصحيح الرصيد») or promote the × to the `wrongText` tint.
- **Risk:** none.

### T3 — Discard-confirm fires the destructive haptic for a non-destructive act
- **Evidence:** `_leave()` calls `confirmDestructive` without `heavyOnConfirm: false` (`exam_entry_screen.dart:284-291`), while the seam documents heavy = "the destructive commit" (`prompts.dart:196-203`) and the sign-out caller explicitly opts out for exactly this reasoning (`settings_screen.dart:651-663`).
- **What the user experiences today:** backing out of a half-typed paper buzzes like a delete. Minor, but it dilutes the one-haptic-one-meaning contract PH-04 built.
- **Severity:** P2.
- **Fix:** pass `heavyOnConfirm: false` (discard clears a draft; nothing owned is destroyed).
- **Risk:** none.

### T4 — Wizard "after" preview ignores review classification
- **Evidence:** step 4 previews with a synthetic `ExamEntry(isReviewExam: false, …)` (`exam_entry_screen.dart:627-638`) while `_save` classifies from the lesson's live `needsReview` (`exam_entry_screen.dart:370-374`).
- **What the user experiences today:** currently harmless — `MasteryCalculator` weights by recency, not by the flag (`mastery_calculator.dart:8-20`) — so preview equals saved number today. It is a latent divergence: any future weighting on `isReviewExam` makes the celebrated preview a lie. Recorded as a trap with the fuse already cut.
- **Severity:** P2 (latent).
- **Fix:** construct the preview entry with the same `isReviewExam` the save will use.
- **Risk:** one-line.

### T5 — Notification deep-link can strand on a deleted lesson
- **Evidence:** tap-through pushes `Routes.lesson(lessonId)` unconditionally (`notification_providers.dart:183-191`); combined with M6, a reminder tapped after the lesson was deleted (chapters cascade deletes, `PROJECT.md` §4) renders the titled-blank screen.
- **Severity:** P2 (folds into M6's fix).
- **Fix:** covered by M6's not-found body.

### T6 — Desktop window: nothing anchors the floating glass bar's contrast assumptions
- **Evidence:** blur is platform-gated off on desktop (`app_shell.dart:174-187`) so the bar is opaque there — safe. UNVERIFIED: `AtherSheet`/bottom-sheet max-width on ≥600 windows; the design rules assume phone widths and I did not find a cap in `ather_sheet.dart` during this pass.
- **Severity:** P2 (UNVERIFIED — verify before acting).
- **Fix:** if uncapped, cap sheets at `AtherScreen.maxContentWidth`.

---

## Prioritized Needs (top 10)

1. **P1 — Stop rendering loading as false content:** gate review/dashboard/settings/backup empty-states on `snapshotProvider` having settled (M1, M2, M5) — the green «كل دروسك في موعدها» flash is the worst offender.
2. **P1 — Validate blank correct-counts in wizard step 3** (T1): a skipped field must block Next with a banner, never silently record zeros into mastery.
3. **P1 — Surface snapshot-stream errors in the UI** (M3): one error banner + retry at the shell level; silent-empty is the antithesis of the product's trust claim.
4. **P1 — Make the tasks add-button day-explicit and re-seed stale past selections** (F4): «+ إضافة مهمة (السبت)» or reset-to-today on day change.
5. **P2 — Shared "not found" body for null chapter/lesson/subject/report summaries** (M6/T5), replacing the titled-blank screen and covering `-1` router fallbacks and stale notification links.
6. **P2 — Accept and normalise Arabic-Indic digits in `NumberField`** (F5): silent keystroke rejection reads as a broken field on the app's primary audience's keyboards.
7. **P2 — Analytics empty-state for "content but no exams"** (M4): replace three cards of dashes with one actionable `EmptyState`.
8. **P2 — Badge semantics: reserve red for overdue** (F3): exclude weak/declining from the tab badge count or drop its alarm colour.
9. **P2 — Signpost the first-run ladder** (F1/F2): three-step copy on `_FirstRunCard`, plus expose the dormant `curriculum_templates` batch path on seeded subjects.
10. **P2 — Hygiene set:** visible exam-delete affordance (T2), `heavyOnConfirm:false` for wizard discard (T3), preview entry classified like the save (T4), PROJECT.md §1 updated for subject management (F7), verify sheet widths ≥600 (T6, UNVERIFIED).
