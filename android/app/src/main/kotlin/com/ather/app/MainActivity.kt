package com.ather.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends FlutterFragmentActivity, not FlutterActivity.
 *
 * local_auth raises the system biometric prompt through AndroidX BiometricPrompt,
 * which requires a FragmentActivity host. With the default FlutterActivity the
 * plugin throws "no_fragment_activity" the moment it is called -- and because the
 * lock screen deliberately releases when biometrics cannot answer, that failure
 * looked exactly like "this device has no fingerprint" instead of a broken build.
 */
class MainActivity : FlutterFragmentActivity() {

    /**
     * Turns FLAG_SECURE on and off from Dart.
     *
     * ## Why this exists
     *
     * Settings offers a fingerprint lock, and a student who turns it on has said
     * they do not want somebody holding their phone to read their record. The
     * lock covers the app (see `_LockGate`), but it does not cover the **task
     * switcher**: Android captures a thumbnail of the last drawn frame when the
     * activity goes away, and that frame is the dashboard. Pressing recents
     * shows the student's mastery number and subject list with no fingerprint
     * asked for -- the lock screen sits behind a picture of what it is hiding.
     *
     * Confirmed rather than assumed: `adb exec-out screencap` returned a normal
     * image of the signed-in dashboard on 2026-08-15, which it cannot do on a
     * window carrying FLAG_SECURE.
     *
     * ## Why it is a switch rather than always on
     *
     * FLAG_SECURE also blocks the student's own screenshots, and sharing a
     * mastery number with a friend or a teacher is a perfectly ordinary thing to
     * want. The lock is off by default, so for most students nothing changes;
     * this follows the switch they already set rather than adding a second
     * decision about the same thing.
     *
     * Applied on the UI thread because window flags may only be touched there,
     * and `MethodChannel` handlers already arrive on it.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.ather.app/secure_window",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setSecure" -> {
                    val secure = call.arguments as? Boolean ?: false
                    if (secure) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
