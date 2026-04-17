import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../main.dart'; // tu instancia global 'pb'
import '../models/video.dart'; // definiremos este modelo
import 'video_player_widget.dart'; // reproductor (próximo paso)

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  List<RecordModel> _videos = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _page = 1;
  final int _perPage = 5;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Future<void> _loadVideos() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await pb.collection('videitos').getList(
            page: _page,
            perPage: _perPage,
            sort: '-created', // más recientes primero
          );
      setState(() {
        _videos = result.items;
        _hasMore = result.items.length == _perPage;
      });
    } catch (e) {
      print('Error loading videos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;
    setState(() => _isLoading = true);
    try {
      final result = await pb.collection('videitos').getList(
            page: _page + 1,
            perPage: _perPage,
            sort: '-created',
          );
      if (result.items.isNotEmpty) {
        setState(() {
          _videos.addAll(result.items);
          _page++;
          _hasMore = result.items.length == _perPage;
        });
      } else {
        _hasMore = false;
      }
    } catch (e) {
      print('Error loading more: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        itemCount: _videos.length,
        controller: PageController(initialPage: 0),
        itemBuilder: (context, index) {
          final video = _videos[index];
          final videoUrl =
              pb.files.getUrl(video, video.data['archivo_video']).toString();
          final title = video.data['titulo'] ?? '';
          final creatorId = video.data['creador'] ?? '';
          return VideoPlayerWidget(
            videoUrl: videoUrl,
            title: title,
            creatorId: creatorId,
            videoId: video.id,
          );
        },
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.add_box), label: 'Subir'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
        onTap: (index) {
          if (index == 1) {
            Navigator.pushNamed(context, '/upload');
          } else if (index == 2) {
            Navigator.pushNamed(context, '/profile');
          }
        },
      ),
    );
  }
}
