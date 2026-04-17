import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import '../models/video.dart';
import '../screens/report_screen.dart';

class VideoPlayerWidget extends StatefulWidget {
  final Video video;
  const VideoPlayerWidget({super.key, required this.video});

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  late VideoPlayerController _videoController;
  late ChewieController _chewieController;
  bool _isInitialized = false;
  bool _showControls = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    String videoUrl = widget.video.url.replaceAll('localhost', '190.107.177.199');
    _videoController = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    await _videoController.initialize();

    _chewieController = ChewieController(
      videoPlayerController: _videoController,
      autoPlay: true,
      looping: true,
      aspectRatio: _videoController.value.aspectRatio,
      showControls: _showControls,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFF00D4FF),
        handleColor: const Color(0xFF00D4FF),
        backgroundColor: Colors.grey,
        bufferedColor: Colors.grey.shade300,
      ),
    );

    setState(() {
      _isInitialized = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showControls = !_showControls;
          // Recrear el controlador con la nueva visibilidad
          _chewieController = _chewieController.copyWith(
            showControls: _showControls,
          );
        });
      },
      child: Stack(
        children: [
          Chewie(controller: _chewieController),
          Positioned(
            bottom: 80,
            right: 16,
            child: IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReportScreen(videoId: widget.video.id),
                  ),
                );
              },
              icon: const Icon(Icons.flag, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
