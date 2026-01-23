plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.iec_app"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.iec_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Em Kotlin, usamos isMinifyEnabled em vez de minifyEnabled
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// --- SOLUÇÃO DEFINITIVA (VACINA TRADUZIDA PARA KOTLIN) ---
configurations.all {
    resolutionStrategy {
        eachDependency {
            // 1. Corrige o erro "requires Android SDK 36" (Browser)
            if (requested.group == "androidx.browser") {
                useVersion("1.8.0")
            }

            // 2. Corrige incompatibilidades de Activity
            if (requested.group == "androidx.activity") {
                useVersion("1.9.3")
            }

            // 3. Corrige o erro "lStar not found" e Core
            if (requested.group == "androidx.core") {
                useVersion("1.13.1")
            }

            // 4. Garante compatibilidade do Lifecycle
            if (requested.group == "androidx.lifecycle") {
                useVersion("2.8.6")
            }
        }
    }
}