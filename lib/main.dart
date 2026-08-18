import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded before the first frame so the locale notifier can read the persisted
  // language synchronously -- otherwise the app flashes Arabic before switching
  // to English for a student who chose English.
  final preferences = await SharedPreferences.getInstance();

  // Firebase reads its cached session from disk here, with no network call, so
  // by the first frame the router already knows whether this student is signed
  // in. That is what lets a signed-in student open the app in airplane mode.
  //
  // Wrapped because initialisation must never be what stops a student reaching
  // their own offline data: if it fails, the app still boots and the login
  // screen reports the failure honestly.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await _activateAppCheck();
    await _initializeCrashlytics();
  } catch (error, stack) {
    debugPrint('Firebase init failed: $error\n$stack');
  }

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const AtherApp(),
    ),
  );
}

/// Attaches an App Check token to Firebase requests, so being in possession of
/// the API key stops being sufficient to talk to this project.
///
/// **Why this is needed.** The key in `firebase_options.dart` is an identifier
/// rather than a secret, which is fine and normal — but only while something
/// else establishes that a caller is a real installation. Nothing did: the
/// security audit on 2026-08-15 created three accounts on the live project using
/// nothing but the key unzipped out of an APK. Without attestation, anyone can
/// mint accounts and drive Firestore writes that are individually legitimate,
/// which is a quota and billing problem rather than a confidentiality one — the
/// rules still stop them reaching another student's data.
///
/// **Why it ships before it is enforced, and why that order is not optional.**
/// Enforcement is a server-side switch, and it rejects every client that cannot
/// present a token. Versions 1.2.0 and 1.3.1 are already installed and contain
/// no App Check code at all, so turning enforcement on now would lock those
/// students out of sign-in and backup with no route forward but an update they
/// have not been offered. The sequence has to be: ship this, wait for the
/// installed base to move, watch the console's *unverified requests* metric fall,
/// and only then enforce.
///
/// Failure here is deliberately not fatal, for the same reason
/// `Firebase.initializeApp` is wrapped: attestation is not allowed to stand
/// between a student and study data sitting on their own phone. While
/// enforcement is off a failed activation costs nothing at all.
Future<void> _activateAppCheck() async {
  try {
    await FirebaseAppCheck.instance.activate(
      // `providerAndroid`, not the `androidProvider` in most tutorials -- that
      // one is deprecated as of firebase_app_check 0.4.6 and goes away in the
      // next major.
      //
      // Play Integrity attests that this is a genuine, Play-installed build. It
      // cannot succeed on a side-loaded APK or an emulator, which is exactly why
      // debug builds use the debug provider rather than pretending: the debug
      // provider prints a token to logcat that has to be registered in the
      // console, and a developer who never sees that step will not understand
      // why enforcement later breaks their local build.
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (error, stack) {
    // Reached on an emulator, a side-load, or a device with no Play Services.
    // Logged rather than swallowed: once enforcement is on, this line is the
    // difference between "App Check is refusing us" and "the network is down",
    // and those have completely different remedies.
    debugPrint('App Check activation failed: $error\n$stack');
  }
}

/// Initializes Firebase Crashlytics to automatically capture and report crashes
/// in production builds.
///
/// **Why this is needed.** The app holds a student's entire exam history with
/// no server copy, so crashes that cause data loss are unacceptable. Crashlytics
/// provides visibility into production crashes before students report them,
/// allowing issues to be fixed proactively.
///
/// **Why only in release builds.** Debug and profile builds generate noise from
/// development crashes that are not representative of production issues. Running
/// Crashlytics only in release builds keeps the console focused on real problems
/// that affect students.
///
/// Failure here is deliberately not fatal, for the same reason
/// `Firebase.initializeApp` is wrapped: crash reporting is not allowed to stand
/// between a student and study data sitting on their own phone.
Future<void> _initializeCrashlytics() async {
  // Skip initialization in debug builds to avoid noise from development crashes
  if (kDebugMode) return;

  try {
    // Enable automatic crash reporting for unhandled exceptions
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  } catch (error, stack) {
    // Crashlytics initialization failure should never prevent the app from
    // starting. Log the error so it's visible during development, but continue.
    debugPrint('Crashlytics initialization failed: $error\n$stack');
  }
}
