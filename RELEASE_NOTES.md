# Ather — release build, 2026-08-04

Motion system (M-01…M-19) + the glass tab bar. No redesign: no layout, colour, spacing,
typography, copy, icon or navigation change, and `lib/domain/` is untouched.

## Which APK to install

| File | Size | Use |
|---|---|---|
| `app-arm64-v8a-release.apk` | 21.8 MB | **Almost every real phone since ~2017.** Start here. |
| `app-armeabi-v7a-release.apk` | 19.3 MB | Older 32-bit devices. |
| `app-x86_64-release.apk` | 23.1 MB | Emulators (Android Studio AVD). |
| `app-release.apk` | 59.8 MB | Universal — all three ABIs. Use only if unsure which one fits. |

All in `build/app/outputs/flutter-apk/`.

```bash
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

Installing by hand instead: copy the APK to the phone and open it, allowing "install from
unknown sources" for whichever app opens it.

**Size did not regress.** The pre-motion build was 22.8 MB on arm64; this one is 21.8 MB. No
dependency was added — the whole motion system is built on Flutter's own implicit animations.

## ⚠️ Signed with the Android debug key

The build verifies (APK Signature Scheme v2) and installs, but the signer is `CN=Android Debug`
— Flutter's default, still carrying its `TODO` in `android/app/build.gradle.kts`.

This is fine for testing and **not** fine for release:

- It cannot be uploaded to Google Play.
- A debug-signed install cannot later be upgraded in place by a properly signed build — testers
  would have to uninstall first, losing their local data.

To fix it (a credential step, deliberately left to a human):

1. Generate a keystore and keep it out of the repo.
2. Put its credentials in `android/key.properties` — git-ignored, never committed.
3. Replace the `release` block's `signingConfig` in `android/app/build.gradle.kts` to read from it.

Flutter's guide: <https://docs.flutter.dev/deployment/android#signing-the-app>

## What to look at when testing

The motion is deliberately quiet — the point is that a change in the number becomes legible, not
that the app feels animated. Things worth checking on a real device:

1. **The count-up.** Record an exam. The lesson, chapter, subject and dashboard percentages all
   count to their new value over 600ms. The *colour* switches instantly on the first frame — if
   you see red fade through black into green, that is a bug.
2. **The glass bar.** Scroll the dashboard. Cards should blur under the bottom bar, and the last
   card should travel behind it rather than stopping short. The FAB stays fully opaque black.
3. **Step 4 of the wizard.** The result counts up from zero **once**. Go back to step 3 and
   forward again — it must show the number, not replay. Below it, `before → arrow → after`
   arrives in reading order.
4. **Tab switching.** A cross-fade, no slide. Switch to Review and back into a subject you had
   opened — your place should be preserved.
5. **Deleting a chapter or lesson.** Open it, delete it, and watch the row you came back to
   collapse while the rows below settle into the gap. This is the only place height animates.
6. **Reduced motion.** Turn on *Settings → Accessibility → Remove animations* and reopen. Every
   screen should land on its final state immediately — but the glass bar stays frosted. Blur is
   a visual effect, not motion, and is deliberately not disabled.
7. **English.** Settings → English. Nothing should slide the wrong way; nothing in this system
   translates horizontally at all. Bars and numbers stay left-to-right on purpose. The wizard's
   before→after arrow should now point right in English and left in Arabic.

## Known limitations

- **No profiling has been done on real hardware.** Every animation touches `transform`/`opacity`
  only (except the collapsing row), nothing animates on scroll position, and there is exactly one
  `BackdropFilter` — so the profile is expected to be boring, but it is unmeasured. The blur is
  the one thing worth watching on a low-end device; if it costs frames, the fallback to an opaque
  bar is a one-line change in `app_shell.dart`.
- **The animated Lottie icons from the handoff are not included.** `lordicon 1.0.3` exposes no
  speed setter and no duration getter, so the spec's "fit the draw to 240ms or 600ms" rule cannot
  be built and all eleven icons would have shipped static. Reasoning in `PROJECT.md` §9.
- **Contrast:** the inactive tab label is 2.80:1 at 11px, which fails WCAG AA. Pre-existing token
  decision, unchanged here; glass does not make it worse (2.55–2.80:1 measured).
