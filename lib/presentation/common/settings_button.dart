import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/icon_motion.dart';

/// The cog in a root screen's header.
///
/// It sits on **every** tab rather than only the dashboard because the "المزيد"
/// tab that used to carry Settings is gone — its slot is the tasks screen now.
/// One widget rather than four call sites building the same button, so the
/// three lines that make it a settings button can only be got wrong once.
///
/// The cog turns 45° on every open (motion handoff §3). Eight teeth means 45°
/// maps the glyph exactly onto itself, so the turn is a gesture and never a
/// change of state — and it accumulates, so a fast double-open turns twice
/// forwards rather than unwinding.
class SettingsButton extends StatefulWidget {
  const SettingsButton({super.key});

  @override
  State<SettingsButton> createState() => _SettingsButtonState();
}

class _SettingsButtonState extends State<SettingsButton> {
  final GlobalKey<SpinningCogState> _cog = GlobalKey<SpinningCogState>();

  @override
  Widget build(BuildContext context) {
    return CircleHeaderButton(
      onTap: () {
        // Turn first, push second: the turn is the button's acknowledgement of
        // the tap, and it has to start on the frame the finger lands rather
        // than behind the route transition.
        _cog.currentState?.turn();
        context.push(Routes.settings);
      },
      child: SpinningCog(key: _cog),
    );
  }
}
