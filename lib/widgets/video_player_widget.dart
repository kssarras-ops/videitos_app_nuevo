// lib/widgets/video_player_widget.dart
// Versión Definitiva — Auditoría Doctorado en Ingeniería Informática
// Arquitectura de reproducción de video optimizada con logs detallados y control de memoria.

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/pocketbase_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final dynamic videoData; // Soporta RecordModel o Map nativo sin romper la jerarquía
  final VoidCallback? onCommentTap;

  const VideoPlayerWidget({
    super.key,
    required this.videoData,
    this.onCommentTap,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  final PocketBaseService _pb = PocketBaseService();

  // Variables locales extraídas dinámicamente de forma segura
  String _videoId = '';
  String _videoUrl = '';
  String _videoTitle = '';
  int _likesCount = 0;
  int _commentsCount = 0;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🎥 [VideoPlayer] initState llamado para widget.');
    _extractData();
    _initializePlayer();
  }

  /// Extracción quirúrgica y segura de datos desde RecordModel o Map
  void _extractData() {
    debugPrint('🔍 [VideoPlayer] Iniciando extracción de datos de video...');
    final item = widget.videoData;

    if (item == null) {
      debugPrint('⚠️ [VideoPlayer] item de video es nulo.');
      setState(() {
        _hasError = true;
      });
      return;
    }

    if (item is RecordModel) {
      _videoId = item.id;
      _videoUrl = item.getStringValue('url').isEmpty
          ? item.getStringValue('video_url')
          : item.getStringValue('url');
      _videoTitle = item.getStringValue('title').isEmpty
          ? item.getStringValue('titulo', 'Video sin título')
          : item.getStringValue('title');
      _likesCount = item.getIntValue('likesCount', item.getIntValue('likes', 0));
      _commentsCount = item.getIntValue('commentsCount', item.getIntValue('comments', 0));
      _isLiked = item.getBoolValue('isLiked', false);
      debugPrint('✅ [VideoPlayer] Datos extraídos desde RecordModel [ID: $_videoId | Título: $_videoTitle]');
    } else if (item is Map) {
      _videoId = (item['id'] ?? '').toString();
      _videoUrl = (item['url'] ?? item['video_url'] ?? '').toString();
      _videoTitle = (item['title'] ?? item['titulo'] ?? 'Video sin título').toString();
      _likesCount = int.tryParse(item['likesCount']?.toString() ?? item['likes']?.toString() ?? '0') ?? 0;
      _commentsCount = int.tryParse(item['commentsCount']?.toString() ?? item['comments']?.toString() ?? '0') ?? 0;
      _isLiked = item['isLiked'] == true;
      debugPrint('✅ [VideoPlayer] Datos extraídos desde Map [ID: $_videoId | Título: $_videoTitle]');
    } else {
      debugPrint('❌ [VideoPlayer] Formato de datos desconocido.');
      setState(() {
        _hasError = true;
      });
    }
  }

  /// Inicialización del reproductor y control de buffer
  Future<void> _initializePlayer() async {
    debugPrint('🚀 [VideoPlayer] Inicializando reproductor para video ID: $_videoId');

    if (_videoUrl.isEmpty || _hasError) {
      debugPrint('❌ [VideoPlayer] URL de video vacía o error previo detectado. Abortando inicialización.');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isInitialized = true;
      });
      return;
    }

    debugPrint('🌐 [VideoPlayer] Cargando URL: $_videoUrl');
    _controller = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));

    try {
      await _controller.initialize();
      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _hasError = false;
      });

      _controller.play();
      _controller.setLooping(true);
      debugPrint('✅ [VideoPlayer] Reproductor inicializado y reproduciendo con éxito para ID: $_videoId');
    } catch (e, stackTrace) {
      debugPrint('💥 [VideoPlayer] Excepción al inicializar video $_videoId: $e');
      debugPrint('📚 [VideoPlayer StackTrace] $stackTrace');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    debugPrint('🧹 [VideoPlayer] Liberando recursos (dispose) para video ID: $_videoId');
    try {
      if (_isInitialized && !_hasError) {
        _controller.pause();
        _controller.dispose();
        debugPrint('✅ [VideoPlayer] Controlador de video eliminado y memoria liberada correctamente.');
      }
    } catch (e) {
      debugPrint('⚠️ [VideoPlayer] Error menor durante el dispose del controlador: $e');
    }
    super.dispose();
  }

  /// Interacción de Me Gusta (Like) con backend
  Future<void> _toggleLike() async {
    if (_videoId.isEmpty) return;
    debugPrint('❤️ [VideoPlayer] Ejecutando toggleLike para video $_videoId');
    try {
      final result = await _pb.toggleLike(_videoId);
      if (!mounted) return;
      setState(() {
        _isLiked = result['liked'] as bool? ?? false;
        _likesCount = result['likesCount'] as int? ?? 0;
      });
      debugPrint('✅ [VideoPlayer] Like actualizado exitosamente. Estado: Liked=$_isLiked | Total=$_likesCount');
    } catch (e) {
      debugPrint('❌ [VideoPlayer] Error en _toggleLike: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al dar like: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
        ),
      );
    }

    if (_hasError) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 60, color: Colors.redAccent),
            SizedBox(height: 12),
            Text(
              'Video no disponible o dañado',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. El Video de fondo a pantalla completa nativa
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),

        // 2. Capa transparente para Play/Pause detectando toques de pantalla entera
        Positioned.fill(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
                debugPrint('⏯️ [VideoPlayer] Toggle Play/Pause manual. Reproduciendo: ${_controller.value.isPlaying}');
              });
            },
            child: Container(
              color: Colors.transparent,
              child: !_controller.value.isPlaying
                  ? const Center(
                      child: Icon(
                        Icons.play_arrow,
                        size: 80,
                        color: Colors.white30,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),

        // Sombra degradada inferior para legibilidad del título
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black.withOpacity(0.6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.7, 1.0],
                ),
              ),
            ),
          ),
        ),

        // 3. CAPA FLOTANTE: Título del video (Estilo TikTok)
        Positioned(
          bottom: 25,
          left: 16,
          right: 90,
          child: IgnorePointer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _videoTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        blurRadius: 6.0,
                        color: Colors.black87,
                        offset: Offset(1, 1),
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // 4. CAPA FLOTANTE: Panel Lateral Derecho
        Positioned(
          right: 12,
          bottom: 40,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón de Like
              IconButton(
                icon: Icon(
                  _isLiked ? Icons.favorite : Icons.favorite_border,
                  color: _isLiked ? Colors.red : Colors.white,
                  size: 35,
                ),
                onPressed: _toggleLike,
              ),
              Text(
                '$_likesCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Botón de Comentarios
              IconButton(
                icon: const Icon(Icons.comment, color: Colors.white, size: 35),
                onPressed: widget.onCommentTap ?? () {},
              ),
              Text(
                '$_commentsCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),

              // MARCA DE AGUA OFICIAL EN LOOP
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Opacity(
                    opacity: 0.7,
                    child: Image.asset(
                      'assets/images/app_logo.jpg',
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.play_circle_filled,
                          color: Color(0xFF00D4FF),
                          size: 44,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}