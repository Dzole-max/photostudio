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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Some plugins (e.g. stripe_android) compile Java for 17 but leave Kotlin on the
// JDK default (25), which Gradle rejects. Force every Kotlin compile task to JVM 17.
// Reflection keeps this independent of the Kotlin Gradle plugin's classpath.
subprojects {
    tasks.configureEach {
        if (name.startsWith("compile") && name.endsWith("Kotlin")) {
            try {
                val options = javaClass.getMethod("getCompilerOptions").invoke(this)
                @Suppress("UNCHECKED_CAST")
                val jvmTarget = options.javaClass.getMethod("getJvmTarget").invoke(options)
                    as org.gradle.api.provider.Property<Any>
                val enumClass = Class.forName(
                    "org.jetbrains.kotlin.gradle.dsl.JvmTarget", true, javaClass.classLoader,
                )
                val jvm17 = enumClass.enumConstants.first { (it as Enum<*>).name == "JVM_17" }
                jvmTarget.set(jvm17)
            } catch (e: Exception) {
                logger.warn("Could not set Kotlin jvmTarget for $path: ${e.message}")
            }
        }
    }
}
