// lib/services/api_service.dart
// Versión definitiva - Corregida, optimizada y con logs detallados
// Preparada para producción, con SSL estricto, subida multimedia y manejo robusto de errores

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/io_client.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SERVICIO CENTRAL DE API — Videitos App
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Este servicio gestiona toda la comunicación con el backend de PocketBase.
///
/// Características:
///  - Singleton thread-safe con inicialización perezosa.
///  - URL base persistida en SharedPreferences.
///  - Sesión persistente con AsyncAuthStore.
///  - Cliente HTTP con timeouts configurables.
///  - Logs detallados en modo debug (no en producción).
///  - Validación estricta de SSL (sin `badCertificateCallback`).
///  - Manejo robusto de errores con códigos tipados.
///  - Recuperación de contraseña vía email.
///  - Subida optimizada de archivos multimedia (videos/imágenes).
///  - Preparado para múltiples entornos (dev, staging, prod).
///
/// Autor: Equipo de Ingeniería Videitos
/// Última actualización: 2026-10-13
/// ═══════════════════════════════════════════════════════════════════════════

class ApiService {
  // ─────────────────────────────────────────────────────────────────────────
  // SINGLETON
  // ─────────────────────────────────────────────────────────────────────────

  ApiService._internal();
  static final ApiService instance = ApiService._internal();

  // ─────────────────────────────────────────────────────────────────────────
  // ESTADO INTERNO
  // ─────────────────────────────────────────────────────────────────────────

  PocketBase? _pb;
  bool _isInitialized = false;

  /// URL por defecto del backend en producción.
  static const String _defaultBaseUrl = 'https://api.videitosapp.cl';

  /// URL efectiva actual (puede ser sobrescrita por SharedPreferences).
  String _baseUrl = _defaultBaseUrl;

  /// Clave de SharedPreferences donde se guarda la URL del servidor.
  static const String _prefKeyServerUrl = 'server_url';

  /// Clave de SharedPreferences donde se guarda la sesión de PocketBase.
  static const String _prefKeyAuth = 'pb_auth';

  /// Timeout de conexión HTTP en segundos.
  static const int _connectionTimeoutSeconds = 20;

  /// Timeout de inactividad HTTP en minutos.
  static const int _idleTimeoutMinutes = 2;

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Instancia de PocketBase. Lanza excepción si no está inicializado.
  PocketBase get pb {
    if (_pb == null) {
      _logError('pb', 'ApiService no inicializado. Llama a init() primero.');
      throw StateError('ApiService no inicializado. Llama a init() primero.');
    }
    return _pb!;
  }

  /// Indica si el servicio está listo para usarse.
  bool get isInitialized => _isInitialized;

  /// URL base actual del backend.
  String get baseUrl => _baseUrl;

  /// Indica si el usuario tiene una sesión válida.
  bool get isLoggedIn => _pb?.authStore.isValid ?? false;

  /// Usuario actual autenticado (null si no hay sesión).
  RecordModel? get currentUser => _pb?.authStore.record;

  // ─────────────────────────────────────────────────────────────────────────
  // LOGS (solo en modo debug)
  // ─────────────────────────────────────────────────────────────────────────

  void _log(String tag, String message) {
    if (kDebugMode) {
      debugPrint('🚀 [ApiService][$tag]$message');
    }
  }

  void _logSuccess(String tag, String message) {
    if (kDebugMode) {
      debugPrint('✅ [ApiService][$tag]$message');
    }
  }

  void _logWarning(String tag, String message) {
    if (kDebugMode) {
      debugPrint('⚠️  [ApiService][$tag]$message');
    }
  }

