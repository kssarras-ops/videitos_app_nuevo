import 'package:pocketbase/pocketbase.dart';

class AuthService {
  final PocketBase pb;

  AuthService(this.pb);

  /// Registra un nuevo usuario
  /// Captura errores específicos de PocketBase para dar feedback real
  Future<RecordModel> register(String email, String password) async {
    try {
      return await pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'emailVisibility': true,
      });
    } on ClientException catch (e) {
      // Extrae el mensaje de error detallado del servidor
      final errorData = e.response['data'];
      String detail = '';
      if (errorData != null && errorData.isNotEmpty) {
        detail = ": ${errorData.toString()}";
      }
      throw Exception(
          'Registro fallido${detail.isNotEmpty ? detail : ": " + e.response['message']}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// Inicia sesión y devuelve el resultado de autenticación
  Future<RecordAuth> login(String email, String password) async {
    try {
      return await pb.collection('users').authWithPassword(email, password);
    } on ClientException catch (e) {
      throw Exception('Login fallido: ${e.response['message']}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// Cierra la sesión actual borrando el AuthStore
  void logout() {
    pb.authStore.clear();
  }

  /// Verifica si el token actual es válido
  bool get isLoggedIn => pb.authStore.isValid;

  /// Devuelve el ID del usuario actual
  String? get currentUserId => pb.authStore.model?.id;

  /// Devuelve el modelo completo del usuario (email, nombre, etc.)
  RecordModel? get currentUser => pb.authStore.model is RecordModel
      ? pb.authStore.model as RecordModel
      : null;

  /// Refresca la sesión (mantiene al usuario logueado por más tiempo)
  Future<void> refreshAuth() async {
    if (isLoggedIn) {
      try {
        await pb.collection('users').authRefresh();
      } catch (_) {
        logout(); // Si el refresh falla, cerramos sesión por seguridad
      }
    }
  }
}
