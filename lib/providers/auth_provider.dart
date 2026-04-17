import 'package:flutter/material.dart';
import '../services/pocketbase_service.dart';

class AuthProvider extends ChangeNotifier {
  final PocketBaseService _pb = PocketBaseService();
  bool _isLoading = true;
  String? _errorMessage;

  AuthProvider() {
    _init();
  }

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _pb.isAuthenticated;
  String? get userEmail => _pb.currentUser?.data['email'] as String?;

  Future<void> _init() async {
    await _pb.init();
    _isLoading = false;
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _pb.login(email, password);
      if (user == null) {
        _errorMessage = 'Credenciales inválidas';
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _pb.register(email, password);
      if (user == null) {
        _errorMessage = 'No se pudo crear el usuario';
        return false;
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _pb.logout();
    notifyListeners();
  }
}
