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
flutter build appbundle          # Google Play wants this
flutter build apk --split-per-abi   # hand-distributed testing
```

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
