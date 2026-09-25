import 'dart:async';

import 'package:ather/domain/entities/account.dart';
import 'package:ather/domain/repositories/auth_repository.dart';

/// An in-memory [AuthRepository].
///
/// Every widget test overrides `authRepositoryProvider` with this, so no test
/// ever reaches Firebase — an uninitialised `FirebaseAuth.instance` throws, and
/// a test suite that needs network credentials to run is a test suite that
/// stops being run.
final class FakeAuthRepository implements AuthRepository {
  /// Positional because Dart has no private *named* parameters, and the lint
  /// that wants an initialising formal cannot be satisfied any other way.
  FakeAuthRepository([this._account]);

  /// Signed in from the start, which is the state every study-screen test
  /// cares about.
  factory FakeAuthRepository.signedIn() => FakeAuthRepository(
    const Account(
      id: 'test-uid',
      email: 'student@example.com',
      isEmailVerified: true,
    ),
  );

  /// Signed in with an address nobody has proved they can read -- the state a
  /// student is in for the first few minutes after registering.
  factory FakeAuthRepository.signedInUnverified() => FakeAuthRepository(
    const Account(id: 'test-uid', email: 'student@example.com'),
  );

  Account? _account;
  final StreamController<Account?> _controller =
      StreamController<Account?>.broadcast();

  /// Failure to throw from the next call, if any. Lets a test drive the login
  /// screen's error states without a network.
  AuthFailure? nextFailure;

  int signOutCount = 0;
  int deleteCount = 0;

  /// How many verification mails have been asked for, including the one
  /// [register] sends itself.
  int verificationsSent = 0;

  int reloadCount = 0;

  /// Set to have the *next* [reloadAccount] discover that the student has
  /// verified in the meantime -- the inbox round trip, without an inbox.
  bool verifyOnNextReload = false;

  /// Thrown by the next [sendEmailVerification]. Firebase rate-limits resends,
  /// and that path has to stay tolerable rather than reading as a broken
  /// account.
  AuthFailure? nextVerificationFailure;

  /// Thrown by the next `deleteAccount()` when non-null, to drive the
  /// re-authentication path exactly the way a stale Firebase session does.
  AuthFailure? nextDeleteFailure;

  @override
  Account? get currentAccount => _account;

  @override
  Stream<Account?> watchAccount() async* {
    yield _account;
    yield* _controller.stream;
  }

  void _set(Account? account) {
    _account = account;
    _controller.add(account);
  }

  void _maybeThrow() {
    final failure = nextFailure;
    if (failure != null) {
      nextFailure = null;
      throw AuthException(failure);
    }
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _maybeThrow();
    _set(Account(id: 'test-uid', email: email));
  }

  /// Set to make the verification mail fail to send while the account is
  /// still created -- what Firebase does when it rate-limits the send, and the
  /// case where the screen used to claim a link was on its way regardless.
  bool verificationSendFails = false;

  @override
  Future<bool> register({
    required String email,
    required String password,
  }) async {
    _maybeThrow();
    _set(Account(id: 'test-uid', email: email));
    if (verificationSendFails) return false;
    // A brand-new email/password account is unverified, and registering sends
    // the first link -- exactly what FirebaseAuthRepository.register does.
    verificationsSent++;
    return true;
  }

  /// Google accounts arrive verified. Google checked the address; the app has
  /// nothing left to ask.
  @override
  Future<void> signInWithGoogle() async {
    _maybeThrow();
    _set(
      const Account(
        id: 'google-uid',
        email: 'student@gmail.com',
        isEmailVerified: true,
      ),
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async => _maybeThrow();

  @override
  Future<void> sendEmailVerification() async {
    final failure = nextVerificationFailure;
    if (failure != null) {
      nextVerificationFailure = null;
      throw AuthException(failure);
    }
    verificationsSent++;
  }

  @override
  Future<void> reloadAccount() async {
    reloadCount++;
    final account = _account;
    if (verifyOnNextReload && account != null) {
      verifyOnNextReload = false;
      _set(
        Account(
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          isEmailVerified: true,
        ),
      );
    }
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    _set(null);
  }

  @override
  Future<void> deleteAccount() async {
    final failure = nextDeleteFailure;
    if (failure != null) {
      nextDeleteFailure = null;
      throw AuthException(failure);
    }
    deleteCount++;
    _set(null);
  }

  /// How the account re-proves itself. Password unless a test says it is a
  /// Google account -- the case that used to dead-end after a restart (D4).
  ReauthMethod reauthMethodValue = ReauthMethod.password;

  /// Whether the sign-in counts as recent. True by default so the tests that
  /// are not about re-authentication go straight through, as a fresh session
  /// does.
  bool recentLogin = true;

  /// Thrown by the next re-authentication of either kind -- `cancelled` for a
  /// student backing out of the Google sheet, `wrongCredentials` for a
  /// mistyped password.
  AuthFailure? nextReauthFailure;

  int googleReauthCount = 0;

  /// Every password handed to [reauthenticateWithPassword], in order.
  final List<String> reauthPasswords = <String>[];

  @override
  ReauthMethod? get reauthMethod => _account == null ? null : reauthMethodValue;

  @override
  Future<bool> hasRecentLogin() async => _account != null && recentLogin;

  /// Called as either re-authentication starts, so a test can look at what
  /// had already been erased by then -- the whole point of D4 is "nothing".
  void Function()? onReauth;

  void _maybeThrowReauth() {
    onReauth?.call();
    final failure = nextReauthFailure;
    if (failure != null) {
      nextReauthFailure = null;
      throw AuthException(failure);
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    _maybeThrowReauth();
    googleReauthCount++;
    recentLogin = true;
  }

  /// Any password succeeds unless [nextReauthFailure] says otherwise — the
  /// fake cannot know the password, and the contract under test is "a proved
  /// owner goes through", not Firebase's credential check.
  @override
  Future<void> reauthenticateWithPassword(String password) async {
    _maybeThrowReauth();
    reauthPasswords.add(password);
    recentLogin = true;
  }

  void dispose() => _controller.close();
}
