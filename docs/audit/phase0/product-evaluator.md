# Product Evaluation

Evaluator: PRODUCT-EVALUATOR · Phase 0 audit · Base inspected: `ai-audit/2026-08-25` @ `547c059`, `pubspec.yaml` version `1.8.0+16`.

---

## Product definition (one paragraph) + verdict

Ather (أثر) is an offline-first, Arabic-first Android app for Egyptian Thanaweya Amma (علمي علوم) students that measures **mastery, not activity**: the student builds their own curriculum of chapters and lessons inside seeded subjects, and the only thing that moves any number is the score of a **real exam they sat and enter question-group by question-group**. Thirty days after a lesson was last proven by an exam, its mastery expires — it turns red and can only be re-earned by another real exam; there is no "mark as reviewed" button anywhere (`lib/domain/services/review_cycle_service.dart`, `PROJECT.md` §1/§3.3). Around that engine sit a Review Center (what decayed and what decays next), analytics (trajectory, velocity, review discipline), daily tasks deliberately walled off from mastery (`lib/presentation/tasks/tasks_screen.dart:25-38`), an exam-eve triage sheet per subject, cloud backup as a signed-in mirror of the local SQLite master, JSON/PDF/image export, and due-date plus 3-days-early reminders.

**Owner verdict:** the core loop is real, coherent, unusually well-tested, and honest — but **it is not shippable to a real Egyptian student today**, for one dominant reason: there is **no distribution channel** (private GitHub repo, undeployed website, no Play listing — `BACKLOG.md:9-29,50-55`), and for one thesis-level reason: **every student must create an account before the app shows them a single value** (`lib/app/router.dart:164-169`), which contradicts the offline-first promise the product is built on. Everything else is polish.

---

## Feature map & coherence table (feature | serves thesis? | verdict | evidence)

Thesis = "mastery measured ONLY from real exam performance; decays after 30 days; student builds own curriculum."

| Feature | Serves thesis? | Verdict | Evidence (file:line) |
|---|---|---|---|
| Dashboard: overall number, 3 stats, subject rows, up-next card, comeback line, first-run card | Yes — "where am I, what now" | **Core** | `lib/presentation/dashboard/dashboard_screen.dart:39-44,92-128,182-205,668` |
| Exam entry wizard (4 steps, question groups) | Yes — the one action mastery derives from | **Core** | `lib/presentation/exam_entry/exam_entry_screen.dart`; `PROJECT.md` §3.2 |
| 30-day decay engine, derived `needsReview` | Yes — the differentiator | **Core** | `lib/domain/services/review_cycle_service.dart`; `PROJECT.md` §3.3 |
| Review Center: decayed-first queue, 14-day radar, rows open wizard directly | Yes — the decay loop's UI | **Core** | `lib/presentation/review_center/review_center_screen.dart:25-35,71` |
| Analytics: subject/chapter bars, trajectory + velocity, weakest-5, review-discipline rate | Yes — measurement of exam performance | **Core** | `lib/presentation/analytics/analytics_screen.dart:30-34,84-90`; `insights_generator.dart:333-368` (discipline = review punctuality, **not** task completion — walls hold) |
| Chapter screen + "أتقنت الباب" gate | Yes — explicit mastery claim | **Core** | `PROJECT.md` §5 |
| Curriculum templates (chapters for 4 seeded subjects) | Yes — removes setup tax from "build your own curriculum" | **Core (supporting mechanism)** | `lib/domain/services/curriculum_templates.dart:39-80` |
| Lesson screen: 5-step checklist, homework readiness line, history + exam delete | Partially — checklist/homework deliberately never touch mastery | **Supporting** | `PROJECT.md` §3.9, §3.31; `lesson_screen.dart:572-607` |
| Daily tasks tab + day picker + surrender marks | No — a habit side-car; kept structurally out of mastery (own repo stream, no FK, no percentage) | **Supporting** (largest non-thesis surface; surrender is polish on it) | `tasks_screen.dart:25-38`; `PROJECT.md` §3.22; schema v4→v5 `app_database.dart:56` |
| Exam-eve sheet (3-tier triage per subject) | Yes, adjacent — prepares for *real* exams, routes into wizard | **Supporting** | `exam_eve_service.dart:1-60`; `exam_eve_sheet.dart:24-41`; ARB `app_ar.arb:751` |
| Reminders (due-day + 3-day early, cap 400, tap opens lesson) | Yes — closes the decay loop | **Core** | `review_cycle_service.dart:149-168`; `review_notification_service.dart:199,232-237` |
| Cloud backup mirror (checksummed, all-or-nothing restore, uid-wipe, delete-account) | Trust layer for a 2-year record | **Core (trust)** | `PROJECT.md` §3.26, §3.30; `backup_screen.dart:19-32` |
| Export JSON / chapter-report PDF / shareable image card | Yes — ownership of the number | **Supporting** | `settings/export_screen.dart:16-19`; `share/mastery_card.dart`; `pubspec.yaml:47-56` |
| Accounts (email+Google), email verification, profile | Only as backup identity | **Supporting — but mandatory gate is thesis-hostile** (see Activation) | `router.dart:164-169`; `login_screen.dart:22-27,37-39`; `profile_screen.dart` |
| Biometric/password lock | Privacy, not thesis | **Supporting** | `PROJECT.md` §3.18; lock-methods row `settings_screen.dart:175,175-193` |
| Free subjects: add / archive / delete / recycle bin | Widened past "student builds curriculum inside 4 fixed subjects" | **Drift vs stated spec**, defensible vs actual user base | `subjects_screen.dart:29,108,188-196`; `recycle_bin_screen.dart`; vs `PROJECT.md:67-68` |
| Share-progress card on dashboard | Growth/vanity, not mastery | **Mild drift** (cheap, gated behind `!isEmpty`) | `dashboard_screen.dart:154-157,216-256` |
| **Windows target** | Claimed platform | **Claim with no screen/build behind it** | `PROJECT.md:117` vs §8 `:1115-1126` (never built; Developer Mode off) |

