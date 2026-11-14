import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';
import '../widgets/video_player_widget.dart';

class UserVideosScreen extends StatefulWidget {
  const UserVideosScreen({super.key});

  @override
  State<UserVideosScreen> createState() => _UserVideosScreenState();
}

class _UserVideosScreenState extends State<UserVideosScreen> {
  final PocketBaseService _pb = PocketBaseService();
  List<dynamic> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserVideos();
  }

  Future<void> _loadUserVideos() async {
    final userId = _pb.currentUserId;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final result = await _pb.pb.collection('videitos').getList(
            filter: 'creador = "$userId"',
            sort: '-created',
          );
      setState(() {
        _records = result.items;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar tus videos: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Fondo oscuro integrado
      appBar: AppBar(
        title: const Text('Mis Videos'),
        backgroundColor: Colors.black,
        foregroundColor: const Color(0xFF00D4FF),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
              ),
            )
          : _records.isEmpty
              ? const Center(
                  child: Text(
                    'Aún no has subido ningún video',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final videoFile = record.data['archivo_video'];

                    // Resuelve quirúrgicamente la URL usando el búnker de PocketBase
                    final videoUrl = videoFile != null
                        ? _pb.pb.files.getUrl(record, videoFile).toString()
                        : '';

                    // Inyectamos dinámicamente la URL en los datos para que el VideoPlayerWidget la consuma de inmediato
                    record.data['url'] = videoUrl;

                    return Card(
                      color: const Color(0xFF1E1E1E),
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: videoUrl.isNotEmpty
                                  ? VideoPlayerWidget(
                                      videoData:
                                          record, // Usa el nuevo mapeo dinámico
                                    )
                                  : const Center(
                                      child: Icon(Icons.video_library,
                                          size: 60, color: Colors.grey),
                                    ),
                            ),
                          ),
                          ListTile(
                            title: Text(
                              record.data['titulo'] ?? 'Sin título',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              'Subido el ${_formatDate(record.created ?? '')}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
