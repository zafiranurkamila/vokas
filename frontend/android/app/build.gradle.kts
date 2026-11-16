plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.vokas_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // dibutuhkan flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.vokas_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Kunci rilis tetap (dari GitHub secret) supaya SHA-1 tidak berubah: wajib untuk login Google di Android
    // dan supaya APK baru bisa dipasang menimpa versi lama. Tanpa kunci ini, build memakai kunci debug.
    val kunciRilis = System.getenv("VOKAS_KEYSTORE")
    signingConfigs {
        create("rilis") {
            if (kunciRilis != null && file(kunciRilis).exists()) {
                storeFile = file(kunciRilis)
                storePassword = System.getenv("VOKAS_KEYSTORE_PASSWORD")
                keyAlias = "vokas"
                keyPassword = System.getenv("VOKAS_KEYSTORE_PASSWORD")
            }
        }
    }

    // lint rilis dimatikan: lint plugin pihak ketiga (google_sign_in_android) bisa crash dan tidak memengaruhi APK
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    buildTypes {
        release {
            signingConfig = if (kunciRilis != null && file(kunciRilis).exists())
                signingConfigs.getByName("rilis") else signingConfigs.getByName("debug")
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
