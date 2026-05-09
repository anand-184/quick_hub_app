import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../services/auth_error_service.dart';
import '../services/notification_service.dart';

class AuthViewModel extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  String? _errorCode;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    return AuthErrorService.getErrorMessage(e.code, errorMessage: e.message);
  }

  String getErrorTitle(String errorCode) {
    return AuthErrorService.getErrorTitle(errorCode);
  }

  bool isRecoverableError(String errorCode) {
    return AuthErrorService.isRecoverable(errorCode);
  }

  bool isNetworkError(String errorCode) {
    return AuthErrorService.isNetworkError(errorCode);
  }

  bool isRateLimitError(String errorCode) {
    return AuthErrorService.isRateLimited(errorCode);
  }

  AuthViewModel() {
    _checkUserSession();
    // Listen for auth state changes (e.g., login, logout)
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      debugPrint("AuthViewModel: Auth state changed. User: ${user?.email}");
      if (user != null) {
        final userProfile = await _firebaseService.getUserProfile(user.uid);
        _currentUser = userProfile;
        // Update push token whenever auth state changes to a logged in user
        NotificationService().updateToken(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message, {String? errorCode}) {
    _errorMessage = message;
    _errorCode = errorCode;
    notifyListeners();
  }

  Future<void> _checkUserSession() async {
    _setLoading(true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userProfile = await _firebaseService.getUserProfile(user.uid);
      _currentUser = userProfile;
    }
    _setLoading(false);
  }

  Future<bool> registerUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    String? serviceType,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _firebaseService.registerUser(
        email: email,
        password: password,
      );
      if (credential != null && credential.user != null) {
        final newUser = UserModel(
          uid: credential.user!.uid,
          name: name,
          email: email,
          role: role,
          createdAt: DateTime.now(),
          serviceType: serviceType,
          isActive: true, // Defaulting to true for simplicity in testing
        );
        await _firebaseService.saveUserProfile(newUser);
        _currentUser = newUser;
        _setLoading(false);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseAuthError(e), errorCode: e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(
        "An unexpected error occurred. Please try again.",
        errorCode: 'unknown',
      );
      _setLoading(false);
      return false;
    }
  }

  Future<bool> loginUser(String email, String password) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _firebaseService.loginUser(
        email: email,
        password: password,
      );
      if (credential != null && credential.user != null) {
        final userProfile = await _firebaseService.getUserProfile(
          credential.user!.uid,
        );
        if (userProfile == null) {
          _setError("User profile not found. Please contact support.");
          _setLoading(false);
          return false;
        }
        _currentUser = userProfile;
        _setLoading(false);
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseAuthError(e), errorCode: e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(
        "An unexpected error occurred. Please try again.",
        errorCode: 'unknown',
      );
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updateProfile(UserModel updatedUser) async {
    _setLoading(true);
    _setError(null);
    try {
      await _firebaseService.saveUserProfile(updatedUser);
      _currentUser = updatedUser;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError("Failed to update profile: $e", errorCode: 'update-failed');
      _setLoading(false);
      return false;
    }
  }

  Future<bool> sendPasswordResetEmail(String email) async {
    _setLoading(true);
    _setError(null);
    try {
      // Security check: Only send if email exists in our DB
      final exists = await _firebaseService.doesEmailExist(email);
      if (!exists) {
        _setError(
          "No account found with this email.",
          errorCode: 'user-not-found',
        );
        _setLoading(false);
        return false;
      }

      await _firebaseService.sendPasswordResetEmail(email);
      _setLoading(false);
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseAuthError(e), errorCode: e.code);
      _setLoading(false);
      return false;
    } catch (e) {
      _setError(
        "An unexpected error occurred. Please try again.",
        errorCode: 'unknown',
      );
      _setLoading(false);
      return false;
    }
  }

  Future<void> logout() async {
    await _firebaseService.logout();
    _currentUser = null;
    notifyListeners();
  }

  Future<bool> checkEmailExists(String email) async {
    return await _firebaseService.doesEmailExist(email);
  }
}