No dead claims found other than Windows. Scope drift is small and mostly documented; the two genuine tensions are the **free-subject widening** and the **mandatory auth gate**.

---

## Activation analysis (install→value path in code, blockers)

Code path a brand-new student walks:

1. **Hard login gate.** `redirect` sends every unsigned-in launch to `/login` (`lib/app/router.dart:164-169`). Value requires an account first: register (password ≥ 8 chars, `login_screen.dart:37-39`) or Google sign-in (needs Play Services + network at that moment). The screen does state the deal honestly (`login_screen.dart:22-27`), and the app works offline *after* — verified in airplane mode (`PROJECT.md` §3.17).
2. **First-run card replaces the empty summary cards** — `dashboard.isEmpty ? _FirstRunCard(...) : ...` (`dashboard_screen.dart:182-188`), copy states the thesis verbatim: «الإتقان يُحسب من امتحاناتك وحدها» (`app_ar.arb:39-44`), CTA "افتح أول مادة" pushes the first subject (`dashboard_screen.dart:303-310`). Deliberately no dismissible tutorial — a documented product decision (`dashboard_screen.dart:277-285`; `PLAN.md` item 7 "rejected").
3. **Build curriculum.** Subject exists (seeded). Chapters: type each by hand, or apply the standard template from the subject's sheet (`curriculum_templates.dart`; wired per `PLAN.md` Batch B4). **Lessons have no template and no bulk add** — one `showNamePrompt` per lesson.
4. **First value.** Record an exam via the wizard (4 steps, points-groups arithmetic). This is the first moment anything on screen means anything: percentage, celebration, restarted clock — and the notification-permission ask fires exactly here, correctly (`exam_entry_screen.dart:395-407`).

**Honest 5-minute judgment:** not met for the median 17-year-old. The login wall (account creation before any value), then Arabic-typing N lesson names through one-at-a-time name sheets, puts a *meaningful* number at roughly 10–20 minutes even using templates. Templates fixed the chapter half of the tax (`PLAN.md:584`: "typing twenty chapter names … should not be the price of admission") but stopped one level short: **lessons are where the remaining typing lives**, and a chapter without lessons cannot hold an exam.

Blockers ranked: (a) mandatory account; (b) per-lesson manual creation; (c) wizard step 1 asks the student to encode points-per-question groups — cognitively correct but the single most abstract screen in the flow (mitigated by good validation, `PROJECT.md` §9 wizard fixes).

---

## Retention loop analysis

The loop is **closed end-to-end in code**, which is rare:

