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
  /// [googleIdToken] is for tests only: it stands in for the Google plugin's
  /// account sheet, which talks to a platform channel no test has.
  /// Production leaves it null.
  FirebaseAuthRepository(
    this._auth, {
    GoogleSignIn? googleSignIn,
    Future<String?> Function()? googleIdToken,
  }) : _google = googleSignIn ?? GoogleSignIn.instance,
       _googleIdTokenOverride = googleIdToken;

  final fb.FirebaseAuth _auth;
  final GoogleSignIn _google;
  final Future<String?> Function()? _googleIdTokenOverride;

  /// Whether *this process* has initialised the Google plugin -- which says
  /// nothing about whether the account is a Google one. It used to be read as
  /// if it did: after a restart it was false, a Google account's delete fell
  /// through to a password prompt it could never answer. Only the plugin
  /// lifecycle reads it now; [reauthMethod] decides the account's kind.
  bool _googleInitialised = false;

  /// Firebase refuses a sensitive operation once the sign-in is about five
  /// minutes old. Four leaves the flush and the wipe room to run between the
  /// check and the delete; `requires-recent-login` remains the backstop.
  static const Duration recentLoginWindow = Duration(minutes: 4);

  /// Which proof an account with these linked sign-in methods can give.
  ///
  /// Google wins when it is linked at all: it answers with one tap on an
  /// account sheet, and an account that reached Firebase through Google may
  /// never have had a password the student knows. Anything else is the
  /// email/password flow -- the only other way into this app.
  static ReauthMethod reauthMethodFor(Iterable<String> providerIds) =>
      providerIds.contains(googleProviderId)
      ? ReauthMethod.google
      : ReauthMethod.password;

  /// Firebase's provider id for a linked Google sign-in.
  static const String googleProviderId = 'google.com';

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
      await _auth.signInWithCredential(await _freshGoogleCredential());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  /// A Google ID token from the plugin's account sheet, initialising the
  /// plugin on demand -- sign-in and re-authentication both come through here,
  /// so a process that restored its session from disk can still re-prove a
  /// Google account without having signed in through Google first.
  Future<String?> _pluginGoogleIdToken() async {
    // v7 requires an explicit initialise. `serverClientId` is deliberately
    // omitted: on Android the plugin reads `default_web_client_id`, the
    // string resource the google-services Gradle plugin generates from
    // google-services.json, so the id lives in one place.
    if (!_googleInitialised) {
      await _google.initialize();
      _googleInitialised = true;
    }
    final account = await _google.authenticate();
    return account.authentication.idToken;
  }

  /// A fresh Google credential, with the plugin's failures already in the
  /// app's vocabulary.
  Future<fb.AuthCredential> _freshGoogleCredential() async {
    try {
      final idToken = await (_googleIdTokenOverride ?? _pluginGoogleIdToken)();
      if (idToken == null) throw const AuthException(AuthFailure.unknown);
      return fb.GoogleAuthProvider.credential(idToken: idToken);
    } on GoogleSignInException catch (e) {
      // Backing out of the account sheet is not a failure to report.
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled
            ? AuthFailure.cancelled
            : AuthFailure.unknown,
      );
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
  ReauthMethod? get reauthMethod {
    final user = _auth.currentUser;
    if (user == null) return null;
    return reauthMethodFor(user.providerData.map((info) => info.providerId));
  }

  @override
  Future<bool> hasRecentLogin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    try {
      // `auth_time` is the claim Firebase itself checks for
      // `requires-recent-login`; a re-authentication refreshes it.
      final authTime = (await user.getIdTokenResult()).authTime;
      if (authTime == null) return false;
      return DateTime.now().difference(authTime) < recentLoginWindow;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> reauthenticateWithGoogle() =>
      _reauthenticate(_freshGoogleCredential);

  @override
  Future<void> reauthenticateWithPassword(String password) =>
      _reauthenticate(() async {
        final email = _auth.currentUser?.email;
        if (email == null) throw const AuthException(AuthFailure.unknown);
        return fb.EmailAuthProvider.credential(
          email: email,
          password: password,
        );
      });

  /// [credential] is a closure rather than a value so no password is held
  /// longer than the call that uses it.
  Future<void> _reauthenticate(
    Future<fb.AuthCredential> Function() credential,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw const AuthException(AuthFailure.unknown);
    try {
      await user.reauthenticateWithCredential(await credential());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

  /// Deletes the account. Callers re-authenticate first (see
  /// [AuthRepository.hasRecentLogin]); what is here is the backstop for when
  /// Firebase still answers `requires-recent-login`.
  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    // Already gone. Treated as success so a retry after a partial failure
    // finishes rather than reporting an error about work already done.
    if (user == null) return;

    try {
      await _delete(user);
    } on AuthException catch (e) {
      // One automatic retry through the Google sheet when the account is a
      // Google one -- decided from the account, not from whether this process
      // signed in through Google (see [_googleInitialised]). The student with
      // the phone in their hand is the owner, and a re-auth prompt they cannot
      // answer is a dead delete button. A password account has to be asked,
      // so that goes back to the caller.
      if (e.failure != AuthFailure.requiresRecentLogin ||
          reauthMethod != ReauthMethod.google) {
        rethrow;
      }
      await reauthenticateWithGoogle();
      await _delete(user);
    }
    await _clearGoogleSession();
  }

  Future<void> _delete(fb.User user) async {
    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      throw AuthException(_map(e));
    } catch (_) {
      throw const AuthException(AuthFailure.unknown);
    }
  }

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
