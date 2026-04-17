import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:cross_file/cross_file.dart';
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  XFile? _selectedFile;
  VideoPlayerController? _controller;
  bool _isUploading = false;
  String? _title;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: kIsWeb,
    );

    if (result != null) {
      if (kIsWeb) {
        // Web: usar bytes, omitimos mimeType si no está disponible
        setState(() {
          _selectedFile = XFile.fromData(
            result.files.single.bytes!,
            name: result.files.single.name,
            // mimeType: result.files.single.mimeType, // ← eliminado por incompatibilidad
          );
        });
      } else {
        // Móvil: usar path
        setState(() {
          _selectedFile = XFile(result.files.single.path!);
        });
      }
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    if (kIsWeb) {
      setState(() {});
    } else {
      _controller = VideoPlayerController.file(File(_selectedFile!.path));
      await _controller!.initialize();
      _controller!.setLooping(true);
      setState(() {});
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedFile == null || !_formKey.currentState!.validate()) return;

    setState(() => _isUploading = true);

    try {
      if (kIsWeb) {
        await ApiService.uploadVideoBytes(
          _selectedFile!.name,
          _selectedFile!.readAsBytes(),
          mimeType: _selectedFile!.mimeType ?? 'video/mp4',
          title: _title,
        );
      } else {
        await ApiService.uploadVideo(
          File(_selectedFile!.path),
          title: _title,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video subido exitosamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir video'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_selectedFile != null && !kIsWeb && _controller != null)
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: VideoPlayer(_controller!),
                )
              else if (_selectedFile != null && kIsWeb)
                Container(
                  height: 200,
                  color: Colors.grey[800],
                  child: const Center(
                    child: Icon(Icons.video_library,
                        size: 50, color: Colors.white),
                  ),
                )
              else
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.video_library,
                            size: 50, color: Colors.grey),
                        const SizedBox(height: 8),
                        Text(
                          'Selecciona un video',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _pickVideo,
                icon: const Icon(Icons.folder_open),
                label: const Text('Seleccionar video'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Título (opcional)',
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _title = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed:
                    _isUploading || _selectedFile == null ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(50),
                ),
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Subiendo...' : 'Publicar video'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
