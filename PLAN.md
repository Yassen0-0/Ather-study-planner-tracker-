# Plan — the app's voice, and the Settings screen

Two pieces of work, in this order. Neither touches the database, so neither can
put a student's exam history at risk (see Rule 1 in [CLAUDE.md](CLAUDE.md)).
Everything still owed after these two is in [BACKLOG.md](BACKLOG.md).

Branch: `claude/app-ai-settings-profile-785e24`.

---

# Part 1 — The voice

## What is wrong

Two separate problems, and they need two different fixes.

**The register is wrong.** The app speaks Egyptian colloquial throughout —
`النهارده`, `دوس`, `جرّب تاني`, `مقدرناش`, `لسه مبدأتش`. The decision is to move
to **simple Modern Standard Arabic**: the Arabic of a well-made product, not of a
textbook and not of a chat message. Short sentences, ordinary words, no
classical flourish.

**The app explains itself to a student who did not ask.** A switch labelled
`قفل بالبصمة` sits above a line reading `اطلب بصمة كل ما تفتح التطبيق`. A
three-way theme control sits above a line explaining that it chooses a theme.
This is the thing to be rid of, and translating those lines into MSA would keep
the problem while changing its accent. **They get deleted, not rewritten.**

## The rule for deciding

A line of body copy earns its place only if it carries something the control
cannot show:

- **Keep** — a consequence (`هيتحذف الباب وكل الدروس والامتحانات اللي جواه`), a
  cause (`التنبيهات مقفولة من إعدادات التليفون`), or a product rule the student
  could not guess (`الواجب لا يدخل في حساب الإتقان`).
- **Delete** — a restatement of the title, an instruction to press the thing in
  front of them, or a reassurance about something that has not gone wrong.

## Lines that get deleted outright

| Key | Current | Why it goes |
|---|---|---|
| `lockSettingBody` | اطلب بصمة كل ما تفتح التطبيق | The title plus a switch already says this. The line the user named specifically. |
| `settingsThemeBody` | اختار مظهر التطبيق، أو سيبه يمشي مع إعدادات الموبايل | The three options are `فاتح / داكن / النظام`. |
| `settingsNotificationsBody` | ذكّرني لما يجي وقت مراجعة درس | Title is `إشعارات المراجعة`. |
| `celebrationHint` | دوس في أي حتة تكمّل | Tells the student to tap. |
| `examHistoryHint` | دوس على امتحان عشان تشيله لو اتسجل غلط | Tells the student to tap. |
| `analyticsAlwaysAllSubjects` | الكارت ده بيقارن المواد الأربعة دايماً | Explains a chart that is legible. Also becomes false the moment subjects are addable — see BACKLOG. |
| `tasksEmptyBody` | اكتب اللي ناوي تعمله، وشيله لما تخلصه | Explains what a task list is. |
| `backupBody` | بياناتك بتتحفظ على حسابك، فلو غيّرت التليفون تلاقيها زي ما هي | The status line underneath (`آخر حفظ: …`) states the fact instead of promising it. |

Two more get **cut in half** rather than deleted, because the surviving clause
is the product's central claim and a student genuinely cannot guess it:

- `firstRunBody` — drop the walkthrough (`افتح مادة، ضيف فيها باب، وبعدين درس`),
  keep the rule: *الإتقان يُحسب من امتحاناتك وحدها.*
- `authSubtitle` — drop the reassurance, keep the fact that sign-in is needed
  once and the app then works offline.

## Sample conversions

The whole file gets passed; these fix the register so the rest is mechanical.

| Key | From | To |
|---|---|---|
| `appTagline` | إنت مش بتخلص الدروس… إنت بتتقنها | أنت لا تُنهي الدروس، بل تُتقنها |
| `dashboardTitle` | النهارده | اليوم |
| `notStartedYet` | لسه مبدأتش | لم تبدأ بعد |
| `lessonNoExamYet` | لسه مفيش امتحان | لا يوجد امتحان بعد |
| `subjectHasOverdueLesson` | فات ميعاد مراجعة درس | تأخّرت مراجعة درس |
| `examDiscardTitle` | تسيب الامتحان؟ | تترك الامتحان؟ |
| `examDiscardLeave` / `examDiscardStay` | سيبه / كمّل | اترك / أكمل |
| `commonSomethingWentWrong` | في حاجة مامشتش صح. جرّب تاني. | تعذّر إتمام العملية. حاول مرة أخرى. |
| `examSaveFailed` | مقدرناش نحفظ الامتحان. أرقامك لسه موجودة — جرّب تاني. | تعذّر حفظ الامتحان. أرقامك لم تَضِع — حاول مرة أخرى. |
| `celebrationBody` | شغل محترم. كمّل على كده. | عمل ممتاز. واصِل. |
| `reviewEmptyBody` | كل دروسك في وقتها. استمر. | كل دروسك في موعدها. |
| `backupNever` | لسه متحفظتش | لم تُحفظ بعد |
| `lockRefused` | مفتحش — جرّب تاني | لم يُفتح. حاول مرة أخرى. |
| weekday names | اتنين، ثلاثاء | الاثنين، الثلاثاء |

## Mechanics

1. `lib/core/l10n/app_ar.arb` is the file being rewritten. `app_en.arb` only
   needs the **deletions** mirrored — its English is not the problem.
