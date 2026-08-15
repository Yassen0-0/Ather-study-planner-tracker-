# Ather — Pre-Play Security Audit

**Audited commit:** `155d34e` (branch `claude/app-security-audit-plan-84db51`, worktree `upload-apk-verify-e40262`)
**Audit date:** 2026-08-15
**Scope:** Confidentiality, authorization, Android attack surface, and Google Play policy readiness.
**Role:** Audit only — **no application file, Firestore rule, or Firebase console setting was modified.** The only writes were three throwaway Auth accounts, since deleted and verified gone.

**Test surface**

| | |
|---|---|
| Device | Nothing Phone **A015**, Android **16** (API 36), non-rooted, `ro.debuggable=0`, `user` build |
| Installed build | **1.2.0+6** (`lastUpdateTime 2026-08-11`) — repo is at `1.3.1+8`, so the phone is two releases behind |
| Firebase project | `ather-49705` (project number `882606725720`) |
| Tooling | `adb` platform-tools 36.0.0, `apksigner` build-tools 36.0.0, `firebase-tools` 15.25.1, Node fetch probes |

Evidence tags used below: **[S]** static (repo), **[D]** device, **[C]** cloud/console, **[N]** network.

---

# Verdict

**Ather cannot be published yet, and the reason is not a vulnerability — it is three missing compliance artefacts and one configuration step that will silently break sign-in for every real user.**

The security engineering in this codebase is genuinely strong, and the audit's highest-risk hypothesis was **disproved**: the live Firestore rules are correctly deployed and do isolate students. Cross-tenant read, cross-tenant write, anonymous read, and out-of-scope collection access were all denied against the production project. The project is **not** in test mode.

What blocks release is paperwork and console config, plus one launch-breaker that no local test can catch:

1. **Google Sign-In will fail for every Play install** until the Play App Signing certificate is registered in Firebase.
2. **No in-app account deletion** — a hard Play rejection.
3. **No privacy policy** — required by Play, and required more strictly because the audience includes minors.
4. **Deleting an Auth account orphans the student's exam history in Firestore forever** — proven during this audit's own cleanup.

None of these are code defects. All four are release-process gaps.

---

# Blockers — Play will reject, or the app will break on release

## BLOCK-1 · Google Sign-In breaks for every Play user · **Critical** · [S][D]

With Play App Signing, Google re-signs the App Bundle with a certificate that is **not** the upload key. Firebase authenticates Android OAuth clients by *package name + signing certificate SHA-1*. Only two fingerprints are registered:

| Key | SHA-1 | Registered in `google-services.json`? |
|---|---|---|
| Upload key (`CN=yassen, OU=per, O=ather, L=giza, C=eg`) | `f3eaec08a58d41d334d22abade33b1e89577623e` | ✅ |
| Android debug key | `6f69a69ee9b3b2a7717c083a833636b9e6e8e86e` | ✅ |
| **Play App Signing key** | *a third, different value* | ❌ **missing** |

Verified by pulling the installed APK off the phone and reading its certificate:

```bash
adb shell pm path com.ather.app
apksigner verify --print-certs base.apk    # → SHA-1 f3eaec08…  (the upload key)
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey   # → 6f69a69e…
```

**Why this is the worst possible failure shape:** every local test passes. Debug builds work (debug SHA-1 registered). The signed release APK works — this is exactly the run recorded in PROJECT.md §9, "Google Sign-In completed on a real phone against the *release* build." That run proves the *upload* key works and says nothing about the Play key. The first time it fails is when a student installs from the store and the account sheet opens, then dies with `ApiException: 10`.

`RELEASING.md:71-78` documents registering the upload key and stops there.

**Fix:** after uploading the first bundle, copy the SHA-1 **and** SHA-256 from Play Console → *Release → Setup → App signing* into Firebase → *Project settings → `com.ather.app` → Add fingerprint*, then re-download `google-services.json`. Do it before promoting to any track real students can reach — internal testing included, since internal testing is Play-signed too.

## BLOCK-2 · No in-app account deletion · **Critical (policy)** · [S]

`lib/presentation/settings/settings_screen.dart` offers sign-out (`:162-168`) and nothing else. Play's *User Data* policy requires any app with account creation to provide in-app account deletion **and** a web-accessible deletion request route.

