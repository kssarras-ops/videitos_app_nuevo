// lib/services/ads_service.dart
// ═══════════════════════════════════════════════════════════════════════════
// ADS SERVICE — Videitos App (VERSIÓN DE PRODUCCIÓN)
// ═══════════════════════════════════════════════════════════════════════════
// Servicio centralizado de AdMob optimizado para Android (Google Play Console).
// - Frecuencia de intersticiales configurada estrictamente a cada 8 videos.
// - Integración con IDs reales de producción proporcionados.
// - Observabilidad avanzada y manejo de errores tolerante a fallos.
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  // ─────────────────────────────────────────────────────────────────────────
  // SINGLETON PATTERN
  // ─────────────────────────────────────────────────────────────────────────

  static final AdsService _instance = AdsService._internal();
  factory AdsService() => _instance;
  AdsService._internal();

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURACIÓN DE PRODUCCIÓN Y ENTORNO
  // ─────────────────────────────────────────────────────────────────────────

  /// 🚀 MODO PRODUCCIÓN ACTIVO (`false` deshabilita los anuncios de prueba de Google).
  static const bool testMode = false;

  /// IDs de dispositivos de prueba (Vacío en producción para evitar interferencias).
  static const List<String> testDeviceIds = [];

  // ─── IDS DE PRUEBA OFICIALES (Google - Fallback técnico para iOS/Seguridad) ──
  static const String _testBannerAndroid       = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS           = 'ca-app-pub-3940256099942544/2934735716';
  static const String _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS     = 'ca-app-pub-3940256099942544/4411468910';
  static const String _testRewardedAndroid     = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIOS         = 'ca-app-pub-3940256099942544/1712485313';

  // ─── IDS REALES DE PRODUCCIÓN (Android - Asignados a Videitos App) ──────
  static const String _prodBannerAndroid       = 'ca-app-pub-9211240922699669/1117526493';
  static const String _prodInterstitialAndroid = 'ca-app-pub-9211240922699669/4261641148';
  static const String _prodRewardedAndroid     = 'ca-app-pub-9211240922699669/7817742770';

  // ─── IDS DE PRODUCCIÓN (Apple App Store / iOS - Espacios reservados) ───
  static const String _prodBannerIOS           = 'ca-app-pub-9211240922699669/TU_BANNER_IOS_ID';
  static const String _prodInterstitialIOS     = 'ca-app-pub-9211240922699669/TU_INTERSTITIAL_IOS_ID';
  static const String _prodRewardedIOS         = 'ca-app-pub-9211240922699669/TU_REWARDED_IOS_ID';

  // ─── RESOLUCIÓN DINÁMICA DE GETTERS DE IDs ──────────────────────────────

  String get bannerAdUnitId {
    if (testMode) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIOS;
    }
    return Platform.isAndroid ? _prodBannerAndroid : _prodBannerIOS;
  }

  String get interstitialAdUnitId {
    if (testMode) {
      return Platform.isAndroid ? _testInterstitialAndroid : _testInterstitialIOS;
    }
    return Platform.isAndroid ? _prodInterstitialAndroid : _prodInterstitialIOS;
  }

  String get rewardedAdUnitId {
    if (testMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIOS;
    }
    return Platform.isAndroid ? _prodRewardedAndroid : _prodRewardedIOS;
  }

  // ─── ESTADO INTERNO Y CONTROL DE FRECUENCIA ────────────────────────────

  bool _isInitialized = false;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _isInterstitialLoading = false;
  bool _isRewardedLoading = false;

  int _videosViewedSinceLastAd = 0;

  /// 🎯 FRECUENCIA ESTRICTA: El anuncio intersticial se desplegará cada 8 videos exactos.
  static const int _interstitialFrequency = 8;

  // ─── SISTEMA DE LOGS Y TELEMETRÍA ─────────────────────────────────────

  void _log(String tag, String message) {
    debugPrint('💰 [AdsService][$tag]$message');
  }

  void _logSuccess(String tag, String message) {
    debugPrint('✅ [AdsService][$tag]$message');
  }

  void _logWarning(String tag, String message) {
    debugPrint('⚠️ [AdsService][$tag]$message');
  }

  void _logError(String tag, String message, [Object? error]) {
    debugPrint('❌ [AdsService][$tag]$message');
    if (error != null) debugPrint('    → error: $error');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INICIALIZACIÓN DEL SDK
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isInitialized) {
      _logWarning('initialize', 'El SDK de AdMob ya se encontraba inicializado.');
      return;
    }

    _log('initialize', 'Iniciando secuencia de arranque del SDK AdMob...');
    _log('initialize', 'Modo Producción Activo (testMode: $testMode)');
    _log('initialize', 'Banner Unit ID en uso: $bannerAdUnitId');
    _log('initialize', 'Interstitial Unit ID en uso: $interstitialAdUnitId');

    try {
      await MobileAds.instance.initialize();
      _logSuccess('initialize', 'SDK de Google Mobile Ads inicializado con éxito.');

      if (testDeviceIds.isNotEmpty) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(testDeviceIds: testDeviceIds),
        );
        _logSuccess('initialize', 'Configuración de dispositivos de prueba aplicada.');
      } else {
        _log('initialize', 'Entorno operando bajo tráfico real de producción.');
      }

      _isInitialized = true;
      
      // Disparamos la precarga del primer intersticial en segundo plano
      _loadInterstitialAd();
      loadRewardedAd();
    } catch (e, st) {
      _logError('initialize', 'Fallo crítico al inicializar el SDK de AdMob.', e);
      debugPrint('    stack trace: $st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GESTIÓN DE BANNER ANCLADO (FEED)
  // ─────────────────────────────────────────────────────────────────────────

  BannerAd createBannerAd({
    required VoidCallback onLoaded,
    required void Function(LoadAdError) onFailed,
  }) {
    _log('createBannerAd', 'Instanciando Banner Ad para el Feed inferior...');

    final banner = BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          _logSuccess('createBannerAd', 'Banner de producción cargado y renderizado correctamente.');
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          _logError('createBannerAd', 'Error al cargar el banner de producción.', error);
          ad.dispose();
          onFailed(error);
        },
        onAdOpened: (ad) => _log('createBannerAd', 'Interacción del usuario con el Banner.'),
        onAdClosed: (ad) => _log('createBannerAd', 'Banner cerrado por el usuario.'),
      ),
    );

    banner.load();
    return banner;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GESTIÓN DE ANUNCIOS INTERSTICIALES (CADA 8 VIDEOS)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadInterstitialAd() async {
    if (_isInterstitialLoading || _interstitialAd != null) {
      return;
    }

    _isInterstitialLoading = true;
    _log('_loadInterstitialAd', 'Solicitando nuevo anuncio intersticial a los servidores de Google...');

    await InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _logSuccess('_loadInterstitialAd', 'Intersticial almacenado en memoria listo para mostrar.');
          _interstitialAd = ad;
          _isInterstitialLoading = false;
        },
        onAdFailedToLoad: (error) {
          _logError('_loadInterstitialAd', 'Fallo en la descarga del intersticial.', error);
          _interstitialAd = null;
          _isInterstitialLoading = false;
        },
      ),
    );
  }

  bool showInterstitialIfReady() {
    if (_interstitialAd == null) {
      _log('showInterstitialIfReady', 'Aviso: El intersticial no estaba listo en memoria. Iniciando recarga de emergencia...');
      _loadInterstitialAd();
      return false;
    }

    _log('showInterstitialIfReady', 'Desplegando anuncio intersticial en pantalla completa...');
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log('showInterstitialIfReady', 'Intersticial descartado por el usuario. Liberando y precargando siguiente...');
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logError('showInterstitialIfReady', 'Error al intentar proyectar el intersticial.', error);
        ad.dispose();
        _interstitialAd = null;
        _loadInterstitialAd();
      },
    );

    _interstitialAd!.show();
    _interstitialAd = null;
    return true;
  }

  /// Método llamado cada vez que el usuario consume un video en el feed.
  void onVideoViewed() {
    _videosViewedSinceLastAd++;
    _log('onVideoViewed', 'Progreso de visualización: Video N° $_videosViewedSinceLastAd / Umbral objetivo:$_interstitialFrequency');

    if (_videosViewedSinceLastAd >= _interstitialFrequency) {
      _log('onVideoViewed', '🎯 ¡Umbral de 8 videos alcanzado! Ejecutando despliegue de intersticial.');
      _videosViewedSinceLastAd = 0; // Reinicio estricto del contador
      showInterstitialIfReady();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GESTIÓN DE ANUNCIOS REWARDED (RECOMPENSADOS)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> loadRewardedAd() async {
    if (_isRewardedLoading || _rewardedAd != null) return;

    _isRewardedLoading = true;
    _log('loadRewardedAd', 'Solicitando anuncio recompensado...');

    await RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _logSuccess('loadRewardedAd', 'Anuncio recompensado cargado exitosamente.');
          _rewardedAd = ad;
          _isRewardedLoading = false;
        },
        onAdFailedToLoad: (error) {
          _logError('loadRewardedAd', 'Fallo al cargar el anuncio recompensado.', error);
          _rewardedAd = null;
          _isRewardedLoading = false;
        },
      ),
    );
  }

  bool showRewardedIfReady({
    required void Function(int amount, String type) onRewarded,
  }) {
    if (_rewardedAd == null) {
      _log('showRewardedIfReady', 'No hay anuncios recompensados listos. Solicitando carga...');
      loadRewardedAd();
      return false;
    }

    _log('showRewardedIfReady', 'Mostrando anuncio recompensado...');
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        _log('showRewardedIfReady', 'Anuncio recompensado cerrado. Recargando...');
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _logError('showRewardedIfReady', 'Fallo al mostrar anuncio recompensado.', error);
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        _logSuccess('showRewardedIfReady', '🏆 Recompensa otorgada con éxito: ${reward.amount}${reward.type}');
        onRewarded(reward.amount.toInt(), reward.type);
      },
    );
    _rewardedAd = null;
    return true;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIBERACIÓN DE RECURSOS (DISPOSE)
  // ─────────────────────────────────────────────────────────────────────────

  void dispose() {
    _log('dispose', 'Iniciando liberación de recursos del servicio publicitario...');
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isInitialized = false;
    _logSuccess('dispose', 'AdsService finalizado y recursos liberados correctamente.');
  }
}