import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/widgets/ather_icons.dart';
import '../../core/widgets/buttons.dart';

/// The cog in a root screen's header.
///
/// It sits on **every** tab rather than only the dashboard because the "المزيد"
/// tab that used to carry Settings is gone — its slot is the tasks screen now.
/// One widget rather than four call sites building the same button, so the
/// three lines that make it a settings button can only be got wrong once.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return CircleHeaderButton(
      onTap: () => context.push(Routes.settings),
      child: const AtherIcon(AtherGlyph.settings, size: 19),
    );
  }
}
