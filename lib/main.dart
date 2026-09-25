import 'dart:async' show unawaited;
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/diagnostics/crash_reporting.dart';
import 'core/haptics/app_haptics.dart';
import 'firebase_options.dart';
import 'presentation/providers/app_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Loaded before the first frame so the locale notifier can read the persisted
  // language synchronously -- otherwise the app flashes Arabic before switching
  // to English for a student who chose English.
  //
  // Firebase reads its cached session from disk here, with no network call, so
  // by the first frame the router already knows whether this student is signed
  // in. That is what lets a signed-in student open the app in airplane mode.
  //
  // The two are **independent** disk reads -- neither consumes the other's
  // result -- so they run concurrently and `runApp` waits for both. Serially,
  // the white screen paid for the sum; concurrently it pays for the slower of
  // the two, which on a mid-range phone is Firebase by a wide margin, leaving
  // SharedPreferences effectively free. Everything each step needs before the
  // first frame is still guaranteed: the haptics gate below is seeded from
  // prefs inside its own future, before the wait completes.
  final preferencesFuture = _loadPreferences();
  var firebaseReady = false;
  final firebaseFuture = () async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      await _initializeCrashlytics();
      firebaseReady = true;
    } catch (error, stack) {
      debugPrint('Firebase init failed: $error\n$stack');
    }
  }();
  await Future.wait(<Future<void>>[preferencesFuture, firebaseFuture]);
  final preferences = await preferencesFuture;

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const AtherApp(),
    ),
  );

  // App Check activates after the first frame rather than ahead of it. Of the
  // three awaits that used to sit between process start and `runApp`, it was
  // the only one whose cost is large *and* unpredictable -- Play Integrity
  // talks to Play Services over the network -- and awaiting it held the white
  // screen open for every student to buy something that today changes no
  // behaviour at all. The other two waits stay where they are because the
  // first frame genuinely reads their results (the persisted language above,
  // and the cached sign-in session below).
  //
  // Guarded so activation is still only ever attempted once Firebase exists:
  // a failed `initializeApp` previously skipped it by falling out of the try
  // block, and that stays true here.
  if (firebaseReady) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_activateAppCheck());
    });
  }
}

/// Loads the preferences and seeds the haptics gate from disk before the first
/// frame.
///
/// AppHaptics is a static API that cannot watch a provider, and its provider is
/// built lazily, so without this a student who turned vibration off would get
/// it back on every cold start until they happened to open Settings. Same
/// reasoning as the persisted locale: read here because the first frame reads
/// it.
Future<SharedPreferences> _loadPreferences() async {
  final preferences = await SharedPreferences.getInstance();
  AppHaptics.configure?.call(preferences.getBool(kHapticsEnabledKey) ?? true);
  return preferences;
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
/// **Why it runs after the first frame, not before it.** This used to be
/// awaited in `main`, third in line behind `SharedPreferences` and
/// `Firebase.initializeApp`. Those two stay ahead of `runApp` because the first
/// frame genuinely reads their results — the persisted language, so it does not
/// flash Arabic at an English-speaking student; the cached sign-in session, so
/// a signed-in student can open the app in airplane mode. Attestation protects
/// *requests*, and drawing frame one makes none; meanwhile activation is the
/// one call in the boot chain whose cost is unknown — Play Integrity talks to
/// Play Services over the network — so awaiting it put its worst case straight
/// onto the white screen of every cold start. It therefore runs from the
/// first post-frame callback, once the student is looking at the app.
///
/// **Why it ships before it is enforced, and why that order is not optional.**
/// Enforcement is a server-side switch, and it rejects every client that cannot
/// present a token. Versions 1.2.0 and 1.3.1 are already installed and contain
/// no App Check code at all, so turning enforcement on now would lock those
/// students out of sign-in and backup with no route forward but an update they
/// have not been offered. The sequence has to be: ship this, wait for the
/// installed base to move, watch the console's *unverified requests* metric fall,
/// and only then enforce. Until then a token is requested and never demanded,
/// which is what makes deferring the activation free today: no behaviour any
/// student could observe depends on when it lands.
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
    // Two channels, because two kinds of unhandled error exist.
    //
    // `FlutterError.onError` catches what the framework drives: build, layout,
    // paint, and the callbacks it schedules. An exception escaping an
    // *unguarded* async callback -- a timer, a stream listener, a future
    // nobody awaited -- never passes through it at all, and used to vanish
    // without a trace. That is what the second channel is for:
    // `PlatformDispatcher.onError` is the engine's last look at every error
    //   in the zone. Returning true marks the error handled, so reporting it is
    //   the whole outcome; the app keeps running rather than dying twice for
    //   one mistake.
    //
    // `fatal: true` on the second channel is deliberate: an error reaching it
    // was unhandled everywhere and its isolate was dying anyway, so the report
    // keeps the severity the event actually had.
    //
    // Known constraint: this runs after `Firebase.initializeApp`, so a device
    // where that call throws gets no crash channels at all. Accepted on
    // purpose -- bootstrapping must never be what stops a student reaching
    // their own offline data.
    //
    // Both go through `core/diagnostics/crash_reporting.dart` rather than
    // straight to Crashlytics: an unhandled drift InvalidDataException carries
    // the row it refused -- the student's own chapter or task name -- and the
    // plain `recordFlutterError`/`recordError` would upload it verbatim.
    FlutterError.onError = reportFlutterError;
    PlatformDispatcher.instance.onError = (error, stack) {
      reportFatal(error, stack);
      return true;
    };
  } catch (error, stack) {
    // Crashlytics initialization failure should never prevent the app from
    // starting. Log the error so it's visible during development, but continue.
    debugPrint('Crashlytics initialization failed: $error\n$stack');
  }
}
