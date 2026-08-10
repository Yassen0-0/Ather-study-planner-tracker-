# Working on Ather

[PROJECT.md](PROJECT.md) is the design source of truth. Read it before changing anything the
student sees. [RELEASING.md](RELEASING.md) covers builds and signing.

---

## Rule 1 — every APK must upgrade the one before it

**A student must never have to uninstall Ather to get a newer build.** Not once, not "just this
release", not "it's only a test build". Assume every APK that leaves this repository is already
on a real phone, holding a real student's exam history.

This is not a packaging preference. Ather's data lives in a local SQLite file that belongs to the
installed app. Uninstalling deletes it. There is no server copy to fall back on — cloud backup is
opt-in and most students will not have turned it on. So "uninstall the old one first" is not an
inconvenient install step; it is **telling a student to throw away every exam they ever recorded.**

Four things break an in-place upgrade. All four are your responsibility on any build you produce:

1. **`versionCode` must go up.** It comes from the `+N` build number in
   [pubspec.yaml](pubspec.yaml) (`version: 1.0.0+1`). Android refuses to install an APK whose
   `versionCode` is not higher than the installed one. **Bump `+N` on every build you hand to
   anyone.** Bump the `1.0.0` part too when the change is worth a name.
2. **The signing key must be the same one.** Android identifies an app by
   *applicationId + signing certificate*. A different key is a different app as far as the system
   is concerned, and it refuses the upgrade outright. This is the entire reason
   `android/app/build.gradle.kts` refuses to sign a release with the debug key rather than
   quietly falling back to it.
3. **`applicationId` must stay `com.ather.app`.** Changing it ships a second app that sits beside
   the first with none of its data.
4. **The new build must open the old database.** `schemaVersion` in
   [lib/data/db/app_database.dart](lib/data/db/app_database.dart) and its `onUpgrade` migration
   move together. If you add or change a table, write the migration and a test that opens a
   database at the previous version. Never "fix" a schema mismatch by deleting or recreating the
   file — an upgrade that wipes the data is the same harm as an uninstall, just quieter.

**Debug and profile builds are signed with the debug key**, so they are a separate identity from
the release line: a profile APK cannot upgrade a release install, and a release cannot upgrade a
profile one. That is fine for handing a build around to try, but say so plainly when you hand one
over — the person receiving it needs to know it is a side-load and not an update.

**`android/key.properties` does not follow a new worktree.** It is git-ignored, so it exists only
in the working directory where it was created, and a fresh worktree looks exactly like a machine
with no signing key at all. It is not. Before concluding that a release cannot be signed, check
the other worktrees:

```bash
ls .claude/worktrees/*/android/key.properties /c/Users/*/keys/*.jks 2>/dev/null
```

If a copy exists, copy it in — do not read its contents, it holds passwords — and build the
release properly. Two profile APKs went out debug-signed because this check was not done.

Before producing any APK, state which of the four you checked. If you cannot satisfy all four —
most often because a release build needs a keystore you do not have — **build nothing and say
why.** Do not generate a signing key to get past it: the key is the app's identity on Play, and
a wrong or lost one means the app can never be updated again. A human creates it, once.

---

## Rule 2 — find the current design before you build on it

This repository is worked on through **git worktrees**, several at once, and work in them is
often left uncommitted for a long time. `master` is therefore **not** reliably the newest design.
A worktree branched from `master` can be months behind what the app actually looks like, and
nothing inside that worktree will tell you so.

That has already cost a build. The icon-motion work was written against a `master` that predated
the visual refresh — no brand blue, and a `+` button in the tab bar that the refresh had removed.
The refresh was finished, correct, and sitting as 62 uncommitted files in another worktree, so it
was invisible to git and to the agent. An APK went out with the old design.

**Before writing code, and again before building anything:**

```bash
git worktree list
for w in .claude/worktrees/*/; do echo "== $w"; git -C "$w" status --short -- lib | head; done
```

If another worktree has uncommitted changes under `lib/`, **assume it is newer than yours** and
stop. Ask which one is current. Do not merge it in silently and do not build past it.

**When a design document disagrees with the code in front of you, doubt the code first.** A
handoff or spec is usually written against the newest build; your checkout may not be it. The
handoff said plainly that the `+` had been removed from the tab bar, the code still had one, and
treating the code as the truth is precisely how the stale APK got built. A contradiction like
that is a signal that you are on the wrong base — not a mistake in the document.

---

## Rule 3 — finished work gets committed

**Do not leave completed work as uncommitted files in a worktree.** Commit it on that worktree's
branch as soon as it stands on its own.

Uncommitted work is invisible work. It cannot be found by anyone else, cannot be branched from,
cannot be reviewed, cannot be built, and is one `git checkout` or one crash away from being gone.
Every problem in Rule 2 came from a finished, good piece of work that existed only as loose files
in a directory. The commit is what makes work exist.
