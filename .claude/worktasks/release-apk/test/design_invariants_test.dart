import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/theme/app_spacing.dart';
import 'package:ather/core/widgets/icon_motion.dart';

/// The design decisions that keep getting undone, asserted mechanically.
///
/// ## Why this file exists
///
/// The approved visual refresh — one brand blue, and a tab bar with four slots
/// and no raised "+" — has been reverted **twice** by agents working on this
/// project. Neither revert was careless. Both were the predictable result of a
/// setup that taught the wrong answer:
///
/// * the refresh lived on an unmerged branch, so every worktree cut from
///   `master` started from the design that came before it;
/// * a worktree directory was named after the design branch while a *different*
///   branch was checked out inside it, so the name said one thing and the
///   content said another;
/// * and `PROJECT.md` — the file whose standing rule orders every agent to read
///   it first and treat it as truth — still described the superseded design in
///   detail. An agent following instructions exactly would defend it.
///
/// The first two are fixed by history: the refresh is on `master` and the extra
/// branches are gone. The third is fixed by prose, which is the weakest kind of
/// fix, because prose can be skimmed, contradicted by neighbouring prose, or
/// simply not believed.
///
/// **This file is the part that cannot be skimmed.** These are not tests of
/// behaviour a student can see going wrong; they are tripwires. If one fails,
/// the likely cause is not a bug in the widget it names — it is that the tree
/// has been rebuilt on a stale base. Read the failure that way first.
void main() {
  group('the palette carries one brand colour, not two greys', () {
    // The pre-refresh palette was white + grey + black plus a red and a green,
    // and it is what a revert lands back on. `accent` is the single token that
    // cannot exist in it.
    test('accent exists and is a real colour, not a grey', () {
      for (final (name, colors) in <(String, AppColors)>[
        ('light', AppColors.light),
        ('dark', AppColors.dark),
      ]) {
        final accent = colors.accent;
        final hsl = HSLColor.fromColor(accent);

        expect(
          hsl.saturation,
          greaterThan(0.4),
          reason:
              '$name accent is $accent, which is unsaturated. The approved '
              'design is built on one brand blue; a grey here means the '
              'palette has been reverted to the black-and-white one.',
        );
        expect(
          hsl.hue,
          inInclusiveRange(180, 280),
          reason:
              '$name accent is $accent, which is not in the blue range. The '
              'brand colour is a blue — see PROJECT.md §3.27.',
        );
      }
    });

    test('accent is distinct from the two state colours', () {
      // Blue is a *brand* colour and green is a verdict. Collapsing them is the
      // other way this design gets flattened: "everything active is green" was
      // the pre-refresh behaviour.
      for (final colors in <AppColors>[AppColors.light, AppColors.dark]) {
        expect(colors.accent, isNot(colors.right));
        expect(colors.accent, isNot(colors.wrong));
      }
    });
  });

  /// §3.19 reasoned about the tab bar's contrast instead of measuring it, and
  /// the reasoning -- "everything that passes under this bar is lighter than the
  /// tint" -- was true of the surfaces and false of the content drawn on them.
  /// An analytics column sat at 1.90:1 for a year.
  ///
  /// The numbers are now a tripwire rather than a paragraph. This is the check
  /// that would have caught it, so it is also the check that stops the two
  /// tokens involved from drifting back.
  group('the inactive tab label survives the glass', () {
    double luminance(Color c) {
      double channel(double v) {
        final s = v;
        return s <= 0.03928
            ? s / 12.92
            : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
      }

      return 0.2126 * channel(c.r) +
          0.7152 * channel(c.g) +
          0.0722 * channel(c.b);
    }

    double ratio(Color a, Color b) {
      final la = luminance(a);
      final lb = luminance(b);
      final hi = math.max(la, lb);
      final lo = math.min(la, lb);
      return (hi + 0.05) / (lo + 0.05);
    }

    /// The bar is `card` at [AppMotion.glassTint] over whatever is scrolling
    /// underneath.
    Color bar(AppColors colors, Color under) =>
        Color.alphaBlend(colors.card.withValues(alpha: AppMotion.glassTint), under);

    test('clears 3:1 over every solid area that can scroll under it', () {
      for (final (name, colors) in <(String, AppColors)>[
        ('light', AppColors.light),
        ('dark', AppColors.dark),
      ]) {
        // Not just the surfaces: the content. These are the wide, solid fills a
        // list or a chart puts under the pill.
        final under = <String, Color>{
          'pageBackground': colors.pageBackground,
          'card': colors.card,
          'muted': colors.muted,
          'fill': colors.fill,
          'track': colors.track,
          'accent (chart column)': colors.accent,
          'right (mastery fill)': colors.right,
          'wrong (mastery fill)': colors.wrong,
        };

        under.forEach((what, colour) {
          final measured = ratio(colors.textTertiary, bar(colors, colour));
          expect(
            measured,
            greaterThanOrEqualTo(3.0),
            reason:
                '$name: the inactive tab label is ${measured.toStringAsFixed(2)}:1 '
                'over $what. The fix is the pair -- raise AppMotion.glassTint '
                'and move textTertiary together. Neither alone reaches 3:1 '
                'without either flattening the label into textSecondary or '
                'making the glass opaque enough to stop being glass. See §3.19.',
          );
        });
      }
    });

    test('stays quieter than body text, which is what makes it a tab label', () {
      // The counter-pressure on the check above: darkening the label until it
      // passes is easy, and at #636369 it *is* textSecondary -- at which point
      // an inactive tab reads as loud as the content it sits under.
      for (final colors in <AppColors>[AppColors.light, AppColors.dark]) {
        expect(
          ratio(colors.textTertiary, colors.card),
          lessThan(ratio(colors.textSecondary, colors.card)),
        );
      }
    });
  });

  group('the tab bar has four slots and no raised "+"', () {
    test('the tab bar draws four destinations and no "+"', () {
      // The raised centre "+" asked the student which lesson they meant, after
      // the fact, from a context that had none, and was dead whenever nothing
      // was recordable (PROJECT.md §3.28).
      //
      // This used to be asserted by demanding that `AtherGlyph.plus` not exist
      // at all, on the reasoning that a glyph nobody can draw cannot come back
      // by habit. That guard has now outlived its accuracy: adding a subject
      // needed a "+" beside the subjects heading on the dashboard, which is a
      // different control in a different place answering a question the raised
      // button never could.
      //
      // So the invariant is asserted where it actually lives -- the tab bar's
      // own source -- rather than by the absence of a shape. Four glyphs, and
      // none of them a plus.
      final source = File(
        'lib/presentation/shell/app_shell.dart',
      ).readAsStringSync();
      final glyphs = RegExp(
        r'glyph: AtherGlyph\.(\w+)',
      ).allMatches(source).map((m) => m.group(1)).toList();

      expect(
        glyphs,
        hasLength(4),
        reason: 'the tab bar is four destinations — see PROJECT.md §3.28',
      );
      expect(
        glyphs,
        isNot(contains('plus')),
        reason:
            'the raised centre "+" is back in the tab bar. It asked which '
            'lesson the student meant from a context that had none — see '
            'PROJECT.md §3.28.',
      );
    });
  });

  group('the icon motion layer is present', () {
    test('SpinningCog exists', () {
      // The six icon transitions are part of the approved design, built with no
      // dependency at all. A revert to the pre-refresh tree loses the whole
      // file, so naming one type from it is enough to notice.
      expect(SpinningCog, isNotNull);
    });
  });
}
