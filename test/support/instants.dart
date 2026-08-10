/// A fixed creation instant for rows a test builds as scenery.
///
/// `createChapter`, `createLesson` and `addTask` take their timestamp from the
/// injectable clock now rather than calling `DateTime.now()` (see
/// `StudyRepository.createChapter`). Most tests do not care when a chapter was
/// created — only that it exists — so they pass this instead of inventing a
/// date each time, and the ones that *do* care about ordering pass their own.
///
/// Deliberately earlier than the dates the review-cycle tests use, so a fixture
/// row can never sort ahead of something a test placed on purpose.
final DateTime kSeedInstant = DateTime(2025, 1, 1);