## BLOCK-3 · Deleting the account orphans the student's data · **Critical (policy)** · [C]

This audit proved it accidentally, which is the best kind of proof. Cleaning up the throwaway accounts, `accounts:delete` removed the Auth user — and left `users/{uid}/backup/snapshot` untouched. The Firestore document had to be deleted in a **separate explicit call**.

There is no Cloud Function, no cascade, no TTL. So a naïve BLOCK-2 implementation that just calls `user.delete()` would leave the student's complete exam history in Firestore permanently, while telling them their account was deleted. That is a data-deletion violation under Play policy and GDPR both.

**Fix:** delete the Firestore document *first*, then the Auth user, and treat a failure on the first step as a failure of the whole operation.

## BLOCK-4 · No privacy policy · **Critical (policy)** · [S]

Nothing in the repository, and no in-app link. Required for the Play listing, required in-app for an app collecting personal data, and non-waivable under Families Policy. It must name: email address, display name, Firebase uid, and the study record (chapters, lessons, exam scores, timestamps).

## BLOCK-5 · Data safety form and Families Policy · **Critical (policy)** · [S]

The declared audience includes under-18 students, which triggers **Google Play Families Policy**. What the app actually transmits:

| Data | Where | Declaration |
|---|---|---|
| Email address | Firebase Auth | Collected, transmitted, tied to identity |
| Display name | Firebase Auth (Google sign-in) | Collected, transmitted |
| Firebase uid | Auth + Firestore path | Collected, transmitted |
| Study record (gzipped JSON blob) | Firestore `users/{uid}/backup/snapshot` | Collected, transmitted, **automatic — not optional** |

**Correction, 2026-08-15 (same day).** An earlier revision of this report called cloud backup "opt-in". It is not. `BackupSyncNotifier` uploads on a 20-second debounce after any write and again when the app backgrounds, for every signed-in student, with no toggle anywhere — and the auth gate makes signing in mandatory to use the app at all. So **every** student's exam history is transmitted to Firestore by default. The Data safety form must declare it as automatic collection, and the privacy policy must not imply a choice the student does not have. The consequences for LOW-1 are worked through there.

**The genuinely good news:** there are no ads, no analytics SDK, no crash reporter, and no third-party trackers. Dependency review confirms it — the only network-capable packages are `firebase_core`, `firebase_auth`, `cloud_firestore`, and `google_sign_in`. That makes the Families Policy questionnaire dramatically easier to pass honestly, and it is a real asset. Do not add an analytics SDK before launch without revisiting this section.

---

# Findings

## HIGH-1 · Firebase App Check is not enforced · [C]

Proven by driving the production project with nothing but the API key extracted from the shipped APK:

```
accounts:signUp  → 200 OK, account created, no App Check token presented
```

The API key in `lib/firebase_options.dart:56` and `android/app/google-services.json` is an **identifier, not a secret** — that is correct and normal. But that statement is only half a sentence: it is safe *because* the Firestore rules and App Check are doing their jobs. The rules are (see VERIFIED-2). App Check is not.

Consequences, in order of likelihood:

- **Unlimited account creation.** Anyone can mint accounts against `ather-49705` at will.
- **Billing / quota denial of service.** Combined with LOW-3, a script can write ~1 MiB documents in a loop under its own uid. Every write is a legitimate, rules-compliant write. On Spark this exhausts the daily quota and backup stops working for real students; on Blaze it is a bill.
- **No cost ceiling was found.** Confirm a budget alert exists (§J).

**Fix:** enable App Check with Play Integrity for Android, run it in *monitoring* mode first to confirm real traffic attests, then enforce on Firestore and Auth. Do not enforce before monitoring — enforcing first locks out the installed 1.2.0/1.3.1 users, who have no App Check code in them at all.

## MEDIUM-1 · The app lock opened without a credential on 2 of 11 cold starts · [D]

The most interesting result of the audit, and it needs stating carefully because **the app's own code is not at fault.**

With *Fingerprint lock* ON in Settings, 11 cold starts were run as `force-stop` → `am start` → observe. On 9 of them the system prompt appeared and held indefinitely with no input, which is correct. On 2 — including one captured as a screenshot showing the **dashboard**, fully unlocked — the prompt dismissed itself after ~2.7s with no input and the app proceeded past the lock.

