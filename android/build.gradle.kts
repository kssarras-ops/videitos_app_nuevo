// =============================================================================
// 📦 GRADLE BUILD SCRIPT - VIDEITOS APP (NIVEL SUPERIOR / KOTLIN DSL)
// =============================================================================
// Configuración global de repositorios, dependencias de construcción y
// POLÍTICA DE COMPILACIÓN UNIFICADA (Java 17 + Kotlin 17) para todos los módulos.

import org.gradle.api.tasks.Delete
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

// ─── LOGS DE INICIO DE EVALUACIÓN ──────────────────────────────────────────
logger.lifecycle("================================================================")
logger.lifecycle("🔧 [Gradle Root] Iniciando evaluación del build.gradle.kts raíz")
logger.lifecycle("================================================================")

// ─── 1. DEPENDENCIAS DE CONSTRUCCIÓN (BUILDSCRIPT) ────────────────────────
buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        // Android Gradle Plugin (AGP) - Estable y moderno
        classpath("com.android.tools.build:gradle:8.11.1")
        
        // Kotlin Gradle Plugin - Debe coincidir con settings.gradle.kts (2.4.0)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.0")
        
        logger.lifecycle("🚀 [Buildscript] Classpath cargado: AGP 8.11.1 + Kotlin 2.4.0.")
    }
}

// ─── 2. REPOSITORIOS Y CONFIGURACIÓN GLOBAL PARA SUBPROYECTOS ──────────────
allprojects {
    repositories {
        google()
        mavenCentral()
        maven("https://storage.googleapis.com/download.flutter.io")
    }

    // Codificación UTF-8 universal para evitar errores de compilación Java
    tasks.withType<JavaCompile>().configureEach {
        options.encoding = "UTF-8"
    }
}

// ─── 3. POLÍTICA DE COMPILACIÓN UNIFICADA (CRÍTICO) ────────────────────────
// Forzamos a TODOS los subproyectos Android (incluyendo plugins de terceros
// como 'video_compress') a usar Java 17 y Kotlin JVM 17.
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // afterEvaluate se ejecuta después de que el plugin de Android haya sido
    // aplicado al subproyecto, permitiéndonos sobrescribir sus valores por defecto.
    afterEvaluate {
        // Verificamos si el subproyecto es una aplicación o librería Android.
        if (plugins.hasPlugin("com.android.application") || plugins.hasPlugin("com.android.library")) {
            
            // 3.1. Forzar Java 17 en las tareas de compilación de Java (javac)
            extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
                
                // Parche de compatibilidad para librerías antiguas (se mantiene)
                if (buildToolsVersion == "25.0.2") {
                    buildToolsVersion = "35.0.0"
                    logger.lifecycle("✅ [PARCHE] buildToolsVersion actualizado en ${project.name} a 35.0.0")
                }
            }

            // 3.2. Forzar Kotlin JVM 17 en las tareas de compilación de Kotlin (kotlinc)
            // Usamos la sintaxis moderna 'compilerOptions' para evitar la deprecación.
            tasks.withType<KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(JvmTarget.JVM_17)
                }
            }
            
            logger.lifecycle("✅ [JVM] ${project.name} configurado a Java 17 / Kotlin 17.")
        }

        // Desactivación segura de validación estricta de AAR Metadata (se mantiene)
        tasks.findByName("checkReleaseAarMetadata")?.let {
            (it as? com.android.build.gradle.internal.tasks.CheckAarMetadataTask)?.enabled = false
        }
    }
}

// ─── 4. DEPENDENCIA DE EVALUACIÓN Y LIMPIEZA ──────────────────────────────
// Asegura que el módulo ':app' se evalúe antes que el resto (orden de compilación)
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
    logger.lifecycle("🧹 [Clean] Directorio de compilación raíz limpiado exitosamente.")
}

logger.lifecycle("================================================================")
logger.lifecycle("✅ [Gradle Root] build.gradle.kts raíz evaluado sin errores.")
logger.lifecycle("================================================================")