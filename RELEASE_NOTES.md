# Ather — release build, 2026-08-15 · 1.4.0+9

**A design release.** Nothing was added and nothing was taken away that a student uses. What
changed is that the design system underneath every screen is now one system instead of one and a
half, one long-standing bug in the week strip is fixed, and the dashboard lost a row of seven
circles that answered no question.

Installs straight over `1.3.1+8`. Same upload key, `versionCode` 8 → 9, every exam kept.

## What changed since 1.3.1+8

### The week strip pointed away from today

When you scrolled the strip on **مهامك** off the current week, a green edge glow appeared to bring
you back — on the wrong edge. Scroll back a week and today is *ahead* of you, so it sits past the
far edge; the glow lit the near one. A sign pointing away from the place it names. It was mirrored
the same way in both languages, so it was wrong in Arabic and in English equally.

The glow now marks the side today's week is actually on. Tapping it still returns in one move.

### The dashboard's calendar is gone

The strip on **النهارده** could not be tapped, selected nothing, and reported one fact — an exam
happened on this day — that the cards directly beneath it already state in full. Seven circles the
eye had to cross to reach the screen. The tasks screen keeps its strip, because there it picks the
day the list belongs to.

### The spacing scale is one ladder

It was `4 · 8 · 10 · 12 · 14 · 16 · 18 · 22 · 24` — a 4-grid and a 4+2 grid laid over each other,
which meant the rule the scale states about itself ("anything off this ladder is a sign the layout
is wrong") could only ever apply to half of it. It is now **`4 · 8 · 12 · 16 · 20 · 24`**.

The four off-grid rungs were deleted rather than redefined, so every one of the ~130 affected call
sites failed to compile until it was looked at. Nothing moved by more than 2dp. Two sub-grid values
survive as named, documented optical exceptions instead of being retyped at thirty call sites.

### The type scale has no invented sizes

Sixty call sites were hard-coding a font size rather than asking whether the role already had a
name. That is now **zero**, and the app went from 26 distinct sizes to 21: every half-step below 16
— 11.5, 12.5, 13.5, 14.5, 15.5 — folded into the whole number it was within half a point of.

### Smaller things

- **Both headers and the bottom sheet moved to the page margin.** An inner screen's title used to
  start 2dp inside its own content and a day screen's title 2dp outside it; the sheet was the only
  surface in the app that did not reach the margin at all.
- **The overall-mastery number and the sentence beside it align on a baseline**, not on their
  boxes. When "١ من ٤ باب اتقنتها" wrapped, bottom alignment lifted the first line clear of the
  number and left the second stranded next to it.
- **The password toggle is a drawn eye** instead of the literal strings `•••` and `———` — Latin
  punctuation sitting in an Arabic form.
- **Two near-identical red washes became one**, and a hairline colour that was doing two jobs under
  one name got the name of the job it actually does.

Nothing above changes a colour value, the typeface, the icon language, the motion system or a flow.

## Known issue, not fixed in this build

**The week strip on مهامك clips on phones narrower than about 368dp** — 8dp on a 360dp phone, which
is the commonest Android width. As a day picker each of its seven cells carries the app's 48dp
minimum touch target, and `7 × 48 = 336` plus the page margin does not fit. This predates this
build; this build made it 4dp better by moving the header to the page margin.

It is not fixed here because both available fixes give up something the app has committed to in
writing — the 48dp floor, or seeing the whole week at once — and that is a product decision.
Measurements and the recommendation: `ATHER_DESIGN_POLISH_REPORT.md` §12.

## Upgrading

**Installs straight over `1.3.1+8`, `1.3.0+7` or `1.2.0+6` on any 64-bit phone.** Same upload key,
`versionCode` 8 → 9, data kept. Nobody uninstalls anything.

A phone still carrying an old **debug-signed** build (the `1.0.0` test APKs, or the `1.1.0+2` /
`1.1.0+3` profile builds) will refuse this with `INSTALL_FAILED_UPDATE_INCOMPATIBLE` — different
signing identity. Save from **Settings → النسخة السحابية** first, then sign back in afterwards.

**A 32-bit phone cannot install Ather** and has not been able to since 1.3.0. It is refused cleanly
at install time, so a student on one keeps what they have and every exam in it.

## The build

| | |
|---|---|
| File | `Ather-1.4.0-build9-arm64.apk` |
| Size | 22.9 MB (24,059,384 bytes) |
| SHA-256 | `489cdb78a7da55a81b2c5cd242148c24f5fef8c63d694fe58dae598e080d8c61` |
| ABI | `arm64-v8a` only |
| `minSdkVersion` | 24 (Android 7.0) |
| `targetSdkVersion` | 36 |

```bash
flutter build apk --release --target-platform android-arm64
```

`--target-platform`, not `--split-per-abi`: splitting adds an ABI offset to the build number
(arm64 would ship as `2009`), and a phone on that line could never be upgraded by a Play release.
RELEASING.md §4.

## Signing

```
Signer #1 certificate DN: CN=yassen, OU=per, O=ather, L=giza, ST=giza, C=eg
Signer #1 certificate SHA-1 digest: f3eaec08a58d41d334d22abade33b1e89577623e
```

Identical to `1.3.1+8`, which is what makes this an in-place upgrade rather than a second app.
Not `CN=Android Debug`: the release config refuses to build rather than falling back to the debug
key. Procedure and the two ways this can go permanently wrong: RELEASING.md.

## Checks run on this build

| | |
|---|---|
| `dart analyze lib test` | no issues |
| `flutter test` | 224 passed |
| `tool/check_invariants.sh` | applicationId · keystore guard · `versionCode` 8 → 9 · `schemaVersion` unchanged · no conflict markers |
| `apksigner verify --print-certs` | upload key, SHA-1 matches 1.3.1+8 |
| Layout matrix | 320 / 360 / 600 / 840 dp, Arabic and English, light and dark |

No database change, so no migration: `schemaVersion` is untouched and the new build opens the old
file exactly as the last one did.

---

## Previously — 1.3.1+8

A point release on 1.3.0: the reminder now lands on the day the lesson screen turns rather than on
the hour, "تسيب الامتحان؟" gained the *"مش هينفع ترجع فيها."* every other irreversible dialog
already had, and two unused dependencies were removed. The Firestore security rules entered version
control with it (`firestore.rules`) — committing them does not deploy them; see RELEASING.md §4a.

## Previously — 1.3.0+7

**A third of the download**: 61.9 MB → 22.9 MB, by shipping 64-bit ARM only. And three silent bugs,
each of which could cost a student work: the cloud backup could overwrite tasks with nothing, a
second account could inherit the first student's curriculum, and the review clock could run a day
behind.