- record exam → `lastReviewedAt` stamped → derived decay flips at day 30 (`review_cycle_service.dart`) → red via `MasteryPalette` precedence grey→red→band (`PROJECT.md` §3.11) → Review Center queues it decayed-first with a 14-day radar (`review_center_screen.dart:71-100`) → tab badge count (M-05) → reminder at due day **and 3 days early** (`kEarlyReminderDays`, `review_cycle_service.dart:149-168`), capped at 400 soonest alarms (`review_notification_service.dart:199`), tap payload opens the lesson (`PROJECT.md` §3.15a) → wizard re-exam → loop resets. Dashboard adds a comeback line measuring lessons that decayed *during* the absence (`dashboard_screen.dart:92-128,165-171`).
- Permission asks are at the two right moments (first exam save, Settings switch): `exam_entry_screen.dart:401`, `settings_screen.dart:567`. OS/preference disagreement surfaces in Settings (`settings_screen.dart:597`).
- Day rollover is driven by a midnight emission **plus** a resume trigger — the "stale 62-day countdown" bug is fixed (`PROJECT.md` §9, day-granular clock).

Honest weaknesses in the loop:
1. **Reboot survival of scheduled reminders is declared but never exercised** — `ScheduledNotificationBootReceiver` registered, yet `PROJECT.md:1159-1161` says explicitly the boot case was not covered by the one successful device observation. A 30-day cycle crosses reboots by construction; this is the loop's least-tested link.
2. Delivery observed exactly once, via a device-clock jump, not a real 30-day wait (`PROJECT.md:1151-1158`).
3. Nothing pulls the student back who has **no decayed lessons yet** except tasks (which the app itself insists measure nothing). Early-life retention rides entirely on the student's own exam schedule. Acceptable for the thesis, but worth stating: the product intentionally has no streaks/points.

---

## Shippability gaps

Format: gap · evidence · severity · need · risk.

