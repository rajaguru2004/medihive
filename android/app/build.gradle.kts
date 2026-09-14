import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Optional release signing, read from `android/key.properties`.
//
// That file is gitignored and absent on a clean checkout, so this resolves to
// empty on every machine that has not been given the hospital's key. The
// fallback in `buildTypes` keeps `flutter run --release` working locally; it
// does not make the output shippable — see the comment there.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties =
    Properties().apply {
        if (keystorePropertiesFile.exists()) {
            keystorePropertiesFile.inputStream().use { load(it) }
        }
    }

// A file that is there at all is meant to be used, so an incomplete one stops
// the build instead of falling back. The fallback is silent by design and a
// silent fallback on a machine that *does* hold the key is how a release APK
// goes out signed by a debug certificate.
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    val missing =
        listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
            .filter { keystoreProperties.getProperty(it).isNullOrBlank() }
    require(missing.isEmpty()) {
        "android/key.properties is missing: ${missing.joinToString(", ")}"
    }
}

android {
    namespace = "com.medihive.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.medihive.app"

        // Pinned rather than inherited from `flutter.minSdkVersion`, which moves
        // with the SDK a developer happens to have checked out — a floor that
        // shifts under a hospital's device fleet between two builds of the same
        // commit is not a floor. 24 is the lowest this dependency set allows:
        // `shared_preferences_android` declares 24, and the whole brand/face
        // snapshot restored before the first frame goes through it.
        //
        // (`flutter_launcher_icons.min_sdk_android` in pubspec.yaml still says
        // 21. It only decides whether adaptive icons are generated, so it is
        // harmless, but it is stale.)
        minSdk = 24

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // Resolved against `android/app/`, per Flutter's keystore docs.
                // An absolute path is the safe thing to write in key.properties.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Falls back to the debug keystore, which Gradle generates per
            // machine with a known password and a 30-year self-signed cert.
            // That is fine for `flutter run --release` and is NOT a build that
            // can ship: every developer's machine produces a different signing
            // identity, so no two of them can upgrade each other's install, and
            // anyone can re-sign the APK. A real keystore plus
            // `android/key.properties` is required before the first release.
            signingConfig =
                signingConfigs.findByName("release")
                    ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
