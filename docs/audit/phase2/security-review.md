# Phase 2 — Cross-Review: SECURITY (of phase1/security-auditor.md)

Reviewer: SECURITY-CROSS-REVIEWER · Date: 2026-08-25 · Base: `ai-audit/2026-08-25` @ working tree.
Method: every citation opened personally; static reading + rg/git only; no builds, no code changes.
Secrets discipline: no secret material copied into this report; `android/key.properties` was never opened (verified ignored via `git check-ignore` only).

## Summary stats

| Verdict | Count | Findings |
|---|---|---|
| CONFIRMED | 5 | SEC-01, SEC-02, SEC-04, SEC-05, SEC-06 |
| STALE | 1 | SEC-03 |
| FALSE-POSITIVE | 0 | — |
| DUPLICATE | 1 (partial) | SEC-04 ⊃ data-auditor D-01 |
| CONFIRMED-with-correction | 1 | SEC-07 |

Re-ranked: **0 × P0** · **2 × P1** · rest P2/informational. No rules hole, no plaintext creds, no
backup-overwrite vector found in the security surface reviewed here. The critical check demanded
by phase 2 — `firestore.rules` unauthenticated access — came back clean **in the repo file**
(firestore.rules:27–53: every verb gated on `request.auth.uid == uid`; explicit deny-all catch-all
at :60–62). Deployed-vs-repo parity is unverifiable from the client and stays the one [OWNER]
action that guards against a de-facto P0 (see SEC-01/W1).

---

## Per-finding verdicts

### SEC-01 — App Check activated but never enforced · claim P1 → **CONFIRMED** · P1 [OWNER] · Effort S (console) + M (staged watch)

- Evidence checked: `lib/main.dart:130–154` (`_activateAppCheck`, Play Integrity provider,
  failure caught non-fatal); `lib/main.dart:115–124` (ship-before-enforce rationale, versions
  1.2.0/1.3.1 named as token-less); `pubspec.yaml:64–69` (added 2026-08-15 after three live
  accounts were minted from the bare API key); `lib/firebase_options.dart:55–64` (public config).
- Calibration honesty: confidentiality survives — the rules admit a forged-install attacker only
  to their own `users/{uid}/backup/**`. What breaks is quota/billing integrity on a shared
  project, which is a real availability risk to real students' backups and is *documented as
  already exploited*. Kept at P1; not P2, because it is the sole control between the public key
  and unlimited abuse and its absence has been demonstrated in production.
- Cannot be verified from repo (console switch state) — hence [OWNER].
- Fix: budget alert now; watch *unverified requests* until 1.2.x/1.3.x base drains; enforce Auth
  + Firestore in the same window. One-line: flip enforcement server-side after the drain metric.
- Risk: premature enforcement bricks sign-in for un-updated installs (main.dart:115–124).

### SEC-02 — Email verification gates nothing (recovery gap, not access gap) · claim P2 → **CONFIRMED** · P2 · Effort M

- Evidence checked: `lib/presentation/providers/auth_providers.dart:35–47` ("gates a prompt,
  never access"); `lib/data/auth/firebase_auth_repository.dart:62–91` (register best-effort
  verification; send failure returns `false`, account stands — exact code at :80–85);
  `firebase_auth_repository.dart:129–137` (reset goes to whatever address is on file).
- Threat model fit: no cross-student impact; harm is self-lockout-from-recovery + orphaned cloud
  blob. Correctly P2 hardening. Deliberate trade-off documented in-code (:40–43).
- N-id: NEW. One-line fix: escalate the banner to an interstitial after N days + let unverified
  users change their own address (re-sends verification to the new one).

### SEC-03 — Password floor is 6 chars, no denylist · claim P2 → **STALE** (headline false; residual sliver real) · P2-optional · Effort S

- Evidence checked: `lib/presentation/auth/login_screen.dart:40` —
  `_minPasswordLength = 8`; `:83–96` — enforced **registration-only**, with an in-code record
  that the old 6-for-both floor was deliberately replaced and that 8 pairs with the Identity
  Platform policy; `firebase_auth_repository.dart:285` (`too-many-requests` mapped) confirmed.
- Why stale: the claim "floor is 6" contradicts shipped code. The 2026-08-15 `'123456'`
  demonstration predates this change.
