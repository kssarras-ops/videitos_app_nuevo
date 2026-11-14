import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:pocketbase/pocketbase.dart';
import 'api_service.dart';

/// 🛡️ Servicio de Autenticación mejorado para VideitosApp.
class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  PocketBase get pb => ApiService.instance.pb;

  /// Retorna si el token existe y es válido.
  bool get isLoggedIn => pb.authStore.isValid;

  String? get currentUserId => pb.authStore.record?.id;
  RecordModel? get currentUser => pb.authStore.record;

  /// 📝 Registro con control de errores mejorado.
  Future<void> register(String email, String password) async {
    try {
      await pb.collection('users').create(body: {
        'email': email,
        'password': password,
        'passwordConfirm': password,
        'emailVisibility': true,
      }).timeout(const Duration(
          seconds: 15)); // Aumentado ligeramente para evitar falsos timeouts

      await login(email, password);
    } on ClientException catch (e) {
      debugPrint('❌ Error de PocketBase en registro: ${e.response}');
      rethrow;
    } catch (e) {
      debugPrint('💥 Error inesperado en registro: $e');
      rethrow;
    }
  }

  /// 🔑 Login optimizado.
  Future<RecordAuth> login(String email, String password) async {
    try {
      return await pb
          .collection('users')
          .authWithPassword(email, password)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('❌ Error de Login: $e');
      // No llamamos a logout aquí automáticamente, dejamos que el UI maneje el error
      rethrow;
    }
  }

  /// 🧹 Cierre de sesión seguro.
  void logout() {
    pb.authStore.clear();
  }

  /// 🔄 Refresca el token solo si es necesario.
  Future<bool> refreshAuth() async {
    // Si no hay token guardado, no hay nada que refrescar
    if (!pb.authStore.isValid) return false;

    try {
      await pb
          .collection('users')
          .authRefresh()
          .timeout(const Duration(seconds: 10));
      return true;
    } catch (e) {
      debugPrint('🔁 Error al refrescar token: $e');
      // Solo limpiamos si el error indica que el token realmente ya no es aceptado por el server
      if (e is ClientException &&
          (e.statusCode == 401 || e.statusCode == 400)) {
        logout();
      }
      return false;
    }
  }
}
