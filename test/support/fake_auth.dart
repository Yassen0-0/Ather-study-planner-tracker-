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
    const Account(id: 'test-uid', email: 'student@example.com'),
  );

  Account? _account;
  final StreamController<Account?> _controller =
      StreamController<Account?>.broadcast();

  /// Failure to throw from the next call, if any. Lets a test drive the login
  /// screen's error states without a network.
  AuthFailure? nextFailure;

  int signOutCount = 0;

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

  @override
  Future<void> register({
    required String email,
    required String password,
  }) async {
    _maybeThrow();
    _set(Account(id: 'test-uid', email: email));
  }

  @override
  Future<void> signInWithGoogle() async {
    _maybeThrow();
    _set(const Account(id: 'google-uid', email: 'student@gmail.com'));
  }

  @override
  Future<void> sendPasswordReset(String email) async => _maybeThrow();

  @override
  Future<void> signOut() async {
    signOutCount++;
    _set(null);
  }

  int deleteAccountCount = 0;

  @override
  Future<void> deleteAccount() async {
    deleteAccountCount++;
    // Before the state change, so a test that arms `nextFailure` gets an
    // account that is still signed in -- which is the situation a student is in
    // when deletion fails, and the only one worth asserting about.
    _maybeThrow();
    _set(null);
  }

  void dispose() => _controller.close();
}
