# Ather — release build, 2026-08-05

**Visual refresh**: one brand blue, a redrawn brand mark, new subject icons, a week strip that
drags between weeks, and the removal of the "+" button. Full reasoning in PROJECT.md §3.27,
§3.28, §3.29 and §7a — where the design contradicted a standing rule, the design won and the
rule was rewritten.

**This is the first properly signed release.** See "Signing" below — it changes what testers
have to do.

## Which APK to install

| File | Size | Use |
|---|---|---|
| `app-arm64-v8a-release.apk` | 22.8 MB | **Almost every real phone since ~2017.** Start here. |
| `app-armeabi-v7a-release.apk` | 20.5 MB | Older 32-bit devices. |
| `app-x86_64-release.apk` | 24.2 MB | Emulators (Android Studio AVD). |

All in `build/app/outputs/flutter-apk/`.

```bash
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Installing by hand instead: copy the APK to the phone and open it, allowing "install from
unknown sources" for whichever app opens it.

## ⚠️ Every existing tester must uninstall first

The previous build was signed with the Android debug key. This one is signed with the real
upload key, and **Android will not install one over the other** — the install fails with
`INSTALL_FAILED_UPDATE_INCOMPATIBLE`.

So each tester has to uninstall Ather before installing this build, and **their local data goes
with it**: chapters, lessons, exam history, tasks. There is no way around it; a signing key
cannot be changed in place. It is a one-time cost — every build after this one upgrades
normally.

If a tester has data worth keeping, have them open Settings → النسخة السحابية → "احفظ دلوقتي"
**before** uninstalling. Signing back in on the fresh install restores it.

## Signing

Signed with the upload key at `C:\Users\<you>\keys\ather-upload.jks`, credentials in the
git-ignored `android/key.properties`. Verified:

```
Signer #1 certificate DN: CN=yassen, OU=per, O=ather, L=giza, ST=giza, C=eg
Signer #1 certificate SHA-1 digest: f3eaec08a58d41d334d22abade33b1e89577623e
```

Not `CN=Android Debug`. Procedure and the two ways this can go permanently wrong: RELEASING.md.

**The keystore must be backed up somewhere that is not the build machine.** If it is lost,
Google Play will not accept an update signed with anything else and Ather can never be updated
again.

## What to look at when testing

The refresh is a colour and navigation change, not a rebuild. Things worth checking on a real
device:

1. **The blue means "active", never "correct".** The selected tab, every progress fill, a ticked
   checkbox, the "امتحن" pill, the primary button. Green still means mastered (≥90) and red
   still means weak or overdue — a bar for a 90% lesson is green, not blue. If you ever see blue
   where the app is making a judgement about your work, that is a bug.
2. **The week strip drags.** Swipe it sideways on Today or Tasks. It moves a week at a time and
   springs back if you let go early. Off the current week, a green glow appears **on the side you
   would drag toward to get home** — check it flips sides between Arabic and English. Tap it to
   jump back.
3. **Today is underlined, not filled.** A filled circle means "that day is done". Today is a dot,
   a darker letter and a rule under it.
4. **There is no "+".** Logging an exam starts either from the "امتحن" pill on the dashboard's
   "اللي بعده" card, or the button at the bottom of a lesson. Both already know which lesson you
   mean — the old "+" had to ask.
5. **The new mark.** Lock screen, splash, and the launcher icon on your home screen: a hand-drawn
   ring with a blue run over the first quarter of it. If the launcher still shows the old
   ring-and-dot, clear the launcher's icon cache or reboot.
6. **English.** Settings → English. The whole layout mirrors; numbers and bars stay
   left-to-right on purpose.
7. **This is the first AOT build of the refresh.** The debug build used for development runs on
   the JIT at ~93 MB. This one is ~23 MB and compiled — scrolling and the glass bar should feel
   noticeably better than anything you have seen so far.

## Known limitations

- **The return-to-today glow overlays the strip's first day cell.** On the Tasks screen, where
  the strip is a day picker, that one day cannot be tapped while another week is on screen. The
  handoff is explicit that the glow itself is tappable, so it was kept; narrowing it or making
  its inner half inert would fix it.
- **The English copy is not verbatim from the handoff's copy table.** Where the table and the
  existing translation differ only by near-synonym or title case ("Exam History" vs "Past
  exams"), the existing string was kept — the table covers ~40 of ~200 keys, and converting only
  those would leave half the app in a different convention.
- **No profiling has been done on real hardware.** Every animation touches `transform`/`opacity`
  only, nothing animates on scroll position, and there is exactly one `BackdropFilter`.
- **Contrast:** the inactive tab label is 2.80:1 at 11px, which fails WCAG AA. Pre-existing token
  decision, unchanged here.
- **Google Sign-In will fail for testers until the new key's SHA-1 is registered with Firebase.**
  See below.

## Before sending this to anyone

Register the upload key's fingerprint with Firebase, or **sign-in breaks for every tester while
continuing to work in development**:

Firebase console → project `ather-49705` → ⚙️ Project settings → under `com.ather.app` → **Add
fingerprint**:

```
SHA-1   F3:EA:EC:08:A5:8D:41:D3:34:D2:2A:BA:DE:33:B1:E8:95:77:62:3E
SHA-256 0D:19:D7:B1:CF:02:8A:32:EA:73:F7:8E:F4:7B:14:2C:0C:93:B3:C7:DA:53:CE:28:7A:5B:63:C7:63:6A:20:23
```

Then re-download `google-services.json` into `android/app/` and rebuild. The debug key's SHA-1 is
already registered, which is why sign-in works locally today.
