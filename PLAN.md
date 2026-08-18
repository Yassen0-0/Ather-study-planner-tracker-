# Ather Execution Plan

Written 2026-08-18. Verified against **`origin/main` @ `0314432`** (`version: 1.7.0+13`),
not against any local worktree. See "Base" below before you do anything.

---

## How To Use This File

You are one of two sessions executing this plan. You have no memory of the conversation
that produced it. Do this, in order:

1. **Read this whole file.** Especially "Base", "File Ownership Map", and "Rules For
   Executing Sessions".
2. **Run `git log --oneline -20`.** Confirm you are on a branch descended from
   `origin/main` @ `0314432` or later. If your `pubspec.yaml` says anything below
   `1.7.0+13`, you are on a stale base — stop and say so. Do not work around it.
3. **Run `git worktree list` and check for uncommitted `lib/` work elsewhere**
   (CLAUDE.md Rule 2). This repository has a documented history of newer work sitting
   uncommitted in a sibling worktree.
4. **Work only on your assigned batch** (SESSION A or SESSION B, whichever you were
   told). Never edit a file owned by another batch.
5. **Commit after each task**, message format `[A1] <task title>`.
6. **After each task: tick the checkbox and fill in the `Result:` line** with what
   changed and which files you touched. That line is how the other session and the
   human find out what happened.
7. **Run `flutter analyze` and `bash tool/check_invariants.sh` before your final commit.**

### Base

The plan targets `origin/main` @ `0314432`. This matters because the worktree the plan
was written in was **42 commits behind** it, and three backlog items were already
resolved upstream. Verification below was done against `origin/main`, not against that
stale tree.

Two `auto-claude/*` branches already contain partial implementations of work in this
plan. **Review and continue them rather than starting from scratch:**

| Branch | Covers | State |
|---|---|---|
| `auto-claude/002-data-export` | Task A1.1, A1.2 | 8 commits: `data_export_service.dart`, `pdf_export_service.dart`, `export_providers.dart`, `export_screen.dart`, router + settings wiring, ARB strings, pubspec deps. Branched from `b6182bd`, **12 behind** `origin/main`. Rebase before judging it. |
| `auto-claude/009-row-level-multi-device-sync` | Item 18 (DEFERRED) | 2 commits: `sync_entity.dart` plus sync metadata on six entities. Scaffolding only. |

Neither is merged. Neither has been reviewed. Treat them as a starting draft, not as
done work — read the code before adopting it.

---

## Verification Summary

I read the code for all 20 items. **Six were already done, three were misdiagnosed or
measured-and-rejected, and three are new features rather than fixes.** Ten items carry
real, confirmed work. That is the honest count.

