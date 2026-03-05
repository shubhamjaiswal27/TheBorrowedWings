import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import 'recording_controller.dart';
import 'location_service.dart';

/// Result class for authentication operations
class AuthResult {
  final bool success;
  final String? error;
  final User? user;

  const AuthResult({
    required this.success,
    this.error,
    this.user,
  });

  factory AuthResult.success(User user) => AuthResult(success: true, user: user);
  factory AuthResult.error(String error) => AuthResult(success: false, error: error);
}

/// Authentication service handling Supabase auth operations
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _client = SupabaseConfig.client;
  
  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;
  
  /// Current user (null if not authenticated)
  User? get currentUser => _client.auth.currentUser;
  
  /// Whether user is currently authenticated
  bool get isAuthenticated => currentUser != null;
  
  /// Current user ID (null if not authenticated)
  String? get currentUserId => currentUser?.id;

  /// Sign up with email and password
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
        },
      );

      if (response.user != null) {
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.error('Failed to create account. Please try again.');
      }
    } catch (e) {
      return AuthResult.error(_parseAuthError(e.toString()));
    }
  }

  /// Sign in with email and password
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final AuthResponse response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.error('Failed to sign in. Please check your credentials.');
      }
    } catch (e) {
      return AuthResult.error(_parseAuthError(e.toString()));
    }
  }

  /// Sign out current user
  Future<AuthResult> signOut() async {
    try {
      print('AuthService: Starting sign out process');
      
      // Clear app state before signing out
      await _clearAppState();
      
      // Sign out from Supabase
      await _client.auth.signOut();
      print('AuthService: Sign out completed');
      
      // Force a small delay to ensure state propagation
      await Future.delayed(const Duration(milliseconds: 100));
      
      return AuthResult.success(User(id: '', appMetadata: {}, userMetadata: {}, aud: '', createdAt: DateTime.now().toIso8601String()));
    } catch (e) {
      print('AuthService: Sign out failed: $e');
      return AuthResult.error('Failed to sign out: ${e.toString()}');
    }
  }

  /// Send password reset email
  Future<AuthResult> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      return AuthResult.success(currentUser!);
    } catch (e) {
      return AuthResult.error(_parseAuthError(e.toString()));
    }
  }

  /// Update user password
  Future<AuthResult> updatePassword({required String newPassword}) async {
    try {
      final UserResponse response = await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user != null) {
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.error('Failed to update password.');
      }
    } catch (e) {
      return AuthResult.error(_parseAuthError(e.toString()));
    }
  }

  /// Update user profile data
  Future<AuthResult> updateProfile({
    String? fullName,
    String? email,
  }) async {
    try {
      final UserResponse response = await _client.auth.updateUser(
        UserAttributes(
          email: email,
          data: fullName != null ? {'full_name': fullName} : null,
        ),
      );

      if (response.user != null) {
        return AuthResult.success(response.user!);
      } else {
        return AuthResult.error('Failed to update profile.');
      }
    } catch (e) {
      return AuthResult.error(_parseAuthError(e.toString()));
    }
  }

  /// Clear all app state (repositories, services, caches)
  Future<void> _clearAppState() async {
    try {
      print('AuthService: Clearing app state');
      
      // Clear services
      final recordingController = RecordingController();
      await recordingController.clearState();
      
      final locationService = LocationService();
      await locationService.clearState();
      
      print('AuthService: App state cleared successfully');
    } catch (e) {
      print('AuthService: Failed to clear app state: $e');
      // Don't throw - continue with logout even if state clearing fails
    }
  }

  /// Parse Supabase auth errors into user-friendly messages
  String _parseAuthError(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please try again.';
    } else if (error.contains('Email not confirmed')) {
      return 'Please check your email and click the confirmation link.';
    } else if (error.contains('User already registered')) {
      return 'An account with this email already exists.';
    } else if (error.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long.';
    } else if (error.contains('Unable to validate email address')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('signup is disabled')) {
      return 'Account creation is currently disabled.';
    } else {
      // Return a cleaned up version of the error
      return error
          .replaceAll('AuthException:', '')
          .replaceAll('PostgrestException:', '')
          .trim();
    }
  }
}