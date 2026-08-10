import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/widgets/ather_icons.dart';
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

  group('the tab bar has four slots and no raised "+"', () {
    test('the plus glyph no longer exists in the icon set', () {
      // The "+" asked the student which lesson they meant, after the fact, from
      // a context that had none, and was dead whenever nothing was recordable
      // (PROJECT.md §3.28). Deleting the glyph is what stops it being drawn
      // again by habit: there is nothing left to draw.
      expect(
        AtherGlyph.values.map((g) => g.name),
        isNot(contains('plus')),
        reason:
            'AtherGlyph.plus is back. It existed only for the raised centre '
            'button the approved design removed — see PROJECT.md §3.28.',
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
