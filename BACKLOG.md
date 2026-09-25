# Backlog — what is left

Everything the owner asked for is built and released as `1.8.0+14`. What
follows is what nobody has asked for yet, and the one thing still waiting on a
hand at a keyboard.

---

## Waiting on you

~~**Deploy the site.**~~ **Done 2026-09-25** — `https://ather-49705.web.app` is live, with
`/privacy` and `/account-deletion`. The APK is *not* served from it: Firebase's free plan
refuses executable files, so the download button points at the public
`Yassen0-0/ather-releases` repository instead. `public/README.md` has the per-release
procedure — the APK goes up there twice, once under the fixed name `ather-latest.apk`.

---

## Not started, and nobody has asked

### Subject ordering

Subjects sort by `sortOrder`, assigned on creation and never changed. There is
no way to reorder them. Worth waiting until someone with six subjects is
annoyed by it.

### A recycle bin for chapters and lessons

Deleting a subject is reversible; deleting a chapter or a lesson still is not.
That is a real inconsistency — a student who learns "delete is recoverable"
from one screen can lose a chapter on another — and it was left out
deliberately: it needs `deleted_at` on two more tables and filtering in every
screen and every calculation, which is a much larger change than the subject
case was.

### Play Store submission

The app has never been submitted. What exists for it: a privacy policy URL, an
account-deletion URL, `allowBackup="false"`, and Data safety answers drafted in
`docs/`. What does not: a listing, screenshots, or a signed **App Bundle** —
Play wants `.aab`, not the `.apk` the GitHub release carries.

---

## Two decisions taken on your behalf, both reversible

### The profile is stored on the device only

A name and a school year are personal data about someone often under 18. The
account knows an email and nothing else, and the privacy policy leans on that
in the section about minors. Syncing it would change the policy, the Play Data
safety answers, and the deletion path, and would buy not retyping a name once.

To reverse: it rides in the existing `StudyBackup` blob, and the delete-account
sequence already wipes that.

### Nothing in the recycle bin expires

No thirty-day auto-purge. A bin that empties itself destroys a student's exam
history while they are not looking, which is the one thing this app promises
not to do. It empties when they empty it.
