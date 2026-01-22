allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Configuração correta para o novo Gradle
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    // CORREÇÃO AQUI: Usamos a nova API 'layout.buildDirectory' para evitar o erro de Tipo
    val subprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}