2. Deleting a key means deleting it from **both** ARB files and from every widget
   that reads it. The `ARB keys resolve in both locales` test catches a key left
   in one file; the analyzer catches a widget still calling a getter that no
   longer exists.
3. Regenerate (`flutter gen-l10n`, or any `flutter run`/`test`) so
   `lib/core/l10n/generated/` follows.
4. Several widget tests find their targets by Arabic text. They break by design,
   and each break is the test confirming the string changed. Update them; do not
   loosen the finders to `textContaining`.

---

# Part 2 — The Settings screen

## What is wrong

`settings_screen.dart` renders **nine free-floating cards in one column**, each
one a different height with a different internal layout: two segmented controls,
two switch rows, a card with two full-width buttons in it, a link row, an about
block, and a bare red button under a `منطقة الخطر` heading. Nothing groups, so
the eye gets no structure and the page reads as a pile rather than a screen.

Two things make it read as cheap in particular:

- **Full-width filled buttons inside a settings list.** `احفظ دلوقتي`,
  `استرجع النسخة السحابية` (large, red), `تسجيل الخروج`, `حذف الحساب` (large,
  red). Serious apps do not put big filled buttons in a settings list; they use
  rows, and reserve red for text.
- **Everything is inline.** Backup shows its status, its explanation, and both
  its actions on the main page. There are no detail screens, so the top level
  carries detail that belongs one level down.

## The shape to build

The pattern the user named — Facebook, Instagram — is: an identity block at the
top, then **titled groups of uniform rows**, each row leading with a label,
trailing with either its current value + chevron or a switch, and anything with
detail living on its own screen.

```
┌─────────────────────────────────┐
│  ◯   <name>                     │   ← account block, tappable
│      <email>                    │      (→ Profile, see BACKLOG)
└─────────────────────────────────┘

  الحساب
  ┌───────────────────────────────┐
  │ الحساب                    ›   │
  │ النسخة الاحتياطية   منذ يومين › │
  └───────────────────────────────┘

  التفضيلات
  ┌───────────────────────────────┐
  │ اللغة                العربية › │
  │ المظهر                 فاتح  › │
  │ إشعارات المراجعة        [ ●] │
  │ قفل بالبصمة             [● ] │
  └───────────────────────────────┘

  عن أثر
  ┌───────────────────────────────┐
  │ سياسة الخصوصية            ›   │
  │ عن التطبيق                ›   │
  └───────────────────────────────┘
                        الإصدار 1.6.0

  ┌───────────────────────────────┐
  │ تسجيل الخروج                  │   ← plain row
  │ حذف الحساب                    │   ← red text, no red slab
  └───────────────────────────────┘
```

Notes on the shape:

- **The version moves out of a card** into a quiet line under the last group,
  where every large app puts it.
- **`منطقة الخطر` as a heading goes.** Naming a danger zone is a developer's
  framing. The position at the bottom and the red text carry it; the
  confirmation dialog does the actual protecting, and that dialog is unchanged.
- **Sign-out stops being a big secondary button** and becomes a row. It is not a
  destructive act — the copy already says the data survives.
- **Backup gets its own screen** holding the status line, `احفظ الآن`, and
  `استرجاع النسخة`. The row on the main page shows the last-saved time as its
  value, which is the only part a student checks at a glance.
- **Language and theme get their own screens** (or sheets) rather than two
  segmented controls competing for attention on the top level. The row shows the
  current choice, which is more informative than a control showing three.
- **Biometrics stays conditional.** The row is still hidden when the device has
  no sensor to answer it — offering a lock that can never open is worse than not
  offering one.

## New widgets

Two, in `lib/core/widgets/`, so this shape is reusable and not settings-only:

- `SettingsGroup` — section title plus a rounded container that draws hairline
  dividers *between* its children and nowhere else.
- `SettingsRow` — label, optional trailing value, and one of: chevron, switch,
  or nothing. One height, one padding, one place to change either. A `tone` for
  the destructive variant so red is defined once rather than per call site.

`AtherCard` is not the right base — it is a standalone card with its own padding,
which is exactly the floating-card look being removed.

## What must not change

- `SettingsScreen.appVersion` stays a hand-written `static const` on the class.
  `tool/check_invariants.sh` reads it, and moving it breaks the check that keeps
  `versionCode` honest.
- The delete-account sequence — flush, wipe device, delete cloud mirror, delete
  account, in that order — is untouched. Only its trigger becomes a row.
- The re-auth password sheet is untouched.
- The `confirmLabel` on every destructive dialog stays. The restore dialog is
  still missing one on this branch and gets it here.

## Tests

`test/widget/backup_test.dart` and `test/widget/auth_test.dart` reach Settings
through an `openSettings` helper and then find controls by Arabic text. Both the
restructure and Part 1 move those targets. Expect to update: the helper, the
scroll-until-visible calls (the page gets shorter, so some may not need to
scroll at all), and every `find.text` for a string that changed.

Add one test the screen does not have: **the destructive rows are the last two
things on the page.** That ordering is a safety property, currently held up only
by a comment.

---

# Order

1. Part 1 on the ARB files and the widgets that read them. Ship it green.
2. `SettingsGroup` / `SettingsRow` plus the detail screens.
3. Rebuild `settings_screen.dart` on top of them.
4. `flutter analyze`, `flutter test`, `bash tool/check_invariants.sh`, then
   commit — Rule 3.