  void _logError(String tag, String message, [Object? error, StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint('❌ [ApiService][$tag]$message');
      if (error != null) debugPrint('   → error: $error');
      if (stack != null) debugPrint('   → stack: $stack');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INICIALIZACIÓN
  // ─────────────────────────────────────────────────────────────────────────

  /// Inicializa el servicio. Es idempotente.
  Future<bool> init({String? baseUrl}) async {
    _log('init', 'Iniciando ApiService...');

    if (_isInitialized && (baseUrl == null || baseUrl == _baseUrl)) {
      _log('init', 'Ya estaba inicializado con $_baseUrl. Omitiendo.');
      return true;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      _log('init', 'SharedPreferences cargado.');

      final savedUrl = prefs.getString(_prefKeyServerUrl);
      final effectiveUrl = baseUrl ?? savedUrl ?? _defaultBaseUrl;
      _baseUrl = _normalizeUrl(effectiveUrl);
      await prefs.setString(_prefKeyServerUrl, _baseUrl);
      _log('init', 'URL efectiva: $_baseUrl (guardada:$savedUrl)');

      final authStore = AsyncAuthStore(
        save: (String data) async {
          _log('authStore', 'Guardando sesión (${data.length} bytes).');
          await prefs.setString(_prefKeyAuth, data);
        },
        initial: prefs.getString(_prefKeyAuth),
        clear: () async {
          _log('authStore', 'Limpiando sesión.');
          await prefs.remove(_prefKeyAuth);
        },
      );

      _pb = PocketBase(
        _baseUrl,
        authStore: authStore,
        httpClientFactory: () => _createHttpClient(),
      );

      _isInitialized = true;
      _logSuccess('init', 'Cliente PocketBase inicializado correctamente.');

      if (_pb!.authStore.isValid) {
        _log('init', 'Sesión previa detectada. Validando con authRefresh()...');
        try {
          await _pb!.collection('users').authRefresh();
          _logSuccess('init', 'Sesión restaurada para: ${currentUser?.id}');
        } catch (e, stack) {
          _logWarning('init', 'Sesión inválida o expirada. Limpiando.');
          _logError('init', 'Detalle del fallo de sesión.', e, stack);
          _pb!.authStore.clear();
        }
      } else {
        _log('init', 'Sin sesión previa.');
      }

      return true;
    } catch (e, stack) {
      _isInitialized = false;
      _pb = null;
      _logError('init', 'Error fatal al inicializar.', e, stack);
      return false;
    }
  }

  /// Crea un nuevo `IOClient` con timeouts y configuración de seguridad.
  IOClient _createHttpClient() {
    _log('http', 'Creando IOClient (timeout: ${_connectionTimeoutSeconds}s).');
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: _connectionTimeoutSeconds)
      ..idleTimeout = const Duration(minutes: _idleTimeoutMinutes);
    return IOClient(client);
  }

  /// Normaliza una URL.
  String _normalizeUrl(String url) {
    var normalized = url.trim();
    normalized = normalized.replaceAll(RegExp(r'/+$'), '');
    if (!normalized.startsWith('http://') &&
        !normalized.startsWith('https://')) {
      normalized = 'https://$normalized';
    }
    _log('normalizeUrl', 'Entrada: "$url" → Salida: "$normalized"');
    return normalized;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CAMBIO DE SERVIDOR
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> connectToServer(String targetUrl) async {
    if (targetUrl.trim().isEmpty) {
      _logWarning('connectToServer', 'URL vacía. Cancelando.');
      return false;
    }

    try {
      final normalized = _normalizeUrl(targetUrl);
      _log('connectToServer', 'Intentando conectar a: $normalized');

      final healthCheck = await _checkServerHealth(normalized);
      if (!healthCheck) {
        _logWarning('connectToServer', 'Servidor no accesible: $normalized');
        return false;
      }

      _isInitialized = false;
      _pb = null;
      final success = await init(baseUrl: normalized);
      if (success) {
        _logSuccess('connectToServer', 'Conectado exitosamente a $normalized');
      } else {
        _logError('connectToServer', 'Fallo al inicializar con nueva URL.');
      }
      return success;
    } catch (e, stack) {
      _logError('connectToServer', 'Error inesperado.', e, stack);
      return false;
    }
  }

  Future<bool> _checkServerHealth(String url) async {
    try {
      _log('healthCheck', 'Probando $url/api/health');
      final client = _createHttpClient();
      final response = await client
          .get(Uri.parse('$url/api/health'))
          .timeout(const Duration(seconds: _connectionTimeoutSeconds));
      final isHealthy = response.statusCode == 200;
      _log('healthCheck', 'Status: ${response.statusCode} →$isHealthy');
      return isHealthy;
    } catch (e, stack) {
      _logError('healthCheck', 'Fallo al verificar $url.', e, stack);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AUTENTICACIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<RecordModel?> login(String email, String password) async {
    _log('login', 'Intentando login con email: $email');

    if (email.trim().isEmpty || password.isEmpty) {
      _logWarning('login', 'Email o contraseña vacíos.');
      return null;
    }

    try {
      final authData = await pb
          .collection('users')
          .authWithPassword(email.trim(), password);

      _logSuccess('login', 'Login exitoso. Usuario: ${authData.record.id}');
      return authData.record;
    } on ClientException catch (e) {
      _logError('login', 'ClientException (¿red o servidor?): $e', e);
      return null;
    } catch (e, stack) {
      _logError('login', 'Error inesperado durante login.', e, stack);
      return null;
    }
  }

  Future<RecordModel?> register({
    required String email,
    required String password,
    required String passwordConfirm,
    String? name,
  }) async {
    _log('register', 'Registrando usuario: $email');

    if (email.trim().isEmpty || password.isEmpty) {
      _logWarning('register', 'Datos incompletos.');
      return null;
    }

    if (password != passwordConfirm) {
      _logWarning('register', 'Las contraseñas no coinciden.');
      return null;
    }

    try {
      final body = <String, dynamic>{
        'email': email.trim(),
        'password': password,
        'passwordConfirm': passwordConfirm,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      };

      final record = await pb.collection('users').create(body: body);
      _logSuccess('register', 'Usuario creado: ${record.id}');

      final authData = await pb
          .collection('users')
          .authWithPassword(email.trim(), password);
      _logSuccess('register', 'Login automático OK para: ${authData.record.id}');
      return authData.record;
    } on ClientException catch (e) {
      _logError('register', 'ClientException: $e', e);
      return null;
    } catch (e, stack) {
      _logError('register', 'Error inesperado durante registro.', e, stack);
      return null;
    }
  }

  void logout() {
    _log('logout', 'Cerrando sesión.');
    _pb?.authStore.clear();
    _logSuccess('logout', 'Sesión cerrada.');
  }

  Future<bool> refreshSession() async {
    _log('refreshSession', 'Refrescando sesión...');
    try {
      await _pb!.collection('users').authRefresh();
      _logSuccess('refreshSession', 'Sesión refrescada.');
      return true;
    } catch (e, stack) {
      _logError('refreshSession', 'Fallo al refrescar sesión.', e, stack);
      _pb?.authStore.clear();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECUPERACIÓN DE CONTRASEÑA
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> requestPasswordReset(String email) async {
    _log('requestPasswordReset', 'Solicitando reset para: $email');

    if (email.trim().isEmpty) {
      _logWarning('requestPasswordReset', 'Email vacío.');
      return false;
    }

    try {
      await pb.collection('users').requestPasswordReset(email.trim());
      _logSuccess('requestPasswordReset', 'PocketBase aceptó la solicitud.');
      return true;
    } on ClientException catch (e) {
      _logError('requestPasswordReset', 'ClientException: $e', e);
      return false;
    } catch (e, stack) {
      _logError('requestPasswordReset', 'Error inesperado.', e, stack);
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 🎥 GESTIÓN Y SUBIDA DE VIDEOS / MULTIMEDIA (NUEVO Y OPTIMIZADO)
  // ─────────────────────────────────────────────────────────────────────────

  /// Sube un registro con archivo de video a una colección de PocketBase (ej: 'videos').
  ///
  /// [collectionName]: Nombre de la colección en PocketBase (ej. 'videos').
  /// [videoFile]: Archivo físico de video obtenido mediante image_picker o file_picker.
  /// [title]: Título descriptivo del video.
  /// [additionalFields]: Campos extra opcionales (descripción, categoría, user ID, etc.).
  Future<RecordModel?> uploadVideo({
    required String collectionName,
    required File videoFile,
    required String title,
    Map<String, dynamic>? additionalFields,
  }) async {
    _log('uploadVideo', 'Iniciando subida de video a colección "$collectionName"...');
    
    if (!isLoggedIn) {
      _logWarning('uploadVideo', 'Intento de subida sin sesión activa.');
      throw StateError('Se requiere iniciar sesión para subir contenido.');
    }

    try {
      if (!await videoFile.exists()) {
        _logError('uploadVideo', 'El archivo de video no existe en la ruta: ${videoFile.path}');
        return null;
      }

      final fileSize = await videoFile.length();
      _log('uploadVideo', 'Archivo válido. Tamaño: ${(fileSize / (1024 * 1024)).toStringAsFixed(2)} MB');

      // Preparar el cuerpo de la petición multipart con el archivo
      final body = <String, dynamic>{
        'title': title,
        if (additionalFields != null) ...additionalFields,
      };

      final files = <http.MultipartFile>[
        await http.MultipartFile.fromPath(
          'video_file', // ⚠️ Asegúrate de que este sea el nombre exacto del campo File en tu colección PocketBase
          videoFile.path,
        ),
      ];

      final record = await pb.collection(collectionName).create(
        body: body,
        files: files,
      );

      _logSuccess('uploadVideo', 'Video subido exitosamente con ID: ${record.id}');
      return record;
    } on ClientException catch (e) {
      _logError('uploadVideo', 'ClientException durante la subida: $e', e);
      return null;
    } catch (e, stack) {
      _logError('uploadVideo', 'Error inesperado al subir video.', e, stack);
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VERIFICACIÓN DE SESIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> isSessionValid() async {
    _log('isSessionValid', 'Verificando validez de la sesión...');

    if (_pb == null || !_pb!.authStore.isValid) {
      _log('isSessionValid', 'No hay sesión o es inválida.');
      return false;
    }

    try {
      await _pb!.collection('users').authRefresh();
      _logSuccess('isSessionValid', 'Sesión válida.');
      return true;
    } catch (e, stack) {
      _logError('isSessionValid', 'Fallo al refrescar sesión.', e, stack);
      _pb?.authStore.clear();
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────────────────────────────────

  String getFileUrl({
    required RecordModel record,
    required String filename,
    String? collectionId,
  }) {
    try {
      final url = pb.getFileUrl(record, filename);
      _log('getFileUrl', 'Generada URL para $filename:$url');
      return url.toString();
    } catch (e, stack) {
      _logError('getFileUrl', 'Error al generar URL de archivo.', e, stack);
      return '';
    }
  }

  Future<void> dispose() async {
    _log('dispose', 'Liberando ApiService...');
    _pb = null;
    _isInitialized = false;
    _logSuccess('dispose', 'ApiService liberado.');
  }
}