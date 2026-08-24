# Ather (أثر)

> «أنت لا تُنهي الدروس، بل تُتقنها»

An offline-first Flutter app that measures **mastery** for Egyptian Thanaweya Amma students.
The student builds their own curriculum — their own subjects, chapters and lessons — then
proves understanding by entering real exam results question by question. Mastery is derived
from exam performance and nothing else, and it decays after 30 days — there is no
"mark as reviewed" button anywhere in the app.

Read **[PROJECT.md](PROJECT.md)** before changing anything: it carries the product rules, the
design system and every decision behind them.

## Run

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter test
```

To render every screen to a PNG for visual review (output is git-ignored):

```bash
flutter test tool/render/ather_render_test.dart --update-goldens
```
