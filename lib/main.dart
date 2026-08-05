import 'package:firebase_core/firebase_core.dart';
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
