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

/// [count] **calendar** days before [from], keeping the time of day.
///
/// `from.subtract(Duration(days: n))` is not this, and the difference is not
/// academic: a `Duration` is elapsed time, and Egypt puts its clocks forward in
/// late April. Subtracting 100×24h from midnight on 1 June lands on 23:00 on
/// **20** February, not midnight on the 21st — so a fixture reading
/// "100 days ago" quietly describes 101 calendar days ago, and the assertion
/// written next to it is off by one in a way nothing points at.
///
/// The review cycle counts calendar days (`ReviewCycleService.daysSinceReview`),
/// so fixtures for it have to be built in the same unit.
DateTime daysBefore(DateTime from, int count) => DateTime(
  from.year,
  from.month,
  from.day - count,
  from.hour,
  from.minute,
  from.second,
);
