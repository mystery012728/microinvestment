import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _biometricEnabled = false;
  String? _error;

  final LocalAuthentication _localAuth = LocalAuthentication();

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get biometricEnabled => _biometricEnabled;
  String? get error => _error;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      if (_biometricEnabled) {
        // If biometric is enabled, require authentication
        _isAuthenticated = false;
      } else {
        // If no biometric, consider authenticated
        _isAuthenticated = true;
      }
    } catch (e) {
      _error = 'Failed to check auth status: $e';
      _isAuthenticated = true; // Default to authenticated on error
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> checkBiometricSupport() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      return isAvailable && isDeviceSupported;
    } catch (e) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  Future<bool> authenticateWithBiometrics() async {
    try {
      final isAuthenticated = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your portfolio',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (isAuthenticated) {
        _isAuthenticated = true;
        _error = null;
        notifyListeners();
      }

      return isAuthenticated;
    } catch (e) {
      _error = 'Authentication failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> enableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', true);
      _biometricEnabled = true;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to enable biometric: $e';
      notifyListeners();
    }
  }

  Future<void> disableBiometric() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('biometric_enabled', false);
      _biometricEnabled = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to disable biometric: $e';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _isAuthenticated = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}