# Security Audit

Phase 1, read-only. Auditor: SECURITY-AUDITOR. Date: 2026-08-25. Repo at commit `83a60fe`
(branch `ai-audit/2026-08-25`). Secret values are redacted throughout (`first4…`).

## Findings

### SEC-01 · App Check activated but not enforced — API key alone still mints accounts · **P1**

- **Where:** `lib/main.dart:130–146` (`_activateAppCheck`, Play Integrity provider, failure
  non-fatal); `lib/firebase_options.dart:56` (apiKey `AIza…`); pubspec.yaml:64–69
  ("shipped *before* it is enforced").
- **Exploit scenario:** An attacker unzips any shipped APK, extracts the Firebase config
  (an identifier, not a secret), and calls the Identity Toolkit REST endpoint directly.
  This is not hypothetical — PROJECT.md records that the 2026-08-15 audit created three
  live accounts this way. Today the attacker can: create unlimited email/password accounts,
  authenticate, and write garbage into their **own** `users/{uid}/backup/snapshot` documents
  up to the 900 KiB ceiling. Confidentiality holds (the rules stop cross-student reads);
  what breaks is quota, billing, and the integrity of the project's data surface. App Check
  tokens are currently *attached* by clients but never *demanded* by the backend.
- **Why it is like this:** Enforcement is a server-side switch; versions 1.2.0/1.3.1 contain
  no App Check code and would be locked out of sign-in entirely. The ship-before-enforce
  sequence in `main.dart:115–124` is correct; what is missing is the follow-through.
- **Fix:** In the Firebase console: watch the App Check *unverified requests* metric until
  the 1.2.x/1.3.x installed base drains, then enforce on **Identity Toolkit** (Auth) and
  **Firestore** together. Set a billing budget alert now, while enforcement is off — it is
  the only tripwire against bulk abuse today.
- **Risk of fixing:** Enforcing before the old installs drain bricks sign-in and backup for
  every student who has not updated — exactly the failure the staged rollout exists to avoid.
  Enforcing Auth before Firestore (or vice versa) creates a half-state where sign-in works
  but backup silently fails; flip both in the same change window.

### SEC-02 · Email verification prompts but never gates anything · **P2**

- **Where:** `lib/presentation/providers/auth_providers.dart:36–47` ("gates a prompt, never
  access"); `lib/data/auth/firebase_auth_repository.dart:62–91` (registration sends
  verification best-effort; a send failure returns `false` but the account stands).
- **Exploit scenario:** A student registers with a typo'd mailbox (`gamil.com`) or an address
  they do not own. The account is fully functional — local data, cloud backup, everything.
  When they later forget the password, reset mail goes to a mailbox they cannot read:
  permanent account loss (and an orphaned cloud backup holding a minor's study record that
  nobody can authenticate to delete). No confidentiality impact to *other* students.
- **Context:** This is a deliberate, documented trade-off (blocking would lock students out
  of their own offline history). The gap is recovery, not access control.
- **Fix:** Escalate the existing banner after N days unverified (e.g. interstitial with a
  "fix your email" affordance rather than a dismissible strip). Consider allowing an
  unverified user to change their own address (re-sends verification to the new one), which
  rescues the typo case without ever blocking access.
- **Risk of fixing:** Any gating risks locking a student away from data only they hold; keep
  the gate soft and reversible.

### SEC-03 · Password policy floor is 6 characters with no composition or breached-password check · **P2**

- **Where:** `lib/presentation/auth/login_screen.dart:73` region (client-side length check);
  backend default Identity Toolkit enforcement. Prior audit
  (`docs/reviews/security-audit-2026-08-15.md`, HIGH-3) demonstrated `'123456'` is accepted.
- **Exploit scenario:** An attacker who learns a student's email tries the obvious candidates;
  Firebase's `too-many-requests` throttling (mapped at
  `firebase_auth_repository.dart:285`) is the only brake. Success yields the student's cloud
  backup blob — their complete exam history — and a durable seat in the project's quota.
- **Fix:** Client-side minimum bump (e.g. 8) plus a small top-common-passwords denylist on
  registration only; leave reset/sign-in untouched so existing users are never locked out.
  Optionally enable Firebase's email-enumeration protections review while in the console.
- **Risk of fixing:** Registration-only changes are safe; changing sign-in validation would
  strand existing weak-password users.

### SEC-04 · "Delete everything" leaves PII-bearing preferences on the device · **P2**

