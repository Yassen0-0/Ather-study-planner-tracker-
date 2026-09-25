# Ather — release build, 2026-09-25 · 1.10.0+18

**The release that has to be installed fresh.** The key that signed every build up to
`1.9.0+17` was lost, and this is the first build signed with its replacement. Android will not
install it over `1.9.0` — to Android it is a different publisher's app with the same name.

**Does NOT install over `1.9.0+17`.** New upload key (SHA-1 `4ea866f7…`, was `f3eaec08…`),
`versionCode` 17 → 18. The database schema does not move — it stays at version 5 — so
nothing about the data itself changes; only the road to it does:

1. Open the old version and wait until the sync card says it is saved.
2. Uninstall it.
3. Install `1.10.0+18`.
4. Sign in with the same account. The curriculum and every exam come back from the cloud.

A student who never signed in to a backup has no cloud copy to come back from. For them there
is no safe route, and they should stay on `1.9.0` until they have one.

The first fix below is what makes step 4 safe, and it is why this build could not go out
without it.

## What changed since 1.9.0+17

### A slow first restore can no longer cost you the cloud copy

On a new phone, if the automatic restore timed out and you then added anything at all — one
task, one chapter — the next backup pushed that near-empty phone over years of history in the
cloud. A phone that has never synced now checks the cloud copy before its first upload, and if
the cloud holds more chapters or exams than the phone, it holds the upload and says so on the
sync card. The restore is also retried when you come back to the app, instead of once per
launch. Saving over the cloud copy anyway is still possible — from the backup screen, and only
after it tells you what is in the cloud.

### Forgetting the app password no longer means clearing the app

With a password-only lock there was no way back in except Android's "Clear data", which deletes
the database. The lock screen now has «نسيت كلمة سر التطبيق؟»: prove it is your account
(Google, or your account password) and the lock is removed. Wrong guesses are now limited —
five free, then a wait that doubles up to fifteen minutes — and the limit survives closing the
app.

### Deleting an account works for Google accounts too

A Google account opened in an earlier session was asked for a password it does not have, and
by then the device and the cloud copy had already been wiped. The app now asks for proof of
ownership first — Google or password, whichever the account actually uses — and wipes nothing
until it has it. Backing out leaves everything as it was.

### "What do I need next time" counts the paper you just entered

After an exam the wizard tells you what the next paper needs for the lesson to cross the line.
It left the paper on screen out of its arithmetic, so on a first exam it always said 100%. A
first paper at 50% now says 79%.

# Ather — release build, 2026-08-25 · 1.9.0+17

**The release where the app stops keeping dangerous secrets.** A phone handed from one student to
another can no longer quietly upload the first student's whole record into the second student's
cloud backup; a failed restore can no longer be overwritten by an empty local copy; and the app
now says when something went wrong instead of pretending nothing did.

Installs straight over `1.8.0+16`. Same upload key, `versionCode` 16 → 17, every exam kept.
The database schema does not move in this release — it stays at version 5 — so the upgrade is a
pure code change with nothing to migrate.

## What changed since 1.8.0+16

### Handing your phone to a brother or cousin is safe now

Signing into a second account on a device that never had one recorded used to skip every safety
question: the next backup could carry the previous student's entire history into the new account's
one cloud document, where wiping the old account would leave nothing to restore. The gate now asks
based on what is actually on the device, not what a preferences file remembers.

### Backups fail loudly, recover cleanly

A failed automatic restore used to look exactly like success with an empty record — and the next
sync could then push that emptiness over the good cloud copy. Restores now land as one all-or-
nothing step, empty uploads wait until this device has actually seen the cloud, and the sync card
tells you when something failed instead of staying green while nothing happened.

### Reminders survive the cold start

Every cold start briefly cancelled all scheduled reminders against a loading placeholder before
rebuilding them; a reminder due inside that window was lost for good. The scheduler now waits for
real data first, and failures are logged instead of swallowed.

### Exam entry refuses wrong input instead of recording it

Leaving the correct-count field blank no longer records every answer as wrong. A pasted `2.5`
is rejected outright rather than silently becoming `25` (scores are whole numbers everywhere).
Names made only of invisible characters are refused like blank ones. And the Arabic plurals you
meet most — «متأخّر يوم», «بقي يومان», the comeback line on the dashboard — are now grammatically
correct at every count, including zero and the dual, in both languages.

### Deleting an account deletes the account

Delete-account and account-switch now clear every per-student trace: exam drafts, profile name,
lock settings, the works — through one shared routine instead of two hand-maintained lists that
had already drifted apart.

Plus: review-badge red is reserved for genuinely overdue decay (dark mode included), task adds
follow the day you are actually on, and dead weight left over from retired tooling is gone.

# Ather — release build, 2026-08-23 · 1.8.0+16

**The release where the app is honest from its first frame.** The tab icons are there when the
screen lights, startup runs its two errands side by side instead of in line, a pile of owed
lessons is labelled what it is — in red — and a task you gave up on can finally be recorded as
what it was instead of being deleted out of history.

Installs straight over `1.8.0+15`. Same upload key, `versionCode` 15 → 16, every exam kept.
The database takes its step to schema 5 — tasks gain one flag, default false — and the
migration was tested against real version-4 databases, with backups compatible in both
directions, so upgrading in place is exactly what it looks like.