The mechanism was narrowed down rather than guessed:

- `lock_screen.dart:59-62` releases the lock on three codes (`noBiometricHardware`, `noBiometricsEnrolled`, `noCredentialsSet`) and logs `Ather lock: device cannot authenticate` when it does.
- **`debugPrint` demonstrably reaches logcat in this release build** — captured live: `I flutter : Ather lock: attempt failed -- LocalAuthException(code userCanceled, null, null)`.
- That log line was **absent** during both anomalous releases.

Therefore the `_cannotEverAuthenticate` branch did **not** run, and `authenticate()` returned `true`. The platform reported a successful authentication that the user never performed. `dumpsys trust` showed `strongAuthRequired=0x0`, `deviceLocked=0` — consistent with Android satisfying the request from a recent-keyguard-unlock trust window rather than prompting.

**So this is a platform trust-window behaviour, not a logic bug** — but the student cannot tell the difference, and the Settings copy promises something stronger than what happens: *"Ask for a fingerprint every time the app opens."*

**Recommendation:** treat this as a copy-and-expectation fix first, and only then a technical one. Do not "harden" `_cannotEverAuthenticate` in response to this finding — the evidence exonerates it, and narrowing it further would risk re-introducing the lockout the comment in that file was written to prevent. Reproduce it deliberately before changing behaviour.

## MEDIUM-2 · Email enumeration protection is off · [C]

```
signUp(existing address)        → EMAIL_EXISTS          ← discloses registration
signIn(nonexistent address)     → INVALID_LOGIN_CREDENTIALS
signIn(registered, wrong pw)    → INVALID_LOGIN_CREDENTIALS
```

The sign-*in* path is correctly indistinguishable — and `firebase_auth_repository.dart:137-140` deliberately collapses `user-not-found` into `wrongCredentials`, which is good work. But `signUp` leaks: `EMAIL_EXISTS` confirms whether any given address has an Ather account. For a product whose users are identifiable schoolchildren, that is a privacy leak, not just an infosec nicety.

**Fix:** Firebase console → Authentication → Settings → **Email enumeration protection**. Note this changes error codes, so re-check that `_map` still produces sensible copy afterwards.

## MEDIUM-3 · Password policy is Firebase default · [C]

`'123456'` was accepted for a new account. No complexity requirement, no length beyond 6, no breached-password check. The client enforces the same weak floor (`login_screen.dart:73`, `_password.text.length < 6`).

**Fix:** Identity Platform password policy — minimum 8, require mixed character classes. Raise the client check to match so the student gets a local error instead of a server rejection.

## MEDIUM-4 · Email addresses are never verified · [S][C]

`register()` (`firebase_auth_repository.dart:53-67`) creates the account and trusts it immediately; the throwaway accounts in this audit were fully usable with addresses that do not exist. A student can register under someone else's address, and password-reset delivery to a typo'd address fails silently.

Weigh against friction: requiring verification before first use costs a real student their first session if mail is slow. A reasonable middle is to allow use immediately but require verification before cloud backup is enabled.

## LOW-1 · Android Auto Backup uploads exam history to Google Drive · [D][S]

`android:allowBackup` is never declared, so it defaults **true**, and the Google backup transport is active on the device:

```
adb shell dumpsys package com.ather.app | grep ALLOW_BACKUP   → ALLOW_BACKUP
adb shell bmgr list transports  → * com.google.android.gms/.backup.BackupTransportService
```

No `dataExtractionRules` governs device-to-device transfer either. So the unencrypted SQLite exam history is eligible for upload to the student's own Google account.

**This is presented as a decision, not a defect, because it cuts both ways.** Against confidentiality: the record leaves the device without the student ever opting into cloud backup. For durability: it is the *only* thing that recovers a student's history after a lost or broken phone when they never enabled Ather's own backup — which is the exact harm CLAUDE.md Rule 1 exists to prevent, arriving through a door Rule 1 does not watch.

**Revised 2026-08-15, after the "opt-in" correction above — and the revision moves the recommendation.**

