plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.iec_app"
    compileSdk = 34 // Mantemos 34 (Android 14)
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
            // Desativa a minificação para evitar erros de recursos sumindo
            isMinifyEnabled = false 
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// --- SOLUÇÃO DEFINITIVA (VACINA DE VERSÕES) ---
configurations.all {
    resolutionStrategy {
        eachDependency {
            // 1. Corrige o erro "requires Android SDK 36"
            if (requested.group == "androidx.activity") {
                useVersion("1.9.3") // Versão estável
            }
            // 2. Corrige o erro "lStar not found"
            if (requested.group == "androidx.core") {
                useVersion("1.13.1") // Versão que tem o lStar corrigido
            }
            // 3. Garante compatibilidade do Lifecycle
            if (requested.group == "androidx.lifecycle") {
                useVersion("2.8.6")
            }
        }
    }
}