- **Where:** `lib/presentation/settings/settings_screen.dart:733–740` — flush → wipe SQLite →
  delete cloud doc → delete Firebase account. Nothing clears SharedPreferences:
  profile display name (`lib/presentation/providers/app_providers.dart:267`, `_kProfileNameKey`),
  lock-method/passcode-hash keys (`auth_providers.dart:135–173`), `last_account_uid`
  (`backup_gate.dart:75`), exam drafts (`exam_entry_screen.dart:186`).
- **Exploit scenario:** A student sells or hands over a phone after "delete my account".
  The database is empty and the cloud doc gone, but the chosen display name (often a real
  name) survives in `shared_prefs/Ather.xml` readable by the next owner of the unlocked
  device, and the app-lock passcode hash/configures survive with it.
- **Fix:** On successful deletion, remove app-owned preference keys (name, drafts, lock
  settings, fingerprint, `last_account_uid`). Removing `last_account_uid` also restores the
  correct first-run semantics for whoever signs in next — the §3.30 wipe check degrades
  safely to "first sign-in".
- **Risk of fixing:** Low. Do it *after* `deleteAccount()` succeeds so a failed delete keeps
  the student's settings intact; do not touch Firebase's own cached-session files.

### SEC-05 · App-lock password hashed with one unsalted-iteration SHA-256 · **P2 (informational)**

- **Where:** `lib/core/auth/app_passcode.dart:29–58` — per-password random 16-byte salt +
  single SHA-256 round, stored in plaintext prefs as `<salt-hex>:<hash-hex>`.
- **Exploit scenario:** Salt is good; work factor is not. Anyone who reads the prefs file
  (rooted device, malware with same-profile access on Windows) brute-forces a 4-character
  floor instantly. The file itself correctly documents this as a privacy convenience behind
  the device screen lock (§3.18), not a security boundary — recorded here so the posture is
  explicit and revisited if the lock ever starts protecting something else.
- **Fix (optional):** Key-stretching (PBKDF2 ~100k rounds) via `pointycastle`, or move
  verification to Android Keystore `BiometricPrompt` crypto object. Version the stored
  format so old hashes migrate on next change.
- **Risk of fixing:** Migration complexity for existing stored hashes; none if versioned.

### SEC-06 · Cloud backup blob is not end-to-end encrypted · **P2 (informational)**

