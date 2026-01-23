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
}

// REMOVIDO: O force para androidx.core 1.6.0 que estava causando conflito
// Agora vamos deixar as versões serem gerenciadas normalmente

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}