The original argument for leaving Auto Backup on was durability: cloud backup was believed to be opt-in, so Auto Backup was the only thing standing between a student who never enabled it and a lost phone. That premise was wrong. Every signed-in student already gets an automatic Firestore copy, and `BackupSyncGate._restoreIfEmpty` pulls it down onto a new phone by itself. So the durability case for Auto Backup is far narrower than stated.

It is nearly empty, in fact: **Android Auto Backup only runs on an unmetered network** (charging and idle besides), so the offline-only student the argument was built around is not covered by it either. Both recovery paths need the same network.

What genuinely remains is the case where the Firestore copy cannot be written while Auto Backup still could — most concretely a record that exceeds `_maxBlobBytes` and fails with `BackupFailure.tooLarge` (see LOW-3/§J). That is real, but it argues for fixing the ceiling rather than for keeping a second uncontrolled copy of a minor's exam history in a different place.

**Recommendation, corrected: set `android:allowBackup="false"`** — the durability it buys is marginal and duplicated, and the audience is minors. It is left at `true` in the code for now, declared explicitly with the reasoning, because flipping it is a behaviour change that removes a recovery path and that is the app owner's call, not the auditor's. Either way it must appear in the Data safety declaration while it is on.

## LOW-2 · Local database is unencrypted · [S]

`lib/data/db/app_database.dart` uses plain SQLite. **Assessed as acceptable**, and this is evidence-based rather than assumed: on this non-rooted Android 16 device the app's private directory was genuinely unreachable — `run-as` refused ("package not debuggable"), `su` is absent, and no ADB path to app-private data exists. Physical-access extraction is not available to a realistic attacker. Encryption would add key-management failure modes that risk data loss, which is a worse outcome than the exposure it prevents. Revisit only if a rooted-device threat becomes relevant.

## LOW-3 · Firestore rules validate size but not shape · [C]

A client can write arbitrary fields into its **own** snapshot document — confirmed: `payload` as a string and `formatVersion` as a non-number were both accepted. The only thing standing between that and a corrupted restore is client-side (`BackupFailure.unreadable`, `firestore_backup_repository.dart:95-108`), which does correctly refuse to touch the local database.

Self-inflicted only — not cross-tenant — so severity is low. Worth adding type assertions to the rules when they are next touched.

*Test precision note:* the 1 MiB ceiling could not be attributed to the rule, because Firestore's own per-property limit (`1048487 bytes`) rejects the write first. The rule is not proven redundant; it still bounds total document size. It is simply untested by this probe.

## LOW-4 · Two exported BROWSABLE activities from `firebase_auth` · [D]

The manifest declares no deep links, but a dependency contributes two:

```
genericidp://firebase.auth/  → com.google.firebase.auth.internal.GenericIdpActivity
recaptcha://firebase.auth/   → com.google.firebase.auth.internal.RecaptchaActivity
```

Both are exported and browsable, so any app or web page can launch them. Both were launched from `adb shell` with no payload: no crash, no exception in logcat, nothing rendered — they are inert. Ather uses neither generic-IdP nor reCAPTCHA sign-in, so this is unused surface from Google's own SDK. Documented so it is not mistaken for a finding later; no action recommended.

## LOW-5 · No `FLAG_SECURE` — exam history is screenshottable · [S][D]

Confirmed empirically: every dashboard screenshot in this audit was captured with `screencap` while the app displayed study data. Screen recording is likewise permitted. Notably, the *system credential prompt* does blank screencap output, so the platform protects its own surfaces but not the app's.

Low severity for a study app, and `FLAG_SECURE` carries a real cost — it breaks the student's own legitimate screenshots. Raised because it interacts with the minors/privacy story; a deliberate "no" is a fine answer.

## LOW-6 · Dependency drift · [S]

No known-vulnerable package found. All drift is patch/minor, no major versions behind:

| | Current | Latest |
|---|---|---|
| `firebase_auth` | 6.5.6 | 6.5.7 |
| `flutter_local_notifications` | 22.2.0 | 22.3.0 |
| `go_router` | 17.3.0 | 17.5.0 |
| `build_daemon` (dev only) | 4.1.3 — **retracted** | 4.1.5 |

The retracted `build_daemon` is a dev dependency and never ships, but it should be bumped.

## LOW-7 · Obsolete `com.sahm.sahm` client still live in the production project · [C]

