// android/build.gradle.kts

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configuração dos diretórios de build
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val subprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
    
    // Força versões compatíveis em TODOS os submódulos (incluindo printing)
    configurations.all {
        resolutionStrategy {
            // Core AndroidX
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
            
            // Activity
            force("androidx.activity:activity:1.9.3")
            force("androidx.activity:activity-ktx:1.9.3")
            
            // Browser
            force("androidx.browser:browser:1.8.0")
            
            // Navigation
            force("androidx.navigation:navigation-common:2.7.7")
            
            // AppCompat - CRÍTICO para resolver lStar
            force("androidx.appcompat:appcompat:1.6.1")
            force("androidx.appcompat:appcompat-resources:1.6.1")
            
            // Material
            force("com.google.android.material:material:1.9.0")
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}