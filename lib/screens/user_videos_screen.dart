import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../models/video.dart';
import '../widgets/video_player_widget.dart';

class UserVideosScreen extends StatefulWidget {
  final String userId;
  const UserVideosScreen({super.key, required this.userId});

  @override
  State<UserVideosScreen> createState() => _UserVideosScreenState();
}

class _UserVideosScreenState extends State<UserVideosScreen> {
  List<Video> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVideos();
  }

  Future<void> _loadUserVideos() async {
    final pb = PocketBaseService();
    try {
      final result = await pb.pb.collection('videitos').getList(
            filter: 'creador = "${widget.userId}"',
            sort: '-created',
          );
      final videos = result.items
          .map((record) => Video.fromRecord(record, pb.pb))
          .toList();
      setState(() {
        _videos = videos;
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando videos del usuario: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis videos')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? const Center(child: Text('No has subido videos aún'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => VideoPlayerWidget(
                              videoUrl: video.videoUrl,
                              title: video.title,
                              creatorId: video.creatorId,
                              videoId: video.id,
                            ),
                          ),
                        );
                      },
                      child: Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Image.network(
                                video.thumbnailUrl ?? video.videoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Container(color: Colors.grey),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                video.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
