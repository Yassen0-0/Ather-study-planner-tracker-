import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_spacing.dart';
import '../domain/entities/account.dart';
import '../presentation/analytics/analytics_screen.dart';
import '../presentation/auth/login_screen.dart';
import '../presentation/chapter/chapter_screen.dart';
import '../presentation/chapter_report/chapter_report_screen.dart';
import '../presentation/dashboard/dashboard_screen.dart';
import '../presentation/exam_entry/exam_entry_screen.dart';
import '../presentation/lesson/lesson_screen.dart';
import '../presentation/privacy/privacy_screen.dart';
import '../presentation/review_center/review_center_screen.dart';
import '../presentation/settings/about_screen.dart';
import '../presentation/settings/backup_screen.dart';
import '../presentation/settings/export_screen.dart';
import '../presentation/settings/profile_screen.dart';
import '../presentation/settings/recycle_bin_screen.dart';
import '../presentation/settings/settings_screen.dart';
import '../presentation/settings/subjects_screen.dart';
import '../presentation/shell/app_shell.dart';
import '../presentation/subject/subject_screen.dart';
import '../presentation/tasks/tasks_screen.dart';

/// Route paths, referenced by name everywhere instead of raw strings.
abstract final class Routes {
  static const String dashboard = '/';
  static const String review = '/review';
  static const String analytics = '/analytics';
  static const String tasks = '/tasks';
  static const String settings = '/settings';
  static const String privacy = '/settings/privacy';
  static const String backup = '/settings/backup';
  static const String export = '/settings/export';
  static const String about = '/settings/about';
  static const String subjects = '/settings/subjects';
  static const String profile = '/settings/profile';
  static const String recycleBin = '/settings/recycle-bin';
  static const String login = '/login';

  static String subject(int id) => '/subject/$id';
  static String chapter(int id) => '/chapter/$id';
  static String lesson(int id) => '/lesson/$id';
  static String chapterReport(int id) => '/chapter/$id/report';

  /// [fromLesson] records whether the wizard was opened from the lesson screen
  /// itself. On save the wizard has to land the student on the lesson -- if it
  /// was launched from the review centre or the dashboard's up-next card,
  /// there is no lesson underneath to pop back to.
  static String exam(int lessonId, {required bool fromLesson}) =>
      '/lesson/$lessonId/exam?from=${fromLesson ? 'lesson' : 'list'}';
}

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Why here and not per route: a transition copy-pasted into nine `GoRoute`s is
/// nine chances for one screen to feel different from the others. [atherPage]
/// and [atherModalPage] are the whole app's transition vocabulary.
///
/// Push: rise 8px + fade. Vertical, so RTL and LTR are identical -- nothing in
/// this app slides horizontally, which is how we know nothing can slide the
/// wrong way.
CustomTransitionPage<void> atherPage(
  GoRouterState state,
  Widget child, {
  double rise = AppMotion.pageRise,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.page,
    reverseTransitionDuration: AppMotion.page,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return FadeTransition(opacity: animation, child: child);
      }

      final incoming = CurvedAnimation(
        parent: animation,
        curve: AppMotion.standard,
      );

      final risen = rise == 0
          ? child
          : AnimatedBuilder(
              animation: incoming,
              builder: (context, inner) => Transform.translate(
                offset: Offset(0, rise * (1 - incoming.value)),
                child: inner,
              ),
              child: child,
            );

      return FadeTransition(
        // The page underneath fades as the next one arrives.
        opacity: Tween<double>(begin: 1, end: 0).animate(
          CurvedAnimation(parent: secondary, curve: AppMotion.standard),
        ),
        child: FadeTransition(opacity: incoming, child: risen),
      );
    },
  );
}

/// The exam wizard only: a full-screen route that slides up from the bottom.
/// Direction-agnostic by construction, and the same 280ms as a bottom sheet,
/// because that is what it is.
CustomTransitionPage<void> atherModalPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: AppMotion.sheet,
    reverseTransitionDuration: AppMotion.sheet,
    transitionsBuilder: (context, animation, secondary, child) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        return FadeTransition(opacity: animation, child: child);
      }
      return SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
            .animate(
              CurvedAnimation(parent: animation, curve: AppMotion.sheetCurve),
            ),
        child: child,
      );
    },
  );
}

