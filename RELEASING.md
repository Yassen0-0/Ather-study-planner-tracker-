# Releasing Ather

Everything needed to produce a distributable build, and the two things that can
permanently break the app if they are got wrong.

---

## 1. Where the signing key lives

| Thing | Location | In git? |
|---|---|---|
| The keystore | `C:\Users\<you>\keys\ather-upload.jks` — **outside this repository** | **No** |
| Its credentials | `android/key.properties` | **No** — `.gitignore`d |
| The template | [`android/key.properties.example`](android/key.properties.example) | Yes |
| The signing wiring | [`android/app/build.gradle.kts`](android/app/build.gradle.kts) | Yes |

**The passwords are deliberately not written down in this repository, and they
must not be.** Not because of policy — because of what the key *is*:

- Anyone holding the keystore and its password can publish an update to Ather
  that Android and Google Play will accept as genuine. It is the app's identity,
  not a config value.
- Git does not forget. A password committed once stays in the history of every
  clone, and the only real remediation is generating a new key — which for a
  published app means Play support, or a new listing.

Keep the keystore and its passwords in a password manager, and keep a **backup
of the `.jks` file somewhere that is not this machine**. If it is lost, Google
Play will not accept a build signed with anything else. The app can never be
updated again — every student would have to uninstall and reinstall, losing the
local database with it.

---

## 2. Creating the key (once, by a human)

```bash
mkdir -p /c/Users/<you>/keys
keytool -genkey -v -keystore /c/Users/<you>/keys/ather-upload.jks \
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias ather
```

It asks for a store password, your real name and organisation details (these go
into the certificate), and then a key password — pressing Enter reuses the store
password, which is fine.

Then copy the template and fill it in:

```bash
cp android/key.properties.example android/key.properties
```

```properties
storeFile=C:\\Users\\<you>\\keys\\ather-upload.jks
storePassword=<the store password>
keyAlias=ather
keyPassword=<the key password>
```

Backslashes are doubled — it is a Java properties file.

---

## 3. Register the key's fingerprint with Firebase

**Google Sign-In will fail for every real user if this is skipped**, while
continuing to work perfectly in development. Google ties sign-in to the signing
certificate, and the release key's fingerprint is different from the debug key's.

```bash
keytool -list -v -alias ather -keystore /c/Users/<you>/keys/ather-upload.jks | grep SHA
```

Firebase console → project `ather-49705` → ⚙️ Project settings → under
`com.ather.app` → **Add fingerprint** → paste SHA-1 (and SHA-256) → then
re-download `google-services.json` into `android/app/`.

The debug key's SHA-1 is already registered, which is why it works locally.

---

## 4. Building

```bash
flutter build appbundle                              # Google Play wants this
flutter build apk --release --target-platform android-arm64   # what we hand out
```

**64-bit ARM only, decided 2026-08-13.** 32-bit phones are not supported. The universal APK was
61.9 MB against **22.9 MB** for arm64 alone, and the other two thirds were `armeabi-v7a` for
phones we no longer serve plus `x86_64` that only ever runs on an emulator. These students are on
mobile data.

Two things about that command are load-bearing:

- **`--target-platform`, not `--split-per-abi`.** Splitting makes Flutter add an ABI offset to the
  build number, so arm64 would ship as `2007` instead of `7` — see below. `--target-platform`
  produces one APK at the plain number.
- **`ndk { abiFilters }` in `build.gradle.kts` does not do this.** It is the obvious place, it is
  accepted, and it is ignored: the Flutter Gradle plugin packages its own `lib/<abi>/` payload
  after AGP's filter has run. An APK built with the filter set was still 61.9 MB.

There is a `packaging { jniLibs { excludes } }` block in `android/app/build.gradle.kts` gated to
release builds, and it is not decoration. `--target-platform` drops *Flutter's* engine for the
other ABIs and stops there; plugin AARs still contribute their own `.so` for every ABI they ship.
The first arm64 build came out with `lib/armeabi-v7a/libdartjni.so` and **no `libflutter.so` next
to it** — which Android reads as "this ABI is supported", so a 32-bit phone would have installed
the update over a working app and then died on launch with no engine to load. A clean
`INSTALL_FAILED_NO_MATCHING_ABIS` leaves the student on the build they already had; a half-ABI
APK takes their working app away and leaves the database stranded behind it.

`tool/check_invariants.sh` now fails if any packaged ABI lacks an engine.

### What dropping 32-bit costs

