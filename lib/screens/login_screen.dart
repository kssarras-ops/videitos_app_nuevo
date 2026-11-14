// lib/screens/login_screen.dart
// Versión Definitiva — Con i18n, OAuth (Google/Apple), recuperación de contraseña y logs detallados
// Preparada para producción: accesibilidad, seguridad y multi-idioma

import 'dart:io'
    show Platform; // [LOG] Para detectar iOS y mostrar botón de Apple
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/auth_provider.dart';
import '../l10n/app_localizations.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// LOGIN SCREEN — Videitos App
/// ═══════════════════════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _rememberMe = true;
  String? _errorMessage;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _log('initState', 'Inicializando LoginScreen...');

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _log('dispose', 'Liberando LoginScreen...');
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _log(String tag, String message) {
    debugPrint('🔐 [LoginScreen][$tag] $message');
  }

  bool get _isLoading => context.select((AuthProvider p) => p.isLoading);
  AuthProvider get _auth => context.read<AuthProvider>();

  void _toggleMode() {
    if (_isLoading) return;
    _log('toggleMode', 'Cambiando a ${_isLogin ? "registro" : "login"}');
    setState(() {
      _isLogin = !_isLogin;
      _passwordController.clear();
      _confirmPasswordController.clear();
      _errorMessage = null;
    });
    _animationController.forward(from: 0.0);
  }

  // ─── VALIDACIÓN ────────────────────────────────────────────────

  String? _validateEmail(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) return l10n.emailRequired;
    final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return l10n.invalidEmail;
    return null;
  }

  String? _validatePassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.passwordRequired;
    if (!_isLogin && value.length < 6) return l10n.passwordMinLength;
    return null;
  }

  String? _validateConfirmPassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) return l10n.confirmPasswordRequired;
    if (value != _passwordController.text) return l10n.passwordsMismatch;
    return null;
  }

  // ─── PARSEO DE ERRORES ─────────────────────────────────────────

  String _parsePocketBaseError(ClientException e, AppLocalizations l10n) {
    String errorMessage = e.response['message']?.toString() ?? e.toString();

    if (e.response.containsKey('data') && e.response['data'] is Map) {
      final Map<String, dynamic> dataErrors = e.response['data'];
      if (dataErrors.isNotEmpty) {
        final firstError = dataErrors.values.first;
        if (firstError is Map && firstError.containsKey('message')) {
          errorMessage = firstError['message'].toString();
        } else if (firstError is List && firstError.isNotEmpty) {
          errorMessage = firstError.first.toString();
        } else {
          errorMessage = firstError.toString();
        }
      }
    }

    final Map<String, String> errorMap = {
      'Invalid login credentials': l10n.invalidCredentials,
      'Email already exists': l10n.emailAlreadyExists,
      'User not found': l10n.userNotFound,
      'Network error': l10n.networkError,
      'Server error': l10n.serverError,
    };

    for (final entry in errorMap.entries) {
      if (errorMessage.toLowerCase().contains(entry.key.toLowerCase())) {
        return entry.value;
      }
    }

    return errorMessage
        .replaceAll('ClientException: ', '')
        .replaceAll('Exception: ', '')
        .replaceAll('_', ' ');
  }

  // ─── ENVÍO TRADICIONAL (EMAIL/PASSWORD) ────────────────────────

  Future<void> _submit(AppLocalizations l10n) async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      _log('submit', 'Formulario inválido. Abortando.');
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final mode = _isLogin ? 'login' : 'register';
    _log('submit', 'Enviando [$mode] — email: $email');

    try {
      if (_isLogin) {
        await _auth.login(email, password);
        if (mounted) _showSuccessSnackBar(l10n.loginSuccess);
      } else {
        await _auth.register(email, password);
        if (mounted) _showSuccessSnackBar(l10n.registerSuccess);
      }
      _log('submit', 'Operación [$mode] exitosa.');
    } on ClientException catch (e) {
      final msg = _parsePocketBaseError(e, l10n);
      if (mounted) {
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
      }
    } on PlatformException catch (e) {
      final msg = e.message ?? 'Error de plataforma.';
      if (mounted) {
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      _log('submit', 'Excepción genérica: $e');
      if (mounted) {
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
      }
    }
  }

  // ─── OAUTH (GOOGLE / APPLE) ────────────────────────────────────

  Future<void> _handleGoogleLogin() async {
    if (_isLoading) return;
    FocusScope.of(context).unfocus();
    _log('_handleGoogleLogin', 'Iniciando flujo de Google OAuth...');

    try {
      await _auth.loginWithGoogle();
      _log('_handleGoogleLogin', '✅ Google Login exitoso.');
      // El AuthProvider notificará el cambio y la app navegará automáticamente.
    } catch (e) {
      _log('_handleGoogleLogin', '❌ Error: $e');
      if (mounted) {
        _showErrorSnackBar(
            'No se pudo iniciar sesión con Google. Intenta de nuevo.');
      }
    }
  }

  // ─── RECUPERAR CONTRASEÑA ──────────────────────────────────────

  Future<void> _onForgotPassword(AppLocalizations l10n) async {
    _log('_onForgotPassword', 'Solicitando recuperación de contraseña...');

    final controller =
        TextEditingController(text: _emailController.text.trim());

    final String? result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: Text(
          l10n.forgotPassword,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Te enviaremos un enlace para restablecer tu contraseña.',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: l10n.email,
                labelStyle: const TextStyle(color: Colors.grey),
                prefixIcon:
                    const Icon(Icons.email_outlined, color: Color(0xFF00D4FF)),
                filled: true,
                fillColor: const Color(0xFF2A2A3E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
            ),
            child: Text(l10n.accept),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) {
      _log('_onForgotPassword', 'Cancelado por el usuario.');
      return;
    }

    try {
      final ok = await _auth.requestPasswordReset(result);
      if (!mounted) return;
      if (ok) {
        _log('_onForgotPassword', 'Email de recuperación enviado.');
        _showSuccessSnackBar(
          'Te enviamos un enlace a $result. Revisa tu correo.',
        );
      } else {
        _log('_onForgotPassword', 'No se pudo enviar el email.');
        _showErrorSnackBar(
          'No se pudo enviar el email. Verifica la dirección.',
        );
      }
    } catch (e) {
      _log('_onForgotPassword', 'Excepción: $e');
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  // ─── SNACKBARS ─────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: l10n.retry,
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: Colors.green.shade700,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ─── ABRIR URLS ────────────────────────────────────────────────

  Future<void> _openUrl(String url) async {
    try {
      _log('_openUrl', 'Intentando abrir: $url');
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _log('_openUrl', '✅ Abierto correctamente: $url');
      } else {
        _log('_openUrl', '❌ No se puede abrir: $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No se pudo abrir: $url'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      _log('_openUrl', '💥 Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el enlace: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _log('build', 'isLogin: $_isLogin, isLoading: $_isLoading');

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 400),
              offset: _slideAnimation.value,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLogo(),
                      const SizedBox(height: 24),
                      _buildTitle(l10n),
                      const SizedBox(height: 36),
                      _buildEmailField(l10n),
                      const SizedBox(height: 18),
                      _buildPasswordField(l10n),
                      if (!_isLogin) ...[
                        const SizedBox(height: 18),
                        _buildConfirmPasswordField(l10n),
                      ],
                      if (_isLogin) ...[
                        const SizedBox(height: 8),
                        _buildRememberMe(l10n),
                      ],
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _buildErrorMessage(),
                      ],
                      const SizedBox(height: 24),
                      _buildSubmitButton(l10n),

                      // [LOG] Separador y Botones de OAuth
                      const SizedBox(height: 24),
                      _buildOAuthDivider(l10n),
                      const SizedBox(height: 16),
                      _buildGoogleButton(),

                      // [LOG] Botón de Apple (Solo se muestra en iOS)
                      if (Platform.isIOS) ...[
                        const SizedBox(height: 12),
                        _buildAppleButton(),
                      ],

                      const SizedBox(height: 24),
                      _buildModeToggle(l10n),
                      const SizedBox(height: 12),
                      _buildHelpLinks(l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── WIDGETS ───────────────────────────────────────────────────

  Widget _buildLogo() {
    return Column(
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
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Center(
            child:
                Icon(Icons.play_arrow_rounded, size: 60, color: Colors.white),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'VIDEITOS',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 3.0,
            color: Color(0xFF00D4FF),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          _isLogin ? l10n.loginTitle : l10n.registerTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isLogin ? l10n.loginSubtitle : l10n.registerSubtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildEmailField(AppLocalizations l10n) {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      enabled: !_isLoading,
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(
        label: l10n.email,
        icon: Icons.email_outlined,
        hint: 'tu@email.com',
      ),
      validator: (v) => _validateEmail(v, l10n),
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildPasswordField(AppLocalizations l10n) {
    return TextFormField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      enabled: !_isLoading,
      textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
      style: const TextStyle(color: Colors.white),
      onFieldSubmitted: (_) => _isLogin ? _submit(l10n) : null,
      decoration: _buildInputDecoration(
        label: l10n.password,
        icon: Icons.lock_outline_rounded,
        hint: '••••••••',
        suffix: IconButton(
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          tooltip: _obscurePassword ? l10n.showPassword : l10n.hidePassword,
        ),
      ),
      validator: (v) => _validatePassword(v, l10n),
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildConfirmPasswordField(AppLocalizations l10n) {
    return TextFormField(
      controller: _confirmPasswordController,
      obscureText: _obscureConfirmPassword,
      enabled: !_isLoading,
      textInputAction: TextInputAction.done,
      style: const TextStyle(color: Colors.white),
      onFieldSubmitted: (_) => _submit(l10n),
      decoration: _buildInputDecoration(
        label: l10n.passwordConfirm,
        icon: Icons.lock_reset_rounded,
        hint: '••••••••',
        suffix: IconButton(
          icon: Icon(
            _obscureConfirmPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: Colors.grey,
          ),
          onPressed: () => setState(
              () => _obscureConfirmPassword = !_obscureConfirmPassword),
          tooltip:
              _obscureConfirmPassword ? l10n.showPassword : l10n.hidePassword,
        ),
      ),
      validator: (v) => _validateConfirmPassword(v, l10n),
      onChanged: (_) => setState(() => _errorMessage = null),
    );
  }

  Widget _buildRememberMe(AppLocalizations l10n) {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: !_isLoading
              ? (value) => setState(() => _rememberMe = value ?? true)
              : null,
          activeColor: const Color(0xFF00D4FF),
          checkColor: Colors.black,
        ),
        Text(l10n.rememberMe,
            style: const TextStyle(color: Colors.white70, fontSize: 14)),
        const Spacer(),
        TextButton(
          onPressed: _isLoading ? null : () => _onForgotPassword(l10n),
          child: Text(
            l10n.forgotPassword,
            style: const TextStyle(color: Color(0xFF00D4FF), fontSize: 13),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(AppLocalizations l10n) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _submit(l10n),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00D4FF),
          foregroundColor: Colors.black,
          disabledBackgroundColor: Colors.grey.shade800,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 4,
          shadowColor: const Color(0xFF00D4FF).withValues(alpha: 0.3),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2.5),
              )
            : Text(
                _isLogin ? l10n.loginButton : l10n.registerButton,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0),
              ),
      ),
    );
  }

  // [LOG] Separador "O continúa con"
  Widget _buildOAuthDivider(AppLocalizations l10n) {
    return Row(
      children: [
        const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            l10n.orContinueWith, // Asegúrate de tener esta clave en tus .arb, o usa "O"
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
        const Expanded(child: Divider(color: Colors.white24, thickness: 1)),
      ],
    );
  }

  // [LOG] Botón de Google OAuth
  Widget _buildGoogleButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _handleGoogleLogin,
        icon: Image.network(
          'https://developers.google.com/identity/images/g-logo.png',
          height: 24,
          width: 24,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.g_mobiledata, color: Colors.black, size: 30),
        ),
        label: const Text(
          'Continuar con Google',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          disabledBackgroundColor: Colors.white70,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24, width: 1),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  // [LOG] Botón de Apple OAuth (Preparado para iOS)
  Widget _buildAppleButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading
            ? null
            : () {
                // TODO: Implementar loginWithApple en AuthProvider
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text(
                          'El inicio de sesión con Apple estará disponible pronto.')),
                );
              },
        icon: const Icon(Icons.apple, color: Colors.white, size: 28),
        label: const Text(
          'Continuar con Apple',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.black54,
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Colors.white24, width: 1),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildModeToggle(AppLocalizations l10n) {
    return GestureDetector(
      onTap: _isLoading ? null : _toggleMode,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isLogin ? l10n.noAccount : l10n.hasAccount,
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w400),
            ),
            Text(
              _isLogin ? l10n.registerHere : l10n.loginHere,
              style: const TextStyle(
                color: Color(0xFF00D4FF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpLinks(AppLocalizations l10n) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextButton(
          onPressed:
              _isLoading ? null : () => _openUrl('https://videitos.cl/terms/'),
          child: Text(
            l10n.termsAndConditions,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const Text(' • ', style: TextStyle(color: Colors.grey, fontSize: 12)),
        TextButton(
          onPressed: _isLoading
              ? null
              : () => _openUrl('https://videitos.cl/privacy-policy/'),
          child: Text(
            l10n.privacyPolicy,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(
          color: Colors.grey, fontSize: 14, fontWeight: FontWeight.w500),
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
      prefixIcon: Icon(icon, color: const Color(0xFF00D4FF), size: 22),
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFF1A1A2E),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF00D4FF), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
    );
  }
}
