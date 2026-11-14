// lib/widgets/admob_banner_widget.dart
// Versión Definitiva — Banner Anclado Inferior con Observabilidad y Ciclo de Vida Seguro

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/config/ad_config.dart'; // <-- Importamos la configuración centralizada

class AdMobBannerWidget extends StatefulWidget {
  const AdMobBannerWidget({super.key});

  @override
  State<AdMobBannerWidget> createState() => _AdMobBannerWidgetState();
}

class _AdMobBannerWidgetState extends State<AdMobBannerWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('💰 [AdMobBanner] Inicializando widget de banner...');
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // 👇 La magia está aquí: AdConfig decide si usar el ID de prueba o tu ID real.
    final String adUnitId = AdConfig.bannerAdUnitId;

    debugPrint(
        '💰 [AdMobBanner] Solicitando carga de Banner (Entorno: ${kDebugMode ? "PRUEBA" : "PRODUCCIÓN"})');
    debugPrint('💰 [AdMobBanner] UnitID: $adUnitId');

    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('✅ [AdMobBanner] ¡Banner cargado y listo para mostrarse!');
          if (mounted) {
            setState(() => _isLoaded = true);
          }
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint(
              '❌ [AdMobBanner] Error cargando banner: ${error.message} (Code: ${error.code})');
          ad.dispose();
          if (mounted) {
            setState(() {
              _bannerAd = null;
              _isLoaded = false;
            });
          }
        },
        onAdOpened: (ad) {
          debugPrint(
              '📱 [AdMobBanner] El usuario hizo clic en el anuncio (se abre pantalla completa).');
        },
        onAdClosed: (ad) {
          debugPrint(
              '📱 [AdMobBanner] El usuario cerró el anuncio y volvió a la app.');
        },
        onAdImpression: (ad) {
          // ⚠️ CRÍTICO: Este log confirma que Google ha contado la impresión para tu monetización.
          debugPrint(
              '👁️ [AdMobBanner] Impresión registrada y facturada por AdMob.');
        },
      ),
    );

    try {
      _bannerAd!.load();
    } catch (e) {
      debugPrint('💥 [AdMobBanner] Excepción crítica al invocar load(): $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 [AdMobBanner] Liberando recursos del banner (dispose)...');
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Estado de Carga: Mostramos un placeholder del mismo tamaño (50px)
    // para evitar que la interfaz de usuario "salte" cuando aparezca el banner.
    if (!_isLoaded || _bannerAd == null) {
      return Container(
        width: double.infinity,
        height: 50, // Altura estándar de un banner
        color: Colors.transparent,
      );
    }

    // 2. Estado Cargado: Mostramos el banner real
    return Container(
      alignment: Alignment.center,
      width: double.infinity,
      height: _bannerAd!.size.height.toDouble(),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF00D4FF).withOpacity(0.3),
            width: 0.5,
          ),
        ),
      ),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
