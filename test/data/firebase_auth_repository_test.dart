import 'package:ather/data/auth/firebase_auth_repository.dart';
import 'package:ather/domain/repositories/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

/// D4: re-authentication decided by the account, not by the process.
///
/// A Google account whose session was restored from disk -- every launch after
/// the first -- never touched the Google plugin in this process. Deletion used
/// to key its Google retry off "has this process initialised the plugin", so
/// after a restart the account fell through to a password prompt it could not
/// answer. These run against a fresh repository, which is exactly that state.
void main() {
  group('reauthMethodFor', () {
    test('a linked Google sign-in re-proves through Google', () {
      expect(
        FirebaseAuthRepository.reauthMethodFor(<String>['google.com']),
        ReauthMethod.google,
      );
    });

    test('an email/password account re-proves with its password', () {
      expect(
        FirebaseAuthRepository.reauthMethodFor(<String>['password']),
        ReauthMethod.password,
      );
    });

    test('Google wins when both are linked', () {
      expect(
        FirebaseAuthRepository.reauthMethodFor(<String>[
          'password',
          'google.com',
        ]),
        ReauthMethod.google,
      );
    });
  });

  group('a session restored after a restart', () {
    late _StaleSessionUser user;
    late int googleSheets;

    FirebaseAuthRepository repositoryFor(
      String providerId, {
      Future<String?> Function()? googleIdToken,
    }) {
      user = _StaleSessionUser(providerId: providerId);
      googleSheets = 0;
      return FirebaseAuthRepository(
        MockFirebaseAuth(signedIn: true, mockUser: user),
        googleIdToken:
            googleIdToken ??
            () async {
              googleSheets++;
              return 'google-id-token';
            },
      );
    }

    test('is not recent: the mock token was issued long ago', () async {
      final repository = repositoryFor('google.com');
      expect(await repository.hasRecentLogin(), isFalse);
    });

    test('a Google account re-proves through Google, then deletes', () async {
      final repository = repositoryFor('google.com');
      expect(repository.reauthMethod, ReauthMethod.google);

      // The up-front step Settings takes before erasing anything.
      await repository.reauthenticateWithGoogle();
      expect(googleSheets, 1);
      expect(user.reauthProviders, <String>['google.com']);

      await repository.deleteAccount();
      expect(user.deletes, 1);
      // Fresh already: the delete did not ask a second time.
      expect(googleSheets, 1);
    });

    test('the delete backstop still retries a Google account itself', () async {
      final repository = repositoryFor('google.com');

      // Straight to delete, stale: `requires-recent-login`, then the sheet.
      await repository.deleteAccount();
      expect(googleSheets, 1);
      expect(user.deletes, 1);
    });

    test('a cancelled Google sheet deletes nothing', () async {
      final repository = repositoryFor(
        'google.com',
        googleIdToken: () async =>
            throw const AuthException(AuthFailure.cancelled),
      );

      await expectLater(
        repository.reauthenticateWithGoogle(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.cancelled,
          ),
        ),
      );
      await expectLater(
        repository.deleteAccount(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.cancelled,
          ),
        ),
      );
      expect(user.deletes, 0);
    });

    test('a password account is never sent to Google', () async {
      final repository = repositoryFor('password');
      expect(repository.reauthMethod, ReauthMethod.password);

      // The caller is told to ask for the password.
      await expectLater(
        repository.deleteAccount(),
        throwsA(
          isA<AuthException>().having(
            (e) => e.failure,
            'failure',
            AuthFailure.requiresRecentLogin,
          ),
        ),
      );
      expect(googleSheets, 0);

      await repository.reauthenticateWithPassword('the-password');
      expect(user.reauthProviders, <String>['password']);
      await repository.deleteAccount();
      expect(user.deletes, 1);
    });
  });
}

/// A linked sign-in method. `UserInfo`'s own constructors are `@protected`;
/// the repository only ever reads `providerId`.
class _LinkedProvider implements UserInfo {
  _LinkedProvider(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A signed-in user whose sign-in is too old to delete: Firebase answers
/// `requires-recent-login` until the user re-authenticates.
// MockUser's own fields (_displayName, _photoURL) are mutable, so any subclass
// trips this whatever its own fields are; the mock cannot be subclassed clean.
// ignore: must_be_immutable
class _StaleSessionUser extends MockUser {
  _StaleSessionUser({required String providerId})
    : super(
        uid: 'uid-1',
        email: 'student@example.com',
        providerData: <UserInfo>[_LinkedProvider(providerId)],
        // Signed in long ago -- the state after an app restart.
        idTokenAuthTime: DateTime(2020),
      );

  /// The provider of every credential this user was re-authenticated with.
  final List<String> reauthProviders = <String>[];

  int deletes = 0;

  @override
  Future<UserCredential> reauthenticateWithCredential(
    AuthCredential? credential,
  ) {
    // Non-null by contract; `!` keeps this override valid whichever
    // nullability the mock's own signature declares.
    final given = credential!;
    reauthProviders.add(given.providerId);
    return super.reauthenticateWithCredential(given);
  }

  @override
  Future<void> delete() async {
    if (reauthProviders.isEmpty) {
      throw FirebaseAuthException(code: 'requires-recent-login');
    }
    deletes++;
  }
}
