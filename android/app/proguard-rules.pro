# ==============================================================================
# 🔐 CONFIGURACIÓN DE PROGUARD / R8 — AUDITORÍA DOCTORADO EN INGENIERÍA INFORMÁTICA
# ==============================================================================
# Proyecto: Videitos App (cl.videitos.app)
# Versión: 2.0 (Optimizado, Blindado y con Trazabilidad de Diagnóstico)
# Objetivo: Prevención absoluta de fallos en runtime, protección de modelos de red,
#           aseguramiento de anuncios y renderizado íntegro de textos y políticas.
# ==============================================================================

# ─── 1. ATRIBUTOS ESENCIALES, REFLEXIÓN Y MODELOS DE DATOS (POLÍTICAS Y JSON) ──
# Conservar anotaciones, firmas y metadatos estructurales para Gson, PocketBase y Modelos Propios
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod,SourceFile,LineNumberTable

# BLINDAJE CRÍTICO: Proteger todos los modelos y controladores del paquete principal de la app
# Esto evita que Gson falle al mapear las condiciones, términos y políticas de privacidad en release.
-keep class cl.videitos.** { *; }
-keepclassmembers class cl.videitos.** { *; }

# Mantener nombres de campos serializados con Gson en cualquier modelo genérico
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
    @com.google.gson.annotations.Expose <fields>;
}

# ─── 2. GOOGLE MOBILE ADS & UMP (MONETIZACIÓN Y CONSENTIMIENTO) ──────────────
-keep public class com.google.android.gms.ads.** { *; }
-keep public class com.google.ads.** { *; }
-dontwarn com.google.android.gms.ads.**
-dontwarn com.google.ads.**

# ─── 3. GOOGLE PLAY CORE & DEFERRED COMPONENTS (BLINDAJE CONTRA ERRORES R8) ───
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ─── 4. REPRODUCTOR DE VIDEO Y EXOPLAYER (FLUTTER VIDEO_PLAYER) ─────────────
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**
-dontwarn android.media.MediaCodec*

# ─── 5. POCKETBASE, GSON Y OKHTTP (CAPA DE RED Y PERSISTENCIA) ──────────────
# Cliente PocketBase
-keep class pocketbase.** { *; }
-dontwarn pocketbase.**

# Gson (Serialización de JSON para políticas y contenidos)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# OkHttp3 y Okio (Pila de red de alta eficiencia)
-keep class com.squareup.okhttp3.** { *; }
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
-dontwarn okhttp3.**
-dontwarn okio.**

# Apache HTTP Legacy
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**

# ─── 6. PLUGINS NATIVOS Y EXTENSIONES DE FLUTTER ────────────────────────────
# Motor principal de Flutter
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugins.** { *; }

# Image Picker & File Picker
-keep class io.flutter.plugins.imagepicker.** { *; }
-dontwarn io.flutter.plugins.imagepicker.**
-keep class io.flutter.plugins.filepicker.** { *; }
-dontwarn io.flutter.plugins.filepicker.**

# Permission Handler
-keep class com.baseflow.permissionhandler.** { *; }
-dontwarn com.baseflow.permissionhandler.**

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }
-dontwarn dev.fluttercommunity.plus.share.**

# URL Launcher
-keep class io.flutter.plugins.urllauncher.** { *; }
-dontwarn io.flutter.plugins.urllauncher.**

# Cached Network Image & Flutter Cache Manager
-keep class com.cachednetworkimage.** { *; }
-dontwarn com.cachednetworkimage.**
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

# Package Info Plus
-keep class dev.fluttercommunity.plus.packageinfo.** { *; }
-dontwarn dev.fluttercommunity.plus.packageinfo.**

# Visibility Detector
-keep class com.visibledetector.** { *; }
-dontwarn com.visibledetector.**

# ─── 7. OPTIMIZACIONES DE INTERFAZ Y VISTAS NATIVAS (XML) ───────────────────
-keep public class * extends android.view.View
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

-keepclassmembers class * extends android.view.View {
    public <init>(android.content.Context);
    public <init>(android.content.Context, android.util.AttributeSet);
    public <init>(android.content.Context, android.util.AttributeSet, int);
    public void set*(...);
}

# ─── 8. TRAZABILIDAD DE DEPURACIÓN Y LOGS CONTROLADOS ──────────────────────
# Mantiene los logs activos en puntos críticos de diagnóstico de red y UI
-keepclassmembers class cl.videitos.** {
    void *Log*(...);
    void *print*(...);
}