| # | Item | Status | Evidence |
|---|---|---|---|
| 1 | Crash Reporting Integration | **ALREADY DONE** | Merged upstream as PR #12. `firebase_crashlytics: ^5.2.7` in `pubspec.yaml:55`; init in `lib/main.dart:113` (`_initializeCrashlytics`, release-only, `FlutterError.onError` wired at `:119`); Gradle plugin at `android/app/build.gradle.kts:49`; non-fatal `recordError` calls in `firestore_backup_repository.dart`, `app_database.dart:85`, `drift_study_repository.dart:345`. |
| 2 | Data Export | **VALID** | No export path anywhere in `lib/` on `origin/main`. `StudyBackup.toJson()` (`study_backup.dart:78`) already serialises subjects, chapters, lessons, exams and tasks, so the work is a file/share layer, not a serialiser. Partial implementation exists on `auto-claude/002-data-export`. |
| 3 | Email Verification & Security Hardening | **PARTLY DONE / PARTLY VALID** | *Password policy: DONE* — `_minPasswordLength = 8` at `login_screen.dart:36`, enforced register-only at `:92` with a documented reason for not applying it to sign-in. *Email verification: VALID* — no `sendEmailVerification` or `emailVerified` anywhere in `lib/`. |
| 4 | Notification & Clock Alignment Fix | **ALREADY DONE** | **Root cause, confirmed, and already fixed.** The 23-hour offset was `dueAt` returning `last.add(Duration(days: 30))` (hour-precise) while `needsReview` counted calendar days. On `origin/main`, `daysSinceReview` normalises through UTC day numbers (`review_cycle_service.dart:49-70`) and `dueAt` is rebuilt from calendar components anchored to `kReminderHour = 18` (`:109-134`). The comment at `:112-127` names the 23-hour disagreement as the defect it fixes. |
| 5 | Release Build Optimization & Dependency Cleanup | **INVALID / MISDIAGNOSED** | R8 was tried on 2026-08-13 and **measured**: both APKs came out at exactly 24,059,384 bytes — zero difference. Reasoning at `android/app/build.gradle.kts:135-160`: 19.9 MB of the APK is native AOT R8 never touches, against 4.0 MB of dex mostly held by Firebase consumer rules. `fl_chart` was already removed (`pubspec.yaml:22-29` documents why). `cupertino_icons` already removed (1,214 bytes, measured separately). Nothing left to do. |
| 6 | Cloud Backup Reliability Improvements | **VALID** | `backup_providers.dart:123` — `if (snapshot.isEmpty && tasks.isEmpty) return;`. A student who deletes everything never uploads that state, so the cloud keeps the pre-delete copy and `BackupSyncGate._restoreIfEmpty` pulls the deleted data back onto the next device. The guard's own comment (`:104-120`) explains it was a loading-state defence — which the switch to `.future` at `:121-122` has since made unnecessary. No checksum field exists in `upload()` (`firestore_backup_repository.dart:130-147`). |
| 7 | Interactive Onboarding Tutorial | **MISDIAGNOSED** | A first-run card already exists (`firstRunTitle/Body/Action` in both ARBs; `_FirstRunCard` in `dashboard_screen.dart:106`) and it already states the mastery claim. The doc comment at `dashboard_screen.dart:108-111` explicitly rejects a dismissible tutorial: "there is no 'got it' button, because a card that has to be got rid of is a card that will be got rid of unread." Building a guided tutorial reverses a decision the code documents. Not scheduled. |
| 8 | Pre-loaded Chapter Templates | **VALID** (new feature) | No `template`/`preset` construct in `lib/`. `SubjectsScreen` (`settings/subjects_screen.dart:45`) only supports adding one subject at a time (`_add` at `:96`). |
| 9 | Decay Countdown Timers & Predictive Alerts | **PARTLY DONE / PARTLY VALID** | *Countdown: DONE* — `daysUntilDue` is computed (`review_cycle_service.dart:88`), carried through `summaries.dart:171`, and rendered as a chip on the lesson screen (`lesson_screen.dart:196`) and chapter screen (`chapter_screen.dart:435`). *Predictive alerts: VALID* — `reschedule` books exactly one notification per lesson, at `dueAt` (`review_notification_service.dart:152-166`). Nothing fires before the due day. |
| 10 | Scroll Performance Optimization | **VALID** | `AtherScreen` takes `List<Widget> children` and passes it straight to `ListView(children: children)` — `core/widgets/ather_scaffold.dart:137-145`. Every row is mounted (element + render object) whether visible or not. Callers build eagerly too, e.g. `review_center_screen.dart:55`. Only `tasks_screen.dart` uses a builder anywhere in `lib/presentation`. **Magnitude, honestly:** a few hundred lessons, not thousands. Real, but not a crisis. |
| 11 | Stricter Static Analysis Configuration | **VALID** | `analysis_options.yaml` is the stock Flutter template: `include: package:flutter_lints/flutter.yaml` and an empty `rules:` block. No `analyzer.language` section, no `strict-casts`, no `strict-raw-types`, no `strict-inference`. → MANUAL, see caveat. |
| 12 | Enhanced Analytics & Trend Insights | **VALID** (enhancement) | `analytics_screen.dart` renders insights, subject bars, chapter bars, weakest-five and a discipline rate. There is no time axis anywhere — no score-over-time series and no mastery-velocity figure. |
| 13 | Chapter Report PDF Export | **VALID** (new feature) | `chapter_report_screen.dart` renders on-screen only. No `pdf`/`printing`/`share_plus`/`path_provider` in `pubspec.yaml`. Draft exists on `auto-claude/002-data-export` as `pdf_export_service.dart`. |
| 14 | Play Store 'Measurement Companion' Positioning | **NO CODE** | Listing copy. Nothing in the repository changes. |
| 15 | Notification Reliability & Scalability | **PARTLY DONE / PARTLY VALID** | *Reboot delivery: DONE* — `RECEIVE_BOOT_COMPLETED` declared and `ScheduledNotificationBootReceiver` registered with `BOOT_COMPLETED`, `MY_PACKAGE_REPLACED` and both QUICKBOOT actions (`AndroidManifest.xml:96-105`), with a comment explaining that without these receivers `zonedSchedule` succeeds and silently shows nothing. *Alarm cap: VALID* — `reschedule` loops every `snapshot.activeLessons` with no ceiling (`review_notification_service.dart:151-166`); Android's per-app alarm limit is ~500. |
| 16 | Shareable Mastery Progress Cards | **VALID** (new feature) | No share, screenshot or image-render path in `lib/`. No `share_plus` in `pubspec.yaml`. |
| 17 | Tutor/Parent Companion View | **VALID but DEFERRED** | New feature. Needs a sharing/permissions model that does not exist. |
| 18 | Row-level Multi-device Sync | **VALID but ISOLATED** | Architecture change. `FirestoreBackupRepository` is one gzipped blob per student at `users/{uid}/backup/snapshot`, and the file argues for that design at `firestore_backup_repository.dart:22-31`. Replacing it is a rewrite, not a task. |
| 19 | Egyptian Baccalaureate Curriculum Support | **VALID but DEFERRED** | New feature, curriculum-model change. |
| 20 | Exam Calendar & Scheduling | **VALID but DEFERRED** | New feature. |

