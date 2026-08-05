import java.util.Properties

// Release signing credentials, kept out of the repository.
//
// `android/key.properties` is git-ignored and holds the keystore path and its
// passwords; the keystore file itself lives outside the project. Neither is ever
// committed -- an upload key in a git history is an upload key that has to be
// treated as compromised, and Play will not let you replace it without a support
// request.
//
// If the file is absent, a **release** build fails outright rather than quietly
// falling back to the debug key. That fallback is what shipped a debug-signed
// APK once already, and it is the same trap §3.18 of PROJECT.md names: a safe
// default that hides its own cause. Gradle's `logger.warn` is not an option
// here -- `flutter build` swallows it, so the "warning" would never be read.
//
// Debug and profile builds are untouched: `flutter run` still works on a machine
// with no keystore at all.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

val buildingRelease = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}

if (buildingRelease && !hasReleaseKeystore) {
    throw GradleException(
        "\n\nRelease build refused: android/key.properties is missing.\n\n" +
            "Signing a release with the debug key produces an APK that cannot go " +
            "to Play and that a properly signed build can never upgrade in place, " +
            "so it is not offered as a fallback.\n\n" +
            "  1. Create a keystore (choose your own password):\n" +
            "     keytool -genkey -v -keystore <path>\\ather-upload.jks " +
            "-storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias ather\n" +
            "  2. Copy android/key.properties.example to android/key.properties " +
            "and fill it in.\n\n" +
            "To build something merely runnable in the meantime, use " +
            "`flutter build apk --debug`.\n"
    )
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ather.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules review reminders with
        // java.time APIs that do not exist below API 26. Desugaring back-fills
        // them; without it the build fails outright at :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Permanent from the day this is published: Play keys the listing, the
        // store URL and every install off it, and it cannot be changed
        // afterwards. Renamed from the pre-rebrand `com.sahm.sahm` while the
        // only installs in the world were test ones.
        //
        // The SQLite file is deliberately NOT renamed with it -- see
        // AppDatabase, where it is still `sahm`.
        applicationId = "com.ather.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Declared only when the credentials are actually present. Referencing a
        // keystore that is not there makes every Gradle task fail, including the
        // debug build.
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Unreachable without a keystore: the guard at the top of this file
            // has already failed the build. The debug branch exists only so that
            // configuring a non-release task does not reference a signing config
            // that was never created.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
