// lib/services/ad_consent_service.dart
// Versión Definitiva — Auditoría Doctorado en Ingeniería Informática
// Arquitectura resiliente de consentimiento UMP, AdMob y Firebase Analytics.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AdConsentService {
  static const String _logPrefix = '🛡️ [AdConsentService]';

  // Estado interno para saber si el SDK de Ads está listo
  static bool _isMobileAdsInitialized = false;

  /// Solicita el consentimiento de UMP, sincroniza con Firebase Analytics
  /// e inicializa AdMob si corresponde.
  static Future<void> requestConsentAndInitialize({
    required VoidCallback onInitializationComplete,
    bool enableDebugInEea = false,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint(
        '$_logPrefix -----------------------------------------------------------------');
    debugPrint('$_logPrefix Iniciando verificación de consentimiento UMP...');

    ConsentDebugSettings? debugSettings;
    if (enableDebugInEea) {
      debugSettings = ConsentDebugSettings(
        debugGeography: DebugGeography.debugGeographyEea,
        testIdentifiers: [
          'TEST-DEVICE-HASH-ID'
        ], // Reemplazar con tu ID real si haces pruebas
      );
      debugPrint('$_logPrefix ⚙️ Modo Debug UMP activado para EEA.');
    }

    final ConsentRequestParameters params = ConsentRequestParameters(
      consentDebugSettings: debugSettings,
    );

    // Usamos un Completer para convertir los callbacks de UMP en un Future (async/await)
    final completer = Completer<void>();

    ConsentInformation.instance.requestConsentInfoUpdate(
      params,
      () async {
        debugPrint(
            '$_logPrefix ✅ Información de consentimiento actualizada. (${stopwatch.elapsedMilliseconds}ms)');
        await _handleConsentForm(completer, onInitializationComplete);
      },
      (FormError error) {
        debugPrint(
            '$_logPrefix ❌ Error al actualizar info de consentimiento: ${error.message}');
        // Si falla UMP, no bloqueamos la app. Continuamos con el flujo seguro.
        if (!completer.isCompleted) completer.complete();
        _syncAnalyticsConsent(ConsentStatus.unknown);
        _initializeAdMob(onInitializationComplete);
      },
    );

    return completer.future;
  }

  /// Maneja la visualización del formulario si es requerido.
  static Future<void> _handleConsentForm(
    Completer<void> completer,
    VoidCallback onInitializationComplete,
  ) async {
    try {
      bool isConsentAvailable =
          await ConsentInformation.instance.isConsentFormAvailable();
      ConsentStatus status =
          await ConsentInformation.instance.getConsentStatus();

      debugPrint(
          '$_logPrefix Estado actual: $status | Formulario disponible: $isConsentAvailable');

      if (status == ConsentStatus.required) {
        debugPrint(
            '$_logPrefix 📝 Mostrando formulario de consentimiento al usuario...');

        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint(
                '$_logPrefix ❌ Error al mostrar el formulario: ${formError.message}');
          } else {
            debugPrint('$_logPrefix ✅ Formulario respondido por el usuario.');
            // Re-evaluamos el estado tras la respuesta del usuario
            status = await ConsentInformation.instance.getConsentStatus();
          }

          // 1. Sincronizar con Firebase Analytics
          await _syncAnalyticsConsent(status);

          // 2. Inicializar AdMob
          if (!completer.isCompleted) completer.complete();
          _initializeAdMob(onInitializationComplete);
        });
      } else {
        debugPrint(
            '$_logPrefix El consentimiento ya fue obtenido previamente o no es requerido.');

        // 1. Sincronizar con Firebase Analytics
        await _syncAnalyticsConsent(status);

        // 2. Inicializar AdMob
        if (!completer.isCompleted) completer.complete();
        _initializeAdMob(onInitializationComplete);
      }
    } catch (e) {
      debugPrint('$_logPrefix ❌ Excepción manejando formulario UMP: $e');
      if (!completer.isCompleted) completer.complete();
      _initializeAdMob(onInitializationComplete);
    }
  }

  /// Sincroniza el estado de UMP con el Consent Mode de Firebase Analytics.
  static Future<void> _syncAnalyticsConsent(ConsentStatus status) async {
    // Si el usuario otorgó consentimiento, o si UMP dice que no se requiere (ej. fuera de EEA)
    bool hasConsent =
        status == ConsentStatus.obtained || status == ConsentStatus.notRequired;

    debugPrint(
        '$_logPrefix 🔄 Sincronizando Consent Mode con Firebase Analytics...');
    debugPrint(
        '$_logPrefix Estado Analytics: ${hasConsent ? "CONCEDIDO ✅" : "DENEGADO ❌"}');

    try {
      await FirebaseAnalytics.instance.setConsent(
        analyticsStorageConsentGranted: hasConsent,
        adStorageConsentGranted: hasConsent,
        adUserDataConsentGranted: hasConsent,
        adPersonalizationSignalsConsentGranted: hasConsent,
      );
      // Nota: Si deseas que la analítica básica funcione incluso sin consentimiento,
      // debes cambiar 'analyticsStorageConsentGranted' a true, dejando los demás en 'hasConsent'.
      debugPrint('$_logPrefix ✅ Firebase Analytics Consent actualizado.');
    } catch (e) {
      debugPrint('$_logPrefix ⚠️ Error al actualizar Analytics Consent: $e');
    }
  }

  /// Inicializa el SDK de Google Mobile Ads si el usuario permite anuncios.
  static Future<void> _initializeAdMob(
      VoidCallback onInitializationComplete) async {
    if (_isMobileAdsInitialized) {
      debugPrint('$_logPrefix ⏭️ AdMob ya estaba inicializado. Omitiendo.');
      onInitializationComplete();
      return;
    }

    final stopwatch = Stopwatch()..start();

    try {
      // Verificar si UMP permite solicitar anuncios (requisito de Google)
      bool canRequestAds = await ConsentInformation.instance.canRequestAds();

      if (!canRequestAds) {
        debugPrint(
            '$_logPrefix 🚫 UMP indica que NO se pueden solicitar anuncios en este contexto.');
        onInitializationComplete();
        return;
      }

      debugPrint('$_logPrefix 💰 Inicializando SDK de Google Mobile Ads...');
      await MobileAds.instance.initialize();

      _isMobileAdsInitialized = true;
      debugPrint(
          '$_logPrefix ✅ AdMob inicializado exitosamente. (${stopwatch.elapsedMilliseconds}ms)');

      onInitializationComplete();
    } catch (e) {
      debugPrint('$_logPrefix ❌ Error crítico inicializando AdMob: $e');
      onInitializationComplete(); // Liberamos el hilo para no bloquear la app
    }
  }

  /// Permite al usuario reabrir las opciones de privacidad (desde un botón en Ajustes).
  static Future<void> showPrivacyOptionsForm(BuildContext context) async {
    debugPrint(
        '$_logPrefix 🔐 Solicitando reapertura del formulario de privacidad...');
    try {
      bool isAvailable =
          await ConsentInformation.instance.isConsentFormAvailable();

      if (isAvailable) {
        ConsentForm.loadAndShowConsentFormIfRequired((formError) async {
          if (formError != null) {
            debugPrint(
                '$_logPrefix ❌ Error al cargar formulario de privacidad: ${formError.message}');
          } else {
            debugPrint(
                '$_logPrefix ✅ Opciones de privacidad actualizadas por el usuario.');
            // Re-sincronizar Analytics por si el usuario cambió de opinión
            final newStatus =
                await ConsentInformation.instance.getConsentStatus();
            await _syncAnalyticsConsent(newStatus);
          }
        });
      } else {
        debugPrint(
            '$_logPrefix ⚠️ El formulario de privacidad no está disponible actualmente.');
      }
    } catch (e) {
      debugPrint(
          '$_logPrefix ❌ Excepción al reabrir opciones de privacidad: $e');
    }
  }
}
