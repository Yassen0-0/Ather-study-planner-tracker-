# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

The app is native Flutter for Android. The public site in `public/` is plain static HTML/CSS on
Firebase Hosting (free Spark plan, so it cannot serve `.apk` files); for that surface, treat the
platform as `web`.

## Users

Egyptian Thanaweya Amma (الثانوية العامة) students. They reach the site on their phone, usually
from a link shared in a class group or by a friend, often on mobile data. The site's first job is
to convince the student themselves, not a parent or a teacher (confirmed 2026-09-25).

## Product Purpose

Ather measures **mastery**, not effort. The student builds their own curriculum (subjects,
chapters, lessons), then proves understanding by entering real exam results question by
question. Success is a student who knows which chapter is weakest and which lesson is overdue,
and studies that instead of re-reading what they already know.

## Positioning

Mastery comes from real exam results and nothing else. There is no "mark as reviewed" button,
homework is logged but never counted, and mastery decays: 30 days after a lesson was last proven
it turns red and has to be earned again with a new exam. The message the site must land first
(confirmed): *you will learn to study the right thing.*

## Operating Context

- Students record exam papers they actually sat (school, private tutor, past papers).
- The app works fully offline; one sign-in at first launch, then cloud backup is automatic.
- Distribution is a side-loaded APK from the public GitHub repo `Yassen0-0/ather-releases`,
  linked from the site. There is no Play Store listing yet.
- Arabic first, English second; Western digits (0123) in both locales.

## Capabilities and Constraints

- Android 7+, 64-bit (arm64) only.
- Free, no ads, no tracking, no third-party sharing. Store releases send crash reports to
  Firebase Crashlytics (failure details only, never the study record). Copy must say this.
- `1.10.0` does not install over `1.9.0` or older (the signing key was replaced); the site
  must carry the reinstall path: sync, uninstall, install, sign in.

## Brand Commitments

- Name: أثر / Ather. Tagline: «أنت لا تُنهي الدروس، بل تُتقنها».
- The mark: one organic, hand-wobbled ring, 27% of it in the brand blue
  (`assets/branding/glyph-mastery.svg`). Only ever scaled uniformly.
- One blue means *active*; red (#FF3B30) and green (#34C759) are verdicts about real work and
  never mean anything else. The user wants the site to share the app's colors, corner radii and
  Readex Pro, but rejected a flat transcription of the app's cards as ugly (2026-09-25).

## Evidence on Hand

- Real app screens rendered by `tool/render/ather_render_test.dart` (seeded demo data).
- Publisher: Yassen Yousry, yassen.y.mohamed.s@gmail.com. Privacy policy and account-deletion
  pages exist in `public/`.
- No testimonials, user counts, ratings or school endorsements exist. Do not invent any.

## Product Principles

1. The number is earned, never granted.
2. Tell the truth about decay; never flatter a stale lesson.
3. The student's record is theirs: offline, private, deletable.
4. Arabic is the primary language, not a translation.
