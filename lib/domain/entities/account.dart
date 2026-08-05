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
  const Account({required this.id, required this.email, this.displayName});

  final String id;
  final String email;
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.email == email &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(id, email, displayName);
}
