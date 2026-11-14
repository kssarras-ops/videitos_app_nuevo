// lib/app.dart
// Versión Definitiva — Auditoría Doctorado en Ingeniería Informática
// Arquitectura Reactiva con Observabilidad Avanzada y Resiliencia de Estados

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/server_config_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// APP — Videitos App Root Navigator
/// ═══════════════════════════════════════════════════════════════════════════
/// Componente raíz encargado de orquestar el flujo de navegación condicional:
/// 1. Verificación de conectividad/configuración del servidor PocketBase.
/// 2. Control de estado de autenticación reactiva del usuario.
/// ═══════════════════════════════════════════════════════════════════════════
class App extends StatelessWidget {
  /// Indica si el backend (PocketBase) está configurado con una URL válida.
  final bool isServerConfigured;

  /// Ruta inicial de compatibilidad declarativa.
  final String initialRoute;

  const App({
    super.key,
    required this.isServerConfigured,
    this.initialRoute = '/',
  });

  // ─────────────────────────────────────────────────────────────────────────
  // LOGS ESTRUCTURADOS CON FILTRADO DE ENTORNO
  // ─────────────────────────────────────────────────────────────────────────
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('🖼️ [AppNavigator] $message');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    _log('build() -> isServerConfigured: $isServerConfigured | initialRoute: $initialRoute');

    // ─── CASO 1: Servidor no configurado en el VPS Hetzner ────────────
    if (!isServerConfigured) {
      _log('⚠️ Servidor PocketBase no configurado. Redirigindo a ServerConfigScreen.');
      return const ServerConfigScreen();
    }

    // ─── CASO 2: Servidor configurado -> Escucha reactiva de AuthProvider ───
    _log('✅ Servidor configurado correctamente. Escuchando AuthProvider...');
    
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        _log('🔄 Consumer Rebuild -> isLoading: ${auth.isLoading} | isAuthenticated: ${auth.isAuthenticated} | userId: ${auth.currentUser?.id ?? "ninguno"} | error: ${auth.lastError ?? "ninguno"}');

        // ─── CASO 2a: Operación de autenticación en curso ─────────
        if (auth.isLoading) {
          _log('⏳ isLoading = true -> Mostrando pantalla de carga interna.');
          return const _LoadingScreen();
        }

        // ─── CASO 2b: Usuario autenticado exitosamente ────────────
        if (auth.isAuthenticated) {
          _log('🚀 isAuthenticated = true -> Desplegando HomeScreen (Feed principal).');
          return const HomeScreen();
        }

        // ─── CASO 2c: Usuario no autenticado / Sesión expirada ────
        _log('🔐 isAuthenticated = false -> Redirigiendo a LoginScreen.');
        return const LoginScreen();
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA DE CARGA INTERNA (_LoadingScreen)
// ═══════════════════════════════════════════════════════════════════════════
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    if (kDebugMode) {
      debugPrint('⏳ [_LoadingScreen] Renderizando indicador de progreso de sesión...');
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00D4FF), Color(0xFF7B2FBE)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withValues(alpha: 0.3),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 45,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
              strokeWidth: 3,
            ),
            const SizedBox(height: 20),
            Text(
              'Cargando VideitosApp...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 16,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}