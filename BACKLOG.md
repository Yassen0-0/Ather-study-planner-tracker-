# Backlog — what is left, and what it is waiting on

Everything from the original list is now built except the parts that need a
decision only the owner can make. This file is what remains.

[PLAN.md](PLAN.md) describes the voice and Settings work, both of which have
landed.

---

## Blocked on you — six answers, and the site can go live

Nothing below is a coding task. Each one is a fact about the world that cannot
be invented, and two of them are legally load-bearing.

| # | Question | Blocks |
|---|---|---|
| 1 | **Publisher name.** Must match the developer name on the Play listing exactly — a policy naming a different entity than the store page is a rejection reason. | the site, Play |
| 2 | **Contact email.** Goes on a public page a scraper will find, and it is the address parents will write to. Prefer a dedicated one over a personal address; it is very hard to change once it is in a published policy. | the site, Play |
| 3 | **Download URL** for the landing page's button. | the site |
| 4 | **Domain.** Firebase Hosting on the existing project needs none, and `https://ather-49705.web.app` works today. | the site |
| 5 | Profile: keep it **device-only**, or sync it to the account? Built device-only; see below. | privacy policy |
| 6 | Should a **hidden subject** ever be permanently deletable with its exams? Built as: no. See below. | nothing — it works |

Placeholders are marked in the files and there is a command to find them:

```bash
grep -rn "\[\[PUBLISHER_NAME\]\]\|\[\[CONTACT_EMAIL\]\]\|\[\[DOWNLOAD_URL\]\]" public/
```

**Do not deploy with them still in place.** A published policy that says
`[[CONTACT_EMAIL]]` is worse than none, because it is a promise of a contact
route that does not exist.

Deploying is one command and it publishes to the public internet, so it is
deliberately left for you to run:

```bash
firebase deploy --only hosting --project ather-49705
```

---

## Two decisions taken on your behalf — reverse either if you disagree

Both were made the safe way, and both are cheap to change.

### The profile is stored on the device only

A name and a school year are personal data about someone who is very often a
minor. The account currently knows one thing about a student — their email —
and the privacy policy leans on that fact in the section about under-18s.
Syncing the profile would put that data on a server, change what the policy has
to say, change the Play Data safety answers, and add a row to everything the
deletion path must reach. What it buys is not retyping a name once on a new
phone.

To reverse it: the profile rides in the existing `StudyBackup` blob rather than
a second document, and the delete-account sequence already wipes that. The
privacy policy and `public/README.md` both name this as a load-bearing claim.

### A subject with any chapter under it cannot be deleted, only hidden

`Chapters.subjectId` cascades. Deleting a subject takes every chapter, lesson
and exam beneath it, and there is no undo anywhere in this app. What a student
almost always means by "remove إنجليزي" is *stop showing it to me*, so that is
what the screen offers: hiding, which touches nothing, reverses from the same
screen, and takes the subject out of every figure rather than merely out of the
list. `deleteEmptySubject` refuses in SQL when a chapter exists, and the screen
only offers delete when the count is already zero.

To reverse it: the guard is one `if` in `DriftStudyRepository`, and it is there
rather than in the screen precisely so that removing it has to be deliberate.

---

## Not started

### A release build

Nothing here has been packaged. Before any APK leaves the machine, all four of
Rule 1's conditions have to hold, and two of them currently do not:

- `versionCode` is still **11** and has not been bumped. It must go up for every
  build handed to anyone.
- The schema moved **2 → 3** in this branch. The migration is additive and
  tested against a real v2 file on disk, but the first install that carries it
  is the one that proves it.

`bash tool/check_invariants.sh` passes on this branch today. Run it again after
the version bump, and verify the signing certificate by hand — CI has no
keystore, so that check cannot be automated:

```bash
apksigner verify --print-certs <file>.apk
```

### Merging to main

This branch carries the voice rewrite, the Settings rebuild, subjects, the
profile, and three security fixes cherry-picked from the audit branch that
`main` still does not have — the task-switcher leak, reminders posting after
sign-out, and a Firestore size rule that enforced nothing. None of it is pushed.

The audit branch has a fourth commit that is deliberately **not** for merging;
its message says so. It answers the Auto Backup finding by keeping backup on
with exclusions, and `main` already answers it harder with `allowBackup="false"`.

### Subject ordering

Subjects sort by `sortOrder`, which is assigned on creation and never changes.
There is no way to reorder them. Not obviously wanted yet — worth waiting until
someone with six subjects asks.
