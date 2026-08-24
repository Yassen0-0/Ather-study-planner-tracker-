import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// The app's one modal shape: a white sheet with 22px top corners, a grey
/// handle, and a 35% scrim behind it.
Future<T?> showAtherSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    // Presented on the root navigator so the scrim covers the tab bar too.
    // Anchored to a branch navigator instead, the sheet is confined to the
    // scaffold body and the tab bar stays lit above the dimmed content.
    useRootNavigator: true,
    barrierColor: context.colors.scrim,
    backgroundColor: context.colors.card,
    elevation: 0,
    // Fills the notch/gesture area itself rather than letting Material inset
    // it, so the sheet's own bottom padding is the only bottom padding.
    useSafeArea: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppRadius.sheet),
      ),
    ),
    transitionAnimationController: null,
    builder: (context) => Padding(
      // Lifts the sheet clear of the keyboard. Without this the field a student
      // is typing into sits behind the IME on most Android phones.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Standard sheet chrome: handle, title, optional body copy, then content.
class AtherSheetBody extends StatelessWidget {
  const AtherSheetBody({
    super.key,
    required this.title,
    required this.child,
    this.body,
  });

  final String title;
  final String? body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        // The page margin on three sides, so the sheet's content lands on the
        // same verticals as the screen behind it. It was 20/20/20/28, which is
        // Material's default and belonged to no scale of ours: the app's one
        // modal was the only surface in it that did not reach the page margin.
        //
        // The bottom is a rung larger than the sides on purpose — it clears the
        // gesture bar, which the sides have nothing to clear.
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageMargin,
          AppSpacing.pageMargin,
          AppSpacing.pageMargin,
          AppSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: Container(
                width: AppSizes.sheetHandleWidth,
                height: AppSizes.sheetHandleHeight,
                decoration: BoxDecoration(
                  color: context.colors.switchOff,
                  borderRadius: BorderRadius.circular(
                    AppSizes.sheetHandleHeight / 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(title, style: AppTypography.screenTitle),
            if (body != null) ...<Widget>[
              const SizedBox(height: AppSpacing.textGap),
              Text(body!, style: context.text.secondary),
            ],
            const SizedBox(height: AppSpacing.xl),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}
