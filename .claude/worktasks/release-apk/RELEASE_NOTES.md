# Ather — release build, 2026-08-17 · 1.7.0+12

**The release where the app stops being built for one student.** Subjects are yours to add,
archive and delete; there is a recycle bin behind the delete; you have a profile; Settings is a
settings screen rather than a pile of cards; and the whole app speaks Arabic in one register
instead of two.

Installs straight over `1.6.0+11`. Same upload key, `versionCode` 11 → 12, every exam kept.
The database moves from schema 2 to 3 — additive only, tested against a real version-2 file.

## What changed since 1.6.0+11

### Subjects are yours now

Ather shipped with four because it was written for one student sitting علمي علوم. Add your own
from the **+** beside «المواد» on the home screen, or from Settings.

Two ways to put one away, and they mean different things:

- **أرشفة** — you are done with it. It leaves the screen and stops counting toward your mastery,
  and everything inside it is kept.
- **حذف** — you did not mean to have it. It goes to **سلة المحذوفات** in Settings, whole, and
  comes back from there exactly as it was.

Nothing in the bin expires or disappears on its own. The only thing that ever destroys a subject
and its exams is «حذف نهائي» from inside the bin, and that asks you first — naming how many
chapters and how many exams it is about to take.

### A subject you put away stops following you around

Archiving used to hide a subject's numbers and nothing else: it kept sending review reminders,
kept appearing in the review queue, and kept producing notes about itself. Reminders carry a
lesson's name, and they land on your lock screen. Fixed.

### Your name, on your phone

Settings → your account opens a profile: a name and a school year. The home screen greets you by
name instead of naming the day.

**It never leaves your phone.** Not the cloud backup, not our servers, nowhere. Your email address
is still the only thing the account knows about you, which is what lets the privacy policy say so
plainly — and that sentence matters most for students under 18.

### Settings looks like settings

It was nine floating cards of nine different heights, with four large filled buttons inside the
list — two of them red. It is now grouped rows, one line each, with the current answer on the
right and anything longer on a screen of its own. Nothing about what the destructive actions do
has changed; they are simply no longer the loudest thing on the page.

### The app speaks one Arabic

Everything moved from Egyptian colloquial to simple Modern Standard Arabic. Separately from that,
eight lines were **deleted rather than translated** — the ones explaining a control to someone
looking straight at it. A switch labelled «قفل بالبصمة» does not need a sentence under it saying
it asks for a fingerprint.

The one line that was carrying real information kept its job and lost its words: each exam in a
lesson's history now ends in a small × instead of a sentence telling you that tapping removes it.

### It is faster and wakes your phone less

Three things on the hot path, all measured rather than guessed:

- **Saving an exam rebuilt the whole app three times.** Six database streams feed one snapshot,
  and one write touches three of them, so it rebuilt once per table — each time recomputing every
  number in your record and redrawing the blurred tab bar. Now once per write.
- **The tab bar redrew on every change anywhere**, to read one number that changes about twice a
  week. It is the most expensive thing the app draws.
- **Every reminder was cancelled and rescheduled after every edit**, and again every time you
  reopened the app — eighty round-trips to the system, and eighty alarms re-registered, to arrive
  at the schedule that was already there. It now checks whether anything actually moved first.

### Security fixes

- The **task switcher** showed your dashboard — mastery number, subject list — with no fingerprint
  asked for, standing in front of the lock screen meant to hide it.
- **Reminders kept arriving after signing out**, carrying the previous student's lesson names.
- The **cloud backup size limit enforced nothing** on the server, and the backup document could
  never be deleted — which is the operation "erase my data" is made of.

### Also

- A website, a published privacy policy, and a page for requesting account deletion.
- The privacy policy said the deletion order backwards in both languages. It deletes what is on
  the phone first, then the cloud copy, then the account.