## What changed since 1.8.0+15

### Icons from frame one

Open the app cold and the bottom bar's tabs used to arrive empty: the spring that carries each
icon in was seeded at zero on the very first frame, so every glyph sat at scale nothing until
your first tap woke the animation. They are drawn from the first frame now, in light mode and
dark alike. Nothing else about how the tabs behave has moved.

### The boot errands run together

Loading your preferences and starting Firebase used to happen back-to-back, each waiting its
turn while the app sat half-awake between them. They now run at the same time, and the app is on
its feet sooner by exactly the shorter of the two jobs. The laziness is pinned by tests, so it
cannot quietly turn back into a queue.

### Subject rows stand on their titles

The decorative glyphs beside the dashboard's subject rows are gone entirely — a deliberate
decision, not an oversight. Titles sit flush where the ornaments used to shove them aside. The
decay mark stays, because unlike the glyphs it says something: it marks a review clock that has
slipped.

### Debt looks like debt

Owed lessons were counted under «دروس متبقية» — *lessons remaining* — painted a reassuring blue,
which framed a growing debt as a tidy to-do list. It reads «دروس متراكمة» now, in the alarm red:
lessons owed accumulate whether or not you look at them, and the label should not soften that.
English had it closer all along — *Lessons owed*.

### The lock answers more than one way

You can now choose how the lock screen opens — fingerprint, password, or both — from Settings,
so a phone without a working sensor is no longer shut out of having a lock at all. Setting a
password stores only a salted hash, never the word itself, and a wrong attempt fails right there
in the sheet where you typed it. If your fingerprint already guards the app, none of that
changes for you.

### Surrender is an answer the app finally knows

Until now a task card had two endings: finished or deleted — and deleting rewrote history as if
the attempt never happened. There is a third verdict students hand down every day, and the app
now has a word for it: مستسلخة. A surrendered task takes an angry zigzag scribble across its
title and counts as a failure for the day, which is what it is. A finished task keeps its clean
straight strike and its check beside it, so the two verdicts never wear the same face.
Surrendering asks you first, buzzes exactly once when you commit, and undoes silently if you
change your mind.

# Ather — release build, 2026-08-23 · 1.8.0+15

**The release where the app starts moving like something physical.** Tabs, buttons, drags and
slides are no longer timed animations — they run on spring physics. They follow your finger,
overshoot by a hair, and settle where they belong. Change your mind halfway through a movement
and it re-aims from where it actually is, carrying the speed your finger left it with, instead
of ignoring you until a timer runs out.

Installs straight over `1.8.0+14`. Same upload key, `versionCode` 14 → 15, every exam kept.
This build also carries the database's step to schema 4 — the migration and its test rode in
with the same care as everything else, so upgrading in place is exactly what it looks like.

## What changed since 1.8.0+14

### Movement you can interrupt

This runs underneath everything below. Press a button and it dips under your touch; let go and
a spring brings it back. Drag something and release it mid-motion — it keeps going with your
finger's speed and settles naturally rather than stopping dead. Tabs, buttons, the day-picker
drag and the panels of numbers all behave this way. If your phone is set to reduce motion,
everything simply appears in its final place, as before.

### Tabs bounce; days flick

Pick a tab and its icon gives a small dip and a clean bounce on the way in — the same accent
colour and heavier stroke arriving together, as before, now with weight behind them.

On the tasks screen, the row of days now behaves like an object: drag it and it follows your
finger, pull it past either end and it resists like a rubber band. A quick flick hands you the
next or previous day; a slow drag that doesn't commit springs back home.

### The exam result lands as one beat

At the final step of recording an exam, the percentage and its mastery bar used to disagree —
the number counted up while the bar sat already full. They now fill together over the same
half-second, ending as one beat, because they measure the same thing. The readiness sentence
arrives just after, once the two have settled.

Mastering a chapter gained pacing to match: the green disc still pulses, but a ring echoes
around it, the percentage counts up alongside, and the explanatory sentence waits a moment
before appearing.

### Analytics draws itself

Open the statistics screen and the subject columns grow out of zero, one after another, their
percentages counting up beside them. Your trajectory line traces itself across the chart before
its end point appears. None of this replays while you scroll — it plays when the screen opens
or when you change the filter, then stands still.

### The mark signs itself in

On the lock screen and the sign-in screen, the Ather mark now draws itself — the ring traced
once, the accent arc swept after it — and then holds completely still. Once per appearance,
never looping.

### An empty queue earns its moment

Finish every task for today and the list marks it properly: the last row leaves and the success
card pops in, noticeably bigger than the small nudge an ordinary daily point gets. Two sizes of
moment for two sizes of occasion.

### Vibration, in four weights

The phone now answers your hand: light when you touch a control down, a small tick for choosing
a tab or a day, a firmer one when an exam is saved or a chapter is mastered, and the heaviest
one reserved for confirming a deletion — where it buzzes exactly once, at the moment you commit.

There is a switch, «الاهتزاز», in Settings. It is on by default; turn it off and all of this
goes quiet. It works independently of reduce-motion — vibration is feedback, not animation.

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
