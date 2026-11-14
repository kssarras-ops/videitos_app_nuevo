// ═══════════════════════════════════════════════════════════════════════════
// ANDROID SETTINGS (Kotlin DSL) - VideitosApp
// ═══════════════════════════════════════════════════════════════════════════

pluginManagement {
    System.setProperty("flutter.buildToolsVersion", "35.0.0")
    System.setProperty("flutter.compileSdkVersion", "36")

    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        } else {
            throw org.gradle.api.GradleException("❌ [FATAL] No se encontró 'local.properties'. Ejecuta 'flutter pub get'.")
        }
        
        properties.getProperty("flutter.sdk") 
            ?: throw org.gradle.api.GradleException("❌ [FATAL] 'flutter.sdk' no definido en local.properties")
    }

    println("✅ [SETTINGS] Flutter SDK Path detectado: $flutterSdkPath")

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("com.google.gms.google-services") version("4.4.4") apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
}

include(":app")