A student on a 32-bit phone running `1.2.0+6` **stays on `1.2.0+6` forever.** The install is
refused cleanly, so they keep the app and every exam in it — they simply receive no further
updates. That is the accepted trade, not an accident: it is the difference between "no new
features" and "no app", and only the first one is survivable.

### `--split-per-abi` moves the versionCode line, permanently

**Flutter does not use `pubspec.yaml`'s build number as-is when it splits.** It adds an ABI
offset, so a single `version: 1.2.0+6` produces three APKs with three different `versionCode`s:

| APK | offset | `versionCode` at `+6` |
|---|---|---|
| `app-armeabi-v7a-release.apk` | +1000 | 1006 |
| `app-arm64-v8a-release.apk` | +2000 | **2006** |
| `app-x86_64-release.apk` | +4000 | 4006 |
| universal (`--release`, no split) | none | **6** |

This is visible in the old builds in `dist/_quarantine-do-not-distribute/`: the same `1.0.0+1`
tree produced a universal APK at `1`, an armeabi one at `1001` and an arm64 one at `2001`. That
`2001` is not a mistake anyone made — it is this offset.

The consequence is one-way and worth stating plainly, because Rule 1 turns on it:

- A phone on the **universal** line (`6`) accepts a split arm64 APK (`2006`) — the number goes up.
- A phone on the **split arm64** line (`2006`) can never go back to a universal APK (`6`), and
  **cannot be upgraded by a Play release either**, because an App Bundle carries the plain
  `versionCode` from `pubspec.yaml`. Play would be shipping `7`, `8`, `9` against a phone holding
  `2006`, and Android refuses every one of them.

So the choice is not "which is smaller". It is **which line every future update has to live on**,
and switching costs a student their database.

**This is why the arm64 build above uses `--target-platform` and not `--split-per-abi`.** It gets
the same ~23 MB and keeps `versionCode` at the plain `7`, so the side-loaded line and the eventual
Play line remain one sequence. Had we split, arm64 would have shipped as `2007`, and the first
Play release — carrying `8` from `pubspec.yaml` — could never have installed over it.

If `--split-per-abi` is ever genuinely needed, the way to take it without stranding anyone is to
raise the base build number above the offsets once, deliberately — `version: 1.4.0+5001` — so the
plain number already exceeds any split APK ever issued. Write it down here if that day comes.

**A release build fails outright when `android/key.properties` is missing.** It
does not fall back to the debug key. That fallback shipped a debug-signed APK
once, and it is silent — `flutter build` swallows Gradle warnings, so a warning
would never have been read. See PROJECT.md §9.

A debug-signed APK installs and runs, so it is fine for a quick test, but it can
never go to Play and a properly signed build can never upgrade it in place —
testers have to uninstall first, losing their local data.

For a build people should actually judge the app by, use `--release`: a debug
APK is ~93 MB and runs on the JIT, against ~22 MB and AOT for release. The
students this is for are on mid-range phones, where that difference is the whole
impression.

### Bump the build number — every time

`versionCode` comes from the `+N` in [`pubspec.yaml`](pubspec.yaml)'s `version: 1.0.0+1`.
Android refuses to install an APK whose `versionCode` is not **higher** than the one
already on the phone, so a build that forgets this cannot be installed over its
predecessor at all — the tester's only way forward is to uninstall, which deletes
their local database.

```yaml
version: 1.0.1+2   # name students see + the number Android compares
```

Bump `+N` on **every** build that leaves this machine, including ones you think are
throwaway. They are not throwaway once they are on someone's phone. Bump the `1.0.0`
part as well when the change is worth a name.

The full rule, and the two other things that break an in-place upgrade (the signing
key and the database migration), are in [CLAUDE.md](CLAUDE.md) — it is Rule 1 there
because it is the one mistake in this repository that destroys a student's data
rather than merely wasting time.

### Verify what you built

```bash
apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk
```

The certificate DN must be your own details. If it says `CN=Android Debug`, the
build used the debug key and must not be distributed.

---

## 5. Before the first public release

Open items recorded in PROJECT.md §9, all of which block Play rather than
testing:

- In-app **account deletion** — mandatory for any app with sign-in.
- A **privacy policy URL**, and the Data safety form (the app collects an email
  address through Firebase Auth).
- ~~The app has still never run on a real phone.~~ Done 2026-08-05 — a debug build was
  driven end to end on a Nothing Phone (Android 16). See PROJECT.md §10.
- ~~Cloud backup has never been exercised against live Firestore.~~ Done 2026-08-05:
  a signed release build was installed on a wiped device, signed in with Google, and the
  curriculum came back from Firestore on its own. See PROJECT.md §10.
