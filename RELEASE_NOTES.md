# Ather — release build, 2026-08-14 · 1.3.1+8

**A point release on 1.3.0.** Same size, same shape, same 64-bit-only reach. What changed is that
the reminder and the lesson screen now say the same thing, and the security rule protecting every
student's backup is in this repository instead of only in a web console.

If you already have `1.3.0+7`, this is a small upgrade. If you are on `1.2.0+6` or older, read the
1.3.0 section further down as well — that is the build that dropped 32-bit phones.

## What changed since 1.3.0+7

- **A reminder no longer arrives before the app agrees.** The notification was scheduled to the
  hour (`last exam + 30 days`) while the lesson screen counts whole days, so an exam recorded at
  23:00 produced a reminder at 23:00 on day 30 while the screen still read **"باقي ١ يوم"** until
  the next midnight. Tapping the reminder landed you on a screen contradicting it — and the gap
  was widest for students who study in the evening, which is most of them. The reminder now lands
  on the day the screen turns, at 18:00.
- **"تسيب الامتحان؟" now says it cannot be undone.** Every other irreversible confirmation in the
  app ends with *"مش هينفع ترجع فيها."* — deleting a chapter, a lesson, an exam. The one dialog
  guarding a fully typed exam paper did not.
- **Two unused dependencies removed**, including a chart library the analytics screen deliberately
  does not use.

Nothing above changes a layout, a colour or a flow.

## Not in the APK, but shipped with it

**The Firestore security rules are now in version control** (`firestore.rules`). Every student's
exam history lives at `users/{uid}/backup/snapshot`, and what stops one student reading another's
was configuration that existed only inside the Firebase console — unreadable from the repository,
unreviewable in a pull request, unrestorable from git.

**Committing them does not deploy them.** See RELEASING.md §4a: the console is still whatever it
already was, and a project left in *test mode* grants every signed-in caller access to every
document until an expiry date, after which all backups start failing with nothing in the code to
explain it. This is the one failure here that is invisible from inside the app, which works
identically either way.

## Carried over from 1.3.0 — read this if you are upgrading from 1.2.0 or older

**A third of the download**: 61.9 MB → **22.9 MB**, by shipping 64-bit ARM only. **A 32-bit phone
can no longer install Ather.** It is refused cleanly at install time, so a student on one keeps
what they have and every exam in it, and simply receives no further updates.

And three silent bugs, each of which could cost a student work:

- **The cloud backup could overwrite your tasks with nothing** — the upload did not wait for both
  halves of the local database to load, and uploaded the half it could see over the half it could
  not.
- **A second account could inherit the first student's curriculum** — the wipe triggered on
  "somebody signed in where nobody was" rather than on the account actually changing.
- **The review clock could be a day behind** — it counted 24-hour periods while the app updates at
  midnight.

## Upgrading

**Installs straight over `1.3.0+7` or `1.2.0+6` on any 64-bit phone.** Same upload key,
`versionCode` 7 → 8, data kept. Nobody uninstalls anything.

A phone still carrying an old **debug-signed** build (the `1.0.0` test APKs, or the `1.1.0+2` /
`1.1.0+3` profile builds) will refuse this with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` — different
signing identity. Save from **Settings → النسخة السحابية** first, then sign back in afterwards.

## The build

| | |
|---|---|
| File | `Ather-1.3.1-build8-arm64.apk` |
| Size | 22.9 MB (24,059,384 bytes) |
| SHA-256 | `e22d6dbdae6fb7d3292a51d502a58eea8ef654828c32e0f90d9ca09adf8e61a6` |
| ABI | `arm64-v8a` only |
| `minSdkVersion` | 24 (Android 7.0) |
| `targetSdkVersion` | 36 |

```bash
flutter build apk --release --target-platform android-arm64
```

`--target-platform`, not `--split-per-abi`: splitting adds an ABI offset to the build number
(arm64 would ship as `2008`), and a phone on that line could never be upgraded by a Play release.
RELEASING.md §4.

## Signing

```
Signer #1 certificate DN: CN=yassen, OU=per, O=ather, L=giza, ST=giza, C=eg
Signer #1 certificate SHA-1 digest: f3eaec08a58d41d334d22abade33b1e89577623e
```

Not `CN=Android Debug`. The release config refuses to build rather than falling back to the debug
key. Procedure and the two ways this can go permanently wrong: RELEASING.md.
