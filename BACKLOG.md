# Backlog — agreed, not built

Everything discussed and not yet done. [PLAN.md](PLAN.md) holds the two pieces
being built now (the app's voice, and the Settings screen); when those land they
leave this file behind them.

Ordered by what should happen first. Each entry says what it actually costs,
because two of these are much larger than they sound.

---

## 1. Merge the security fixes that main does not have

**Smallest item here, and the most urgent, because it blocks a Play release.**

The worktree `ather-android-security-audit-e46c18` now has four commits on
`claude/ather-android-security-audit-e46c18`. Three of them fix things that are
**still live on `main`**:

- **The task-switcher leak.** Android snapshots the last drawn frame; that frame
  is the dashboard. Recents showed a locked student's mastery number and subject
  list with no fingerprint asked for. Fixed with `FLAG_SECURE`, following the
  lock switch rather than always on.
- **Reminders after sign-out.** A reminder's body is a lesson name and its
  chapter's. Signing out leaves the database in place, so the scheduler kept
  rebuilding and posting the *previous* student's lesson names to the lock
  screen of a phone they no longer use.
- **The Firestore backup size rule enforced nothing.** It called `size()` on a
  document, which counts fields — four of them — so `4 < 1048576` was true for
  every write ever made. A 1,000,000-byte payload was accepted against the
  emulator. Worse, `allow write` covers delete and the condition touched
  `request.resource`, which does not exist on a delete — so the cloud backup
  document **could never be deleted**, which is the operation "erase my data" is
  made of.

The fourth commit is deliberately **not** for merging: it answers the Auto
Backup finding by keeping backup on with exclusions, and `main` already answers
it harder with `allowBackup="false"`. Its commit message says so.

Cost: a merge and a test run. The branch is behind `main`, so rebase or merge
`main` into it first. Nothing here is pushed yet.

---

## 2. Subjects the student adds, instead of four fixed ones

The app ships four subjects (`biology`, `physics`, `chemistry`, `english`)
because it was built for one student. They are an enum, not data.

### What it actually touches

Fewer files than expected — `SubjectCode` appears in nine, three of them tests:

| File | What changes |
|---|---|
| `lib/domain/entities/subject.dart` | The enum stops being the identity. `Subject` gains a name and an icon it currently refuses to carry. |
| `lib/data/db/tables.dart` | `Subjects` gains `name` and `icon`; `id` stops being hand-assigned 1–4. |
| `lib/data/db/app_database.dart` | `schemaVersion` 2 → 3, plus the migration. See the trap below. |
| `lib/data/repositories/drift_study_repository.dart` | Create / rename / delete / reorder. |
| `lib/presentation/common/subject_presentation.dart` | The glyph and label switches become lookups. |
| `lib/domain/entities/study_backup.dart` | The backup format has to carry custom subjects, or a restore onto a new phone loses them. |

Plus a new screen for adding and editing, and an entry point for it — Settings
is the natural home, which is one reason Settings is being rebuilt first.

### The trap

`_seedSubjects()` runs in `beforeOpen`, on **every launch**, and re-inserts any
missing subject row. It is written that way on purpose today ("self-healing if a
row is ever lost"). The moment subjects are deletable, that same line
**resurrects every subject the student deleted, on the next launch.** This is the
single most likely way to get this feature wrong.

### The decisions needed before it can be built

- Does a fresh install start with the four seeded, or with an empty list?
- Icon from a fixed set, or a letter/emoji?
- **Deleting a subject deletes its history.** `Chapters.subjectId` already
  cascades, so a delete takes every chapter, lesson and exam under it. Is that
  the intended behaviour, or should a subject be archivable instead? An archive
  is more work but it is the answer that cannot destroy two years of exams by
  one tap plus one confirmation.

### The rule this must not break

Rule 1 in [CLAUDE.md](CLAUDE.md). `schemaVersion` and the `onUpgrade` migration
move together, the migration is additive, and a test must open a database at
version 2 and confirm the student's existing subjects and every chapter under
them survive. `tool/check_invariants.sh` fails the build if `schemaVersion`
moves without a migration test moving with it — let it.

---

## 3. A student profile

Name, avatar or initial, school year, and possibly a target percentage. Replaces
the generic greeting on the dashboard, and gives the new Settings screen the
identity block at the top of the page that its layout is already designed around.

**Open question, and it changes more than it looks:** is the profile stored on
the device only, or attached to the account and synced?

- **Device only** — nothing new leaves the phone, the privacy policy barely
  changes, and the profile does not follow a student to a new phone.
- **Synced** — it follows the account, but a name and a school year are personal
  data about a minor stored on a server, and the privacy policy, the Play Data
  safety form, and the deletion path all have to say so. The account currently
  holds an email and nothing else, which is a genuinely strong position to be
  giving up.

If it syncs, it rides in the existing `StudyBackup` blob rather than a second
document, and the delete-account sequence already wipes that.

---

## 4. The privacy policy, as a public document

The in-app policy already exists (`lib/presentation/privacy/privacy_screen.dart`
and the `privacy*` ARB keys) and it is honest and specific. What is missing is a
**published document at a stable URL**, which is a hard Play requirement, not a
nicety.

Play also requires, for any app with accounts, a **web page where a user can
request account deletion** — separate from the in-app button, reachable without
installing the app.

It must be written from what the app actually does, and that has to be checked
against the code at the time of writing rather than assumed. Today that is: a
local SQLite database, an opt-in account, an account-keyed Firestore backup, no
ads, no analytics, no third-party tracking. Items 2 and 3 can both change it, so
this is written *after* them.

Still needed from the user before it can be written:

- Published under a personal name or a company?
- A contact email that will be read.

---

## 5. The website

One page, plus the two pages Play needs to find:

- The landing page — what Ather is, what it looks like, a download link.
- `/privacy` — item 4.
- `/account-deletion` — the deletion request page.
- A contact email, on all three.

Decisions needed: domain and hosting. `firebase.json` already exists in the
repository, so Firebase Hosting is the path of least resistance and costs
nothing extra — but a note in the release history says it was once pointed at a
dead app, so whatever it holds now needs checking before anything is deployed
from it.

---

## Open questions, collected

| # | Question | Blocks |
|---|---|---|
| 1 | Fresh install: four subjects seeded, or an empty list? | 2 |
| 2 | Deleting a subject — destroy its exams, or archive it? | 2 |
| 3 | Subject icons: fixed set, or a letter/emoji? | 2 |
| 4 | Profile: device-only, or synced to the account? | 3, 4 |
| 5 | Publisher name and contact email | 4, 5 |
| 6 | Domain and hosting | 5 |
