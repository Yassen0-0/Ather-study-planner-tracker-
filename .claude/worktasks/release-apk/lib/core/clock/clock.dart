/// Injectable time source.
///
/// The 30-day review cycle is the app's central mechanic, and a hard-coded
/// `DateTime.now()` would make it untestable without literally waiting a month.
/// Every piece of code that asks what time it is goes through a [Clock], so
/// tests can pin the date and a debug tool can fast-forward it.
abstract interface class Clock {
  DateTime now();
}

/// Real wall clock. Used everywhere in release builds.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Clock that can be pinned and advanced. Used by unit tests and the debug-only
/// time-travel tool that verifies review decay in seconds instead of 30 days.
final class MutableClock implements Clock {
  MutableClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  /// Deliberately a method, not a `set now` -- a setter named `now` would
  /// collide with the [Clock.now] method this class implements.
  void setNow(DateTime value) => _now = value;

  void advance(Duration by) => _now = _now.add(by);

  void advanceDays(int days) => advance(Duration(days: days));
}
