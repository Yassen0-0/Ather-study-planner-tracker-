package com.sahm.sahm

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * Extends FlutterFragmentActivity, not FlutterActivity.
 *
 * local_auth raises the system biometric prompt through AndroidX BiometricPrompt,
 * which requires a FragmentActivity host. With the default FlutterActivity the
 * plugin throws "no_fragment_activity" the moment it is called -- and because the
 * lock screen deliberately releases when biometrics cannot answer, that failure
 * looked exactly like "this device has no fingerprint" instead of a broken build.
 */
class MainActivity : FlutterFragmentActivity()
