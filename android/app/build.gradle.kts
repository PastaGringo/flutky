import java.util.Properties

// Release signing. Obtainium refuses an update whose signature differs from
// the installed app, so this key must stay identical for the life of the
// project — losing it means every user has to uninstall and reinstall.
//
// key.properties is git-ignored and holds the passwords; the keystore itself
// lives outside the repository. When either is missing (a clone without the
// secrets), the build falls back to the debug key rather than failing: a
// developer build still runs, it simply cannot be published as an update.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProperties.getProperty("storeFile")
    ?.let { file(it).exists() } == true

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.delvops.flutky"
    // flutter_secure_storage 11 ships an AAR that requires API 37; Flutter's
    // default (36) fails :app:checkReleaseAarMetadata. AGP warns that 36 is its
    // recommended maximum, but the dependency check is what actually blocks.
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.delvops.flutky"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    // `--target-platform` and `ndk { abiFilters }` only reach libraries the
    // NDK compiles for us: neither touches the .so files shipped inside a
    // dependency AAR. ML Kit ships one per architecture, and its x86_64 build
    // survived both — 18 MB of code that cannot run anyway, since the Flutter
    // engine is no longer there for that architecture. Excluding at packaging
    // time is the only filter that applies to every source of native code.
    //
    // Emulators are the only x86 Android there is; no phone needs these.
    // Emulators are the only x86 Android there is, so a release drops those
    // libraries — 18 MB that no phone can use. A build for an emulator needs
    // them back, hence the switch rather than a line to comment out and
    // forget:  flutter build apk --release -Pemulator=true
    packaging {
        jniLibs {
            if (!project.hasProperty("emulator")) {
                excludes += listOf("lib/x86/**", "lib/x86_64/**")
            }
        }
    }

    buildTypes {
        release {
            // A release that quietly falls back to the debug key is worse than
            // one that does not build: it installs, it runs, it looks right —
            // and Android then refuses every update, because a signature is
            // the app's identity. Obtainium shows "Signing certificate
            // mismatch" and the only way out is uninstalling, which costs the
            // session.
            //
            // It happened: v0.16.0 and v0.17.0 went out signed with a debug
            // key, built from a fresh checkout where `key.properties` — which
            // git ignores — was simply absent. Nothing warned.
            //
            // So a release now FAILS without the key. A developer who only
            // wants to run the thing passes -Pdebug-signing=true and gets an
            // APK that is explicitly not publishable.
            if (!hasReleaseKey && !project.hasProperty("debug-signing")) {
                throw GradleException(
                    "Clé de release introuvable : android/key.properties ou le " +
                    "keystore qu'il désigne est absent. Un APK signé avec la " +
                    "clé de débogage ne pourra jamais être mis à jour par-dessus " +
                    "une version publiée. Pour une construction locale non " +
                    "publiable : -Pdebug-signing=true",
                )
            }
            signingConfig = if (hasReleaseKey) {
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
