import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../repositories/pilot_repository.dart';
import 'auth/login_page.dart';
import 'auth/complete_profile_page.dart';
import '../app.dart';

/// AuthGate manages routing based on authentication state and profile completion status
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  final _pilotRepository = PilotRepository();
  
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkInitialAuthState();
  }

  /// Check initial authentication state and profile status
  Future<void> _checkInitialAuthState() async {
    try {
      // Give a moment for Supabase to initialize if needed
      await Future.delayed(const Duration(milliseconds: 100));
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Determine which screen to show based on auth state and profile status
  Future<Widget> _determineScreen() async {
    final user = _authService.currentUser;
    
    // Not authenticated -> Login flow
    if (user == null) {
      return const LoginPage();
    }
    
    // Authenticated -> Check if pilot profile exists
    try {
      final pilot = await _pilotRepository.getPilotByUserId(user.id);
      
      if (pilot == null) {
        // Profile doesn't exist -> Complete profile
        return CompleteProfilePage(
          fullName: user.userMetadata?['full_name'] as String?,
        );
      } else {
        // Profile exists -> Main app
        return const MainNavigationWrapper();
      }
    } catch (e) {
      // Error checking profile -> Complete profile as fallback
      return CompleteProfilePage(
        fullName: user.userMetadata?['full_name'] as String?,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Authentication Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _error = null;
                    _isLoading = true;
                  });
                  _checkInitialAuthState();
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    // Listen to auth state changes and rebuild accordingly
    return StreamBuilder<AuthState>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        // Show loading during auth state transitions
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // Determine which screen to show
        return FutureBuilder<Widget>(
          future: _determineScreen(),
          builder: (context, screenSnapshot) {
            if (screenSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (screenSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error Loading App',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          screenSnapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () {
                          setState(() {});
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return screenSnapshot.data ?? const LoginPage();
          },
        );
      },
    );
  }
}