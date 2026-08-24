import 'dart:io';

import 'package:flutter/services.dart';

/// Keeps the app's contents out of the task-switcher thumbnail and out of
/// screenshots, for students who asked for the fingerprint lock.
///
/// The lock in Settings covers the app while it is open. It does not cover what
/// Android keeps *after* it closes: the platform snapshots the last drawn frame
/// for the recents list, and that frame is the dashboard -- the mastery number,
/// the subject list, the overdue lessons. So the lock screen was standing in
/// front of a photograph of everything behind it, and the fingerprint was never
/// asked for to see the photograph.
///
/// `FLAG_SECURE` is the platform's answer and there is no Flutter API for it, so
/// this is the one method channel in the app. It is deliberately **not** always
/// on: the same flag blocks the student's own screenshots, and there is nothing
/// wrong with a student sending a friend a picture of their progress. It follows
/// the switch they already set, and does nothing at all on a device where they
/// never turned it on -- which is the default.
///
/// Android only. iOS has no equivalent flag and the desktop builds have no task
/// switcher thumbnail to protect; both are a silent no-op rather than a failure,
/// because a platform that cannot be asked must never stand between a student
/// and their study record.
abstract final class SecureWindow {
  static const MethodChannel _channel = MethodChannel(
    'com.ather.app/secure_window',
  );

  /// Never throws. A missing channel -- an old engine, a platform without the
  /// handler, a test with no binary messenger -- means the flag cannot be set,
  /// which is the state the app was already in.
  static Future<void> set({required bool secure}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('setSecure', secure);
    } on Object {
      // Nothing to tell the student: they cannot act on it, and the app works.
    }
  }
}
