// lib/screens/feed_screen.dart
// Versión Definitiva — Auditoría Doctorado en Ingeniería Informática
// Feed optimizado con Banner Anclado Inferior Fijo, Intersticiales y Pull-to-Refresh.

import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:video_player/video_player.dart';

import '../services/ads_service.dart';
import '../services/api_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// FEED SCREEN — Pantalla principal de videos con Banner Anclado
/// ═══════════════════════════════════════════════════════════════════════════
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // ─── ESTADO DEL FEED ─────────────────────────────────────────────
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String? _errorMessage;

  // ─── ADMOB: BANNER ANCLADO ───────────────────────────────────────
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _log('initState', 'Inicializando FeedScreen y servicios publicitarios...');
    _loadVideos();
    _loadBannerAd();
  }

  @override
  void dispose() {
    _log('dispose', 'Liberando recursos del banner de AdMob y Feed...');
    _bannerAd?.dispose();
    super.dispose();
  }

  // ─── LOGS ESTRUCTURADOS ──────────────────────────────────────────
  void _log(String tag, String message) {
    debugPrint('📺 [FeedScreen][$tag] $message');
  }

  void _logError(String tag, String message, [Object? error]) {
    debugPrint('❌ [FeedScreen][$tag] $message');
    if (error != null) debugPrint('    → Detalle error: $error');
  }

  // ─── CARGA DE BANNER ADMOB ───────────────────────────────────────
  void _loadBannerAd() {
    _log('_loadBannerAd', 'Solicitando creación de banner anclado inferior...');

    try {
      _bannerAd = AdsService().createBannerAd(
        onLoaded: () {
          _log('_loadBannerAd', '✅ Banner cargado exitosamente.');
          if (mounted) {
            setState(() => _isBannerLoaded = true);
          }
        },
        onFailed: (error) {
          _logError('_loadBannerAd', 'Fallo al cargar el banner de AdMob.', error);
          if (mounted) {
            setState(() => _isBannerLoaded = false);
          }
        },
      );
    } catch (e) {
      _logError('_loadBannerAd', 'Excepción al invocar createBannerAd', e);
    }
  }

  // ─── CARGAR VIDEOS DESDE POCKETBASE (api.videitosapp.cl) ─────────
  Future<void> _loadVideos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _log('_loadVideos', 'Conectando con PocketBase para obtener colección videitos...');

      final result = await ApiService.instance.pb
          .collection('videitos')
          .getList(
            sort: '-created',
            perPage: 50,
            expand: 'creador',
          );

      if (mounted) {
        setState(() {
          _videos = result.items;
          _isLoading = false;
        });
      }
      _log('_loadVideos', '✅ Sincronización exitosa: ${_videos.length} videos cargados en memoria.');
    } catch (e, stack) {
      _logError('_loadVideos', 'Error crítico al consultar PocketBase.', e);
      debugPrint('📚 [Stacktrace] $stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Error al conectar con el servidor: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    _log('_onRefresh', 'Ejecutando Pull-to-Refresh del feed...');
    await _loadVideos();
  }

  // ─── BUILD PRINCIPAL ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
                const SizedBox(height: 20),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _loadVideos,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar Conexión'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_videos.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF00D4FF),
          child: ListView(
            children: const [
              SizedBox(height: 200),
              Icon(Icons.video_library_outlined, size: 80, color: Colors.grey),
              SizedBox(height: 20),
              Center(
                child: Text(
                  'No hay videos disponibles aún',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ),
              SizedBox(height: 10),
              Center(
                child: Text(
                  '¡Sube tu primer video desde la pestaña inferior!',
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 🌟 ARQUITECTURA DE STACK: Feed de videos + Banner Anclado Inferior Fijo
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. LISTA DE VIDEOS (Corre libremente por todo el espacio con padding inferior para no solapar el banner)
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: const Color(0xFF00D4FF),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 70), // Espacio reservado para el banner inferior
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                return _VideoCard(
                  video: video,
                  onVideoViewed: () {
                    // Notificar visualización para disparar intersticiales de AdMob
                    AdsService().onVideoViewed();
                  },
                );
              },
            ),
          ),

          // 2. BANNER ANCLADO FIJO EN LA PARTE INFERIOR
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
              ),
              child: _buildBannerAdWidget(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerAdWidget() {
    if (!_isBannerLoaded || _bannerAd == null) {
      return SizedBox(
        height: 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00D4FF)),
            ),
            SizedBox(width: 10),
            Text(
              'Cargando anuncio publicitario...',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: _bannerAd!.size.width.toDouble(),
      height: _bannerAd!.size.height.toDouble(),
      child: AdWidget(ad: _bannerAd!),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// VIDEO CARD — Reproductor individual con Chewie y VideoPlayer
// ═══════════════════════════════════════════════════════════════════════════
class _VideoCard extends StatefulWidget {
  final dynamic video;
  final VoidCallback? onVideoViewed;

  const _VideoCard({
    required this.video,
    this.onVideoViewed,
  });

  @override
  State<_VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<_VideoCard> {
  VideoPlayerController? _controller;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _viewNotified = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final videoFile = widget.video.data['archivo_video'] ??
          widget.video.getStringValue('archivo_video');

      if (videoFile == null || videoFile.toString().isEmpty) {
        debugPrint('❌ [_VideoCard] El registro de video no contiene archivo asociado.');
        if (mounted) {
          setState(() {
            _isInitialized = true;
            _hasError = true;
          });
        }
        return;
      }

      final baseUrl = ApiService.instance.baseUrl;
      final fileUrl = '$baseUrl/api/files/videitos/${widget.video.id}/$videoFile';

      debugPrint('🎥 [_VideoCard] Conectando reproductor a URL: $fileUrl');

      _controller = VideoPlayerController.networkUrl(Uri.parse(fileUrl));
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0); // Silenciado por defecto para experiencia óptima

      _chewieController = ChewieController(
        videoPlayerController: _controller!,
        autoPlay: false,
        looping: true,
        showControls: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF00D4FF),
          handleColor: const Color(0xFF00D4FF),
          backgroundColor: Colors.grey,
          bufferedColor: Colors.white54,
        ),
        errorBuilder: (context, errorMessage) {
          debugPrint('❌ [_VideoCard] Error interno en Chewie: $errorMessage');
          return const Center(
            child: Text(
              'Error al reproducir el flujo de video',
              style: TextStyle(color: Colors.white),
            ),
          );
        },
      );

      if (!_viewNotified) {
        _viewNotified = true;
        widget.onVideoViewed?.call();
      }

      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint('❌ [_VideoCard] Excepción inicializando video: $e');
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.video.data['titulo']?.toString() ?? 'Sin título';
    final creator = widget.video.expand?['creador'];
    final username = creator?['username']?.toString() ??
        creator?['name']?.toString() ??
        'Usuario desconocido';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadatos (Título y Creador)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Creador: @$username',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Contenedor del Reproductor
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: Container(
              height: 320,
              color: Colors.black,
              child: _buildPlayerContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerContent() {
    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.videocam_off_rounded, size: 50, color: Colors.redAccent),
            SizedBox(height: 8),
            Text(
              'No se pudo cargar el archivo multimedia',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_isInitialized && _chewieController != null) {
      return Chewie(controller: _chewieController!);
    }

    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
            strokeWidth: 2.5,
          ),
          SizedBox(height: 10),
          Text(
            'Cargando reproductor...',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}