/// Bridges the account stream to something [GoRouter] will listen to, so the
/// redirect below re-runs the moment a student signs in or out.
/// Disposed by [GoRouter.dispose], which `routerProvider` hooks to the provider
/// scope -- otherwise this subscription outlives the app that created it.
class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<Account?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Account?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// [isSignedIn] is read synchronously from the session Firebase restored from
/// disk, and [accountChanges] only ever refreshes that answer. The gate never
/// waits on the network, which is what keeps a signed-in student's app opening
/// instantly in airplane mode.
GoRouter createRouter({
  required bool Function() isSignedIn,
  required Stream<Account?> accountChanges,
}) {
  final refresh = _AuthRefresh(accountChanges);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.dashboard,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = isSignedIn();
      final atLogin = state.matchedLocation == Routes.login;

      if (!signedIn) return atLogin ? null : Routes.login;
      return atLogin ? Routes.dashboard : null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: Routes.login,
        parentNavigatorKey: rootNavigatorKey,
        // Fade only, 220ms. Signing in is a `redirect`, not a push from the
        // screen, so this page's own transition is what carries M-19: the first
        // thing a student sees afterwards should be their number, not a slide.
        pageBuilder: (context, state) =>
            atherPage(state, const LoginScreen(), rise: 0),
      ),
      // A StatefulShellRoute so each tab keeps its own navigation stack and
      // scroll position -- switching to Review and back must not throw away
      // where the student was inside a subject.
      //
      // The base constructor rather than `.indexedStack`, because the tab
      // cross-fade needs every branch handed to it at once
      // (`navigatorContainerBuilder`) -- see BranchCrossFade.
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            BranchCrossFade(
              currentIndex: navigationShell.currentIndex,
              children: children,
            ),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.dashboard,
                pageBuilder: (context, state) =>
                    atherPage(state, const DashboardScreen()),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'subject/:subjectId',
                    pageBuilder: (context, state) => atherPage(
                      state,
                      SubjectScreen(subjectId: _intParam(state, 'subjectId')),
                    ),
                  ),
                  GoRoute(
                    path: 'chapter/:chapterId',
                    pageBuilder: (context, state) => atherPage(
                      state,
                      ChapterScreen(chapterId: _intParam(state, 'chapterId')),
                    ),
                    routes: <RouteBase>[
                      GoRoute(
                        path: 'report',
                        pageBuilder: (context, state) => atherPage(
                          state,
                          ChapterReportScreen(
                            chapterId: _intParam(state, 'chapterId'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'lesson/:lessonId',
                    pageBuilder: (context, state) => atherPage(
                      state,
                      LessonScreen(lessonId: _intParam(state, 'lessonId')),
                    ),
                    routes: <RouteBase>[
                      // The wizard is a full-screen route on the **root**
                      // navigator: no tab bar, no way to wander off mid-entry.
                      // It is also the one bottom-anchored slide in the app.
                      GoRoute(
                        path: 'exam',
                        parentNavigatorKey: rootNavigatorKey,
                        pageBuilder: (context, state) => atherModalPage(
                          state,
                          ExamEntryScreen(
                            lessonId: _intParam(state, 'lessonId'),
                            openedFromLesson:
                                state.uri.queryParameters['from'] != 'list',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.review,
                pageBuilder: (context, state) =>
                    atherPage(state, const ReviewCenterScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.analytics,
                pageBuilder: (context, state) =>
                    atherPage(state, const AnalyticsScreen()),
              ),
            ],
          ),
          // The slot the "المزيد" tab used to hold. Settings did not lose a
          // home -- it never belonged in a tab bar, and the cog in every root
          // header reaches it from anywhere.
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: Routes.tasks,
                pageBuilder: (context, state) =>
                    atherPage(state, const TasksScreen()),
              ),
            ],
          ),
        ],
      ),
      // Settings sits above the shell: it is a place you leave, not a tab you
      // live in, so it shows no tab bar.
      GoRoute(
        path: Routes.settings,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (context, state) =>
            atherPage(state, const SettingsScreen()),
        routes: <RouteBase>[
          GoRoute(
            path: 'privacy',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const PrivacyScreen()),
          ),
          GoRoute(
            path: 'backup',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const BackupScreen()),
          ),
          GoRoute(
            path: 'export',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const ExportScreen()),
          ),
          GoRoute(
            path: 'about',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const AboutScreen()),
          ),
          GoRoute(
            path: 'subjects',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const SubjectsScreen()),
          ),
          GoRoute(
            path: 'profile',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const ProfileScreen()),
          ),
          GoRoute(
            path: 'recycle-bin',
            parentNavigatorKey: rootNavigatorKey,
            pageBuilder: (context, state) =>
                atherPage(state, const RecycleBinScreen()),
          ),
        ],
      ),
    ],
  );
}

/// `-1` for anything unparseable, rather than throwing.
///
/// Every screen already handles an id that matches no row — it is the ordinary
/// case after a delete, and the summary providers return null for it. A bare
/// `int.parse` turned a malformed path into an exception during route building
/// instead, which is a crash with no screen to show it on. Nothing in the app
/// produces such a path today; a restored deep link or a typo'd URL on the
/// desktop build can.
int _intParam(GoRouterState state, String name) =>
    int.tryParse(state.pathParameters[name] ?? '') ?? -1;