```
firebase apps:list --project ather-49705
  ather (android)   1:882606725720:android:9f14effc7ebfcedd20c82d   ← com.sahm.sahm, obsolete
  [Not specified]   1:882606725720:android:f7e9109d4620e84420c82d   ← com.ather.app, current
```

The pre-rebrand app and its OAuth client remain registered, with the debug-key SHA-1 attached, and `google-services.json` still carries both. Unused credential surface: anything signed with that key under that package name can still authenticate to the production project. Also worth noting the **debug** key is registered against the production project at all — convenient for development, but it means any debug build reaching that keystore talks to real student data.

## LOW-8 · Housekeeping confirmed outstanding · [C]

Both items recorded in PROJECT.md §9 are still real:

- The stray Google Cloud project **`ather-app-2026`** exists (`firebase projects:list`).
- The `test@ather.app` account should be confirmed deleted from Authentication.

---

# Verified good — with evidence

These were attacked, not assumed. **Do not "simplify" any of them without re-running the test.**

**VERIFIED-1 · Release signing cannot silently fall back to the debug key.** `tool/check_invariants.sh` passes all five checks, and the installed APK is genuinely upload-key signed. The Gradle guard in `android/app/build.gradle.kts:29-44` throws rather than degrading.

**VERIFIED-2 · Per-student isolation is live in production.** The audit's highest-risk hypothesis, disproved. Two throwaway accounts, real tokens, direct Firestore REST:

| Attempt | Result |
|---|---|
| B reads A's `users/{A}/backup/snapshot` | **403 PERMISSION_DENIED** |
| B writes into A's snapshot | **403 PERMISSION_DENIED** |
| Unauthenticated read of a snapshot | **403 PERMISSION_DENIED** |
| A writes its own snapshot | 200 OK (intended path works) |
| `audit_probe/doc1` — no rule covers it | **403 PERMISSION_DENIED** |
| `users/{A}` document itself | **403 PERMISSION_DENIED** |
| `users/{A}/other/doc1` | **403 PERMISSION_DENIED** |

The live rules match `firestore.rules` in git behaviourally, and the deny-all fallback genuinely denies. The `firestore.rules` header comment worried that the live copy could silently be test-mode; it is not.

**VERIFIED-3 · The app lock holds on cancellation.** Captured live: `Ather lock: attempt failed -- LocalAuthException(code userCanceled)` — and the lock stayed on. The hardening described in `lock_screen.dart:14-31` works; the old "release on any failure" behaviour is genuinely gone. (See MEDIUM-1 for the separate platform-side issue.)

**VERIFIED-4 · No secrets in the working tree or git history.**

```bash
git log --all --diff-filter=A --name-only -- "*.jks" "*.keystore" "**/key.properties"   # → empty
```

Never committed, at any point in history. Only `key.properties.example` with placeholders. The one high-entropy string is the Firebase API key, which is a public identifier. `.gitignore:97-102` is correct.

**VERIFIED-5 · No PII in logcat.** A full session's log was swept for email addresses, id tokens, bearer tokens, uids and document paths — nothing. All six `debugPrint` call sites log error *types*, not payloads. This matters more than it looks, because `debugPrint` **does** print in release builds (proven above), so a careless one would ship.

**VERIFIED-6 · Attack surface is minimal.** Only `MainActivity` is exported by the app itself. Both `flutter_local_notifications` receivers are `exported=false`. No `WebView`, no `FileProvider`, no exported `ContentProvider` (only Firebase's and AndroidX's internal init providers). A protected-broadcast injection was refused by the platform: `SecurityException: not allowed to send broadcast android.intent.action.BOOT_COMPLETED from uid=2000`.

**VERIFIED-7 · Play technical requirements met.** `minSdk 24`, `targetSdk 36`, `compileSdk 36`. No dangerous permissions; `SCHEDULE_EXACT_ALARM` deliberately not declared. All eight merged permissions are plugin-contributed and defensible.

**VERIFIED-8 · No trackers.** No ads, analytics, or crash-reporting SDK. Materially simplifies Families Policy compliance.

---

# Not covered, and why

An honest gap list. Each of these is a real hole in the audit, not a formality.

