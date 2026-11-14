import org.gradle.api.JavaVersion
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ─── LOGS DE DIAGNÓSTICO DEL GRADLE ────────────────────────────────────────
logger.lifecycle("================================================================")
logger.lifecycle("🔧 [Gradle] Iniciando evaluación de build.gradle.kts para cl.videitos.app")
logger.lifecycle("================================================================")

// ─── CONFIGURACIÓN DE ANDROID ────────────────────────────────────────────────
android {
    namespace = "cl.videitos.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        jvmToolchain(17)
    }

    // ─── FIRMAS PARA RELEASE Y CI/CD ──────────────────────────────────────────
    signingConfigs {
        create("release") {
            val keyPropsFile = rootProject.file("key.properties")
            if (keyPropsFile.exists()) {
                logger.lifecycle("🔐 [Signing] key.properties detectado. Cargando credenciales...")
                val keyProps = Properties()
                keyPropsFile.inputStream().use { keyProps.load(it) }
                storeFile = rootProject.file(keyProps["storeFile"] as String)
                storePassword = keyProps["storePassword"] as String?
                keyAlias = keyProps["keyAlias"] as String?
                keyPassword = keyProps["keyPassword"] as String?
            } else {
                logger.lifecycle("⚠️ [Signing] key.properties no encontrado. Usando variables de entorno CI/CD...")
                storeFile = System.getenv("CM_KEYSTORE_PATH")?.let { file(it) }
                storePassword = System.getenv("CM_KEY_PASSWORD")
                keyAlias = System.getenv("CM_KEY_ALIAS")
                keyPassword = System.getenv("CM_KEY_PASSWORD")
            }
        }
    }

    // ─── CONFIGURACIÓN POR DEFECTO ─────────────────────────────────────────────
    defaultConfig {
        applicationId = "cl.videitos.app"
        minSdk = 24
        targetSdk = 36

        // ⚠️ Sincronizado con pubspec.yaml (Versión 4.0.1+5)
        versionCode = 999999
        versionName = "6.0.1"

        logger.lifecycle("📦 [defaultConfig] versionCode: $versionCode | versionName: $versionName")
    }

    // ─── TIPOS DE COMPILACIÓN ──────────────────────────────────────────────────
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("profile") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // ─── NOMBRE DE LOS APKS DE SALIDA ─────────────────────────────────────────
    applicationVariants.all {
        val variant = this
        variant.outputs.all {
            val output = this as com.android.build.gradle.internal.api.ApkVariantOutputImpl
            output.outputFileName = "app-${variant.name}.apk"
        }
    }
}

// ─── DEPENDENCIAS NATIVAS ──────────────────────────────────────────────────────
dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.9.0")
}

// ─── CONFIGURACIÓN DE FLUTTER ─────────────────────────────────────────────────
flutter {
    source = "../.."
}

// ─── PARCHES DE COMPATIBILIDAD ──────────────────────────────────────────────
tasks.withType<com.android.build.gradle.internal.tasks.CheckAarMetadataTask>().configureEach {
    enabled = false
}

subprojects {
    afterEvaluate {
        extensions.findByType<com.android.build.gradle.BaseExtension>()?.apply {
            if (buildToolsVersion == "25.0.2") {
                buildToolsVersion = "35.0.0"
            }
        }
    }
}

logger.lifecycle("================================================================")
logger.lifecycle("✅ [Gradle] build.gradle.kts evaluado correctamente.")
logger.lifecycle("================================================================")