1. **No way for a real student to obtain the app.**
   Evidence: GitHub repository is private, so the existing GitHub release is invisible to students (`BACKLOG.md:19-22`); website written but deployment is a pending human step (`BACKLOG.md:9-17`); Play never submitted, no listing/screenshots/**.aab** (`BACKLOG.md:50-55`).
   Severity **P0**. Need: execute the already-written deploy procedure (site + APK), decide Play timing. Risk if skipped: all other work reaches zero users; sideloaded APKs circulate un-updatable.
2. **Mandatory account before any value — thesis contradiction.**
   Evidence: `lib/app/router.dart:164-169` redirects every launch to `/login`; `login_screen.dart:22-27`. The stated product intent is offline-first with sign-in *only* for the cloud mirror (brief; `PROJECT.md` §3.17 heritage: "no accounts… no network requests" was the original rule).
   Severity **P0** (product-defining, not a bug). Need: local-first mode — start studying immediately; raise sign-in only when enabling backup/sync. Risk: auto-restore/wipe logic (`backup_gate.dart`) assumes an account at first run; needs a designed variant, not a flag.
3. **Lesson-level activation tax.**
   Evidence: templates cover chapters only (`curriculum_templates.dart:33-45` return shape is chapter-name lists); lessons are one `showNamePrompt` each (`PLAN.md:584-587` frames the problem, solved one level short).
   Severity **P1**. Need: lesson bundles per template chapter or multi-line paste-add. Risk: low; pure setup UX.
4. **Reminder reboot delivery unverified.**
   Evidence: `PROJECT.md:1159-1161` (boot receiver "declared and registered, but was not exercised").
   Severity **P1**. Need: one device test — schedule, reboot, observe. Risk: silent death of the entire retention loop for the majority of phones that reboot weekly.
5. **Arabic PDF export never seen on a device.**
   Evidence: `PLAN.md:217-220` — pipeline proven by tests, "Worth one look on a phone before release"; rasterized-image approach chosen precisely because font shaping fails silently.
   Severity **P1**. Need: 5-minute device verification; hide PDF row if wrong. Risk: exporting a third-blank report to a teacher is a trust wound worse than no export.
6. **Docs are the source of truth and are materially stale.**
   Evidence: `PROJECT.md:67-68` still claims "Exactly four subjects, fixed… no subject-management UI" vs `subjects_screen.dart:108,188-196` + `recycle_bin_screen.dart` (shipped 1.7.0+12, `RELEASE_NOTES.md:133-157`); §5 features table (`PROJECT.md:842-878`) omits exam-eve, export, share, PDF, profile, privacy, recycle bin, password lock, surrender, email verification, early reminders; §3.28 `:618-620` says exam entry has exactly two doors while Review rows open the wizard as a third (`review_center_screen.dart:28-31`). This repo's own history proves the cost: stale docs produced a shipped wrong-design APK (CLAUDE.md Rule 2 preamble).
   Severity **P1**. Need: reconcile PROJECT.md §1/§5/§3.28 and pin one "current release" fact. Risk: every future agent session inherits false constraints.
7. **Backup size ceiling untested against real two-year data.**
   Evidence: 900 KiB budget, refuses rather than truncates (`PROJECT.md` §3.26); `PROJECT.md:1650-1653`: "size ceiling is still untested against a large real curriculum."
   Severity **P1**. Need: synthesize a maximal record, attempt upload; design the refusal message students will actually see. Risk: the exact student who used the app longest discovers their backup silently never fit.
8. **Windows claimed, never built.**
   Evidence: `PROJECT.md:117` (target) vs `:1115-1126`, `:1146-1150` (Developer Mode off; blocks builds *and* `flutter test` in worktrees).
   Severity **P2** (product claim, not Android shipping). Need: enable one switch, run once, then either verify or strike the claim. Risk: continued agent time burned on a phantom platform.
9. **Chapter/lesson deletion is irreversible while subject deletion is recoverable — taught behavior then punished.**
   Evidence: `BACKLOG.md:41-48` (deliberate deferral, acknowledged inconsistency).
   Severity **P2**. Need: extend bin or strengthen confirm copy naming what is lost. Risk: a student loses exam history to a gesture the app taught them was safe.
10. **Motion/perf never profiled on mid-range hardware.**
    Evidence: `PROJECT.md:1265-1270`.
    Severity **P2**. Need: one profile run on the Nothing Phone A015 already in use. Risk: jank on the exact devices students own.

---

## Divergences docs-vs-code

| Doc says | Code/shipped reality | Evidence |
|---|---|---|
| `PROJECT.md:67-68` four fixed subjects, no subject-management UI | Subjects freely added/archived/deleted + recycle bin since 1.7.0+12 | `subjects_screen.dart:108,188-196`; `RELEASE_NOTES.md:133-157` |
| `PROJECT.md:618-620` exam entry from exactly two places | Third door: Review Center rows open the wizard | `review_center_screen.dart:28-31` |
| `PROJECT.md` §5 table (features/status) | Missing ≥6 shipped features (export/PDF/share, exam-eve, profile, privacy screen, recycle bin, password-lock methods, surrender, email verification, early reminders, App Check) | `PROJECT.md:842-878` vs `ls lib/presentation` |
| `BACKLOG.md:3` "Everything… released as `1.8.0+14`" | Current release `1.8.0+16`; RELEASE_NOTES head agrees with pubspec | `pubspec.yaml:6`; `RELEASE_NOTES.md:1` |
| Brief/thesis: sign-in *optional*, for cloud mirror only | Sign-in mandatory at router level | `router.dart:164-169` |
| `PLAN.md:694` exam calendar deliberately removed, deferred | Calendar-adjacent "exam eve" triage shipped per subject | `exam_eve_service.dart`, `exam_eve_sheet.dart`, `app_ar.arb:751` |
| `PROJECT.md:117` Windows is a target | Never built once; blocks `flutter test` in worktrees too | `PROJECT.md:1115-1126,1146-1150` |
| `PROJECT.md` §3.22 tasks feed nothing | Still true post-v5 — surrender affects only the task row's own verdict, not mastery/discipline analytics | `insights_generator.dart:333-368`; `analytics_screen.dart:84-90` |

---

## Prioritized Needs (top 10 ordered)

1. **Ship a channel:** run the already-written `firebase deploy --only hosting` + copy `ather-latest.apk` (`BACKLOG.md:23-26`) — today the product cannot reach a single student.
2. **Make the app usable without an account:** local-first mode, sign-in surfaced only when turning on cloud backup (fixes `router.dart:164-169` vs the offline-first thesis).
3. **Cut activation under 5 minutes:** lesson-level template bundles / bulk lesson add, so a template-applied subject is exam-ready in a few taps.
4. **Prove reminder delivery across reboot on one real device** (boot receiver declared, never exercised — `PROJECT.md:1159-1161`).
5. **Verify Arabic chapter-report PDF on a device; hide the row if wrong** (`PLAN.md:217-220`).
6. **Reconcile PROJECT.md with shipped reality** (subjects freedom, §5 table, §3.28 third entry point, current release line) — it is the document every agent obeys.
7. **Load-test the 900 KiB backup ceiling with a realistic 2-year record and design the refusal UX** (`PROJECT.md:1650-1653`).
8. **Extend the recycle bin (or the warning) to chapters/lessons** so delete-is-recoverable stops being a lie the app teaches (`BACKLOG.md:41-48`).
9. **Resolve the Windows claim:** flip Developer Mode, build/run once, then verify §2 or delete the claim (`PROJECT.md:1146-1150`).
10. **Profile motion + scroll on a mid-range Android and record numbers in §9** (`PROJECT.md:1265-1270`) before marketing the feel the spring work promises.
