// lib/screens/profile_screen.dart
// Versión Definitiva — Corregida, optimizada con i18n correcto y enlaces separados
// Preparada para producción: accesibilidad, multi-idioma y seguridad

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../providers/auth_provider.dart';
import '../services/pocketbase_service.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';
import 'user_videos_screen.dart';
import 'report_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PROFILE SCREEN — Videitos App
/// ═══════════════════════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final PocketBaseService _pb = PocketBaseService();
  String _appVersion = '';

  // ─── CONFIGURACIÓN DE ENLACES EXTERNOS ─────────────────────────
  // URLs reales de políticas informadas en Google Play Console
  static const String _urlTerminos = 'https://videitos.cl/terms/';
  static const String _urlPoliticas = 'https://videitos.cl/privacy-policy/';
  static const String _urlBorradoDatos = 'https://forms.gle/JmVaP7aTNJ2mbnMr6';
  static const String _urlReporteProblemas = 'https://forms.gle/JmVaP7aTNJ2mbnMr6';

  // ─── INICIALIZACIÓN ─────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _cargarVersionApp();
  }

  Future<void> _cargarVersionApp() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar versión de la app: $e');
      if (mounted) {
        setState(() {
          _appVersion = '1.0.0';
        });
      }
    }
  }

  // ─── MÉTODOS DE UTILIDAD ────────────────────────────────────────

  Map<String, dynamic>? get _currentUser => _pb.currentUser?.data;

  String get _userEmail {
    final email = _currentUser?['email'] as String?;
    return email?.isNotEmpty == true ? email! : 'Usuario';
  }

  String get _displayName {
    final name = _currentUser?['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    return _userEmail;
  }

  // ─── LOGS ────────────────────────────────────────────────────────

  void _log(String tag, String message) {
    debugPrint('👤 [ProfileScreen][$tag] $message');
  }

  void _logError(String tag, String message, [Object? error]) {
    debugPrint('❌ [ProfileScreen][$tag] $message');
    if (error != null) debugPrint('   → error: $error');
  }

  // ─── MANEJO DE ENLACES EXTERNOS ─────────────────────────────────

  Future<void> _abrirEnlaceWeb(
    String urlString,
    BuildContext context, {
    bool showError = true,
  }) async {
    final Uri url = Uri.parse(urlString);
    try {
      _log('_abrirEnlaceWeb', 'Intentando abrir: $urlString');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        _log('_abrirEnlaceWeb', '✅ Abierto: $urlString');
      } else {
        throw 'No se puede abrir el navegador.';
      }
    } catch (e) {
      _logError('_abrirEnlaceWeb', 'Fallo al abrir.', e);
      if (mounted && showError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo cargar: $urlString'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // ─── DIÁLOGO DE CONFIRMACIÓN ───────────────────────────────────

  Future<bool> _mostrarDialogoConfirmacion(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String? botonConfirmar,
    Color? colorConfirmar,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            title: Text(
              titulo,
              style: const TextStyle(color: Colors.white),
            ),
            content: Text(
              mensaje,
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(l10n.cancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorConfirmar ?? Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: Text(botonConfirmar ?? l10n.accept),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ─── CERRAR SESIÓN ─────────────────────────────────────────────

  Future<void> _cerrarSesion(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmado = await _mostrarDialogoConfirmacion(
      context,
      titulo: l10n.logout,
      mensaje: '¿Estás seguro de que deseas cerrar sesión?',
      botonConfirmar: l10n.logout,
      colorConfirmar: Colors.red,
    );

    if (!confirmado) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await _pb.logout();
      auth.logout();

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada con éxito'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      _logError('_cerrarSesion', 'Error al cerrar sesión.', e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al cerrar sesión. Intenta nuevamente.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isLoggedIn = auth.isAuthenticated;

    if (!isLoggedIn) {
      return _buildLoginRequiredScreen(context);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir perfil',
            onPressed: () => _compartirPerfil(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 24),
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildOptionsList(context),
            const SizedBox(height: 24),
            _buildVersionFooter(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─── WIDGETS ────────────────────────────────────────────────────

  Widget _buildProfileHeader() {
    final email = _userEmail;
    final displayName = _displayName;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF00D4FF).withValues(alpha: 0.1),
            const Color(0xFF7B2FBE).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xFF00D4FF),
            child: Text(
              displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          if (email != 'Usuario')
            Text(
              email,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionsList(BuildContext context) {
    return Card(
      elevation: 2,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Mis Videos
          _buildOptionTile(
            icon: Icons.video_library_outlined,
            iconColor: const Color(0xFF00D4FF),
            title: 'Mis Videos',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserVideosScreen()),
              );
            },
          ),
          _divider(),

          // Reportar un problema
          _buildOptionTile(
            icon: Icons.flag_outlined,
            iconColor: Colors.orangeAccent,
            title: 'Reportar un problema',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReportScreen()),
              );
            },
          ),
          _divider(),

          // ✅ SEPARADO: Términos y Condiciones
          _buildOptionTile(
            icon: Icons.gavel_outlined,
            iconColor: Colors.green,
            title: 'Términos y Condiciones',
            subtitle: 'Plataforma exclusiva para mayores de 18 años',
            trailing: const Icon(Icons.open_in_browser_outlined, size: 20),
            onTap: () => _abrirEnlaceWeb(_urlTerminos, context),
          ),
          _divider(),

          // ✅ SEPARADO: Política de Privacidad
          _buildOptionTile(
            icon: Icons.privacy_tip_outlined,
            iconColor: Colors.green,
            title: 'Política de Privacidad',
            trailing: const Icon(Icons.open_in_browser_outlined, size: 20),
            onTap: () => _abrirEnlaceWeb(_urlPoliticas, context),
          ),
          _divider(),

          // Eliminar cuenta
          _buildOptionTile(
            icon: Icons.delete_forever_outlined,
            iconColor: Colors.grey,
            title: 'Eliminar cuenta y datos asociados',
            trailing: const Icon(
              Icons.open_in_browser_outlined,
              size: 20,
              color: Colors.grey,
            ),
            onTap: () => _abrirEnlaceWeb(_urlBorradoDatos, context),
          ),
          _divider(),

          // Centro de ayuda
          _buildOptionTile(
            icon: Icons.help_outline,
            iconColor: Colors.purple,
            title: 'Centro de ayuda',
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _abrirEnlaceWeb(_urlReporteProblemas, context),
          ),
          _divider(),

          // Cerrar sesión
          _buildOptionTile(
            icon: Icons.logout,
            iconColor: Colors.red,
            title: 'Cerrar sesión',
            titleStyle: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
            onTap: () => _cerrarSesion(context),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    TextStyle? titleStyle,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 24),
      title: Text(
        title,
        style: titleStyle ?? const TextStyle(color: Colors.white),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            )
          : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      minLeadingWidth: 32,
    );
  }

  Widget _divider() {
    return const Divider(
      height: 1,
      thickness: 0.5,
      indent: 16,
      endIndent: 16,
      color: Colors.white12,
    );
  }

  Widget _buildVersionFooter() {
    return Center(
      child: Text(
        'Versión $_appVersion',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
    );
  }

  Widget _buildLoginRequiredScreen(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 80, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'Inicia sesión para ver tu perfil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Accede a tu cuenta para gestionar tus videos y preferencias',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Icons.login),
                label: const Text('Iniciar sesión'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── COMPARTIR PERFIL ──────────────────────────────────────────

  Future<void> _compartirPerfil() async {
    try {
      final email = _userEmail;
      final mensaje = '📱 Videitos App\n👤 Usuario: $email\n\n'
          '¡Mira mis videos en Videitos! '
          'Descarga la app: https://videitos.cl';

      await Share.share(
        mensaje,
        subject: 'Mi perfil en Videitos',
      );
    } catch (e) {
      _logError('_compartirPerfil', 'Error al compartir.', e);
    }
  }
}