### Localization files are shared, by decision

`lib/core/l10n/app_ar.arb`, `lib/core/l10n/app_en.arb` and everything under
`lib/core/l10n/generated/` are **exempt from the one-batch-owns-one-file rule.** Seven
tasks need new strings; enforcing ownership would collapse them into a single batch and
make an A/B split impossible.

**The convention both sessions follow:**

- Append your keys at the **end** of both ARB files, inside a block marked with your
  batch id. **Correction, found by Session A:** a bare `"_comment_A1"` key does *not*
  work -- `flutter gen-l10n` rejects any resource name starting with an underscore
  ("Resources names must be valid Dart method names"). Put the marker in the
  `description` of the block's first key instead, which is legal ARB and just as
  visible in a merge:

      "exportTitle": "...",
      "@exportTitle": {
        "description": "=== Batch A1: data export, chapter report PDF, share card. Appended block, append-only, do not reorder. ==="
      },

- **Never edit or reorder a key you did not add.** Append only.
- `app_ar.arb` is the template (see `l10n.yaml`); every key must exist in both files.
- `lib/core/l10n/generated/*` is generated output. Do not hand-edit it. Regenerate with
  `flutter gen-l10n` and commit the result; if the other session regenerated first, take
  theirs and regenerate on top.
- A merge conflict here will be two adjacent JSON blocks. Keep both.

---

## SESSION A

### Batch A1 — Export, PDF and share cards

Files owned by this batch:

- `pubspec.yaml`, `pubspec.lock`
- `lib/app/router.dart`
- `lib/presentation/settings/settings_screen.dart`
- `lib/presentation/settings/export_screen.dart` *(new)*
- `lib/presentation/providers/export_providers.dart` *(new)*
- `lib/domain/services/data_export_service.dart` *(new)*
- `lib/domain/services/pdf_export_service.dart` *(new)*
- `lib/presentation/chapter_report/chapter_report_screen.dart`
- `lib/presentation/dashboard/dashboard_screen.dart`
- `lib/presentation/share/mastery_card.dart` *(new)*
- `test/domain/data_export_test.dart` *(new)*

> Start by rebasing `auto-claude/002-data-export` onto `origin/main` and reading what is
> already there. It covers most of A1.1 and drafts A1.2. Adopt what is sound; do not
> assume it is correct.

