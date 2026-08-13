# Ather — release build, 2026-08-11 · 1.2.0+6

**A minor-version bump, because five things that were silently broken now work.** No visual
change: this sits on top of the 1.1.0+4 visual refresh and does not touch a colour, a layout, a
glyph or a piece of copy that a student had already learned. What changed is behaviour that had
never behaved.

## What was broken, and how it looked from the outside

Every one of these failed **silently** — no crash, no error, nothing on screen. That is why none
of them had been reported.

- **Review reminders had never fired. Not once, in the app's history.** Two independent causes:
  nothing ever asked for the notification permission, so the flag guarding the scheduler stayed
  false and every pass cancelled the schedule and booked nothing; and the plugin's receivers were
  never declared in the manifest, so even a booked alarm would have shown nothing. Both fixed,
  and the whole cycle has now been watched end to end on a real phone — permission prompt, alarm
  booked at thirty days, reminder posted, and tapping it opening the lesson it names.
- **A second account on the same phone inherited the first student's curriculum** — and the
  backup then mirrored it into the second student's cloud document. The device is now wiped when
  a *different* uid signs in, and never on sign-out, so signing out and back in still loses
  nothing.
- **The exam wizard hung for good on a failed save.** No catch, and the in-flight flag was never
  cleared, so one failure left a fully entered paper behind a button that ignored every tap after.
- **A mistyped exam could not be corrected.** The delete existed in the data layer and no screen
  called it. It is now on the lesson's history card — and it moves the review clock back to the
  newest surviving evidence, which the naive version would have left pointing at a deleted exam.
- **Every other write was fire-and-forget** — ticking a step, saving homework, mastering a
  chapter, any task edit. A failure changed nothing and said nothing.

## Also in this build

- **Faster where it was quietly expensive**: the clock woke sixty times an hour and recomputed
  every summary for the whole curriculum; each lesson's mastery was derived four times per
  dashboard build; list rows replayed their entrance on every scroll; and the backup's gzip ran
  on the UI thread while the student was using the app.
- **Accessibility**: the app had two `Semantics` widgets in total. Every icon-only control now
  has a name, tap targets are 48dp (the drawn sizes are unchanged), and two colours that failed
  contrast outright — the brand green as *text* at 2.2:1, and the "no data" grey at 1.7:1 — were
  fixed without touching the fills.
- **A guard against the design being reverted a third time.** `test/design_invariants_test.dart`
  fails if the brand blue disappears or the removed "+" comes back. See PROJECT.md's standing
  rule.

## Upgrading

**Installs straight over 1.1.0+4.** Same upload key, `versionCode` 4 → 6, data kept. Nobody
uninstalls anything.

`+5` was never built — the notes below were written for it, then the build number was bumped
again before anything left the machine. So `1.1.0+4` is the newest build that exists on anyone's
phone, and this one goes straight over it. Everything described above is in this artefact; the
only change between `+5` and `+6` is the build number itself.

The old warning about the two debug-signed **profile** builds (`1.1.0+2`, `1.1.0+3`) still
applies if anyone is somehow still on one: those carry a different signing identity, so Android
refuses this release over them with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`. Save to the cloud from
Settings → النسخة السحابية before uninstalling, and sign back in to restore.

## The build

One **universal** APK, carrying all three ABIs, so a single file installs on any phone without
anyone having to know which one they need.

| | |
|---|---|
| File | `Ather-1.2.0-build6-universal.apk` |
| Size | 61.9 MB (64,932,945 bytes) |
| SHA-256 | `cf2245c5ab1617f677699316bc31513d490c03e79504a29890a7a883bdc7b4a3` |
| ABIs | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| `minSdkVersion` | 24 (Android 7.0) |
| `targetSdkVersion` | 36 |

Rebuild it with:

```bash
flutter build apk --release
```

Splitting per ABI instead gets arm64 down to roughly a third of the size, at the cost of having
to hand each person the right file:

```bash
flutter build apk --release --split-per-abi
```

## Signing

Signed with the upload key at `C:\Users\<you>\keys\ather-upload.jks`, credentials in the
git-ignored `android/key.properties`. The release config **refuses to build** rather than falling
back to the debug key, which is how the profile builds above went out wrong. Verify what you
actually produced:

```
Signer #1 certificate DN: CN=yassen, OU=per, O=ather, L=giza, ST=giza, C=eg
Signer #1 certificate SHA-1 digest: f3eaec08a58d41d334d22abade33b1e89577623e
```

Not `CN=Android Debug`. Procedure and the two ways this can go permanently wrong: RELEASING.md.
