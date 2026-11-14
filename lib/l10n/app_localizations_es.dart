// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Videitos';

  @override
  String get loginTitle => 'Ingresa al búnker';

  @override
  String get loginSubtitle => 'Ingresa tus credenciales para continuar';

  @override
  String get registerTitle => 'Crea una credencial de acceso';

  @override
  String get registerSubtitle => 'Completa los datos para crear tu cuenta';

  @override
  String get email => 'Email';

  @override
  String get password => 'Contraseña';

  @override
  String get passwordConfirm => 'Confirmar contraseña';

  @override
  String get name => 'Nombre';

  @override
  String get username => 'Nombre de usuario';

  @override
  String get loginButton => 'INICIAR SESIÓN';

  @override
  String get registerButton => 'CREAR CUENTA';

  @override
  String get forgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get forgotPasswordFeature => 'Función de recuperación próximamente';

  @override
  String get rememberMe => 'Recordarme';

  @override
  String get noAccount => '¿No tienes cuenta? ';

  @override
  String get hasAccount => '¿Ya tienes cuenta? ';

  @override
  String get registerHere => 'Regístrate aquí';

  @override
  String get loginHere => 'Conéctate';

  @override
  String get termsAndConditions => 'Términos y condiciones';

  @override
  String get privacyPolicy => 'Política de privacidad';

  @override
  String get loading => 'Cargando...';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Reintentar';

  @override
  String get welcome => 'Bienvenido';

  @override
  String get cancel => 'Cancelar';

  @override
  String get accept => 'Aceptar';

  @override
  String get emailRequired => 'Ingresa tu email';

  @override
  String get invalidEmail => 'Formato de email inválido';

  @override
  String get passwordRequired => 'Ingresa tu contraseña';

  @override
  String get passwordMinLength => 'Debe tener al menos 6 caracteres';

  @override
  String get confirmPasswordRequired => 'Confirma tu contraseña';

  @override
  String get passwordsMismatch => 'Las contraseñas no coinciden';

  @override
  String get invalidCredentials =>
      'Credenciales inválidas. Verifica tu email y contraseña.';

  @override
  String get emailAlreadyExists => 'Este email ya está registrado.';

  @override
  String get userNotFound => 'Usuario no encontrado. Verifica tu email.';

  @override
  String get networkError => 'Error de conexión. Verifica tu internet.';

  @override
  String get serverError => 'Error del servidor. Intenta más tarde.';

  @override
  String get loginSuccess => '¡Bienvenido de vuelta!';

  @override
  String get registerSuccess => '¡Cuenta creada! Iniciando sesión...';

  @override
  String get showPassword => 'Mostrar contraseña';

  @override
  String get hidePassword => 'Ocultar contraseña';
}