- [x] **Task: Data export to JSON**
      Problem: There is no way for a student to get their own data out of the app.
      `StudyBackup.toJson()` (`study_backup.dart:78`) already serialises subjects,
      chapters, lessons, exams and tasks — nothing exposes it.
      Approach: Add `DataExportService` that builds `StudyBackup.fromSnapshot(...)`,
      encodes it as indented JSON, writes it to a temp file via `path_provider`, and
      hands it to the OS share sheet via `share_plus`. Reach it from a new
      `ExportScreen` under Settings, with a route beside the existing `/settings/backup`
      (`router.dart:302`). Include `formatVersion` in the payload.
      Acceptance: From Settings, exporting produces a JSON file whose parsed content
      round-trips through `StudyBackup.fromJson` to an equal record. A unit test asserts
      that round-trip. Export of an empty database produces a valid, empty-but-parseable
      file rather than failing.
      Result: Done, commit `4d1e5d5`. `DataExportService` (new) encodes
      `StudyBackup.toJson()` as indented JSON -- `formatVersion` included -- writes it
      to the temp directory and shares it. `ExportScreen` (new) under Settings, route
      `/settings/export` beside `/settings/backup`, `dataExportProvider` (new) reading
      `snapshotProvider.future` / `tasksProvider.future`. `test/domain/data_export_test.dart`
      (new, 6 tests) asserts the round-trip through real JSON text, the empty-database
      case, the version marker, indentation, and filename collision/portability.
      Continued `auto-claude/002-data-export`; **three things in that draft were
      rejected**: (1) its "Save to Downloads" button -- on Android
      `getDownloadsDirectory()` is `Android/data/com.ather.app/files/Download`, which is
      app-private and deleted with the app, so the label was false and the copy did not
      survive; the share sheet is the only place the student picks the destination, and
      is what this plan asked for. (2) the screen and Settings row were hardcoded
      English with a `TODO: Add localization in phase 5`, while the ARB keys the draft
      added were wired to nothing. (3) no test existed. Deps pinned exactly
      (`path_provider: 2.1.6`, `share_plus: 10.1.4`, `pdf: 3.13.0`) to match the file's
      convention for non-Firebase packages. Files: `pubspec.yaml`, `pubspec.lock`,
      `lib/domain/services/data_export_service.dart`,
      `lib/presentation/providers/export_providers.dart`,
      `lib/presentation/settings/export_screen.dart`, `lib/app/router.dart`,
      `lib/presentation/settings/settings_screen.dart`, both ARBs + generated,
      `test/domain/data_export_test.dart`, `windows/flutter/generated_plugin*`.

- [ ] **Task: Chapter report PDF export**
      Problem: `ChapterReportScreen` renders lesson-by-lesson mastery and exam history
      on screen only; the student cannot keep or send it.
      Approach: Add `PdfExportService` building the report with the `pdf` package, and
      an export action in the chapter report header. **The hard part is Arabic:** the
      `pdf` package does not shape Arabic with a default font. Embed
      `assets/fonts/ReadexPro.ttf` as a `pw.Font`, set page `textDirection` to RTL, and
      check the output visually — do not assume it rendered.
      Acceptance: Exporting a chapter with Arabic lesson names produces a PDF whose
      Arabic text is correctly shaped, joined and right-aligned — verified by opening
      the file, not by the absence of an exception. Percentages and dates match what the
      screen shows.
      Result:

- [ ] **Task: Shareable mastery progress card**
      Problem: Nothing renders a shareable summary of a student's progress.
      Approach: Build the card as a Flutter widget, rasterise it with `RepaintBoundary`
      + `toImage`, write the PNG to a temp file and share it. Entry point on the
      **dashboard** — deliberately not the analytics screen, which Batch B2 owns. Show
      overall percentage, per-subject breakdown, and the count of lessons above
      threshold.
      Acceptance: The share sheet opens with a PNG attached. The card renders correctly
      in both light and dark theme and in Arabic RTL. No student name, email or uid
      appears on the card.
      Result:

### Batch A2 — Cloud backup reliability

Files owned by this batch:

- `lib/presentation/providers/backup_providers.dart`
- `lib/data/backup/firestore_backup_repository.dart`
- `lib/domain/entities/study_backup.dart`
- `test/widget/backup_flush_test.dart`
- `test/data/backup_restore_test.dart`
- `test/domain/study_backup_test.dart`

