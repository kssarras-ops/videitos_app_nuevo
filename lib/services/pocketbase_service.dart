// lib/services/pocketbase_service.dart
// Versión Definitiva - Con colección `videitos` (nombre real)
// Wrapper unificado que delega en ApiService

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../models/video.dart';
import 'api_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EXCEPCIÓN
// ═══════════════════════════════════════════════════════════════════════════

class PocketBaseException implements Exception {
  final int? statusCode;
  final String message;
  final Map<String, dynamic>? details;

  PocketBaseException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

// ═══════════════════════════════════════════════════════════════════════════
// SERVICIO
// ═══════════════════════════════════════════════════════════════════════════

class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  // ─── CONSTANTES ──────────────────────────────────────────────────

  /// Nombre de la colección en PocketBase.
  static const String _collection = 'videitos';

  /// Campos de la colección (ajusta si son diferentes).
  static const String _fieldTitle = 'titulo';
  static const String _fieldUser = 'creador';
  static const String _fieldFile = 'archivo_video';
  static const String _fieldThumbnail = 'thumbnail';
  static const String _fieldSize = 'size';

  // ─── GETTERS ─────────────────────────────────────────────────────

  PocketBase get pb => ApiService.instance.pb;
  RecordModel? get currentUser => ApiService.instance.currentUser;
  String? get currentUserId => ApiService.instance.currentUser?.id;
  bool get isAuthenticated => ApiService.instance.isLoggedIn;

  // ─── LOGS ────────────────────────────────────────────────────────

  void _log(String tag, String message) {
    debugPrint('📡 [PocketBaseService][$tag] $message');
  }

  void _logError(String tag, String message, [Object? error, StackTrace? st]) {
    debugPrint('❌ [PocketBaseService][$tag] $message');
    if (error != null) debugPrint('   → error: $error');
    if (st != null) debugPrint('   → stack: $st');
  }

  // ─── PARSEO DE ERRORES ──────────────────────────────────────────

  PocketBaseException _handleClientError(
      ClientException e, String contextMessage) {
    int statusCode = e.statusCode;
    String finalMessage = contextMessage;
    Map<String, dynamic>? details;

    try {
      if (e.response is Map) {
        final resMap = e.response as Map<String, dynamic>;
        statusCode = resMap['status'] ?? resMap['code'] ?? statusCode;
        finalMessage = resMap['message'] ?? finalMessage;
        if (resMap['data'] is Map<String, dynamic>) {
          details = resMap['data'] as Map<String, dynamic>;
        }
      } else if (e.response is String && (e.response as String).isNotEmpty) {
        final decoded = json.decode(e.response as String);
        if (decoded is Map<String, dynamic>) {
          statusCode = decoded['status'] ?? decoded['code'] ?? statusCode;
          finalMessage = decoded['message'] ?? finalMessage;
          if (decoded['data'] is Map<String, dynamic>) {
            details = decoded['data'] as Map<String, dynamic>;
          }
        }
      }
    } catch (parseError) {
      _logError('_handleClientError', 'Fallo al decodificar.', parseError);
    }

    if (details != null && details.isNotEmpty) {
      final buffer = StringBuffer('$finalMessage: ');
      details.forEach((key, value) {
        if (value is Map && value.containsKey('message')) {
          buffer.write('\n• $key: ${value['message']}');
        } else {
          buffer.write('\n• $key: $value');
        }
      });
      return PocketBaseException(buffer.toString(),
          statusCode: statusCode, details: details);
    }

    return PocketBaseException('$finalMessage ($statusCode)',
        statusCode: statusCode, details: details);
  }

  // ─── AUTENTICACIÓN ──────────────────────────────────────────────

