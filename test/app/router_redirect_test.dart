import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ather/app/router.dart';
import 'package:ather/domain/entities/account.dart';
import 'package:go_router/go_router.dart';

/// The auth-redirect truth table (arch F-07).
///
/// The whole gate is four lines [lib/app/router.dart:164-170]:
///
/// ```dart
/// final signedIn = isSignedIn();
/// final atLogin = state.matchedLocation == Routes.login;
/// if (!signedIn) return atLogin ? null : Routes.login;
/// return atLogin ? Routes.dashboard : null;
/// ```
///
/// | signed in | matched at /login | redirect        |
/// |-----------|-------------------|-----------------|
/// | no        | no                | `/login`        |
/// | no        | yes               | stay            |
/// | yes       | no                | stay            |
/// | yes       | yes               | `/` (dashboard) |
///
/// These tests pin **current** behaviour, not desired behaviour. Two things a
/// reader may find surprising are deliberate findings, recorded where they
/// occur: the deep-link destination is discarded on the way to `/login`, and
/// post-login every student lands on the dashboard regardless of where they
/// were originally headed -- the gate has no return-to-original mechanism.
///
/// The tests call the real redirect closure straight off the router built by
/// [createRouter] (`router.configuration.topRedirect`), rather than rendering
/// the app: the screens behind these routes pull a database and Firebase, none
/// of which a routing decision should depend on. The states handed to the
/// redirect mirror what go_router itself builds for a top-level redirect --
/// `matchedLocation` is the URI **path**, query strings included only on
/// `uri`.
/// A stand-in for the auth repository's session view: the synchronous
/// answer the gate polls, plus the stream that makes it re-answer.
///
/// Deliberately not FakeAuthRepository -- the gate never sees the repository,
/// only `isSignedIn()` and `accountChanges`, so those are the only seams the
/// truth table can turn.
final class _Session {
  bool signedIn = false;
  final StreamController<Account?> _changes =
      StreamController<Account?>.broadcast();

  Stream<Account?> get changes => _changes.stream;

  void signInAs(String email) {
    signedIn = true;
    _changes.add(Account(id: 'uid', email: email));
  }

  void signOut() {
    signedIn = false;
    _changes.add(null);
  }

  void dispose() => _changes.close();
}

