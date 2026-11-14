// lib/screens/home_screen.dart
// Versión Definitiva — Auditoría Doctorado en Ingeniería Informática
// Arquitectura completa: HomeScreen, Feed TikTok con Banner Anclado, MyVideos y Profile.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart'; // 💰 Importado para AdMob

import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/ads_service.dart'; // 💰 Servicio de anuncios
import 'upload_screen.dart';

// ─── CACHE MANAGER PERSONALIZADO ──────────────────────────────────
class CustomCacheManager extends CacheManager {
  static const key = 'videitosCache';
  static final CustomCacheManager _instance = CustomCacheManager._internal();

  factory CustomCacheManager() => _instance;

  CustomCacheManager._internal()
      : super(
          Config(
            key,
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 100,
            fileService: HttpFileService(),
          ),
        );
}

// ─── HOME SCREEN ──────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    debugPrint('🏠 [HomeScreen] Inicializando contenedor principal de navegación...');
    _pages = [
      const FeedScreen(),
      const UploadScreen(),
      const ProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        backgroundColor: Colors.black,
        selectedItemColor: const Color(0xFF00D4FF),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 1 && !ApiService.instance.isLoggedIn) {
            debugPrint('⚠️ [HomeScreen] Intento de acceso a "Subir" sin sesión activa.');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Debes iniciar sesión para subir videos')),
            );
            return;
          }
          debugPrint('🔄 [HomeScreen] Cambiando a pestaña de índice: $index');
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Feed'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle), label: 'Subir'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}

// ─── PANTALLA DE FEED CON BÚSQUEDA Y BANNER ANCLADO ───────────────
class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String _error = '';
  String _searchQuery = '';
  Timer? _debounceTimer;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // ─── ADMOB: BANNER ANCLADO ───────────────────────────────────────
  BannerAd? _bannerAd;
  bool _isBannerLoaded = false;

  @override
  void initState() {
    super.initState();
    debugPrint('📺 [FeedScreen] Inicializando Feed y cargando banner publicitario...');
    _loadVideos();
    _loadBannerAd();
    _pageController.addListener(_onPageChange);
  }

  @override
  void dispose() {
    debugPrint('🧹 [FeedScreen] Liberando recursos de FeedScreen...');
    _debounceTimer?.cancel();
    _pageController.removeListener(_onPageChange);
    _pageController.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

  // ─── CARGAR BANNER DE ADMOB ──────────────────────────────────────
  void _loadBannerAd() {
    debugPrint('💰 [FeedScreen] Solicitando creación de banner anclado...');
    try {
      _bannerAd = AdsService().createBannerAd(
        onLoaded: () {
          debugPrint('✅ [FeedScreen] Banner de AdMob cargado exitosamente.');
          if (mounted) setState(() => _isBannerLoaded = true);
        },
        onFailed: (error) {
          debugPrint('❌ [FeedScreen] Error al cargar banner de AdMob: ${error.message}');
          if (mounted) setState(() => _isBannerLoaded = false);
        },
      );
    } catch (e) {
      debugPrint('💥 [FeedScreen] Excepción al crear banner: $e');
    }
  }

  void _onPageChange() {
    final newPage = _pageController.page?.round() ?? 0;
    if (newPage != _currentPage) {
      _currentPage = newPage;
      _preloadVideo(_currentPage);
    }
  }

  Future<void> _preloadVideo(int index) async {
    if (index < 0 || index >= _videos.length) return;
    try {
      final video = _videos[index];
      final videoFile = video.data['archivo_video'] ?? '';
      if (videoFile.isEmpty) return;
      final videoUrl =
          '${ApiService.instance.baseUrl}/api/files/videitos/${video.id}/$videoFile';
      CustomCacheManager().getSingleFile(videoUrl).then((_) {
        debugPrint('📦 [FeedScreen] Precargado video en índice $index');
      }).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _loadVideos() async {
    if (!ApiService.instance.isLoggedIn) {
      debugPrint('⚠️ [FeedScreen] Usuario no autenticado al intentar cargar videos.');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Inicia sesión para ver videos.';
        });
      }
      return;
    }

    setState(() => _isLoading = true);
    try {
      debugPrint('🔧 [FeedScreen] Consultando colección "videitos" en PocketBase...');
      String filter = '';
      if (_searchQuery.isNotEmpty) {
        filter = 'titulo ~ "$_searchQuery"';
      }
      final result = await ApiService.instance.pb
          .collection('videitos')
          .getList(sort: '-created', perPage: 50, filter: filter);

      if (mounted) {
        setState(() {
          _videos = result.items;
          _isLoading = false;
          _error = '';
        });
        debugPrint('✅ [FeedScreen] ${_videos.length} videos cargados correctamente.');
        if (_videos.isNotEmpty) _preloadVideo(0);
      }
    } catch (e) {
      debugPrint('❌ [FeedScreen] Error al cargar videos desde PocketBase: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar videos: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Videitos'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Buscar videos...',
                hintStyle: TextStyle(color: Colors.grey),
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.black,
              ),
              onChanged: (query) {
                _debounceTimer?.cancel();
                _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                  setState(() {
                    _searchQuery = query;
                  });
                  _loadVideos();
                });
              },
            ),
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            Text(_error, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadVideos,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.video_library, size: 60, color: Colors.grey),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No se encontraron videos para "$_searchQuery"'
                  : 'Aún no hay videos. ¡Sé el primero en subir uno!',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 🌟 ARQUITECTURA DE STACK: Feed de videos + Banner Anclado Inferior Fijo
    return Stack(
      children: [
        // 1. PageView de videos vertical estilo TikTok (con padding inferior para el banner)
        Positioned.fill(
          bottom: 55, // Espacio reservado para que el contenido no quede oculto bajo el banner
          child: PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: _videos.length,
            itemBuilder: (context, index) {
              final video = _videos[index];
              final videoId = video.id;
              final videoFile = video.data['archivo_video'] ?? '';
              final titulo = video.data['titulo'] ?? 'Sin título';
              final creador = video.data['creador'] ?? 'Usuario';
              final videoUrl =
                  '${ApiService.instance.baseUrl}/api/files/videitos/$videoId/$videoFile';

              return TikTokVideoCard(
                key: ValueKey('video_$videoId'),
                videoUrl: videoUrl,
                title: titulo,
                creator: creador,
                index: index,
                onVideoViewed: () {
                  // Notificar visualización para control de anuncios intersticiales
                  AdsService().onVideoViewed();
                },
              );
            },
          ),
        ),

        // 2. Banner de AdMob Anclado Permanentemente en la Parte Inferior
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 2),
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
    );
  }

  Widget _buildBannerAdWidget() {
    if (!_isBannerLoaded || _bannerAd == null) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: Text(
            'Cargando anuncio publicitario...',
            style: TextStyle(color: Colors.grey, fontSize: 11),
          ),
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

// ─── WIDGET DE VIDEO TIKTOK-LIKE ──────────────────────────────────
class TikTokVideoCard extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String creator;
  final int index;
  final VoidCallback? onVideoViewed;

  const TikTokVideoCard({
    super.key,
    required this.videoUrl,
    required this.title,
    required this.creator,
    required this.index,
    this.onVideoViewed,
  });

  @override
  State<TikTokVideoCard> createState() => _TikTokVideoCardState();
}

