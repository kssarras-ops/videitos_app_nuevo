// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Videitos';

  @override
  String get loginTitle => 'Log in';

  @override
  String get loginSubtitle => 'Enter your credentials to continue';

  @override
  String get registerTitle => 'Create an access credential';

  @override
  String get registerSubtitle => 'Complete the form to create your account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get passwordConfirm => 'Confirm password';

  @override
  String get name => 'Name';

  @override
  String get username => 'Username';

  @override
  String get loginButton => 'LOG IN';

  @override
  String get registerButton => 'SIGN UP';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get forgotPasswordFeature => 'Password recovery coming soon';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get hasAccount => 'Already have an account? ';

  @override
  String get registerHere => 'Sign up here';

  @override
  String get loginHere => 'Log in';

  @override
  String get termsAndConditions => 'Terms and conditions';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get welcome => 'Welcome';

  @override
  String get cancel => 'Cancel';

  @override
  String get accept => 'Accept';

  @override
  String get emailRequired => 'Enter your email';

  @override
  String get invalidEmail => 'Invalid email format';

  @override
  String get passwordRequired => 'Enter your password';

  @override
  String get passwordMinLength => 'Must be at least 6 characters';

  @override
  String get confirmPasswordRequired => 'Confirm your password';

  @override
  String get passwordsMismatch => 'Passwords don\'t match';

  @override
  String get invalidCredentials =>
      'Invalid credentials. Check your email and password.';

  @override
  String get emailAlreadyExists => 'This email is already registered.';

  @override
  String get userNotFound => 'User not found. Check your email.';

  @override
  String get networkError => 'Connection error. Check your internet.';

  @override
  String get serverError => 'Server error. Try again later.';

  @override
  String get loginSuccess => 'Welcome back!';

  @override
  String get registerSuccess => 'Account created! Logging in...';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';
}
