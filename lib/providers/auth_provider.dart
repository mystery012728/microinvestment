import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider with ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  bool _biometricEnabled = false;
  String? _error;
  User? _user;

  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get biometricEnabled => _biometricEnabled;
  String? get error => _error;
  User? get user => _user;

  AuthProvider() {
    _checkAuthStatus();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _firebaseAuth.authStateChanges().listen((User? user) {
      if (user != null) {
        _user = user;
        _handleFirebaseAuthSuccess();
      } else {
        _user = null;
        _isAuthenticated = false;
        notifyListeners();
      }
    });
  }

  Future<void> _checkAuthStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

      // Check if user is already signed in with Firebase
      _user = _firebaseAuth.currentUser;

      if (_user != null) {
        // User is signed in with Firebase
        if (_biometricEnabled) {
          // If biometric is enabled, require biometric authentication
          _isAuthenticated = false;
        } else {
          // If no biometric, consider authenticated
          _isAuthenticated = true;
        }
      } else {
        // User is not signed in with Firebase
        _isAuthenticated = false;
      }
    } catch (e) {
      _error = 'Failed to check auth status: $e';
      _isAuthenticated = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _handleFirebaseAuthSuccess() {
    if (_biometricEnabled) {
      // If biometric is enabled, require biometric authentication
      _isAuthenticated = false;
    } else {
      // If no biometric, consider authenticated
      _isAuthenticated = true;
    }
    notifyListeners();
  }

  // Firebase Authentication Methods
  void setUser(User user) {
    _user = user;
    _handleFirebaseAuthSuccess();
  }

  Future<bool> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      _handleFirebaseAuthSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e);
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign in failed: $e';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> signUpWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      _user = credential.user;
      _handleFirebaseAuthSuccess();
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e);
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Sign up failed: $e';
      _isAuthenticated = false;
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> resetPassword(String email) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } on FirebaseAuthException catch (e) {
      _error = _getFirebaseErrorMessage(e);
      notifyListeners();
      return false;
    } catch (e) {
      _error = 'Password reset failed: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getFirebaseErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  // Biometric Authentication Methods
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
      // First check if user is signed in with Firebase
      if (_user == null) {
        _error = 'Please sign in first';
        notifyListeners();
        return false;
      }

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

      // If user is currently authenticated, require biometric for next access
      if (_isAuthenticated) {
        _isAuthenticated = false;
      }

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

      // If user is signed in with Firebase, allow access without biometric
      if (_user != null) {
        _isAuthenticated = true;
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to disable biometric: $e';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      _isAuthenticated = false;
      _user = null;
      notifyListeners();
    } catch (e) {
      _error = 'Sign out failed: $e';
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Helper method to manually authenticate (for cases where biometric is disabled)
  void authenticate() {
    if (_user != null) {
      _isAuthenticated = true;
      notifyListeners();
    }
  }
}