1. **Third-party-app reachability of non-exported components.** `adb shell` runs as uid 2000, which bypasses `exported=false` — a broadcast to `ScheduledNotificationReceiver` succeeded *from shell*, which proves nothing about a normal app. Properly testing this needs a purpose-built malicious APK. `exported=false` is platform-enforced and was verified in the manifest, so risk is low, but it was not empirically attacked.

2. **TLS interception.** The mitmproxy run in the plan was not performed. Expected result is that interception fails (targetSdk ≥ 24 does not trust user CAs and no `network_security_config` opens that door), and static review confirms no `usesCleartextTraffic`, no `networkSecurityConfig`, and no plaintext endpoint in `lib/`. But the negative was not demonstrated. **Certificate pinning is recommended against** — Firebase manages its own transport and pinning Google endpoints is a self-inflicted outage risk — recorded here as a decision rather than an omission.

3. **Multi-tenancy attack (§H of the plan) — not run.** Every variant requires clearing app data or signing a second account into the device, and this is the user's personal phone. `BackupSyncGate._clearIfDifferentAccount` was reviewed and is well reasoned, but **the two-students-one-phone wipe was not empirically verified**, nor was the crash-mid-wipe ordering guarantee, nor restore-onto-non-empty. This is the largest untested area in the audit and deserves a dedicated pass on a disposable device.

4. **Local data extraction.** Not possible on this device: no root, `su` absent, `run-as` refused. This is *why* LOW-2 is assessed as acceptable, but it also means the encryption question was never tested adversarially.

5. **Play Console state.** Play App Signing enrolment, the Data safety form, content rating, and target-audience declaration were not inspected — they need Play Console access, which was out of scope for a read-only audit phase. BLOCK-1 in particular needs confirming against the actual console.

6. **MEDIUM-1 is unreproduced on demand.** 2 anomalies in 11 trials, both in runs where other `adb` activity had just occurred, so instrumentation artefact cannot be ruled out. Needs a clean, scripted, many-trial run before any code changes.

7. **Firebase budget alert.** Not confirmed either way.

---

# Console state as found — 2026-08-15

Recorded so drift is detectable later.

| Setting | State |
|---|---|
| Firestore rules (live) | **Correct** — per-uid isolation verified behaviourally |
| Firestore test mode | **Not** in test mode |
| App Check | **Not enforced** on Auth; Firestore enforcement not observed |
| Email enumeration protection | **Off** |
| Password policy | **Firebase default** (≥6 chars, no complexity) |
| Email verification | Not required |
| Registered Android apps | 2 — `com.ather.app` **and obsolete `com.sahm.sahm`** |
| Registered SHA-1s for `com.ather.app` | Upload key + debug key. **No Play App Signing key.** |
| GCP projects on the account | `ather-49705` (live) and stray **`ather-app-2026`** |
| Budget alert | Unconfirmed |

---

# Recommended order of work

Blockers first, then the cheap high-value console toggles, then the rest.

1. **BLOCK-4 / BLOCK-5** — privacy policy, Data safety form, Families Policy declarations. Longest lead time; start now.
2. **BLOCK-2 + BLOCK-3 together** — account deletion that removes the Firestore document *before* the Auth user. They are one feature; shipping BLOCK-2 without BLOCK-3 creates a worse violation than shipping neither.
3. **BLOCK-1** — register the Play App Signing SHA-1/SHA-256 the moment the first bundle is uploaded, and add the step to `RELEASING.md` so it cannot be forgotten again.
4. **MEDIUM-2, MEDIUM-3** — two console toggles, minutes of work, real privacy gain. Re-check `_map` copy afterwards.
5. **HIGH-1** — App Check in monitoring mode, then enforce. Confirm a budget alert while in the console.
6. **LOW-7, LOW-8** — delete the obsolete `com.sahm.sahm` client, the stray project, and the test account.
7. **LOW-1** — decide `allowBackup` deliberately and write down the reasoning either way.
8. **MEDIUM-1** — reproduce properly before changing any lock code. The evidence currently exonerates `_cannotEverAuthenticate`; changing it now would be fixing the wrong thing.
9. **Gap 3** — run the multi-tenancy attack on a disposable device. It is the biggest untested risk to a student's data.

One process note worth acting on independently: the phone is running **1.2.0+6** while the repo is at **1.3.1+8**. Any future device verification should start by confirming which build is actually installed — two of this audit's findings would have been misattributed if the version had been assumed.