- [ ] **Task: Sync the empty state, and checksum the payload**
      Problem: `backup_providers.dart:123` returns early when
      `snapshot.isEmpty && tasks.isEmpty`, so a student who deletes everything never
      uploads that fact. The cloud keeps the pre-delete copy, and
      `BackupSyncGate._restoreIfEmpty` restores the deleted data onto the next device.
      Separately, `upload()` stores a gzipped blob with no integrity field, so a corrupt
      payload is only discovered when `download()` fails to decode it.
      Approach: Remove the empty-state guard — the loading-state risk it was written for
      is already handled by reading `snapshotProvider.future` / `tasksProvider.future`
      at `:121-122`. Then add a checksum (e.g. SHA-256 of the uncompressed JSON) as a
      plain document field beside `formatVersion`, verified in `download()` before
      decoding, raising `BackupFailure.unreadable` on mismatch. Bump
      `StudyBackup.formatVersion` to 3.
      Acceptance: A test proves that clearing all data and flushing uploads an empty
      backup, and that a device restoring from it ends up empty rather than repopulated.
      A second test proves a tampered checksum raises `unreadable` and leaves the local
      database untouched. **A third test proves a `formatVersion: 2` document with no
      checksum still restores** — students have v2 backups in the cloud right now and
      breaking them is data loss.
      Result:

### Batch A3 — Scroll performance

Files owned by this batch:

- `lib/core/widgets/ather_scaffold.dart`
- `test/widget/layout_matrix_test.dart`

- [ ] **Task: Make AtherScreen mount its rows lazily**
      Problem: `AtherScreen` passes its `List<Widget> children` to
      `ListView(children: children)` (`ather_scaffold.dart:137-145`), which builds an
      element and render object for every row regardless of visibility. Every screen in
      the app uses it; only `tasks_screen.dart` uses a builder anywhere.
      Approach: Switch the inner `ListView` to `ListView.builder` over the same list, so
      off-screen rows are no longer mounted. Keep the existing padding, the
      `_NoScrollbar` behavior, the `underBar` inset and the `ListEntranceScope` wrapper
      exactly as they are — this is a performance change, not a layout change.
      Acceptance: `flutter test` passes with no golden or layout test changed, in
      particular `layout_matrix_test.dart` and `design_invariants_test.dart`. Entrance
      animations still play once per row per visit (the behaviour `ListEntranceScope`
      exists to guarantee). Scrolling a long Review Center list is visibly smooth.
      **If a test has to change to make this pass, the change is wrong — stop and say so.**
      Result:

---

## SESSION B

### Batch B1 — Notification scheduling

Files owned by this batch:

- `lib/domain/services/review_cycle_service.dart`
- `lib/data/notifications/review_notification_service.dart`
- `lib/presentation/providers/notification_providers.dart`
- `test/domain/review_cycle_service_test.dart`
- `test/support/fake_notifications.dart`

> Read the doc comments in `review_cycle_service.dart:44-134` before touching anything.
> The calendar-day arithmetic there is deliberate and was written to fix a real 23-hour
> bug. Do not "simplify" it back to `Duration.inDays` or `last.add(Duration(days: 30))`.

- [ ] **Task: Predictive reminder before a lesson falls due**
      Problem: `reschedule` books exactly one notification per lesson, at `dueAt`
      (`review_notification_service.dart:152-166`). The student is told a lesson decayed
      on the day it decayed, with no warning.
      Approach: Add a second scheduled moment — `dueAt` minus N days at the same
      `kReminderHour` — with its own body string and its own notification id namespace
      (the current id is the raw `lesson.id`; a second notification per lesson needs a
      collision-free scheme, e.g. an offset range). Derive it from the same calendar-day
      anchoring `dueAt` uses, so the two never disagree. Skip it when it would land in
      the past. Include both moments in the fingerprint at `:169-173` or the dedupe will
      suppress the new notification.
      Acceptance: A unit test with a pinned clock proves a lesson examined on day 0 has
      an early reminder and a due-day reminder at the expected local times, that the
      early one is skipped when already past, and that the fingerprint changes when
      either moves. The reminder body names the lesson and chapter, as the existing one
      does.
      Result:

