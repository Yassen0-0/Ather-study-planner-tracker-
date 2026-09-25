import '../entities/account.dart';

/// Why a sign-in attempt failed, in the app's own vocabulary.
///
/// Structured rather than a message string, for the same reason insights are:
/// the data layer has no access to localisation, so it returns a variant and
/// the presentation layer renders it through the ARB files. A failure that
/// arrived as English text could never be shown to an Arabic student.
enum AuthFailure {
  invalidEmail,
  weakPassword,

  /// Wrong password, unknown account, or a disabled one. Deliberately one
  /// case: telling an attacker which emails are registered is a gift, and the
  /// student's next action is identical either way.
  wrongCredentials,

  emailInUse,

  /// No network. The only failure the copy has to explain at length, because
  /// it is the one moment this offline-first app genuinely needs a connection.
  network,

  tooManyRequests,

  /// The student backed out of the Google sheet. Not an error — the UI shows
  /// nothing at all for this.
  cancelled,

  /// The account exists but Firebase will not delete it until the student
  /// proves they are its owner again. Surfaces a re-authentication step, never
  /// a dead button: Google Play requires in-app account deletion, and a delete
  /// that fails silently is worse than none.
  requiresRecentLogin,

  unknown,
}

final class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

/// How the signed-in account proves, a second time, that it is its owner.
///
/// Decided from the account's own linked sign-in methods, never from how this
/// process happened to sign in: a session restored from disk after a restart
/// has not touched Google in this process, and asking a Google account for a
/// password it never had is a question the student cannot answer.
enum ReauthMethod { google, password }

/// Accounts. Everything here throws [AuthException] and nothing else.
abstract interface class AuthRepository {
  /// Emits the current account, or null when signed out. Emits immediately on
  /// listen with the restored session, so the router can decide without a
  /// round trip.
  Stream<Account?> watchAccount();

  /// The session restored from disk, available synchronously after
  /// `Firebase.initializeApp`. This is what makes the app openable with no
  /// network: the gate reads a cached answer, it does not ask a server.
  Account? get currentAccount;

  Future<void> signIn({required String email, required String password});

  /// Returns whether the verification mail was actually sent.
  ///
  /// **Not `void`, and the return value is not decoration.** The send is
  /// best-effort -- the account exists whether or not the mail goes out, so a
  /// failure to send must not fail the registration. But the screen used to
  /// say "we sent you a confirmation link" on every successful `register`,
  /// which is a statement about something it had no way to know. Several
  /// students registering from one school's IP is enough for Firebase to
  /// rate-limit the send; the account is created, the mail is not, and the
  /// student is told to go and look for it.
  Future<bool> register({required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  /// Sends (or re-sends) the address-verification link to the current account.
  ///
  /// Separate from [register], which already sends one, because the first mail
  /// gets lost, filtered, or opened on a phone the student no longer has. A
  /// verification a student cannot re-trigger is a dead end.
  ///
  /// Throws [AuthFailure.tooManyRequests] when Firebase rate-limits the resend.
  /// That is a "wait a moment", not a failure of the account, and the caller
  /// must say so rather than reporting a generic error.
  Future<void> sendEmailVerification();

  /// Re-reads the account from the server.
  ///
  /// Verification happens *outside* the app -- the student opens their inbox
  /// and taps a link -- so nothing in the running app would otherwise notice.
  /// Called when a screen that shows the verified state opens, so returning
  /// from the inbox shows the truth rather than a stale prompt to do something
  /// already done.
  Future<void> reloadAccount();

  Future<void> signOut();

  /// Deletes the account **and the credentials Firebase holds for it**.
  ///
  /// Callers re-authenticate *before* starting a deletion (see
  /// [hasRecentLogin]); this still throws [AuthException] with
  /// [AuthFailure.requiresRecentLogin] when Firebase disagrees about how
  /// recent the sign-in is and the account cannot re-prove itself here (a
  /// password account). The caller must re-authenticate and retry — never
  /// swallow it, because Google Play requires in-app account deletion and a
  /// delete that quietly does nothing is a dead button.
  Future<void> deleteAccount();

  /// Which proof [reauthenticateWithGoogle] / [reauthenticateWithPassword]
  /// this account can give. Null when signed out.
  ReauthMethod? get reauthMethod;

  /// Whether the sign-in is recent enough for Firebase to accept a sensitive
  /// operation (deleting the account) without asking again.
  ///
  /// Asked *before* anything destructive starts, so the answer "no" costs a
  /// prompt rather than a device already wiped under an account that then
  /// refuses to go. False when it cannot be told -- offline, signed out --
  /// because the cost of a needless prompt is one tap and the cost of a wrong
  /// "yes" is the student's data.
  Future<bool> hasRecentLogin();

  /// Re-proves ownership through the Google account sheet. Throws
  /// [AuthFailure.cancelled] when the student backs out of it.
  Future<void> reauthenticateWithGoogle();

  /// Re-proves ownership with the account's password.
  Future<void> reauthenticateWithPassword(String password);
}