- Residual truth: rg over `lib/` finds no breached/common-password denylist — that part stands,
  worth S effort on registration only. Server-side policy state is console-side: add "[OWNER]
  confirm Identity Platform minimum-password policy is active" to W1.
- N-id: NEW. One-line fix: top-N common-password denylist on register path only.

### SEC-04 — "Delete everything" leaves PII-bearing preferences on device · claim P2 → **CONFIRMED**, re-ranked **P1** · Effort S

- Evidence checked: `lib/presentation/settings/settings_screen.dart:730–759` — flush → clear DB
  → clearTasks → deleteCloudData → deleteAccount; **zero SharedPreferences mutation anywhere in
  either deletion path** (also `_retryWithPassword` :744–759). Repo-wide rg for `prefs.remove|clear()`:
  only `exam_entry_screen.dart:208` (per-draft, normal flow) and
  `review_notification_service.dart:440` (fingerprint marker). Surviving keys verified at:
  `_kProfileNameKey` set `app_providers.dart:260–268`; lock method/passcode hash/digits
  `auth_providers.dart:130–174`; `kLastAccountUidKey` `backup_gate.dart:70–102`; `_draftKey`
  `exam_entry_screen.dart:183–202`.
- Re-rank justification: this is exactly the ladder's P1 row — data-at-rest exposure of a
  **minor's** display name plus lock config on a handed-over/rooted device, and the draft subset
  leaks Student A's scores into Student B's wizard (cross-student). Data-auditor rated the same
  drafts leak P1 (D-01); consistency demands P1 here too.
- **DUPLICATE (partial): data-auditor.md D-01** covers the exam-draft subset (same root cause,
  same fix site). SEC-04 is the superset (name, lock keys, last uid) — keep both, execute once.
- N-id: **N20** (its "clear `exam_draft_*` keys on account wipe" clause); extend scope beyond N20
  to all app-owned keys. One-line fix: after `deleteAccount()` succeeds, remove name/drafts/
  lock/passcode/fingerprint/last-account keys — never before success.

### SEC-05 — App-lock passcode: salted single-round SHA-256 · claim P2 informational → **CONFIRMED** (informational) · Effort M

- Evidence checked: `lib/core/auth/app_passcode.dart:24` (`minLength = 4`), `:29–33` (fresh
  16-byte `Random.secure` salt per hash), `:56–58` (single sha256 over salt‖password),
  `:66–73` (constant-time compare present). Storage shape `<salt>:<hash>` confirmed via
  `auth_providers.dart:144–174`.
- Threat-model calibration correct in the source report: privacy convenience behind the OS
  screen lock, explicitly not a boundary; rooted-device brute force of a 4-char floor is trivial.
  Stays informational P2; do not spend before P1s. Versioned PBKDF2 migration if pursued.
- N-id: NEW. One-line fix: keyed stretching (~100k rounds) behind a stored-format version byte.

### SEC-06 — Cloud backup blob not end-to-end encrypted · claim P2 informational → **CONFIRMED** (informational) · Effort L (optional)

- Evidence checked: `lib/data/backup/firestore_backup_repository.dart:155–193` — upload builds
  gzip/base64 JSON into `Blob(bytes)` + `checksum` + metadata fields (:177–190); no cipher
  anywhere in the file; checksum protects integrity only.
- Posture agrees with §3.26 mirror design; the realistic exposure is "a future rules regression"
  which the deny-all + parity check (W1) addresses more cheaply than crypto. Not recommended now.
- N-id: NEW. One-line fix: none now; if ever, envelope encryption keyed from the account password
  with v-ladder migration.

### SEC-07 — Duplicate tracked `google-services.json` under `.claude/worktasks/` · claim P2 hygiene → **CONFIRMED**, one correction · Effort S

- Evidence checked: both files exist; `diff -q` reports them **currently identical** (so "drift"
  is prospective, not present — the report's "stale-capable" wording was fair, its exploit
  scenario correctly hypothetical). Legacy `com.sahm.sahm` client entries present in **both**
  copies (:57, :65) matching `firebase_options.dart:57–59` commentary. Public identifiers only;
  correctly *not* called a secret leak.