- [ ] **Task: Cap the number of scheduled alarms**
      Problem: `reschedule` registers one alarm per active lesson with no ceiling
      (`:151-166`). Android's per-app limit is ~500; past it, registrations fail
      silently and the student loses reminders with no error anywhere. The predictive
      task above doubles the count.
      Approach: Sort the due list by `at` ascending and take the nearest N (well under
      500, and remember each lesson may now hold two alarms). The reschedule pass
      already runs on every resume and on every data change, so lessons beyond the
      window get scheduled as they come into range.
      Acceptance: A test with more lessons than the cap proves at most N alarms are
      registered and that they are the N soonest. `fake_notifications.dart` records the
      registrations to assert against.
      Result:

### Batch B2 — Analytics trends

Files owned by this batch:

- `lib/presentation/analytics/analytics_screen.dart`
- `lib/domain/services/insights_generator.dart`
- `lib/domain/services/summaries.dart`
- `test/domain/insights_generator_test.dart`

- [ ] **Task: Exam score trajectory and mastery velocity**
      Problem: `analytics_screen.dart` has no time axis. Subject bars, chapter bars,
      weakest-five and the discipline rate are all snapshots — a student cannot see
      whether they are improving.
      Approach: Compute a per-subject score-over-time series and a mastery-velocity
      figure (change per unit time) in the domain layer, then render them with
      `CustomPaint` in the same plain geometry as the existing bars. **No chart
      package** — `pubspec.yaml:22-29` records that `fl_chart` was removed deliberately
      and explains why the hand-built charts are a choice, not debt. Respect the
      existing `_subjectFilter`, and note the deliberate exception documented at
      `analytics_screen.dart:96-98`.
      Acceptance: A student with exams across several months sees a trajectory that
      matches their recorded scores. A student with fewer than two exams sees the
      existing "not enough data" state rather than an empty or misleading chart. A unit
      test covers the velocity computation including the flat and single-exam cases.
      Result:

### Batch B3 — Email verification

Files owned by this batch:

- `lib/data/auth/firebase_auth_repository.dart`
- `lib/domain/repositories/auth_repository.dart`
- `lib/presentation/auth/login_screen.dart`
- `lib/presentation/providers/auth_providers.dart`
- `test/support/fake_auth.dart`
- `test/widget/auth_test.dart`

- [ ] **Task: Verify the email address on new accounts**
      Problem: Nothing in `lib/` calls `sendEmailVerification` or reads `emailVerified`.
      A new email/password account is fully usable with an address nobody proved they
      own. (The password policy half of this backlog item is already done —
      `_minPasswordLength = 8` at `login_screen.dart:36`.)
      Approach: Send a verification email on `register`, surface the unverified state,
      and offer a resend. **Do not gate the app behind verification.** The auth gate
      stands in front of everything, the database is local, and locking out a student
      who cannot reach their inbox costs them their exam history. Prefer a dismissible
      banner and a Settings entry over a blocking screen. Extend `AuthRepository` rather
      than reaching for `FirebaseAuth` from the UI — `firebase_auth_repository.dart` is
      the only file that may import it.
      Acceptance: Registering sends a verification email and the UI says so. The student
      can still use the entire app unverified. Resend works and is rate-limit-tolerant.
      Google sign-in accounts, which arrive verified, show no prompt. `auth_test.dart`
      covers verified, unverified and Google paths via `fake_auth.dart`.
      Result:

### Batch B4 — Curriculum templates

Files owned by this batch:

- `lib/domain/services/curriculum_templates.dart` *(new)*
- `lib/presentation/settings/subjects_screen.dart`
- `lib/domain/repositories/study_repository.dart`
- `lib/data/repositories/drift_study_repository.dart`
- `test/data/drift_study_repository_test.dart`