class _TikTokVideoCardState extends State<TikTokVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isPlaying = false;
  int _likes = 0;
  bool _isLiked = false;
  bool _isInitializing = false;
  Timer? _autoPlayTimer;
  bool _viewNotified = false;

  @override
  void initState() {
    super.initState();
    _likes = 42 + (widget.index * 7) % 100;
  }

  Future<void> _initializeVideo() async {
    if (_isInitialized || _isInitializing || _isLoading) return;

    setState(() {
      _isInitializing = true;
      _isLoading = true;
    });

    try {
      debugPrint('🎥 [TikTokVideoCard] Descargando/cargando video #${widget.index} desde caché...');
      final file = await CustomCacheManager().getSingleFile(widget.videoUrl);
      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      await _controller!.setLooping(true);

      if (!mounted) return;

      setState(() {
        _isInitialized = true;
        _isLoading = false;
        _isInitializing = false;
        _hasError = false;
      });

      if (!_viewNotified) {
        _viewNotified = true;
        widget.onVideoViewed?.call();
      }
    } catch (e) {
      debugPrint('❌ [TikTokVideoCard] Error cargando video #${widget.index}: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitializing = false;
          _hasError = true;
        });
      }
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized || _hasError) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _isPlaying = false);
    } else {
      _controller!.play();
      setState(() => _isPlaying = true);
    }
  }

  void _toggleLike() {
    setState(() {
      _isLiked = !_isLiked;
      _likes += _isLiked ? 1 : -1;
    });
  }

  void _shareVideo() {
    Share.share(
      '🎬 ${widget.title}\n'
      '👤 @${widget.creator}\n'
      '📹 ${widget.videoUrl}',
    );
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return VisibilityDetector(
      key: Key('vis_${widget.index}'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction > 0.7;
        if (visible) {
          if (!_isInitialized && !_isInitializing && !_isLoading) {
            _initializeVideo();
          }
          if (_isInitialized && _controller != null && !_hasError) {
            if (!_controller!.value.isPlaying) {
              _autoPlayTimer?.cancel();
              _autoPlayTimer = Timer(const Duration(milliseconds: 300), () {
                if (mounted &&
                    _controller != null &&
                    !_controller!.value.isPlaying) {
                  _controller!.play();
                  setState(() => _isPlaying = true);
                }
              });
            }
          }
        } else {
          _autoPlayTimer?.cancel();
          if (_isInitialized &&
              _controller != null &&
              _controller!.value.isPlaying) {
            _controller!.pause();
            setState(() => _isPlaying = false);
          }
        }
      },
      child: Container(
        width: screenWidth,
        height: screenHeight,
        color: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: _isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF00D4FF)),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Cargando video...',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  : _hasError
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.broken_image,
                                  size: 60, color: Colors.grey),
                              SizedBox(height: 10),
                              Text(
                                'Video no disponible',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : _isInitialized && _controller != null
                          ? FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.size.width,
                                height: _controller!.value.size.height,
                                child: VideoPlayer(_controller!),
                              ),
                            )
                          : Container(),
            ),
            Positioned.fill(
              child: GestureDetector(
                onTap: _togglePlayPause,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                      stops: const [0.7, 1.0],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${widget.creator}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Column(
                              children: [
                                IconButton(
                                  icon: Icon(
                                    _isLiked
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: _isLiked ? Colors.red : Colors.white,
                                    size: 40,
                                  ),
                                  onPressed: _toggleLike,
                                ),
                                Text(
                                  '$_likes',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 16),
                                ),
                                const SizedBox(height: 16),
                                IconButton(
                                  icon: const Icon(Icons.share_outlined,
                                      color: Colors.white, size: 40),
                                  onPressed: _shareVideo,
                                ),
                                const Text(
                                  'Compartir',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!_isPlaying && _isInitialized && !_hasError)
              Positioned.fill(
                child: Center(
                  child: IconButton(
                    icon: const Icon(Icons.play_circle_outline,
                        color: Colors.white, size: 80),
                    onPressed: _togglePlayPause,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── PANTALLA DE MIS VIDEOS ──────────────────────────────────────
class MyVideosScreen extends StatefulWidget {
  const MyVideosScreen({super.key});

  @override
  State<MyVideosScreen> createState() => _MyVideosScreenState();
}

class _MyVideosScreenState extends State<MyVideosScreen> {
  List<dynamic> _videos = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMyVideos();
  }

  Future<void> _loadMyVideos() async {
    if (!ApiService.instance.isLoggedIn) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Inicia sesión para ver tus videos.';
        });
      }
      return;
    }

    final userId = ApiService.instance.currentUser?.id;
    if (userId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Usuario no identificado.';
        });
      }
      return;
    }

    try {
      final result =
          await ApiService.instance.pb.collection('videitos').getList(
                filter: 'creador = "$userId"',
                sort: '-created',
                perPage: 50,
              );

      if (mounted) {
        setState(() {
          _videos = result.items;
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Error al cargar tus videos: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Videos'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
              ),
            )
          : _error.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 60, color: Colors.grey),
                      const SizedBox(height: 20),
                      Text(_error, style: const TextStyle(color: Colors.white)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadMyVideos,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                )
              : _videos.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library,
                              size: 60, color: Colors.grey),
                          SizedBox(height: 20),
                          Text(
                            'No has subido videos aún.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _videos.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final video = _videos[index];
                        final videoId = video.id;
                        final videoFile = video.data['archivo_video'] ?? '';
                        final titulo = video.data['titulo'] ?? 'Sin título';
                        final videoUrl =
                            '${ApiService.instance.baseUrl}/api/files/videitos/$videoId/$videoFile';

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[900],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: VideoCardMini(
                              videoUrl: videoUrl,
                              title: titulo,
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

// ─── MINI REPRODUCTOR ──────────────────────────────────────────
class VideoCardMini extends StatefulWidget {
  final String videoUrl;
  final String title;

  const VideoCardMini({super.key, required this.videoUrl, required this.title});

  @override
  State<VideoCardMini> createState() => _VideoCardMiniState();
}

class _VideoCardMiniState extends State<VideoCardMini> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      final file = await CustomCacheManager().getSingleFile(widget.videoUrl);
      _controller = VideoPlayerController.file(file);
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error cargando video mini: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
            Icon(Icons.broken_image, color: Colors.grey, size: 40),
            Text('Video no disponible', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }
    return _isInitialized && _controller != null
        ? FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        : Container();
  }
}

