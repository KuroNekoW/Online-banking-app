import 'package:flutter/material.dart';
import '../core/storage/storage_service.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  UserModel? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> checkAuthStatus() async {
    final token = StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      _isAuthenticated = false;
      _currentUser = null;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await AuthService.getMe();
      _isAuthenticated = true;
      _errorMessage = null;
    } catch (e) {
      _isAuthenticated = false;
      _currentUser = null;
      await StorageService.clearTokens();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password, {bool remember = true}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await AuthService.login(identifier: identifier, password: password);
      _isAuthenticated = true;
      if (remember) {
        await StorageService.setRememberedIdentifier(identifier);
      }
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      _currentUser = null;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String phone,
    required String fullName,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await AuthService.register(
        email: email,
        phone: phone,
        fullName: fullName,
        password: password,
      );
      return res;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyRegistration(String challengeId, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await AuthService.verifyRegistration(challengeId: challengeId, code: code);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      await AuthService.logout();
    } finally {
      _isAuthenticated = false;
      _currentUser = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    try {
      _currentUser = await AuthService.getMe();
      notifyListeners();
    } catch (_) {}
  }
}