- **Where:** `lib/data/backup/firestore_backup_repository.dart:155–193` — full study record
  (a minor's exam history) as gzip+base64 JSON, integrity-HMAC'd (SHA-256) but **not**
  encrypted client-side; Firestore holds it Google-side encrypted, readable by anyone the
  rules admit (the owning uid, plus project admins) and by whoever the rules ever admit by
  mistake.
- **Exploit scenario:** A single future rules regression (e.g. a broadened match, a test-mode
  relapse) exposes every student's record at once; a compromised admin/service credential
  reads all blobs. The checksum field protects integrity, not confidentiality.
- **Posture:** Consistent with §3.26's documented "mirror" design. True E2E encryption needs
  a user-held key, which collides with password-reset reality (lost key = lost backup) and
  the offline-first UX; not recommended casually.
- **Fix (if pursued later):** Envelope-encrypt with a key derived from the account password,
  accepting the documented recovery trade-off; keep v2/v3 blobs restorable during transition
  (the format-version ladder already exists).
- **Risk of fixing:** High UX/recovery cost; strictly optional.

### SEC-07 · Second, stale-capable `google-services.json` tracked under `.claude/worktasks/` · **P2 (hygiene)**

- **Where:** `.claude/worktasks/release-apk/android/app/google-services.json` duplicates the
  canonical `android/app/google-services.json`. Values are public-by-design identifiers
  (projectId `ather-49705`, appId `1:882606725720:android:f7e9109d4620e84420c82d`) — **not
  a secret leak**; the problem is drift: two copies can diverge (old `com.sahm.sahm` client
  already lingers in the project per `firebase_options.dart:57–59`).
- **Exploit scenario:** A future release built inside the worktask directory picks up the
  stale copy and reports into the wrong app identity — an operational bug, not exposure.
- **Fix:** Delete the duplicate; keep exactly one canonical copy referenced by path. Add the
  path to any packaging checklist that runs inside worktrees.
- **Risk of fixing:** None.

## Verified-fine areas

These were examined and found sound; listed so they are not re-litigated.

1. **Secrets in repo (HEAD and shallow history).** `git log --diff-filter=A --name-only` over
   `*.jks *.keystore *.pem *.p12 *.env *key.properties* *serviceAccount* *secret* *credential*`
   surfaces only `android/key.properties.example`, which contains four placeholder values
   (verified placeholder-shaped, no real material). No keystores, service-account JSONs, or
   `.env` files are tracked at HEAD or were ever added in reachable history. The real
   `android/key.properties` is git-ignored (.gitignore:73–79 covers `key.properties`,
   `*.jks`, `*.keystore`), and `build.gradle.kts:92–95` reads signing material exclusively
   from that ignored file — no passwords in build scripts. The tracked Firebase API key
   (`AIza…`) is a public identifier; noted, not alarmed.
2. **Firestore rules least privilege.** `firestore.rules:26–54`: the only reachable path is
   `users/{uid}/backup/**`, every verb requires `request.auth.uid == uid`; explicit deny-all
   catch-all at :60–62 means new collections inherit nothing. Size ceiling uses
   `request.resource.data.payload.size() <= 921600` — the correct bytes-over-blob form (the
   `resource.size()` bug is documented in-file as fixed and emulator-verified 2026-08-15).
   Delete split from create/update so erase-my-data works. **Stricter than §3.26's published
   rule** (repo adds the size check and `{document=**}` recursion; published snippet was
   `read, write` on `{document}` alone) — repo supersedes doc, doc should be refreshed.
   One action item outside the repo: confirm the **deployed** ruleset equals this file
   (`firebase deploy --only firestore:rules` is manual per :17–18; nothing in CI verifies it).
   `storage.rules` absent and correctly so — no `firebase_storage` dependency exists.
3. **Insecure storage posture.** SQLite (`sahm.sqlite`) is unencrypted by documented choice;
  protected by app-private storage, sandbox, and — decisively — Auto Backup fully disabled:
  `allowBackup="false"` (AndroidManifest.xml:58) **and** `data_extraction_rules` excluding
  root `.` for both cloud-backup and device-transfer channels (data_extraction_rules.xml:18–24),
  so neither adb/cloud backup nor a setup-wizard transfer carries the DB or prefs. SharedPreferences
  inventory reviewed key-by-key (locale, theme, haptics, notifications flag, profile name/year,
  lock flags, salted passcode hash, last uid, day marker, schedule fingerprint, exam drafts):
  no credentials or tokens at rest; only items flagged are in SEC-04/SEC-05. Backup blob PII
  posture: see SEC-06.
4. **Network.** Zero `http://` endpoints in `lib/`; all traffic is Firebase-over-TLS. No TLS
   pinning — judged acceptable: pinning against Google's rotating infrastructure for
   Firebase SDK traffic is impractical and the data-at-rest threat is covered by the rules
   discussion above. Merged release manifest has no `usesCleartextTraffic`. Share/PDF temp
   files land in `getTemporaryDirectory()` (app-private, not world-readable) and reach other
   apps only through the system share sheet's per-target URI grants
   (`pdf_export_service.dart:86–94`, `widget_raster.dart:188–190`).
5. **Input validation surface.** No deep links exist: the manifest's only intent filter is
   MAIN/LAUNCHER (AndroidManifest.xml:78–81), so router paths arrive only from inside the app;
   even so, numeric params parse defensively to `-1` instead of throwing
   (`router.dart:353–354`) and screens treat unknown ids as empty. Notification payloads are
   self-produced `"lessonId"` integers, `int.tryParse`d (`review_notification_service.dart:105–110`);
   no FCM/push surface exists to spoof them. Free-text chapter/lesson names reach exactly two
   sinks: parameterized drift statements (no injection) and filenames — sanitized via
   `_safeSegment` keeping Unicode letters/digits only, ≤40 chars
   (`pdf_export_service.dart:121–139`); JSON-export and progress-card filenames are fixed
   templates (`data_export_service.dart:114–121`, `widget_raster.dart:152–156`). Exam drafts in
   prefs hold score digits only. Paste abuse lands in validated numeric fields feeding
   parameterized SQL — nothing to escalate.
6. **Auth flow mechanics.** Sign-out flushes pending backup *before* dropping the session
   (`settings_screen.dart:667–676`) and clears the Google session too
   (`firebase_auth_repository.dart:170–182`). Deletion ordering (flush → wipe → delete cloud →
   delete account, each gated on the previous, `settings_screen.dart:730–759`) is crash-safe in
   both directions: die before the cloud delete and auto-restore refills the wiped device; die
   after it and the residual state is "account alive, nothing anywhere" — the outcome the
   student asked for. Orphaned-doc edge handled (`notSignedIn` treated as success,
   `firestore_backup_repository.dart:196–206`). `requires-recent-login` answered with a re-auth
   sheet, password held only for the call duration (:187–259). Login error mapping collapses
   `user-not-found`/`wrong-password` into `invalid-credential` (no enumeration aid, :280–283).
   §3.30 cross-account wipe compares uids and writes the new uid only after the wipe commits
   (`backup_gate.dart:68–104`).
7. **Android manifest & permissions.** Declared by the app: `POST_NOTIFICATIONS` (runtime-
   requested at the moment a review clock starts), `RECEIVE_BOOT_COMPLETED` (re-arming
   reminders across reboot — the 30-day cycle guarantees one). `SCHEDULE_EXACT_ALARM`
   deliberately absent, matching `inexactAllowWhileIdle` scheduling
   (`review_notification_service.dart:414–417`). Receivers `exported="false"` (:96–108).
   Merged-from-plugin permissions (verified in the release merged manifest):
   INTERNET/ACCESS_NETWORK_STATE (Firebase), USE_BIOMETRIC/USE_FINGERPRINT (local_auth),
   VIBRATE (notifications/haptics) — all justified. Exported components are exactly:
   MainActivity (launcher requirement), Firebase Auth GenericIdp/ReCAPTCHA activities, GMS
   RevocationBoundService, ProfileInstallReceiver — vendor-required, none custom.
8. **Windows target.** Runner sources are stock Flutter template; the only registry access is
   HKCU theme-preference reading (`windows/runner/win32_window.cpp`); no credential material
   anywhere under `windows/`. `firebase_options.dart` throws for Windows — the desktop target
   is local-first with no Firebase config compiled in.
9. **Logging hygiene.** Every `debugPrint` site inspected (12 sites): message strings carry
   exception text only — no emails, uids, or study content. Crashlytics receives structured
   errors via `recordError` with no `setUserId`/`setCustomKey` anywhere in `lib/`, so no uid
   or email reaches crash reports. Lesson names appear in notification bodies by design
   (lock-screen visibility is inherent to reminders and acknowledged in-code).

## Manifest & permission table

Merged release manifest audited (build intermediates, `processReleaseManifest`).

| Permission | Used by | Justified? |
|---|---|---|
| `POST_NOTIFICATIONS` | Review reminders (runtime-requested at clock start, `review_notification_service.dart:151–163`) | Yes |
| `RECEIVE_BOOT_COMPLETED` | Re-arm pending reminders after reboot/update (boot receiver, manifest :99–108) | Yes |
| `VIBRATE` | flutter_local_notifications + haptics (`core/haptics`) | Yes (merged) |
| `INTERNET` | Firebase Auth/Firestore/Crashlytics/App Check | Yes (merged from plugins; app manifest omits it, merger supplies it) |
| `ACCESS_NETWORK_STATE` | Firebase connectivity handling | Yes (merged) |
| `USE_BIOMETRIC` / `USE_FINGERPRINT` | Biometric app lock (local_auth) | Yes (merged) |
| `SCHEDULE_EXACT_ALARM` | — deliberately absent; inexact alarms chosen | Correct omission |

Components: MainActivity exported (launcher); both notification receivers non-exported;
remaining exported components are Firebase/GMS/profileinstaller vendor requirements.
`allowBackup=false` + exclude-all extraction rules (see Verified-fine #3). No cleartext
permitted, no deep-link filters, no content providers of our own.

## Rules review

**Repo `firestore.rules` (source of truth):**

```
match /users/{uid}/backup/{document=**} {
  allow read:  if request.auth != null && request.auth.uid == uid;
  allow create, update: if request.auth != null && request.auth.uid == uid
                        && request.resource.data.payload is bytes
                        && request.resource.data.payload.size() <= 921600;
  allow delete: if request.auth != null && request.auth.uid == uid;
}
match /{document=**} { allow read, write: if false; }
```

- **Least privilege:** yes — single uid-scoped subtree, explicit global deny.
- **uid scoping:** the path uid is compared against the token uid on every verb; no
  collection is open; no wildcard-auth grant anywhere.
- **vs §3.26's published rule:** repo is strictly narrower (adds byte-size ceiling, splits
  delete, widens match to subcollections defensively). Recommend updating §3.26's embedded
  snippet to match the file so the doc stops teaching the older shape.
- **Gap (process, not code):** deployment is manual (`firebase.json` wires it, nothing runs
  it); nothing in CI proves the deployed ruleset equals this file. Add a deploy step or a
  rules-diff check to the release checklist.
- **storage.rules:** intentionally absent — no `firebase_storage` dependency; bucket string
  in options is inert configuration.

**App Check state:** activated post-frame with Play Integrity (release) / debug provider
(kDebugMode only, token-to-logcat workflow respected) — **shadow mode**; nothing server-side
demands a token yet. See SEC-01 for what that means today and the exit condition.

---

*Report generated by Phase 1 SECURITY-AUDITOR. Read-only audit; only this file written.*