  Future<RecordModel> login(String email, String password) async {
    _log('login', 'Intentando login: $email');
    try {
      final result = await pb
          .collection('users')
          .authWithPassword(email, password)
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException(
                'Tiempo de espera agotado al conectar al servidor.'),
          );

      if (result.record == null) {
        throw PocketBaseException('No se recibió información del usuario.');
      }
      _log('login', '✅ Login OK. Usuario: ${result.record.id}');
      return result.record;
    } on ClientException catch (e) {
      throw _handleClientError(e, 'Login fallido');
    } on TimeoutException catch (e) {
      throw PocketBaseException(e.message ?? 'Timeout en login.');
    } catch (e, st) {
      _logError('login', 'Error inesperado.', e, st);
      throw PocketBaseException('Error inesperado al iniciar sesión: $e');
    }
  }

  Future<RecordModel> register(String email, String password) async {
    _log('register', 'Registrando: $email');
    try {
      final body = <String, dynamic>{
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'emailVisibility': true,
      };

      final record = await pb.collection('users').create(body: body).timeout(
            const Duration(seconds: 8),
            onTimeout: () => throw TimeoutException('Timeout al crear la cuenta.'),
          );

      _log('register', '✅ Usuario creado: ${record.id}');

      try {
        await login(email, password);
      } catch (loginError) {
        _logError('register', 'Falló el login automático.', loginError);
        throw PocketBaseException(
            'Cuenta creada con éxito, pero debes iniciar sesión manualmente.');
      }

      return record;
    } on ClientException catch (e) {
      throw _handleClientError(e, 'Registro fallido');
    } on TimeoutException catch (e) {
      throw PocketBaseException(e.message ?? 'Timeout en registro.');
    } catch (e, st) {
      if (e is PocketBaseException) rethrow;
      _logError('register', 'Error inesperado.', e, st);
      throw PocketBaseException('Error inesperado al registrarse: $e');
    }
  }

  void logout() {
    _log('logout', 'Cerrando sesión.');
    try {
      ApiService.instance.logout();
    } catch (e) {
      _logError('logout', 'Error al cerrar sesión.', e);
    }
  }

  Future<void> refreshAuth() async {
    if (!isAuthenticated) return;
    _log('refreshAuth', 'Refrescando token...');
    try {
      await pb
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      _logError('refreshAuth', 'Fallo al refrescar. Cerrando sesión.', e);
      logout();
    }
  }

  Future<void> ensureAuthenticated() async {
    if (!isAuthenticated) {
      throw PocketBaseException('Usuario no autenticado.');
    }
    try {
      await pb
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 5));
    } catch (e, st) {
      _logError('ensureAuthenticated', 'Sesión inválida.', e, st);
      throw PocketBaseException(
          'Sesión expirada. Por favor, inicia sesión de nuevo.');
    }
  }

  // ─── VIDEOS: LECTURA ────────────────────────────────────────────

  Future<List<Video>> getVideosSafe() async {
    try {
      return await getVideosFromPocketBase();
    } catch (e) {
      _logError('getVideosSafe', 'Devolviendo lista vacía.', e);
      return [];
    }
  }

  /// Carga los videos de la colección `videitos`.
  /// Usa los campos `titulo`, `creador`, `archivo_video`.
  Future<List<Video>> getVideosFromPocketBase() async {
    _log('getVideos', 'Cargando catálogo desde $_collection...');
    try {
      final result = await pb
          .collection(_collection)
          .getList(
            sort: '-created',
            expand: _fieldUser,
          )
          .timeout(const Duration(seconds: 10));

      _log('getVideos', 'Recibidos ${result.items.length} videos.');

      final List<Future<Video>> videoFutures = result.items.map((record) async {
        final video = _recordToVideo(record);
        final stats = await getVideoStats(video.id);

        video.likesCount = stats['likesCount'] ?? 0;
        video.isLiked = stats['isLiked'] ?? false;
        video.commentsCount = stats['commentsCount'] ?? 0;

        return video;
      }).toList();

      return await Future.wait(videoFutures);
    } on ClientException catch (e) {
      throw _handleClientError(e, 'Error al cargar videos');
    } catch (e, st) {
      _logError('getVideos', 'Error inesperado.', e, st);
      throw PocketBaseException('Error al cargar videos: $e');
    }
  }

  Video _recordToVideo(RecordModel record) {
    final String videoFile = record.getStringValue(_fieldFile);
    final String videoUrl =
        videoFile.isNotEmpty ? pb.files.getUrl(record, videoFile).toString() : '';

    final String thumbnailFile = record.getStringValue(_fieldThumbnail);
    final String? thumbnailUrl = thumbnailFile.isNotEmpty
        ? pb.files.getUrl(record, thumbnailFile).toString()
        : null;

    return Video(
      id: record.id,
      name: record.getStringValue(_fieldTitle).isNotEmpty
          ? record.getStringValue(_fieldTitle)
          : 'Sin título',
      url: videoUrl,
      size: record.getIntValue(_fieldSize, 0),
      createdAt: DateTime.tryParse(record.created) ?? DateTime.now(),
      thumbnailUrl: thumbnailUrl,
    );
  }

  // ─── VIDEOS: ESCRITURA ──────────────────────────────────────────

  /// Sube un video a la colección `videitos`.
  Future<RecordModel> uploadVideo(String title, String videoPath) async {
    _log('uploadVideo', 'Subiendo: $title');
    final String? userId = currentUserId;
    if (userId == null) {
      throw PocketBaseException('Usuario no autenticado.');
    }

    const int maxRetries = 2;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        _log('uploadVideo', 'Intento ${attempt + 1}/${maxRetries + 1}');

        // ✅ Usa los nombres reales: colección `videitos`, campos `titulo`, `creador`, `archivo_video`.
        final record = await pb.collection(_collection).create(
          body: {
            _fieldTitle: title,
            _fieldUser: userId,
          },
          files: [
            await http.MultipartFile.fromPath(_fieldFile, videoPath),
          ],
        ).timeout(const Duration(minutes: 5));

        _log('uploadVideo', '✅ Subida OK: ${record.id}');
        return record;
      } on ClientException catch (e) {
        if (e.statusCode >= 500 && attempt < maxRetries) {
          _logError('uploadVideo',
              'Servidor inestable (${e.statusCode}). Reintentando...', e);
          await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
          continue;
        }
        throw _handleClientError(e, 'Error en la subida del video');
      } on SocketException catch (e) {
        if (attempt < maxRetries) {
          _logError('uploadVideo', 'Error de red. Reintentando...', e);
          await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
          continue;
        }
        throw PocketBaseException('Error de conexión: $e');
      } catch (e, st) {
        if (attempt < maxRetries) {
          _logError('uploadVideo', 'Error inesperado. Reintentando...', e, st);
          continue;
        }
        _logError('uploadVideo', 'Fallo crítico.', e, st);
        throw PocketBaseException('Fallo inesperado en subida: $e');
      }
    }
    throw PocketBaseException('Subida abortada tras agotar reintentos.');
  }

  Future<void> deleteVideo(String videoId) async {
    _log('deleteVideo', 'Eliminando: $videoId');
    try {
      await pb
          .collection(_collection)
          .delete(videoId)
          .timeout(const Duration(seconds: 8));
      _log('deleteVideo', '✅ Eliminado.');
    } on ClientException catch (e) {
      throw _handleClientError(e, 'Error al eliminar video');
    }
  }

  // ─── MÉTRICAS ───────────────────────────────────────────────────

  Future<Map<String, dynamic>> getVideoStats(String videoId) async {
    final String? userId = currentUserId;

    try {
      final results = await Future.wait([
        pb.collection('likes').getList(filter: 'video = "$videoId"', perPage: 0),
        userId != null
            ? pb.collection('likes').getList(
                filter: 'video = "$videoId" && user = "$userId"', perPage: 1)
            : Future.value(null),
        pb
            .collection('comments')
            .getList(filter: 'video = "$videoId"', perPage: 0),
      ]).timeout(const Duration(seconds: 8));

      final likesResult = results[0] as ResultList<RecordModel>;
      final userLikeResult = results[1] as ResultList<RecordModel>?;
      final commentsResult = results[2] as ResultList<RecordModel>;

      return {
        'likesCount': likesResult.totalItems,
        'isLiked': userLikeResult != null && userLikeResult.items.isNotEmpty,
        'commentsCount': commentsResult.totalItems,
      };
    } catch (e, st) {
      _logError('getVideoStats', 'Error al obtener stats.', e, st);
      return {'likesCount': 0, 'isLiked': false, 'commentsCount': 0};
    }
  }

  Future<Map<String, dynamic>> toggleLike(String videoId) async {
    final String? userId = currentUserId;
    if (userId == null) {
      throw PocketBaseException('Usuario no autenticado.');
    }

    try {
      final existing = await pb
          .collection('likes')
          .getList(filter: 'video = "$videoId" && user = "$userId"', perPage: 1)
          .timeout(const Duration(seconds: 8));

      if (existing.items.isNotEmpty) {
        await pb
            .collection('likes')
            .delete(existing.items.first.id)
            .timeout(const Duration(seconds: 8));
      } else {
        await pb.collection('likes').create(body: {
          'user': userId,
          'video': videoId,
        }).timeout(const Duration(seconds: 8));
      }

      final countResult = await pb
          .collection('likes')
          .getList(filter: 'video = "$videoId"', perPage: 0)
          .timeout(const Duration(seconds: 8));

      return {
        'liked': existing.items.isEmpty,
        'likesCount': countResult.totalItems,
      };
    } catch (e, st) {
      if (e is ClientException) {
        throw _handleClientError(e, 'Error al procesar el like');
      }
      _logError('toggleLike', 'Error inesperado.', e, st);
      throw PocketBaseException('Error al procesar el like: $e');
    }
  }

  // ─── COMENTARIOS ────────────────────────────────────────────────

  Future<List<RecordModel>> getComments(String videoId) async {
    try {
      final result = await pb
          .collection('comments')
          .getList(
            filter: 'video = "$videoId"',
            sort: '-created',
            expand: 'user',
          )
          .timeout(const Duration(seconds: 8));
      return result.items;
    } catch (e, st) {
      if (e is ClientException) {
        throw _handleClientError(e, 'Error al cargar comentarios');
      }
      _logError('getComments', 'Error inesperado.', e, st);
      throw PocketBaseException('Error al cargar comentarios: $e');
    }
  }

  Future<RecordModel> addComment(String videoId, String text) async {
    final String? userId = currentUserId;
    if (userId == null) {
      throw PocketBaseException('Usuario no autenticado.');
    }

    try {
      return await pb.collection('comments').create(body: {
        'user': userId,
        'video': videoId,
        'text': text,
      }).timeout(const Duration(seconds: 8));
    } catch (e, st) {
      if (e is ClientException) {
        throw _handleClientError(e, 'Error al publicar comentario');
      }
      _logError('addComment', 'Error inesperado.', e, st);
      throw PocketBaseException('Error al publicar comentario: $e');
    }
  }
}