- N-id: NEW. One-line fix: delete `.claude/worktasks/release-apk/android/app/google-services.json`,
  rely on the canonical `android/app/google-services.json`.

---

## Verified-fine claims spot-checked (agreed, do not re-litigate)

- **No secrets tracked:** `git ls-files` shows no `.jks/.keystore/key.properties/service-account`;
  `git check-ignore` pins `android/key.properties` to `android/.gitignore:12`;
  `.gitignore:72–79` covers `key.properties`, `*.jks`, `*.keystore` with correct intent prose.
  `android/app/build.gradle.kts:93` reads `storePassword` solely from `keystoreProperties`.
  Real `android/key.properties` exists locally and is ignored (contents deliberately not read).
- **Backup/transfer off:** AndroidManifest `android:allowBackup="false"` +
  `dataExtractionRules` wired; `data_extraction_rules.xml` excludes `domain="root" path="."` for
  **both** cloud-backup and device-transfer channels.
- **Rules file least privilege:** see summary block above. `firebase.json` wires `firestore.rules`
  but nothing deploys or diffs it in CI — process gap, correctly characterized by the report.
- **No denylist exists** (supports the surviving half of SEC-03).

## Needs-map tagging

SEC-04 → **N20** (+ dup D-01). SEC-01/02/05/06/07 → **NEW** (no N-item covers auth hardening,
App Check enforcement, prefs purge beyond N20's drafts clause, E2E crypto, config duplication).
The phase-0 list contains no security items at all; this workstream introduces them.

## Workstream proposal — **W-security: "Own-the-keys-off" hardening**

Exact file set:

1. `.claude/worktasks/release-apk/android/app/google-services.json` — **delete** (SEC-07).
2. `lib/presentation/settings/settings_screen.dart` — purge app-owned pref keys after successful
   `deleteAccount()`/`_retryWithPassword` success tail (SEC-04/N20/D-01).
3. `lib/presentation/providers/auth_providers.dart` + `lib/presentation/providers/app_providers.dart`
   — expose a single `wipeAccountPreferences()` helper owning the key constants (keeps key names
   out of the screen; supports M5/F-02 dedup instead of fighting it).
4. `lib/presentation/exam_entry/exam_entry_screen.dart` — route `_draftKey` removal through the
   helper (D-01 closure).
5. `lib/presentation/auth/login_screen.dart` — optional registration-only denylist (SEC-03 residue).
6. `docs/reviews/security-audit-2026-08-15.md` successor note / PROJECT.md §3.26 — [DOC] refresh
   of the published rules snippet (repo file supersedes it).

Ordered sequence:

1. [CODE] Delete duplicate google-services.json (trivial, zero-risk, removes drift trap).
2. [CODE] `wipeAccountPreferences()` + wire into both deletion tails; widget test asserting
   prefs empty after mocked-successful delete and untouched after mocked-failed delete.
3. [OWNER] Console, one window: confirm deployed Firestore ruleset == repo file (or run
   `firebase deploy --only firestore:rules`) → set budget alert → when *unverified requests*
   metric drains, enforce App Check on **Auth + Firestore together** (SEC-01).
4. [CODE] Email-verification interstitial + self-service address change (SEC-02).
5. [CODE, optional] Registration denylist (SEC-03 residue); passcode stretching (SEC-05) last,
   versioned format only.

Risks & sequencing constraints:

- Rules deploy is manual and outside CI; a deploy that doesn't match the repo file silently
  changes the confidentiality contract — hence step 3a is *verify-or-deploy once*, then diff-check
  in release checklist. [OWNER]
- Enforcing App Check before the 1.2.x/1.3.x installed base drains bricks sign-in/backup for
  those students (main.dart:115–124); Auth and Firestore must flip in the same window to avoid
  the signed-in-but-backup-fails half-state. [OWNER]
- Prefs purge must stay **after** successful account deletion or a failed cloud-delete strands a
  student without their settings; interacts with N4/N14 workstream (backup gate) — land the
  backup-gate fixes first so the deletion-tail tests don't churn twice. [CODE]
- Draft-key handling overlaps maintainability M5 (duplicate wipe sequences) and architecture F-02;
  implement via the shared helper in (3) rather than editing both call sites independently.

*Phase 2 review. Read-only; only this file written.*
