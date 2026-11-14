// lib/screens/upload_screen.dart
// Versión Definitiva y Blindada — Videitos App
// Arquitectura robusta: Photo Picker nativo, limpieza de caché, manejo de tokens y seguridad asíncrona

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;
import 'package:video_compress/video_compress.dart';

import '../services/api_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// UPLOAD SCREEN — Videitos App (Conforme a Políticas de Google Play)
/// ═══════════════════════════════════════════════════════════════════════════
class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // ─── CONFIGURACIÓN ──────────────────────────────────────────────
  static const int _maxFileSize = 200 * 1024 * 1024; // 200 MB

  static const String _collection = 'videitos';
  static const String _fieldTitle = 'titulo';
  static const String _fieldUser = 'creador';
  static const String _fieldFile = 'archivo_video';

  // ─── ESTADO ──────────────────────────────────────────────────────
  File? _selectedVideo;
  bool _isUploading = false;
  bool _isCompressing = false;
  double _uploadProgress = 0.0;
  String _statusMessage = '';
  final TextEditingController _titleController = TextEditingController();
  http.Client? _httpClient;
  bool _isCancelled = false;

  // ─── CICLO DE VIDA ──────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    VideoCompress.setLogLevel(0);
    _log('initState', 'UploadScreen inicializado correctamente.');
  }

  @override
  void dispose() {
    _log('dispose', 'Liberando recursos de UploadScreen y cerrando conexiones HTTP.');
    _httpClient?.close();
    _titleController.dispose();
    // Limpieza automática de caché de compresión al salir de la pantalla
    VideoCompress.deleteAllCache().catchError((_) {});
    super.dispose();
  }

  // ─── LOGS ────────────────────────────────────────────────────────

  void _log(String tag, String message) {
    debugPrint('📤 [UploadScreen][$tag] $message');
  }

  void _logError(String tag, String message, [Object? error, StackTrace? st]) {
    debugPrint('❌ [UploadScreen][$tag] $message');
    if (error != null) debugPrint('    → error: $error');
    if (st != null) debugPrint('    → stack: $st');
  }

  // ─── SELECCIONAR VIDEO (SELECTOR NATIVO / PHOTO PICKER) ──────────

  Future<void> _pickVideo() async {
    if (_isUploading || _isCompressing) return;

    _log('_pickVideo', 'Abriendo el selector nativo del sistema (Photo Picker)...');

    try {
      final picker = ImagePicker();
      final result = await picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 10),
      );

      if (!mounted) return;

      if (result == null) {
        _log('_pickVideo', 'El usuario canceló la selección de video.');
        return;
      }

      final file = File(result.path);
      if (!await file.exists()) {
        _logError('_pickVideo', '❌ El archivo seleccionado no existe en ruta: ${result.path}');
        setState(() => _statusMessage = 'Error: El archivo seleccionado no es válido.');
        return;
      }

      final fileSize = await file.length();
      _log('_pickVideo', 'Video seleccionado: ${path.basename(file.path)} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');

      if (fileSize > _maxFileSize) {
        setState(() => _statusMessage = 'Video demasiado grande (Máx. 200 MB permitidos).');
        return;
      }

      setState(() {
        _isCompressing = true;
        _statusMessage = 'Preparando y comprimiendo video...';
        _selectedVideo = file;
      });

      await _compressVideo(file, fileSize);
    } catch (e, st) {
      _logError('_pickVideo', '❌ Excepción crítica al abrir el selector.', e, st);
      if (mounted) {
        setState(() {
          _isCompressing = false;
          _selectedVideo = null;
          _statusMessage = 'Error al abrir la galería: $e';
        });
      }
    }
  }

  // ─── COMPRIMIR VIDEO ────────────────────────────────────────────

  Future<void> _compressVideo(File file, int fileSize) async {
    try {
      _log('_compressVideo', 'Iniciando compresión con VideoCompress...');

      final compressed = await VideoCompress.compressVideo(
        file.path,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (!mounted) return;

      if (compressed == null || compressed.path == null) {
        throw Exception('El motor de compresión devolvió un resultado nulo.');
      }

      final compressedFile = File(compressed.path!);
      final compressedSize = await compressedFile.length();

      _log('_compressVideo', '✅ Compresión finalizada con éxito. Reducción: ${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB → ${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB');

      setState(() {
        _isCompressing = false;
        _selectedVideo = compressedFile;
        _statusMessage = 'Listo: ${path.basename(compressedFile.path)} (${(compressedSize / 1024 / 1024).toStringAsFixed(1)} MB)';
      });
    } catch (e, st) {
      _logError('_compressVideo', '⚠️ Compresión falló. Se procederá con el archivo original.', e, st);
      if (!mounted) return;

      setState(() {
        _isCompressing = false;
        _selectedVideo = file;
        _statusMessage = 'Compresión omitida. Usando video original.';
      });
    }
  }

  // ─── SUBIR VIDEO ─────────────────────────────────────────────────

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null) {
      setState(() => _statusMessage = 'Por favor selecciona un video primero.');
      return;
    }
    if (!ApiService.instance.isLoggedIn) {
      setState(() => _statusMessage = 'Sesión expirada. Debes iniciar sesión.');
      return;
    }

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _statusMessage = 'Debes ingresar un título para el video.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _statusMessage = 'Iniciando subida al servidor...';
      _isCancelled = false;
    });

    final token = ApiService.instance.pb.authStore.token;
    final userId = ApiService.instance.currentUser?.id ?? '';
    if (token.isEmpty) {
      _logError('_uploadVideo', '❌ Token de autenticación vacío.');
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _statusMessage = 'Error de autenticación. Vuelve a iniciar sesión.';
      });
      return;
    }

    final file = _selectedVideo!;
    final fileSize = await file.length();
    _log('_uploadVideo', '📤 Transmitiendo archivo: ${path.basename(file.path)} (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB)');

    _httpClient = http.Client();

    try {
      final uri = Uri.parse(
        '${ApiService.instance.baseUrl}/api/collections/$_collection/records',
      );

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';

      request.fields[_fieldTitle] = title;
      request.fields[_fieldUser] = userId;

      final mimeType = lookupMimeType(file.path) ?? 'video/mp4';
      final stream = http.ByteStream(file.openRead());
      
      final multipartFile = http.MultipartFile(
        _fieldFile,
        stream,
        fileSize,
        filename: path.basename(file.path),
        contentType: http.MediaType.parse(mimeType),
      );
      request.files.add(multipartFile);

      _log('_uploadVideo', 'POST Endpoint: $uri');
      final streamedResponse = await _httpClient!.send(request);
      
      if (_isCancelled) return;

      final response = await http.Response.fromStream(streamedResponse);

      _log('_uploadVideo', '📥 Código de respuesta HTTP: ${response.statusCode}');
      _log('_uploadVideo', '📦 Respuesta del servidor: ${response.body}');

      if (!mounted) return;

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Limpiar caché temporal de video comprimido tras subida exitosa
        await VideoCompress.deleteAllCache().catchError((_) {});

        setState(() {
          _statusMessage = '✅ ¡Video subido con éxito!';
          _selectedVideo = null;
          _titleController.clear();
          _uploadProgress = 0.0;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Video subido y publicado correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (response.statusCode == 401) {
        // Token expirado o inválido
        ApiService.instance.logout();
        throw Exception('Sesión expirada. Por favor inicia sesión nuevamente.');
      } else {
        throw Exception('Error del servidor [${response.statusCode}]: ${response.body}');
      }
    } catch (e, st) {
      if (_isCancelled) {
        _log('_uploadVideo', 'Transmisión cancelada por el usuario.');
        return;
      }
      _logError('_uploadVideo', '❌ Error fatal durante la transmisión.', e, st);
      if (!mounted) return;

      setState(() => _statusMessage = 'Error en subida: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      _httpClient?.close();
      _httpClient = null;
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // ─── CANCELAR SUBIDA ─────────────────────────────────────────────

  void _cancelUpload() {
    _log('_cancelUpload', 'Cancelación de subida solicitada por el usuario.');
    _isCancelled = true;
    _httpClient?.close();
    if (mounted) {
      setState(() {
        _isUploading = false;
        _uploadProgress = 0.0;
        _statusMessage = 'Subida cancelada por el usuario.';
      });
    }
  }

  // ─── UI ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Video'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (_isUploading)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _cancelUpload,
              tooltip: 'Cancelar subida',
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.upload_file, size: 80, color: Colors.grey),
              const SizedBox(height: 20),

              // Campo de título.
              TextField(
                controller: _titleController,
                enabled: !_isUploading && !_isCompressing,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Título del video',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Mi video destacado',
                ),
              ),
              const SizedBox(height: 20),

              // Archivo seleccionado.
              if (_selectedVideo != null && !_isCompressing)
                Text(
                  'Archivo: ${path.basename(_selectedVideo!.path)}',
                  style: const TextStyle(fontSize: 16, color: Colors.blue),
                  textAlign: TextAlign.center,
                ),

              // Mensaje de estado.
              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.contains('✅') ||
                              _statusMessage.contains('Listo')
                          ? Colors.green
                          : _statusMessage.contains('Error') ||
                                  _statusMessage.contains('cancelada')
                              ? Colors.red
                              : Colors.orange,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Barra de progreso de subida.
              if (_isUploading) ...[
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: _uploadProgress > 0 && _uploadProgress < 1
                      ? _uploadProgress
                      : null,
                  backgroundColor: Colors.grey[800],
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                ),
                const SizedBox(height: 10),
                Text(
                  _uploadProgress >= 1
                      ? 'Finalizando...'
                      : 'Subiendo... ${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],

              // Indicador de compresión.
              if (_isCompressing) ...[
                const SizedBox(height: 10),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Comprimiendo video... (puede tomar unos segundos)',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 30),

              // Botón "Seleccionar Video" — SIEMPRE RESPONSIVO.
              ElevatedButton.icon(
                onPressed:
                    (_isUploading || _isCompressing) ? null : _pickVideo,
                icon: const Icon(Icons.video_library),
                label: const Text('Seleccionar Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B2FBE),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Botón "Subir Video" — Se habilita al elegir un video.
              ElevatedButton.icon(
                onPressed: (_isUploading ||
                        _isCompressing ||
                        _selectedVideo == null)
                    ? null
                    : _uploadVideo,
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload),
                label: _isUploading
                    ? const Text('Subiendo...')
                    : const Text('Subir Video'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              const Text(
                'Formatos: MP4, MOV, AVI\nMáx: 200 MB (se comprime automáticamente)',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}