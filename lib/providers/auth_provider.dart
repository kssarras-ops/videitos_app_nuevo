// lib/providers/auth_provider.dart
// Versión definitiva - Corregida, optimizada y con logs detallados
// Preparada para producción y extensible al futuro (OAuth Google/Apple)

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // Para capturar errores de plataforma
import 'package:flutter_custom_tabs/flutter_custom_tabs.dart'; // Para OAuth
import 'package:pocketbase/pocketbase.dart';

import '../services/api_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// AUTH PROVIDER — Videitos App
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Proveedor reactivo de autenticación, basado en `ChangeNotifier` + `provider`.
///
/// Características:
///  - Escucha cambios del `AuthStore` de PocketBase y notifica a los widgets.
///  - Manejo de estado de carga tipado (`isLoading`).
///  - Login, registro, logout y recuperación de contraseña.
///  - Inicio de sesión con Google (OAuth2 vía flutter_custom_tabs).
///  - Verificación de sesión al iniciar la app (authRefresh).
///  - Manejo robusto de errores (credenciales, red, servidor, OAuth).
///  - Cancelación limpia de subscripciones en `dispose()`.
///
/// Autor: Equipo de Ingeniería Videitos
/// Última actualización: 2026-11-14
/// ═══════════════════════════════════════════════════════════════════════════

class AuthProvider with ChangeNotifier {
  // ─────────────────────────────────────────────────────────────────────────
  // ESTADO INTERNO
  // ─────────────────────────────────────────────────────────────────────────

  bool _isLoading = false;
  String? _lastError;
  StreamSubscription<AuthStoreEvent>? _authSubscription;

  // ─────────────────────────────────────────────────────────────────────────
  // CONSTRUCTOR
  // ─────────────────────────────────────────────────────────────────────────

