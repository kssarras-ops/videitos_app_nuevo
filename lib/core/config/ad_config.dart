// lib/core/config/ad_config.dart
// Configuración centralizada de IDs de AdMob.
// El Consejo advierte: NUNCA hardcodear IDs en los widgets.

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;

class AdConfig {
  // ═══════════════════════════════════════════════════════════════════════════
  // IDs DE PRUEBA OFICIALES DE GOOGLE (Siempre devuelven anuncios de prueba)
  // ═══════════════════════════════════════════════════════════════════════════
  static const String _testBannerAndroid =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';

  static const String _testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testInterstitialIOS =
      'ca-app-pub-3940256099942544/4411468910';

  static const String _testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedIOS =
      'ca-app-pub-3940256099942544/1712485313';

  // ═══════════════════════════════════════════════════════════════════════════
  // TUS IDs REALES DE PRODUCCIÓN (Debes extraerlos de tu consola de AdMob)
  // ═══════════════════════════════════════════════════════════════════════════
  // ⚠️ REEMPLAZA LOS 'XXXXXXXX' CON TUS IDs REALES ANTES DE COMPILAR PARA PRODUCCIÓN
  static const String _realBannerAndroid =
      'ca-app-pub-9211240922699669/1117526493';
  static const String _realBannerIOS = 'ca-app-pub-XXXXXXXX/ZZZZZZZZZZ';

  static const String _realInterstitialAndroid =
      'ca-app-pub-9211240922699669/4261641148';
  static const String _realInterstitialIOS = 'ca-app-pub-XXXXXXXX/ZZZZZZZZZZ';

  static const String _realRewardedAndroid =
      'ca-app-pub-9211240922699669/7817742770';
  static const String _realRewardedIOS = 'ca-app-pub-XXXXXXXX/ZZZZZZZZZZ';

  // ═══════════════════════════════════════════════════════════════════════════
  // GETTERS INTELIGENTES
  // Cambian automáticamente según el entorno (Debug vs Release) y la plataforma
  // ═══════════════════════════════════════════════════════════════════════════

  static String get bannerAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testBannerAndroid : _testBannerIOS;
    }
    return Platform.isAndroid ? _realBannerAndroid : _realBannerIOS;
  }

  static String get interstitialAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid
          ? _testInterstitialAndroid
          : _testInterstitialIOS;
    }
    return Platform.isAndroid ? _realInterstitialAndroid : _realInterstitialIOS;
  }

  static String get rewardedAdUnitId {
    if (kDebugMode) {
      return Platform.isAndroid ? _testRewardedAndroid : _testRewardedIOS;
    }
    return Platform.isAndroid ? _realRewardedAndroid : _realRewardedIOS;
  }
}
