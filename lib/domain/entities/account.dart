/// The signed-in student, reduced to what the app actually shows.
///
/// Deliberately tiny and provider-agnostic: no Firebase types leak past the
/// data layer, so the study code never learns where the account came from and
/// swapping the provider later touches one file.
///
/// **Nothing in the app keys study data off this.** Chapters, lessons and exams
/// live in local SQLite with no owner column — the account exists to identify
/// the student, not to gate their work.
final class Account {
  const Account({
    required this.id,
    required this.email,
    this.displayName,
    this.isEmailVerified = false,
  });

  final String id;
  final String email;
  final String? displayName;

  /// Whether the student has proved they can read this address.
  ///
  /// **Nothing in the app is gated on this.** The auth gate already stands in
  /// front of everything, the database is local, and locking a student out
  /// because they cannot reach their inbox would cost them their exam history
  /// -- a far worse outcome than an unverified address. It exists so the app
  /// can *ask*, once, in a place the student can dismiss.
  ///
  /// A Google account arrives with this already true: Google has verified the
  /// address, and asking again would be asking for a proof already given.
  final bool isEmailVerified;

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName &&
      other.isEmailVerified == isEmailVerified;

  @override
  int get hashCode => Object.hash(id, email, displayName, isEmailVerified);
}
