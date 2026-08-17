# `public/` — the site, and the two pages Play requires to have a URL

Google Play will not publish Ather without a **privacy policy URL**, and will not
publish an app with account creation without a **web-accessible account-deletion
route**. Both have to be reachable by someone who has not installed the app, so
neither can live inside it.

They are served from **Firebase Hosting**, on the project that already exists:

| Page | URL once deployed |
|---|---|
| [index.html](index.html) | `https://ather-49705.web.app/` |
| [privacy.html](privacy.html) | `https://ather-49705.web.app/privacy` |
| [account-deletion.html](account-deletion.html) | `https://ather-49705.web.app/account-deletion` |

The landing page states four claims and every one of them is checkable against the
code. Keep it that way — it is the page a stranger reads first, and it is the only
page here that can be marketing rather than fact if nobody is watching.

`cleanUrls` in `firebase.json` is what drops the `.html`.

Firebase Hosting rather than GitHub Pages for a plain reason: **this repository is
private**, and Pages on a private repository needs a paid plan. The Firebase
project is already provisioned, costs nothing on the free tier for two static
files, and keeps the policy on infrastructure we already depend on.

## Before deploying — fill in the two placeholders

The files contain `[[PUBLISHER_NAME]]`, `[[CONTACT_EMAIL]]` and — on the landing page
only — `[[DOWNLOAD_URL]]`, deliberately left unfilled. **Do not deploy with them still in place** — a privacy policy that says
`[[CONTACT_EMAIL]]` is worse than none, because it is a published promise of a
contact route that does not exist.

```bash
grep -rn "\[\[PUBLISHER_NAME\]\]\|\[\[CONTACT_EMAIL\]\]\|\[\[DOWNLOAD_URL\]\]" public/
```

On the contact address: prefer a dedicated one (`privacy@…`, or a fresh Gmail) over
a personal address. This goes on a public page that a scraper will find, it is the
address parents will write to, and it is very hard to change once it is in a
published Play listing and a policy students have already been shown.

`PUBLISHER_NAME` must match the developer name on the Play listing exactly. A
policy naming a different entity than the store page is a rejection reason.

## Deploying

```bash
firebase deploy --only hosting --project ather-49705
```

This publishes to the public internet. Nothing deploys automatically — `firebase.json`
only makes it possible, the same arrangement the Firestore rules have.

## Keeping it honest

The policy describes real behaviour, and two lines of it are load-bearing enough to
break if the app changes:

- **"The cloud copy is automatic."** True because `BackupSyncNotifier` uploads on a
  20-second debounce and on every backgrounding, with no toggle. If a toggle is ever
  added, this sentence becomes a lie in the student's favour and still has to change.
- **"Your study record exists in exactly two places."** True because
  `android:allowBackup="false"` and `data_extraction_rules.xml` exclude both cloud
  backup and device transfer. This is the strongest claim on the page and the easiest
  to falsify by accident: turning Auto Backup back on, or adding any SDK that ships
  data off the device, makes it false. Both pages say it in both languages.
- **"No ads, no tracking, no analytics, no crash reporting."** True today. Adding
  Firebase Analytics or Crashlytics — the two most natural things to reach for next —
  breaks this and the Data safety form together.
- **"Your email is the only thing we know about you on the server."** True because the
  profile — the student's name and school year — is written to `SharedPreferences` and
  is not part of `StudyBackup`. Syncing the profile breaks this line, the Data safety
  form, and the under-18 section, which leans on it hardest.
- **The deletion order.** Both pages say device, then cloud, then account, because that
  is the order `_deleteEverything` actually runs in. They said the reverse until
  2026-08-17; the sequence is deliberate (an account deleted before its data leaves a
  student whose cloud copy outlives their ability to reach it), so if the code order
  ever changes, these pages are describing a promise that no longer holds.