void main() {
  late _Session session;
  late GoRouter router;
  BuildContext? context;

  setUp(() {
    session = _Session();
    router = createRouter(
      isSignedIn: () => session.signedIn,
      accountChanges: session.changes,
    );
  });

  tearDown(() {
    router.dispose();
    session.dispose();
  });

  /// A BuildContext to satisfy the redirect signature; the gate never reads
  /// it, so any element will do.
  Future<void> captureContext(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (element) {
            context = element;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  /// Evaluates the real redirect for [location], the way go_router would hand
  /// it over after matching: `matchedLocation` carries the path only.
  String? redirectFor(String location) {
    final uri = Uri.parse(location);
    final state = GoRouterState(
      router.configuration,
      uri: uri,
      matchedLocation: uri.path,
      fullPath: uri.path,
      pathParameters: const <String, String>{},
      pageKey: ValueKey<String>(uri.path),
    );

    final Object? result = router.configuration.topRedirect(context!, state);
    // The gate is synchronous today; if it ever goes async this harness must
    // be rewritten, so fail loudly instead of returning a Future as a String.
    expect(result, isNot(isA<Future<Object?>>()));
    return result as String?;
  }

  /// Every route except `/login`: shell tabs, the settings subtree above the
  /// shell, and the parameterised study deep links.
  const List<String> kProtectedLocations = <String>[
    Routes.dashboard,
    Routes.review,
    Routes.analytics,
    Routes.tasks,
    Routes.settings,
    Routes.privacy,
    Routes.backup,
    Routes.export,
    Routes.about,
    Routes.subjects,
    Routes.profile,
    Routes.recycleBin,
    '/subject/3',
    '/subject/3/chapter/7',
    '/subject/3/chapter/7/report',
    '/subject/3/chapter/7/lesson/12',
    '/subject/3/chapter/7/lesson/12/exam?from=list',
  ];

  group('signed out', () {
    testWidgets('any protected route redirects to /login', (tester) async {
      await captureContext(tester);

      for (final location in kProtectedLocations) {
        expect(
          redirectFor(location),
          Routes.login,
          reason: '$location must be gated while signed out',
        );
      }
    });

    testWidgets('a deep link reaches /login but its destination is dropped',
        (tester) async {
      await captureContext(tester);

      // CURRENT BEHAVIOUR (finding): the redirect target is bare `/login`.
      // Nothing records where the student was headed -- no `?from=`, no
      // `redirect=` parameter -- so the destination cannot be restored after
      // sign-in. If a return-to-original is ever added, this is the assertion
      // that changes.
      final result = redirectFor('/subject/3/chapter/7/lesson/12');
      expect(result, Routes.login);
      expect(Uri.parse(result!).queryParameters, isEmpty);
    });

    testWidgets('already on /login, stays', (tester) async {
      await captureContext(tester);

      expect(redirectFor(Routes.login), isNull);
    });

    testWidgets('/login carrying query parameters still counts as /login',
        (tester) async {
      await captureContext(tester);

      // The comparison is against `matchedLocation` -- the path alone -- so a
      // speculative `?next=/settings` on the login URL neither traps a signed
      // out student nor leaks anywhere; the parameter is simply unread.
      expect(redirectFor('${Routes.login}?next=/settings'), isNull);
    });
  });

  group('signed in', () {
    setUp(() {
      session.signInAs('student@example.com');
    });

    testWidgets('visiting /login is bounced to the dashboard', (tester) async {
      await captureContext(tester);

      expect(redirectFor(Routes.login), Routes.dashboard);
    });

    testWidgets('every other route passes through untouched',
        (tester) async {
      await captureContext(tester);

      // There is no route a signed-out student may see but a signed-in one
      // may not: apart from /login itself, the whole map is "protected" only
      // in the sense that the gate stands in front of it.
      for (final location in kProtectedLocations) {
        expect(
          redirectFor(location),
          isNull,
          reason: '$location must pass while signed in',
        );
      }
    });

    testWidgets('signing out mid-session gates the next evaluation',
        (tester) async {
      await captureContext(tester);

      expect(redirectFor(Routes.dashboard), isNull);

      session.signOut();

      expect(redirectFor(Routes.dashboard), Routes.login);
    });
  });

  group('auth state still loading', () {
    testWidgets('an unrestored session is indistinguishable from signed out',
        (tester) async {
      await captureContext(tester);

      // There is no third "loading" answer in the gate: `isSignedIn()` is a
      // plain bool read synchronously from whatever the session layer has
      // restored so far. Until the account stream emits, a cold boot answers
      // "signed out", so even a signed-in student's deep link bounces through
      // /login once and back when the refresh listenable fires.
      session.signedIn = false;
      expect(redirectFor(Routes.profile), Routes.login);
    });

    testWidgets('the gate re-answers once the session resolves',
        (tester) async {
      await captureContext(tester);

      // Mid-restore: everything gated.
      expect(redirectFor(Routes.review), Routes.login);

      // The repository finishes restoring and emits; app.dart wires this
      // stream to the router's refreshListenable, which re-runs the gate.
      session.signInAs('student@example.com');

      // Same location, new answer -- nothing was consumed or lost by the
      // intermediate bounce decision itself.
      expect(redirectFor(Routes.review), isNull);
    });
  });

  group('post-login landing', () {
    testWidgets('every sign-in lands on the dashboard; origin is not restored',
        (tester) async {
      await captureContext(tester);

      // CURRENT BEHAVIOUR (finding): the signed-in-at-/login branch returns
      // Routes.dashboard unconditionally. Combined with the dropped
      // destination above, a student who tapped a notification or opened a
      // subject deep link while signed out ends up on `/`, not where they
      // meant to go. Pinned here so a future fix must update this test.
      session.signedIn = true;
      expect(redirectFor(Routes.login), Routes.dashboard);
    });

    testWidgets(
        'the original destination still opens if navigated to after sign-in',
        (tester) async {
      await captureContext(tester);

      session.signInAs('student@example.com');

      // The deep link itself is not forbidden -- only remembered-by-nobody.
      // Reaching it after the fact passes the gate cleanly.
      expect(redirectFor('/subject/3/chapter/7/lesson/12'), isNull);
    });
  });
}
