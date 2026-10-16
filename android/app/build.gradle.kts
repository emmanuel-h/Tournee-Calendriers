plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    // Reads google-services.json (gitignored, written from a secret in CI)
    // into the Android resources Firebase starts from. The markers let
    // `flutterfire configure` find its own lines when run again.
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.mandarine.tourneecalendriers"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "fr.mandarine.tourneecalendriers"
        // Android 8.0 (API 26) and later, as decided in PLAN §10.2.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The upload key (Play App Signing holds the app key). Its four settings
    // come from ~/.gradle/gradle.properties or the environment, never from
    // the repository; see the release-store skill.
    val releaseSigning = listOf(
        "TOURNEE_RELEASE_KEYSTORE_FILE",
        "TOURNEE_RELEASE_KEYSTORE_PASSWORD",
        "TOURNEE_RELEASE_KEY_ALIAS",
        "TOURNEE_RELEASE_KEY_PASSWORD",
    ).associateWith { findProperty(it)?.toString() ?: System.getenv(it) }

    if (releaseSigning.values.none { it.isNullOrBlank() }) {
        signingConfigs {
            create("release") {
                storeFile = file(releaseSigning.getValue("TOURNEE_RELEASE_KEYSTORE_FILE")!!)
                storePassword = releaseSigning.getValue("TOURNEE_RELEASE_KEYSTORE_PASSWORD")
                keyAlias = releaseSigning.getValue("TOURNEE_RELEASE_KEY_ALIAS")
                keyPassword = releaseSigning.getValue("TOURNEE_RELEASE_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Without the upload key (CI, another machine) the release build
            // still builds, signed with the debug key; Play refuses such a
            // bundle, and the release-store skill checks the certificate.
            signingConfig = signingConfigs.findByName("release")
                ?: signingConfigs.getByName("debug")
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