// ─── PANTALLA DE PERFIL ──────────────────────────────────────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw Exception('No se pudo abrir el enlace: $url');
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay usuario autenticado.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: const Text(
          'Esta acción eliminará permanentemente tu cuenta y todos tus datos asociados. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ApiService.instance.pb.collection('users').delete(user.id);
      auth.logout();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta eliminada correctamente.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar cuenta: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.currentUser;

    final username = user?.data['username'] ?? 'Usuario';
    final email = user?.data['email'] ?? 'Sin email';
    final initial = username.isNotEmpty ? username[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF00D4FF),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Divider(color: Colors.grey),
            ListTile(
              leading:
                  const Icon(Icons.video_library, color: Color(0xFF00D4FF)),
              title: const Text('Mis Videos',
                  style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MyVideosScreen()),
                );
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.report_problem, color: Color(0xFF00D4FF)),
              title: const Text('Reportar un problema',
                  style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
              onTap: () {
                _launchUrl('https://forms.gle/JmVaP7aTNJ2mbnMr6');
              },
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip, color: Color(0xFF00D4FF)),
              title: const Text(
                'Términos y Políticas de Privacidad',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: const Text(
                'Plataforma exclusiva para mayores de 18 años',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
              onTap: () {
                _launchUrl('https://videitos.cl/privacy-policy/');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text(
                'Eliminar cuenta y datos asociados',
                style: TextStyle(color: Colors.red),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.grey, size: 16),
              onTap: () => _deleteAccount(context),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () {
                auth.logout();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sesión cerrada')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}