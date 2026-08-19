import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';

/// [AuthRepository] over Firebase Auth.
///
/// This is the only file in the app that imports `firebase_auth`. Every failure
/// is translated into an [AuthFailure] here, so no Firebase error code and no
/// English Firebase message can reach a screen.
final class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._auth, {GoogleSignIn? googleSignIn})
    : _google = googleSignIn ?? GoogleSignIn.instance;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;

  bool _googleInitialised = false;

  /// `userChanges`, not `authStateChanges`.
  ///
  /// The latter fires only on sign-in and sign-out, so a `reload()` that
  /// discovers the student has just verified their address would change
  /// nothing anyone could see -- the banner asking them to verify would stay
  /// up after they had. `userChanges` also emits on reload and on profile
  /// updates. It emits more often, but [Account] compares by value, so an
  /// unchanged account does not propagate past the provider.
  @override
  Stream<Account?> watchAccount() => _auth.userChanges().map(_toAccount);

  @override
  Account? get currentAccount => _toAccount(_auth.currentUser);

  static Account? _toAccount(fb.User? user) {
    if (user == null) return null;
    return Account(
      id: user.uid,
      // A Google account always carries an email; the email/password flow
      // cannot exist without one. The fallback is defensive, not expected.
      email: user.email ?? '',
      displayName: user.displayName,
      isEmailVerified: user.emailVerified,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<bool> register({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      // Best-effort, and deliberately not allowed to fail the registration.
      // The account exists at this point; throwing here would report a *failed
      // registration* for a student who now has a working account, and their
      // retry would come back "email already in use". The address can be
      // verified later from the profile screen, which is where the resend
      // lives.
      //
      // The outcome is **reported** rather than swallowed, so the screen can
      // stop claiming a mail is in an inbox it never reached.
      try {
        await credential.user?.sendEmailVerification();
        return true;
      } catch (_) {
        return false;
      }
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      // v7 requires an explicit initialise. `serverClientId` is deliberately
      // omitted: on Android the plugin reads `default_web_client_id`, the
      // string resource the google-services Gradle plugin generates from
      // google-services.json, so the id lives in one place.
      if (!_googleInitialised) {
        await _google.initialize();
        _googleInitialised = true;
      }

      final account = await _google.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AuthException(AuthFailure.unknown);

      await _auth.signInWithCredential(
        fb.GoogleAuthProvider.credential(idToken: idToken),
      );
    } on GoogleSignInException catch (e) {
      // Backing out of the account sheet is not a failure to report.
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : AuthFailure.unknown,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthFailure.unknown);
    // Nothing to send. Reported as success: the student's goal is "this
    // address is verified", and it already is.
    if (user.emailVerified) return;

    try {
      await user.sendEmailVerification();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  @override
  Future<void> reloadAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.reload();
    } catch (_) {
      // Offline is the normal case for this app, and a refresh that could not
      // reach the server is not an error worth showing: the cached answer is
      // still the best one available.
    }
  }

  @override
  Future<void> signOut() async {
    // Google's own session is cleared too. Without this, "sign out" leaves the
    // previous account silently pre-selected on the next attempt, which reads
    // as the app ignoring the request.
    if (_googleInitialised) {
      try {
        await _google.signOut();
      } catch (_) {
        // Never block signing out of the app on the Google plugin.
      }
    }
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() => _deleteAccount(null);

  /// Deletes the account, re-authenticating first when Firebase demands it.
  ///
  /// [reauth] is the caller's second attempt with fresh proof of ownership
  /// (a password re-typed into the delete sheet, or a fresh Google token) —
  /// a closure rather than credentials so no password is ever held longer
  /// than the call that uses it.
  Future<void> _deleteAccount(Future<void> Function()? reauth) async {
    final user = _auth.currentUser;
    // Already gone. Treated as success so a retry after a partial failure
    // finishes rather than reporting an error about work already done.
    if (user == null) return;

    try {
      if (reauth != null) await reauth();
      await user.delete();
      await _clearGoogleSession();
      return;
    } on fb.FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') {
        throw AuthException(_map(e));
      }
      // The first attempt with stale credentials lands here. One automatic
      // retry with a fresh Google token when this session is a Google one:
      // the student with the phone in their hand is the owner, and a
      // re-auth prompt they cannot answer is a dead delete button.
      if (reauth == null && _googleInitialised) {
        try {
          final account = await _google.authenticate();
          final idToken = account.authentication.idToken;
          if (idToken == null) {
            throw const AuthException(AuthFailure.unknown);
          }
          await user.reauthenticateWithCredential(
            fb.GoogleAuthProvider.credential(idToken: idToken),
          );
          await user.delete();
          await _clearGoogleSession();
          return;
        } on GoogleSignInException catch (e) {
          throw AuthException(
            e.code == GoogleSignInExceptionCode.canceled
                ? AuthFailure.cancelled
                : AuthFailure.unknown,
          );
        } on fb.FirebaseAuthException catch (e) {
          throw AuthException(_map(e));
        } on AuthException {
          rethrow;
        } catch (_) {
          throw const AuthException(AuthFailure.unknown);
        }
      }
      throw const AuthException(AuthFailure.requiresRecentLogin);
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  /// Re-authenticates with email/password and deletes. The sheet's second
  /// attempt, after the student has re-typed their password.
  @override
  Future<void> deleteAccountWithPassword(String password) =>
      _deleteAccount(() async {
        final user = _auth.currentUser;
        if (user == null) throw const AuthException(AuthFailure.unknown);
        final email = user.email;
        if (email == null) {
          throw const AuthException(AuthFailure.unknown);
        }
        await user.reauthenticateWithCredential(
          fb.EmailAuthProvider.credential(email: email, password: password),
        );
      });

  /// Google's own session survives `user.delete()`, and leaving it in place
  /// pre-selects the account that was just deleted on the next attempt --
  /// which reads as the deletion not having worked.
  Future<void> _clearGoogleSession() async {
    if (!_googleInitialised) return;
    try {
      await _google.signOut();
    } catch (_) {
      // Never let the Google plugin turn a completed deletion into a failure.
    }
  }

  static AuthFailure _map(fb.FirebaseAuthException e) => switch (e.code) {
    'invalid-email' => AuthFailure.invalidEmail,
    'weak-password' => AuthFailure.weakPassword,
    'email-already-in-use' => AuthFailure.emailInUse,
    // Modern Firebase collapses "no such user" and "wrong password" into
    // `invalid-credential` on purpose; the older codes are kept for
    // devices still talking to an older backend.
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'user-disabled' => AuthFailure.wrongCredentials,
    'network-request-failed' => AuthFailure.network,
    'too-many-requests' => AuthFailure.tooManyRequests,
    'requires-recent-login' => AuthFailure.requiresRecentLogin,
    _ => AuthFailure.unknown,
  };
}