- [ ] **Task: Optional pre-loaded chapter templates**
      Problem: `SubjectsScreen` (`settings/subjects_screen.dart:45`) only adds one
      subject at a time, and `_add` at `:96` takes a name and nothing else. A new
      student types out the whole Thanaweya Amma structure by hand before the app can
      measure anything.
      Approach: Declare the four subjects' standard chapter structure as data in
      `curriculum_templates.dart` (Arabic names — this is student-facing content, so it
      belongs in the ARB or in a reviewed data file, not in ad-hoc string literals). Add
      a bulk-insert method to `StudyRepository` and its Drift implementation, in one
      transaction. Offer it as an **opt-in** action on the subjects screen.
      Acceptance: Applying a template creates the subject with its chapters in one
      transaction; a failure part-way leaves nothing behind. Applying it twice does not
      duplicate. Existing chapters are never modified or removed. **No schema change** —
      if you find yourself editing `tables.dart`, stop: that triggers CLAUDE.md Rule 1
      and needs a migration plus a migration test.
      Result:

---

## MANUAL — DO MYSELF

### Item 11 — Stricter static analysis configuration

`analysis_options.yaml` is the stock Flutter template — `include:
package:flutter_lints/flutter.yaml` and an empty `rules:` block, no `analyzer.language`
section at all. Adding it:

```yaml
analyzer:
  language:
    strict-casts: true
    strict-raw-types: true
    strict-inference: true
```

**Caveat on the 30-minute estimate.** Writing the four lines is 30 seconds. Fixing what
they surface across 99 Dart files is not bounded, and every fix touches files owned by
the batches above. **Do this after both sessions have merged**, or the diagnostics land
in the middle of someone else's work. If you want it sooner, turn on one flag at a time
and measure the fallout before committing to the next.

### Item 5 — Release build optimization

Nothing to do. R8 was measured on 2026-08-13 and changed the APK by zero bytes; the
reasoning is recorded at `android/app/build.gradle.kts:135-160`. `fl_chart` and
`cupertino_icons` are already gone. **If you revisit R8, revisit it with a number** —
build both, compare bytes — which is exactly what that comment asks for.

---

## NO CODE NEEDED

### Item 14 — Play Store 'Measurement Companion' positioning

Listing copy: rewrite the description around "mastery measurement from real exams", in
Arabic and English, with screenshots. No file in this repository changes. Worth pairing
with `PROJECT.md`, which already states the product's one claim, and with the first-run
card copy (`firstRunBody`), which states it to the student — the listing should not
promise something different from what the app says on launch.

---

## DEFERRED

Excluded from both sessions. These are new features or architecture changes, not fixes,
and none of them is blocked on anything above.

| # | Item | Why deferred |
|---|---|---|
| 18 | Row-level Multi-device Sync | **Isolated architecture batch — never run alongside Batch A2.** Both rewrite `firestore_backup_repository.dart` and `study_backup.dart`. Replacing the single-blob model means per-entity documents, conflict resolution, and a migration for every student who already has a v2 blob in the cloud. `firestore_backup_repository.dart:22-31` argues for the current design; answer that argument before starting. Scaffolding exists on `auto-claude/009-row-level-multi-device-sync`. |
| 17 | Tutor/Parent Companion View | Needs a sharing and permissions model that does not exist, plus a Firestore rules change. A minor's exam history leaving the account is a privacy decision before it is a feature. |
| 19 | Egyptian Baccalaureate Curriculum Support | Changes the curriculum model the whole app is shaped around. Do Batch B4 (templates) first — it will show whether the structure generalises. |
| 20 | Exam Calendar & Scheduling | New feature. A calendar was deliberately removed from the dashboard in `d70a707`; re-adding one needs a design answer, not just code. |
| 7 | Interactive Onboarding Tutorial | Not deferred — **rejected.** It reverses a documented decision (`dashboard_screen.dart:108-111`). Reopen it as a design question if you disagree. |

---

## File Ownership Map

