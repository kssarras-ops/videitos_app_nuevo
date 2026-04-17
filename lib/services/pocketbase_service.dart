import 'package:pocketbase/pocketbase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video.dart';

/// Servicio singleton para manejar la autenticación y datos con PocketBase.
class PocketBaseService {
  static final PocketBaseService _instance = PocketBaseService._internal();
  factory PocketBaseService() => _instance;
  PocketBaseService._internal();

  late final PocketBase pb;

  /// Inicializa el cliente de PocketBase con almacenamiento de sesión persistente.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    final store = AsyncAuthStore(
      save: (String data) async => prefs.setString('pb_auth', data),
      initial: prefs.getString('pb_auth'),
    );

    pb = PocketBase(
      'http://190.107.177.199:8090', // Cambia por tu URL si es necesario
      authStore: store,
    );
  }

  /// Inicia sesión con email y contraseña.
  /// Retorna el registro del usuario si éxito, o lanza una excepción con mensaje claro.
  Future<RecordModel> login(String email, String password) async {
    try {
      final result =
          await pb.collection('users').authWithPassword(email, password);
      if (result.record == null) {
        throw Exception('Credenciales inválidas');
      }
      return result.record!;
    } on ClientException catch (e) {
      // Extraer mensaje de error de la respuesta de PocketBase
      final message = e.response?['message'] ?? 'Error de autenticación';
      throw Exception(message);
    }
  }

  /// Registra un nuevo usuario con email y contraseña.
  /// Retorna el registro del usuario si éxito, o lanza una excepción con mensaje claro.
  Future<RecordModel> register(String email, String password) async {
    try {
      final record = await pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'emailVisibility': true,
      });
      // Iniciar sesión automáticamente después del registro
      await login(email, password);
      return record;
    } on ClientException catch (e) {
      final message = e.response?['message'] ?? 'Error de registro';
      throw Exception(message);
    }
  }

  /// Cierra la sesión actual.
  void logout() {
    pb.authStore.clear();
  }

  /// Indica si hay un usuario autenticado.
  bool get isAuthenticated => pb.authStore.isValid;

  /// Obtiene el usuario actual (si existe).
  RecordModel? get currentUser => pb.authStore.record;

  /// Obtiene la lista de videos desde la colección 'videos' de PocketBase.
  /// Retorna una lista de objetos [Video].
  Future<List<Video>> getVideosFromPocketBase() async {
    try {
      final result = await pb.collection('videos').getList(
            sort: '-created',
          );
      return result.items.map((record) {
        // Construir URL del archivo de video
        final videoFile = record.data['video'];
        final videoUrl = videoFile != null
            ? pb.getFileUrl(record, videoFile).toString()
            : '';

        // Construir URL del thumbnail si existe
        final thumbnailFile = record.data['thumbnail'];
        final thumbnailUrl = thumbnailFile != null
            ? pb.getFileUrl(record, thumbnailFile).toString()
            : null;

        return Video(
          id: record.id,
          name: record.data['name'] ?? 'Sin título',
          url: videoUrl,
          size: record.data['size_bytes'] ?? 0,
          createdAt: DateTime.parse(record.data['created']),
          thumbnailUrl: thumbnailUrl,
        );
      }).toList();
    } on ClientException catch (e) {
      final message = e.response?['message'] ?? 'Error al obtener videos';
      throw Exception(message);
    }
  }
}
