buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Necesario para poder configurar KotlinAndroidProjectExtension más abajo.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.20")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround: algunos plugins (p.ej. file_picker 11.x) asumen que AGP 9+
// aplica Kotlin automáticamente y omiten `org.jetbrains.kotlin.android`,
// pero AGP 9.0.1 todavía no lo hace, dejando sus fuentes .kt sin compilar
// ("cannot find symbol"). Lo aplicamos manualmente si hace falta.
subprojects {
    val hasKotlinSrc = project.projectDir.resolve("src/main/kotlin").exists()
    if (hasKotlinSrc &&
        !project.plugins.hasPlugin("org.jetbrains.kotlin.android") &&
        !project.plugins.hasPlugin("org.jetbrains.kotlin.jvm")
    ) {
        project.pluginManager.apply("org.jetbrains.kotlin.android")
        project.extensions.configure(
            org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension::class.java
        ) {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
