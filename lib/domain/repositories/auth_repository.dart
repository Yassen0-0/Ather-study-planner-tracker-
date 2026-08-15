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

  /// Firebase will not delete an account on a session it considers stale, and
  /// a student who signed in weeks ago and never signed out has exactly that.
  /// The remedy is to sign out and back in, so the copy has to say so — this
  /// arriving as [unknown] would read as "deleting is broken".
  requiresRecentLogin,

  unknown,
}

final class AuthException implements Exception {
  const AuthException(this.failure);

  final AuthFailure failure;

  @override
  String toString() => 'AuthException(${failure.name})';
}

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

  Future<void> register({required String email, required String password});

  Future<void> signInWithGoogle();

  Future<void> sendPasswordReset(String email);

  Future<void> signOut();

  /// Deletes the account itself, permanently.
  ///
  /// **This is not the whole of "delete my account", and must never be called on
  /// its own.** Firebase deletes the Auth user and nothing else: the student's
  /// backup document at `users/{uid}/backup/snapshot` is left behind, and with
  /// the account gone there is no longer any uid that satisfies the security
  /// rules for it — so the record becomes unreachable, undeletable, and
  /// permanent. Measured on the live project on 2026-08-15: deleting the user
  /// left the document sitting there until a separate explicit delete removed
  /// it.
  ///
  /// The cloud copy therefore goes **first**. `Settings` owns that order; see
  /// `_DeleteAccountCard`.
  Future<void> deleteAccount();
}
