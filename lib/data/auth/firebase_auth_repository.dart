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

  @override
  Stream<Account?> watchAccount() => _auth.authStateChanges().map(_toAccount);

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
  Future<void> register({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
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
    _ => AuthFailure.unknown,
  };
}