  AuthProvider() {
    _log('constructor', 'Inicializando AuthProvider...');
    _initAuthListener();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GETTERS PÚBLICOS
  // ─────────────────────────────────────────────────────────────────────────

  bool get isLoading => _isLoading;
  bool get isAuthenticated => ApiService.instance.isLoggedIn;
  RecordModel? get currentUser => ApiService.instance.currentUser;
  String? get lastError => _lastError;
  bool get isServerConfigured => ApiService.instance.isInitialized;

  // ─────────────────────────────────────────────────────────────────────────
  // LOGS (solo en modo debug)
  // ─────────────────────────────────────────────────────────────────────────

  void _log(String tag, String message) {
    if (kDebugMode) debugPrint('🔐 [AuthProvider][$tag] $message');
  }

  void _logSuccess(String tag, String message) {
    if (kDebugMode) debugPrint('✅ [AuthProvider][$tag] $message');
  }

  void _logWarning(String tag, String message) {
    if (kDebugMode) debugPrint('⚠️  [AuthProvider][$tag] $message');
  }

  void _logError(String tag, String message, [Object? error, StackTrace? st]) {
    if (kDebugMode) {
      debugPrint('❌ [AuthProvider][$tag] $message');
      if (error != null) debugPrint('   → error: $error');
      if (st != null) debugPrint('   → stack: $st');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LISTENER DEL AUTH STORE
  // ─────────────────────────────────────────────────────────────────────────

  void _initAuthListener() {
    try {
      if (!ApiService.instance.isInitialized) {
        _logWarning('_initAuthListener',
            'ApiService no inicializado. Se registrará luego.');
        return;
      }

      _authSubscription =
          ApiService.instance.pb.authStore.onChange.listen((event) {
        final bool isAuth = event.token.isNotEmpty;
        _log('authStore', 'Cambio de estado. Autenticado: $isAuth');
        notifyListeners();
      });

      _logSuccess('_initAuthListener', 'Listener del AuthStore activo.');
    } catch (e, st) {
      _logError('_initAuthListener', 'Fallo al registrar listener.', e, st);
    }
  }

  void attachAuthListener() {
    if (_authSubscription != null) {
      _log('attachAuthListener', 'El listener ya estaba activo.');
      return;
    }
    _initAuthListener();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACCIONES DE AUTENTICACIÓN (Email/Password)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> login(String email, String password) async {
    if (_isLoading) {
      _logWarning('login', 'Operación en curso. Ignorando.');
      return;
    }
    _setLoading(true);
    _clearError();

    try {
      _log('login', 'Intentando login con: $email');
      await ApiService.instance.login(email, password);
      _logSuccess('login', 'Login exitoso para $email.');
    } on ClientException catch (e) {
      final msg = 'Credenciales inválidas o servidor inaccesible.';
      _lastError = msg;
      _logError('login', '$msg → $e', e);
      rethrow;
    } catch (e, st) {
      final msg = 'Error inesperado durante login.';
      _lastError = msg;
      _logError('login', msg, e, st);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String email, String password,
      {String? username}) async {
    if (_isLoading) {
      _logWarning('register', 'Operación en curso. Ignorando.');
      return;
    }
    _setLoading(true);
    _clearError();

    try {
      final effectiveUsername = (username == null || username.trim().isEmpty)
          ? email.split('@').first
          : username.trim();

      _log('register', 'Registrando: $email (username: $effectiveUsername)');
      await ApiService.instance.register(
        email: email,
        password: password,
        passwordConfirm: password,
        name: effectiveUsername,
      );
      _logSuccess('register', 'Usuario registrado y logueado automáticamente.');
    } on ClientException catch (e) {
      final msg = 'El correo ya está en uso o los datos son inválidos.';
      _lastError = msg;
      _logError('register', '$msg → $e', e);
      rethrow;
    } catch (e, st) {
      final msg = 'Error inesperado durante el registro.';
      _lastError = msg;
      _logError('register', msg, e, st);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void logout() {
    _log('logout', 'Cerrando sesión.');
    ApiService.instance.logout();
    _clearError();
    _logSuccess('logout', 'Sesión cerrada.');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OAUTH2: LOGIN CON GOOGLE (Y PREPARACIÓN PARA APPLE)
  // ─────────────────────────────────────────────────────────────────────────

  /// Inicia sesión con Google OAuth2 usando el flujo All-in-one de PocketBase.
  Future<void> loginWithGoogle() async {
    if (_isLoading) {
      _logWarning('loginWithGoogle', 'Operación en curso. Ignorando.');
      return;
    }
    _setLoading(true);
    _clearError();

    try {
      _log('loginWithGoogle', 'Iniciando flujo OAuth2...');

      // [LOG] PocketBase maneja internamente el intercambio de tokens y la
      // actualización del AuthStore. Solo necesitamos abrir la URL.
      await ApiService.instance.pb.collection('users').authWithOAuth2(
        'google',
        (url) async {
          _log('loginWithGoogle',
              'Abriendo URL de autorización en Custom Tab...');

          // [LOG] Abre la pestaña segura (Custom Tabs en Android / Safari en iOS)
          await launchUrl(
            Uri.parse(url),
            customTabsOptions: CustomTabsOptions(
              colorSchemes: CustomTabsColorSchemes.defaults(
                toolbarColor: const Color(0xFF1A1A2E),
              ),
              shareState: CustomTabsShareState.on,
              urlBarHidingEnabled: true,
              showTitle: true,
            ),
            safariVCOptions: const SafariViewControllerOptions(
              preferredBarTintColor: Color(0xFF1A1A2E),
              preferredControlTintColor: Colors.white,
              barCollapsingEnabled: true,
            ),
          );
        },
      );

      _logSuccess('loginWithGoogle', 'Login con Google exitoso.');
    } catch (e, st) {
      // [LOG] Captura errores de plataforma (ej. si el usuario cancela o cierra la pestaña)
      final msg = 'Error al iniciar sesión con Google. Intenta de nuevo.';
      _lastError = msg;
      _logError('loginWithGoogle', msg, e, st);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECUPERACIÓN DE CONTRASEÑA
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> requestPasswordReset(String email) async {
    if (_isLoading) {
      _logWarning('requestPasswordReset', 'Operación en curso. Ignorando.');
      return false;
    }
    _setLoading(true);
    _clearError();

    try {
      _log('requestPasswordReset', 'Solicitando reset para: $email');
      final ok = await ApiService.instance.requestPasswordReset(email);

      if (ok) {
        _logSuccess('requestPasswordReset', 'Email de recuperación enviado.');
      } else {
        _logWarning('requestPasswordReset', 'PocketBase rechazó la solicitud.');
      }
      return ok;
    } catch (e, st) {
      final msg = 'Error al enviar el email de recuperación.';
      _lastError = msg;
      _logError('requestPasswordReset', msg, e, st);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VERIFICACIÓN DE SESIÓN
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> checkAuthStatus() async {
    if (!ApiService.instance.isLoggedIn) {
      _log('checkAuthStatus', 'No hay sesión guardada. Nada que verificar.');
      return;
    }

    _setLoading(true);
    try {
      _log('checkAuthStatus', 'Verificando sesión en el servidor...');
      final valid = await ApiService.instance.isSessionValid();
      if (!valid) {
        _logWarning('checkAuthStatus', 'Sesión inválida. Cerrando.');
        ApiService.instance.logout();
        _clearError();
      } else {
        _logSuccess(
            'checkAuthStatus', 'Sesión válida para ${currentUser?.id}.');
      }
    } catch (e, st) {
      _logError('checkAuthStatus', 'Error al verificar sesión.', e, st);
      ApiService.instance.logout();
      _clearError();
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILIDADES
  // ─────────────────────────────────────────────────────────────────────────

  void _setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void clearError() => _clearError();

  // ─────────────────────────────────────────────────────────────────────────
  // DISPOSE
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _log('dispose', 'Liberando AuthProvider...');
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
    _logSuccess('dispose', 'AuthProvider liberado.');
  }
}
