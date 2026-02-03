plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    // Namespace deve coincidir com o seu applicationId
    namespace = "com.example.iec_app"
    compileSdk = 36 // Recomendado 35 para estabilidade atual, ou 36 se já tiver o SDK instalado
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Atualizado para Java 17 para compatibilidade com AGP 8.6.1 e Kotlin 2.0
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.iec_app"
        minSdk = flutter.minSdkVersion // Definido explicitamente ou via flutter.minSdkVersion
        targetSdk = 35 
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Em produção, use uma chave real. Aqui mantive sua config de debug.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
    
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Essencial para suportar multidex em aparelhos antigos
    implementation("androidx.multidex:multidex:2.0.1")
    
    // Importa o BoM do Firebase para alinhar versões automaticamente
    implementation(platform("com.google.firebase:firebase-bom:33.1.2"))
    implementation("com.google.firebase:firebase-analytics")
}

// BLOCO CRÍTICO: Resolve conflitos de classes duplicadas (lStar, etc)
configurations.all {
    resolutionStrategy {
        // Força versões estáveis que não possuem conflitos entre si
        force("androidx.core:core:1.13.1")
        force("androidx.core:core-ktx:1.13.1")
        force("androidx.activity:activity:1.9.3")
        force("androidx.activity:activity-ktx:1.9.3")
        force("androidx.browser:browser:1.8.0")
        force("androidx.navigation:navigation-common:2.7.7")
        force("androidx.appcompat:appcompat:1.6.1")
        force("androidx.appcompat:appcompat-resources:1.6.1")
        force("com.google.android.material:material:1.9.0")

        // Garante que nenhuma dependência transitiva puxe versões problemáticas
        eachDependency {
            if (requested.group == "androidx.core" && requested.name == "core") {
                useVersion("1.13.1")
            }
        }
    }
}
