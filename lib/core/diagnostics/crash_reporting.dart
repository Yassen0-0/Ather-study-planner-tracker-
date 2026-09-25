import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// The one way code outside `main.dart` reports a non-fatal error (S4, S5).
///
/// It replaces direct `FirebaseCrashlytics.instance.recordError` calls, which
/// had two problems:
///
/// * **They could throw.** `FirebaseCrashlytics.instance` needs an initialised
///   Firebase app, and `main()` deliberately tolerates `Firebase.initializeApp`
///   failing (PROJECT.md §3.17). On such a device the report itself threw from
///   inside a `catch` block -- replacing the error being handled, in the one
///   place (a migration, an exam save) where the original mattered most.
/// * **They sent student text.** `recordError` uploads `exception.toString()`.
///   drift's `InvalidDataException` embeds the companion it rejected --
///   `ChaptersCompanion(name: Value(<what the student typed>), ...)` -- and a
///   `SqliteException` appends the statement *and its parameters*. Chapter,
///   lesson and task names are the student's own words, and the privacy
///   screen promises they stay on the phone.
///
/// So this records the error's **type** and a [scrubbedDescription] of it, and
/// it never throws: a crash report is never allowed to become the failure.
///
/// Release builds only, matching `main.dart`'s policy for the crash channels:
/// `debugPrint` covers local visibility, and a development device reporting
/// non-fatals would fill the production console with its own experiments.
void reportNonFatal(Object error, StackTrace stack, {String? reason}) =>
    _report(error, stack, reason: reason, fatal: false);

/// [reportNonFatal] for an error nothing caught -- `main.dart`'s
/// `PlatformDispatcher.onError`. Same scrubbing, same never-throw; the report
/// keeps `fatal: true` because the error really was unhandled everywhere.
void reportFatal(Object error, StackTrace stack) =>
    _report(error, stack, fatal: true);

/// The framework's error channel (`FlutterError.onError`), scrubbed.
///
/// Replaces `FirebaseCrashlytics.instance.recordFlutterError`, which sends
/// `exceptionAsString()` -- the same student text [scrubbedDescription]
/// exists to keep home -- plus the `context` node and everything the
/// `informationCollector` adds. Those describe the widget that failed, and a
/// widget's description can quote the `Text` it was showing: a lesson name,
/// a task. So the exception goes through [ScrubbedError], the context through
/// [scrubText], and the collected information is not sent at all. The
/// library name and the stack trace are kept: they locate the bug and carry
/// nothing the student typed.
///
/// The error is still printed to the local console first, as
/// `recordFlutterError` did, so a release log on a developer's own device
/// reads the same as before.
void reportFlutterError(FlutterErrorDetails details, {bool fatal = false}) {
  try {
    FlutterError.presentError(details);
  } catch (_) {}
  try {
    final context = details.context?.toString();
    final scrubbedContext = context == null ? '' : scrubText(context);
    final reason = <String>[
      if (details.library != null) details.library!,
      if (scrubbedContext.isNotEmpty) scrubbedContext,
    ].join(': ');
    _report(
      details.exception,
      details.stack ?? StackTrace.empty,
      reason: reason.isEmpty ? null : reason,
      fatal: fatal,
    );
  } catch (_) {}
}

void _report(
  Object error,
  StackTrace stack, {
  String? reason,
  required bool fatal,
}) {
  try {
    final scrubbed = ScrubbedError.of(error);
    final sink = nonFatalSinkForTesting;
    if (sink != null) {
      sink(scrubbed, stack, reason, fatal);
      return;
    }
    if (kDebugMode) return;
    if (Firebase.apps.isEmpty) return;
    unawaited(
      FirebaseCrashlytics.instance
          .recordError(
            scrubbed,
            stack,
            reason: reason,
            fatal: fatal,
            printDetails: false,
          )
          .catchError((Object _) {}),
    );
  } catch (_) {
    // Nothing to do: see the class comment. The caller's own handling of the
    // original error goes on unaffected.
  }
}

/// Receives what [reportNonFatal], [reportFatal] and [reportFlutterError]
/// would have sent, in place of Crashlytics.
@visibleForTesting
void Function(
  ScrubbedError error,
  StackTrace stack,
  String? reason,
  bool fatal,
)?
nonFatalSinkForTesting;

/// What actually leaves the phone for an error: its type, and a description
/// with anything the student might have typed taken out.
final class ScrubbedError implements Exception {
  const ScrubbedError(this.type, this.description);

  factory ScrubbedError.of(Object error) =>
      ScrubbedError(error.runtimeType.toString(), scrubbedDescription(error));

  /// The original error's runtime type, e.g. `InvalidDataException`.
  final String type;

  /// See [scrubbedDescription]. May be empty.
  final String description;

  @override
  String toString() => description.isEmpty ? type : '$type: $description';
}

/// The longest description ever sent. What survives scrubbing is structure --
/// a constraint name, an error code -- and none of it needs more.
const int kMaxScrubbedLength = 200;

/// Markers after which an error message is statement text, parameters or a
/// dump of row values -- student text, in this app -- and is cut off.
const List<String> _cutMarkers = <String>[
  'Causing statement',
  'parameters:',
  'Companion(',
  'Value(',
  'Instance of',
];

/// [error] described without any text the student could have typed.
///
/// A whitelist where one is possible, a scrub where it is not:
///
/// * a `FirebaseException` is reduced to its plugin and code -- the server's
///   message can quote a document path, and the path carries the uid;
/// * anything else keeps its message only up to the first [_cutMarkers]
///   entry, with every quoted span and every non-ASCII character removed --
///   Arabic is what students type, and a quoted span is how SQLite quotes a
///   value -- and is capped at [kMaxScrubbedLength].
///
/// What is left is enough to tell a full disk from a constraint from a
/// migration bug, which is what the report is for.
String scrubbedDescription(Object error) {
  if (error is FirebaseException) return '[${error.plugin}/${error.code}]';

  var text = error.toString();
  // `toString` usually leads with the type, which [ScrubbedError] already
  // carries.
  final type = error.runtimeType.toString();
  if (text.startsWith('$type: ')) text = text.substring(type.length + 2);
  return scrubText(text);
}

/// The text half of [scrubbedDescription], for any string that may quote
/// the student: cut at the first [_cutMarkers] entry, quoted spans and
/// non-ASCII characters removed, whitespace collapsed, capped at
/// [kMaxScrubbedLength].
String scrubText(String input) {
  var text = input;
  for (final marker in _cutMarkers) {
    final at = text.indexOf(marker);
    if (at != -1) text = text.substring(0, at);
  }
  text = text
      .replaceAll(RegExp(r"'[^']*'"), "''")
      .replaceAll(RegExp(r'"[^"]*"'), '""')
      .replaceAll(RegExp(r'[^\x20-\x7E]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.length > kMaxScrubbedLength
      ? text.substring(0, kMaxScrubbedLength)
      : text;
}
