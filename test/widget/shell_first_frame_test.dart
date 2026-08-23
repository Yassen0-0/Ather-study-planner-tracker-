import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ather/app/app.dart';
import 'package:ather/core/clock/clock.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/widgets/ather_icons.dart';
import 'package:ather/domain/entities/chapter.dart';
import 'package:ather/domain/entities/exam_entry.dart';
import 'package:ather/domain/entities/homework_entry.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/entities/study_snapshot.dart';
import 'package:ather/domain/entities/subject.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/providers/auth_providers.dart';
import 'package:ather/presentation/providers/backup_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/fake_auth.dart';
import '../support/fake_backup.dart';

// T3 cold-open guard: the first frame must already show every unselected tab
// glyph in its resting grey and the selected one in accent, with the pick
// bounce sitting at rest (scale 1) -- in both themes, with no tap anywhere.
//
// This exists because the SP-02 bounce layer seeded its SpringController at
// the default 0, so every glyph mounted inside Transform.scale(0): an empty
// bar that stayed empty until the student tapped a tab. The tween underneath
// was never at fault -- TweenAnimationBuilder with an end-only tween mounts
// *at* its end -- which is why the assertions read both layers separately:
// the bounce's transform, and the tint/weight TabGlyph actually paints with.
//
// The bug was theme-independent by mechanism; dark only *looked* fine when it
// was observed behind reduce-motion (which jumps the spring to rest). Both
// themes are pinned here so neither can regress silently again.

final DateTime kNow = DateTime(2026, 6, 1);

/// The four glyphs the bottom bar owns; nothing else in the app draws them.
const Set<AtherGlyph> _tabGlyphs = <AtherGlyph>{
  AtherGlyph.home,
  AtherGlyph.review,
  AtherGlyph.chart,
  AtherGlyph.tasks,
};

StudySnapshot _emptySnapshot() => StudySnapshot(
  subjects: const <Subject>[
    Subject.seeded(id: 1, code: SubjectCode.biology, sortOrder: 0),
    Subject.seeded(id: 2, code: SubjectCode.physics, sortOrder: 1),
    Subject.seeded(id: 3, code: SubjectCode.chemistry, sortOrder: 2),
    Subject.seeded(id: 4, code: SubjectCode.english, sortOrder: 3),
  ],
  chapters: const <Chapter>[],
  lessons: const <Lesson>[],
  exams: const <ExamEntry>[],
  homework: const <HomeworkEntry>[],
);

/// Pins the theme so the palette assertions below are deterministic instead of
/// inheriting whatever ThemeMode.system resolves to on the CI host.
class _PinnedThemeMode extends ThemeModeNotifier {
  _PinnedThemeMode(this.mode);

  final ThemeMode mode;

  @override
  ThemeMode build() => mode;
}

Future<Widget> _boot(ThemeMode mode) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final preferences = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(FakeAuthRepository.signedIn()),
      backupRepositoryProvider.overrideWithValue(
        FakeBackupRepository.failing(),
      ),
      sharedPreferencesProvider.overrideWithValue(preferences),
      snapshotProvider.overrideWith(
        (ref) => Stream<StudySnapshot>.value(_emptySnapshot()),
      ),
      clockProvider.overrideWithValue(MutableClock(kNow)),
      nowProvider.overrideWith((ref) => Stream<DateTime>.value(kNow)),
      themeModeProvider.overrideWith(() => _PinnedThemeMode(mode)),
    ],
    child: const AtherApp(),
  );
}

List<AtherIcon> _barIcons(WidgetTester tester) =>
    tester
        .widgetList<AtherIcon>(
          find.byWidgetPredicate(
            (w) => w is AtherIcon && _tabGlyphs.contains(w.glyph),
          ),
        )
        .toList(growable: false);

/// The uniform factor of the nearest Transform above [icon] -- the pick
/// bounce's scale (Pressable's press spring sits one level above it).
double _bounceScaleOf(AtherIcon icon, WidgetTester tester) {
  Transform? bounce;
  tester.element(find.byWidget(icon)).visitAncestorElements((ancestor) {
    if (ancestor.widget is Transform) {
      bounce = ancestor.widget as Transform;
      return false;
    }
    return true;
  });
  return bounce!.transform.storage[0];
}

void _expectFirstFramePainted(AppColors palette, WidgetTester tester) {
  final icons = _barIcons(tester);
  // Exactly four: if any other surface starts drawing a tab glyph this must
  // be tightened, not loosened.
  expect(icons, hasLength(4));

  for (final icon in icons) {
    // The bounce sits at rest on the very first frame -- never mid-dip,
    // never at 0.
    expect(_bounceScaleOf(icon, tester), 1.0,
        reason: '${icon.glyph} must mount unscaled');
    // Weight axis: the selected glyph fully selected, the rest untouched --
    // the end-only tween mounts at its end, so there is no "warming up".
    final expectedSelection = icon.glyph == AtherGlyph.home ? 1.0 : 0.0;
    expect(icon.selection, expectedSelection,
        reason: '${icon.glyph} selection axis');
    // And the tint it actually paints with is opaque and legible: accent for
    // "you are here", the palette's inactive-tab grey otherwise.
    final expectedColor = icon.glyph == AtherGlyph.home
        ? palette.accent
        : palette.textTertiary;
    expect(icon.color, expectedColor, reason: '${icon.glyph} tint');
  }
}

void main() {
  // The android pin routes the bar through its production glass path
  // (_glassPill gates the BackdropFilter on platform). The reset has to sit
  // in a finally *inside* the body: the framework verifies its debug globals
  // before test-framework tearDowns run.
  Future<void> pinnedAndroid(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  testWidgets('light theme: every tab paints on the cold-open first frame', (
    tester,
  ) async {
    await pinnedAndroid(() async {
      await tester.pumpWidget(await _boot(ThemeMode.light));
      await tester.pump();
      await tester.pump();

      // Before any tap, before anything settles.
      _expectFirstFramePainted(AppColors.light, tester);

      // And after everything settles: identical. Rest is not a frame that
      // arrives late.
      await tester.pumpAndSettle();
      _expectFirstFramePainted(AppColors.light, tester);
    });
  });

  testWidgets('dark theme: every tab paints on the cold-open first frame', (
    tester,
  ) async {
    await pinnedAndroid(() async {
      await tester.pumpWidget(await _boot(ThemeMode.dark));
      await tester.pump();
      await tester.pump();

      _expectFirstFramePainted(AppColors.dark, tester);

      await tester.pumpAndSettle();
      _expectFirstFramePainted(AppColors.dark, tester);
    });
  });
}
