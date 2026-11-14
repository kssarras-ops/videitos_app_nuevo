// lib/main.dart
// Versión Definitiva — Auditoría Doctorado en Ingeniería Informática
// Arquitectura resiliente con observabilidad total, Firebase Analytics, UMP, AdMob, Localización y Auth.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

import 'app.dart';
import 'l10n/app_localizations.dart';
import 'providers/auth_provider.dart';
import 'services/ad_consent_service.dart';
import 'services/api_service.dart';
import 'firebase_options.dart';

// ═══════════════════════════════════════════════════════════════════════════
// PUNTO DE ENTRADA ÚNICO
// ═══════════════════════════════════════════════════════════════════════════

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint(
      '================================================================');
  debugPrint('🚀 [BOOT] Iniciando Videitos App (Entry Point Optimizado)...');
  debugPrint(
      '================================================================');

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    debugPrint('📱 [SystemChrome] Orientaciones fijadas (portrait).');
  } catch (e) {
    debugPrint('⚠️ [SystemChrome] Error fijando orientaciones: $e');
  }

  runApp(const AppBootstrap());
}

// ═══════════════════════════════════════════════════════════════════════════
// APP BOOTSTRAP — Gestor de Estado de Inicialización
// ═══════════════════════════════════════════════════════════════════════════

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _isLoading = true;
  Object? _fatalError;

  // Dependencias globales
  late AuthProvider _authProvider;
  late PackageInfo _packageInfo;
  bool _isServerConfigured = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    final stopwatch = Stopwatch()..start();
    debugPrint(
        '----------------------------------------------------------------');
    debugPrint('⚙️ [init] Iniciando secuencia de inicialización asíncrona...');

    try {
      // ─── PASO 0: FIREBASE & ANALYTICS ────────────────────────
      debugPrint('🔥 [init][0/5] Inicializando Firebase Core...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Bloqueo estricto de analítica hasta que UMP resuelva
      await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(false);
      debugPrint(
          '✅ [init][0/5] Firebase listo (Bloqueado por consentimiento). (${stopwatch.elapsedMilliseconds}ms)');

      // ─── PASO 1: FLUJO DE CONSENTIMIENTO UMP & ADMOB ─────────
      debugPrint('🛡️ [init][1/5] Iniciando flujo UMP y AdMob...');
      await Future.delayed(const Duration(milliseconds: 300));

      await AdConsentService.requestConsentAndInitialize(
        onInitializationComplete: () async {
          debugPrint(
              '✅ [init][1/5] UMP y AdMob completados. (${stopwatch.elapsedMilliseconds}ms)');
          // Desbloqueamos la recolección de Firebase. El setConsent dentro de
          // AdConsentService ya se encargó de decirle a Google qué puede recolectar.
          await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
          debugPrint('📊 [init][1/5] Firebase Analytics desbloqueado y listo.');
        },
        enableDebugInEea: false,
      );

      // ─── PASO 2: POCKETBASE API ──────────────────────────────
      debugPrint(
          '🔧 [init][2/5] Conectando con PocketBase (api.videitosapp.cl)...');
      try {
        // Timeout de 10 segundos para evitar cuelgues si el VPS está caído
        _isServerConfigured = await ApiService.instance
            .init()
            .timeout(const Duration(seconds: 10), onTimeout: () {
          debugPrint(
              '⏱️ [init][2/5] Timeout alcanzado intentando conectar a PocketBase.');
          return false;
        });
        debugPrint(
            '✅ [init][2/5] ApiService OK. Conexión: $_isServerConfigured (${stopwatch.elapsedMilliseconds}ms)');
      } catch (e) {
        debugPrint('❌ [init][2/5] Error crítico conectando a ApiService: $e');
      }

      // ─── PASO 3: AUTH PROVIDER ───────────────────────────────
      debugPrint('🔐 [init][3/5] Verificando sesión de usuario...');
      _authProvider = AuthProvider();
      try {
        // Timeout para no colgar la app si el token de sesión no responde
        await _authProvider
            .checkAuthStatus()
            .timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint('⏱️ [init][3/5] Timeout verificando sesión.');
        });
        debugPrint(
            '✅ [init][3/5] Auth OK. Autenticado: ${_authProvider.isAuthenticated} (${stopwatch.elapsedMilliseconds}ms)');
      } catch (e) {
        debugPrint('⚠️ [init][3/5] Error al verificar sesión: $e');
      }

      // ─── PASO 4: PACKAGE INFO ────────────────────────────────
      debugPrint('📦 [init][4/5] Extrayendo metadatos (PackageInfo)...');
      try {
        _packageInfo = await PackageInfo.fromPlatform();
        debugPrint(
            '✅ [init][4/5] PackageInfo: v${_packageInfo.version}+${_packageInfo.buildNumber} (${stopwatch.elapsedMilliseconds}ms)');
      } catch (e) {
        debugPrint('⚠️ [init][4/5] PackageInfo falló. Usando respaldo.');
        _packageInfo = PackageInfo(
          appName: 'Videitos App',
          packageName: 'cl.videitos.app',
          version: '22.5.5',
          buildNumber: '99999102',
        );
      }

      // ─── PASO 5: LANZAMIENTO ─────────────────────────────────
      stopwatch.stop();
      debugPrint(
          '----------------------------------------------------------------');
      debugPrint(
          '🚀 [init] ✅ Arranque completo en ${stopwatch.elapsedMilliseconds}ms. Lanzando UI...');

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (error, stackTrace) {
      stopwatch.stop();
      debugPrint('💥 [FATAL ERROR] Excepción no controlada: $error');
      debugPrint('📚 [STACKTRACE] $stackTrace');

      if (mounted) {
        setState(() {
          _fatalError = error;
          _isLoading = false;
        });
      }
    }
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _fatalError = null;
    });
    _initializeApp();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const LoadingApp();
    }

    if (_fatalError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: ErrorScreen(
          error: _fatalError!,
          onRetry: _retry,
        ),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        Provider<PackageInfo>.value(value: _packageInfo),
        Provider<bool>.value(value: _isServerConfigured),
      ],
      child: const MyApp(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA DE CARGA INICIAL (Splash)
// ═══════════════════════════════════════════════════════════════════════════

class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF7B2FBE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00D4FF).withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded,
                      size: 60, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              const Text(
                'Videitos App',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Iniciando sistemas seguros...',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PANTALLA DE ERROR CRÍTICO
// ═══════════════════════════════════════════════════════════════════════════

class ErrorScreen extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorScreen({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                    color: Colors.redAccent, shape: BoxShape.circle),
                child: const Icon(Icons.error_outline_rounded,
                    size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),
              const Text(
                'Error al iniciar la aplicación',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: const Color(0xFF1A1A2E),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(
                  error.toString(),
                  style:
                      const TextStyle(color: Colors.orangeAccent, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _reportarError(error),
                    icon: const Icon(Icons.flag_outlined),
                    label: const Text('Reportar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _reportarError(Object error) async {
    final Uri url = Uri.parse(
      'https://forms.gle/YourErrorReportFormIDHere?entry.xxxx=${Uri.encodeComponent(error.toString())}',
    );
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ [ErrorScreen] Error al abrir formulario: $e');
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL (MyApp) — UI, Tema y Rastreo Automático
// ═══════════════════════════════════════════════════════════════════════════

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🎨 [UI] Construyendo el árbol raíz de componentes (MyApp)...');

    final isServerConfigured = Provider.of<bool>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Videitos App',

      // ─── OBSERVADOR DE ANALYTICS (CRÍTICO) ───────────────────
      // Esto rastrea automáticamente cada Navigator.push() como un 'screen_view'
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      // ─────────────────────────────────────────────────────────

      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: Colors.black,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00D4FF),
          secondary: Color(0xFF7B2FBE),
          surface: Color(0xFF1A1A2E),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1A1A2E),
          selectedItemColor: Color(0xFF00D4FF),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF2A2A3E),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00D4FF),
            foregroundColor: Colors.black,
            textStyle:
                const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            minimumSize: const Size(double.infinity, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00D4FF),
              textStyle: const TextStyle(fontSize: 14)),
        ),
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: App(isServerConfigured: isServerConfigured),
    );
  }
}