| File | Owner |
|---|---|
| `pubspec.yaml`, `pubspec.lock` | A1 |
| `lib/app/router.dart` | A1 |
| `lib/presentation/settings/settings_screen.dart` | A1 |
| `lib/presentation/settings/export_screen.dart` *(new)* | A1 |
| `lib/presentation/providers/export_providers.dart` *(new)* | A1 |
| `lib/domain/services/data_export_service.dart` *(new)* | A1 |
| `lib/domain/services/pdf_export_service.dart` *(new)* | A1 |
| `lib/presentation/chapter_report/chapter_report_screen.dart` | A1 |
| `lib/presentation/dashboard/dashboard_screen.dart` | A1 |
| `lib/presentation/share/mastery_card.dart` *(new)* | A1 |
| `test/domain/data_export_test.dart` *(new)* | A1 |
| `lib/presentation/providers/backup_providers.dart` | A2 |
| `lib/data/backup/firestore_backup_repository.dart` | A2 *(and item 18, deferred)* |
| `lib/domain/entities/study_backup.dart` | A2 *(and item 18, deferred)* |
| `test/widget/backup_flush_test.dart` | A2 |
| `test/data/backup_restore_test.dart` | A2 |
| `test/domain/study_backup_test.dart` | A2 |
| `lib/core/widgets/ather_scaffold.dart` | A3 |
| `test/widget/layout_matrix_test.dart` | A3 |
| `lib/domain/services/review_cycle_service.dart` | B1 |
| `lib/data/notifications/review_notification_service.dart` | B1 |
| `lib/presentation/providers/notification_providers.dart` | B1 |
| `test/domain/review_cycle_service_test.dart` | B1 |
| `test/support/fake_notifications.dart` | B1 |
| `lib/presentation/analytics/analytics_screen.dart` | B2 |
| `lib/domain/services/insights_generator.dart` | B2 |
| `lib/domain/services/summaries.dart` | B2 |
| `test/domain/insights_generator_test.dart` | B2 |
| `lib/data/auth/firebase_auth_repository.dart` | B3 |
| `lib/domain/repositories/auth_repository.dart` | B3 |
| `lib/presentation/auth/login_screen.dart` | B3 |
| `lib/presentation/providers/auth_providers.dart` | B3 |
| `test/support/fake_auth.dart` | B3 |
| `test/widget/auth_test.dart` | B3 |
| `lib/domain/services/curriculum_templates.dart` *(new)* | B4 |
| `lib/presentation/settings/subjects_screen.dart` | B4 |
| `lib/domain/repositories/study_repository.dart` | B4 |
| `lib/data/repositories/drift_study_repository.dart` | B4 |
| `test/data/drift_study_repository_test.dart` | B4 |
| `analysis_options.yaml` | MANUAL — after both sessions merge |
| `lib/core/l10n/app_ar.arb` | **SHARED** — append-only, marked block per batch |
| `lib/core/l10n/app_en.arb` | **SHARED** — append-only, marked block per batch |
| `lib/core/l10n/generated/*` | **SHARED** — generated, never hand-edited |

**Not owned by anyone, and not to be touched by either session:**
`lib/data/db/tables.dart`, `lib/data/db/app_database.dart`,
`android/app/build.gradle.kts`, and the `version:` line in `pubspec.yaml`. Those carry
CLAUDE.md Rule 1 obligations — schema migrations, signing, `versionCode` — that belong
to whoever cuts the release, not to a feature batch.

---

## Rules For Executing Sessions

1. Read this file and `git log --oneline -20` before writing any code. Confirm your base
   is `origin/main` @ `0314432` or later (`pubspec.yaml` ≥ `1.7.0+13`).
2. Work only on your assigned batch. Never touch a file owned by another batch. The ARB
   files are the one exception, under the append-only convention above.
3. One commit per task, message format: `[A1] <task title>`.
4. After each task: tick the checkbox and write the `Result:` line — what changed and
   which files you touched.
5. If you find a task is already done or impossible, **mark it and move on. Do not
   improvise replacement work.** Six of the twenty items in the original backlog were
   already done; finding a seventh is a likely outcome, not a failure.
6. Run `flutter analyze` before your final commit.
7. Also run `bash tool/check_invariants.sh` — it is the mechanical half of CLAUDE.md
   Rule 1 and it runs in CI anyway.
8. Commit finished work; do not leave it loose in the worktree (CLAUDE.md Rule 3).
9. **Do not build or hand over an APK.** Nothing in this plan requires one, and every
   APK carries the Rule 1 obligations in full.
