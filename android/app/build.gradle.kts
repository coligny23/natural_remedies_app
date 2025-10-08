// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

// --- Load signing properties (android/key.properties) ---
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")    // <- use this
    id("dev.flutter.flutter-gradle-plugin")
}


android {
    // ⚠️ Package names must be lowercase (recommend changing this)
    namespace = "com.example.afyabomba"

    compileSdk = flutter.compileSdkVersion
    

    // Java 17 is the current Flutter/AGP default; if your JDK is 11 only, set both to 11
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    kotlin {
        jvmToolchain(17)                                   // <- enforce 17 toolchain
    }


    defaultConfig {
        // ⚠️ Also keep applicationId lowercase
        applicationId = "com.example.afyabomba"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // --- Signing config (Kotlin DSL) ---
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Use the signing config defined above
            signingConfig = signingConfigs.getByName("release")

            // Start with shrinking disabled; we can enable later with proper keep rules
            isMinifyEnabled = false
            isShrinkResources = false
            // If you enable shrinking later:
            // proguardFiles(
            //     getDefaultProguardFile("proguard-android-optimize.txt"),
            //     "proguard-rules.pro"
            // )
        }
        // debug { }  // default debug is fine
    }

    // (Any other android { } sections you had can remain here)
}

// Flutter config
flutter {
    source = "../.."
}

dependencies {
    // Other dependencies you already have
    add("coreLibraryDesugaring", "com.android.tools:desugar_jdk_libs:2.1.4")
}
