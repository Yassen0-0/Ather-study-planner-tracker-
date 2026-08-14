# Ather — release build, 2026-08-13 · 1.3.0+7

**A third of the download, and three silent bugs that could each cost a student their work.**
No new features. The minor version moves because this build stops supporting 32-bit phones,
which is a decision about who can install it rather than about what it does.

## The size

| | |
|---|---|
| `1.2.0+6`, all three ABIs | 61.9 MB |
| **`1.3.0+7`, arm64 only** | **22.9 MB** |

Two thirds of the old download was `armeabi-v7a` for 32-bit phones and `x86_64`, which only ever
runs on an emulator. Every student was carrying both. On mobile data that is the whole first
impression of the app.

**A 32-bit phone can no longer install Ather.** It is refused cleanly at install time, so a
student on one keeps `1.2.0+6` and every exam in it, and simply receives no further updates.
That is the accepted trade — "no new features" is survivable, "no app" is not, and the build was
deliberately shaped so they get the first and never the second. See RELEASING.md for the
half-ABI trap that would have caused the second, and how it is now checked.

## What was broken

Each of these failed **silently**, which is why none had been reported.

- **The cloud backup could overwrite your tasks with nothing.** The upload read the curriculum
  and the task list from two independent streams and did not wait for both. If one had loaded and
  the other had not — closing the app shortly after opening it was enough — it uploaded the half
  it could see over the half it could not, and the cloud copy is the only one that survives a lost
  phone. It now waits for both. Nothing in the test suite had ever exercised the upload path; it
  has four cases now.
- **A second account could inherit the first student's curriculum.** The wipe that keeps two
  students apart on one phone triggered on "somebody signed in where nobody was", which is only
  the same thing as "a different account is here" if every switch passes through signed-out. It
  is now keyed on the account id itself.
- **The review clock could be a day behind.** It counted 24-hour periods while everything reading
  it updates at midnight, so a lesson examined at 15:00 fell due at 15:00 thirty days later and
  the app could not notice until the following midnight. It counts calendar days now, which is
  what "30 days" meant all along.

## Also in this build

- **The inactive tab labels are readable.** Measured rather than assumed: over an analytics
  column the label was at 1.90:1, well under any threshold. The bar's tint and the label tone
  moved together — neither alone could fix it — and a test now fails the build if any surface
  that can scroll under the tab bar drops below 3:1. The input hints and the wizard's fine print
  get the same improvement. **This is the one thing here a student can see.**
- **The release rules are enforced by a script, not by memory.** `tool/check_invariants.sh` runs
  in CI and checks the things that break an in-place upgrade.

## Upgrading

**Installs straight over `1.2.0+6` on any 64-bit phone.** Same upload key, `versionCode` 6 → 7,
data kept. Nobody uninstalls anything.

Unchanged from before: a phone still carrying one of the old **debug-signed** builds (the `1.0.0`
test APKs, or the `1.1.0+2` / `1.1.0+3` profile builds) will refuse this with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`, because those carry a different signing identity. Save from
**Settings → النسخة السحابية** before uninstalling, and sign back in to restore.

## The build

| | |
|---|---|
| File | `Ather-1.3.0-build7-arm64.apk` |
| Size | 22.9 MB (24,060,598 bytes) |
| SHA-256 | `b3d4d17d2d5314d061f3da8fd4b3c4f079aeae6b921fc8eb419c88d9b51bd1bb` |
| ABI | `arm64-v8a` only |
| `minSdkVersion` | 24 (Android 7.0) |
| `targetSdkVersion` | 36 |

```bash
flutter build apk --release --target-platform android-arm64
```

`--target-platform`, not `--split-per-abi`: splitting adds an ABI offset to the build number
(arm64 would ship as `2007`), and a phone on that line could never be upgraded by a Play release.
RELEASING.md §4.

## Signing

Signed with the upload key at `C:\Users\<you>\keys\ather-upload.jks`, credentials in the
git-ignored `android/key.properties`. The release config **refuses to build** rather than falling
back to the debug key. Verify what you actually produced:

```
Signer #1 certificate DN: CN=yassen, OU=per, O=ather, L=giza, ST=giza, C=eg
Signer #1 certificate SHA-1 digest: f3eaec08a58d41d334d22abade33b1e89577623e
```

Not `CN=Android Debug`. Procedure and the two ways this can go permanently wrong: RELEASING.md.
