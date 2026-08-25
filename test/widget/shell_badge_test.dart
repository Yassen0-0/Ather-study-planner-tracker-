import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ather/core/l10n/generated/app_localizations.dart';
import 'package:ather/core/theme/app_colors.dart';
import 'package:ather/core/theme/app_theme.dart';
import 'package:ather/domain/entities/lesson.dart';
import 'package:ather/domain/services/review_cycle_service.dart';
import 'package:ather/presentation/providers/app_providers.dart';
import 'package:ather/presentation/shell/app_shell.dart';

/// N22 -- the review tab badge reserves red for overdue decay.
///
/// The queue mixes three reasons: overdue (past the 30-day cycle), low
/// mastery and declining. All of them counted toward the badge, and the
/// badge painted every one of them alarm red -- so a student who was merely
/// weak in a few lessons wore an emergency they had not earned. Red is now
/// paid out only when an overdue lesson is actually in the queue; otherwise
/// the badge wears accent, the palette's attention-without-alarm tier.
void main() {
  final DateTime kNow = DateTime(2026, 6, 1);
  DateTime daysAgo(int n) => kNow.subtract(Duration(days: n));

  ReviewItem item(
    int lessonId,
    ReviewReason reason, {
    double mastery = 40,
    int daysOverdue = 0,
  }) =>
      ReviewItem(
        lesson: Lesson(
          id: lessonId,
          chapterId: 1,
          name: 'درس $lessonId',
          createdAt: daysAgo(45),
          lastReviewedAt: daysAgo(reason == ReviewReason.overdue ? 40 : 5),
        ),
        chapterId: 1,
        subjectId: 1,
        mastery: mastery,
        reason: reason,
        daysOverdue: daysOverdue,
      );

  Future<void> pumpShell(WidgetTester tester, List<ReviewItem> queue) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: <RouteBase>[
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => AppShell(navigationShell: shell),
          branches: <StatefulShellBranch>[
            for (final path in <String>['home', 'review', 'progress', 'tasks'])
              StatefulShellBranch(
                routes: <RouteBase>[
                  GoRoute(
                    path: '/$path',
                    builder: (_, _) => const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // The production provider derives from the whole snapshot; the
          // colour contract under test starts from the queue itself.
          reviewQueueProvider.overrideWith((ref) => queue),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('ar'),
          localizationsDelegates: L.localizationsDelegates,
          supportedLocales: L.supportedLocales,
          theme: AppTheme.light,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationOfBadge(WidgetTester tester, String count) {
    final containers = tester.widgetList<Container>(
      find.ancestor(of: find.text(count), matching: find.byType(Container)),
    );
    return containers
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.color != null);
  }

  testWidgets('a weak-only queue wears accent, never alarm red', (
    tester,
  ) async {
    await pumpShell(tester, <ReviewItem>[
      item(1, ReviewReason.lowMastery, mastery: 40),
    ]);

    final decoration = decorationOfBadge(tester, '1');
    expect(decoration.color, AppColors.light.accent);
    expect(decoration.color, isNot(AppColors.light.wrong));
  });

  testWidgets('a declining-only queue wears accent too', (tester) async {
    await pumpShell(tester, <ReviewItem>[item(2, ReviewReason.declining)]);

    final decoration = decorationOfBadge(tester, '1');
    expect(decoration.color, AppColors.light.accent);
  });

  testWidgets('an overdue item turns the badge red', (tester) async {
    await pumpShell(tester, <ReviewItem>[
      item(3, ReviewReason.overdue, mastery: 90, daysOverdue: 10),
    ]);

    expect(decorationOfBadge(tester, '1').color, AppColors.light.wrong);
  });

  testWidgets('red survives a mixed queue; weak alone never earns it', (
    tester,
  ) async {
    await pumpShell(tester, <ReviewItem>[
      item(4, ReviewReason.overdue, mastery: 85, daysOverdue: 3),
      item(5, ReviewReason.lowMastery, mastery: 30),
      item(6, ReviewReason.declining, mastery: 55),
    ]);

    // One red pill counts the whole queue of three.
    expect(decorationOfBadge(tester, '3').color, AppColors.light.wrong);
  });
}
