import com.google.gms.googleservices.GoogleServicesPlugin.MissingGoogleServicesStrategy
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing lives outside the repo. Locally `key.properties` is a symlink
// to ../../../secrets/android-key.properties; on CI the job writes the file.
// Without it, release builds fall back to the debug key.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

// One flavor per store (productFlavors below). Every Android build names one:
// `--flavor play|galaxy|huawei`, with the matching `--dart-define=STORE=...`.
// The Makefile passes both.

// The Firebase config moved into each store's source set, because galaxy and
// huawei are other Firebase apps. A copy left at the old place would be read
// by every flavor that has none of its own, and fail on the package name.
if (file("google-services.json").exists()) {
    throw GradleException(
        "android/app/google-services.json moved to android/app/src/play/google-services.json. " +
            "Run: mv android/app/google-services.json android/app/src/play/",
    )
}

// AGP 9 has no per-flavor asset packs. `assetPacks` lives on the android block
// only, and every variant's bundle gets the pack (assetPack<Variant>PreBundleTask).
// Only an app bundle carries a pack, so it is decided per Gradle run from the
// bundle tasks asked for: a run that bundles galaxy or huawei leaves the pack
// out. One run that bundles Play and another store cannot be right for both,
// so it stops. tool/store_leak_check.sh checks each bundle either way.
val bundledStores = gradle.startParameter.taskNames
    .map { it.substringAfterLast(':') }
    .mapNotNull { Regex("^bundle(Play|Galaxy|Huawei)").find(it)?.groupValues?.get(1)?.lowercase() }
    .toSet()
val bundlesOtherStore = bundledStores.any { it != "play" }
if (bundlesOtherStore && "play" in bundledStores) {
    throw GradleException(
        "Bundle the play flavor in its own Gradle run. Its sound pack cannot be scoped to it " +
            "when galaxy or huawei bundles in the same run (asked for: $bundledStores).",
    )
}

android {
    namespace = "app.critalarm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications requires core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.critalarm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // 28 is the floor flutter_local_notifications wants with core library
        // desugaring enabled below.
        minSdk = maxOf(28, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    flavorDimensions += "store"
    productFlavors {
        // Google Play. The app as it has always been: same package, same
        // Firebase app, the Play sound pack.
        create("play") {
            dimension = "store"
        }
        // Samsung Galaxy Store and Huawei AppGallery. Their own packages, so
        // all three install side by side. Store SDKs come with their own tasks.
        create("galaxy") {
            dimension = "store"
            applicationIdSuffix = ".galaxy"
        }
        create("huawei") {
            dimension = "store"
            applicationIdSuffix = ".huawei"
        }
    }

    // Sound packs the Play Store hosts and the app downloads on request. Only an
    // app bundle carries them; a sideloaded apk reports the pack as unavailable.
    // Play only, see bundledStores above.
    if (!bundlesOtherStore) {
        assetPacks += listOf(":sound_pack_library")
    }

    buildTypes {
        debug {
            // Builds the en-XA pseudo-locale from the default strings, so a
            // debug run with the pseudo-locale picked shows which native text
            // follows the app's language. Never on in release.
            isPseudoLocalesEnabled = true
        }
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Flutter's Gradle plugin switches R8 on for release builds, so
            // isMinifyEnabled is not set here. proguard-rules.pro holds the
            // keep rules R8 needs; without it the release app closes at launch.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// galaxy and huawei have no Firebase app of their own yet. Until their
// google-services.json files exist (src/galaxy/, src/huawei/, symlinks into
// secrets/), their builds go without one and Firebase starts from
// lib/firebase_options.dart. The setting is global, so the play build gets an
// explicit check instead: it never builds without its own file.
googleServices {
    missingGoogleServicesStrategy = MissingGoogleServicesStrategy.WARN
}
val playGoogleServices = file("src/play/google-services.json")
tasks.matching { it.name.startsWith("processPlay") && it.name.endsWith("GoogleServices") }.configureEach {
    doFirst {
        if (!playGoogleServices.exists()) {
            throw GradleException(
                "android/app/src/play/google-services.json is missing. It is kept out of this public repo.",
            )
        }
    }
}

// Crashlytics sends R8's map by the Firebase app id, which galaxy and huawei
// get from their own google-services.json. Without one the upload task has no
// app id and the build stops, so it is off for them until those files exist.
// Their crash reports then read as obfuscated names.
val noFirebaseAppYet = listOf("galaxy", "huawei").filter { !file("src/$it/google-services.json").exists() }
tasks.matching { task ->
    task.name.startsWith("uploadCrashlyticsMappingFile") &&
        noFirebaseAppYet.any { task.name.contains(it, ignoreCase = true) }
}.configureEach {
    enabled = false
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
    implementation(platform("com.google.firebase:firebase-bom:34.18.0"))
    implementation("com.google.firebase:firebase-messaging")
    implementation("androidx.core:core-ktx:1.17.0")
    // AssetPackManager, for the on-demand sound packs. Play only: the other
    // stores must not carry Play Core (tool/store_leak_check.sh).
    "playImplementation"("com.google.android.play:asset-delivery:2.3.0")

    testImplementation("junit:junit:4.13.2")
    testImplementation("com.google.code.gson:gson:2.13.2")
    // android.jar's org.json is a stub that throws. The real one lets the
    // incident-content parser be tested off-device.
    testImplementation("org.json:json:20250517")
}
