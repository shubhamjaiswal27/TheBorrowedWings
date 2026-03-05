import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../repositories/pilot_repository.dart';
import '../../models/pilot.dart';
import '../../app.dart';
import '../auth_gate.dart';

/// Profile update page for existing users to modify their pilot profile
class CompleteProfilePage extends StatefulWidget {
  final String? fullName;

  const CompleteProfilePage({
    super.key,
    this.fullName,
  });

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _licenseIdController = TextEditingController();
  final _emergencyNameController = TextEditingController();
  final _emergencyPhoneController = TextEditingController();
  
  final _authService = AuthService();
  final _pilotRepository = PilotRepository();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeForm();
  }

  /// Initialize form with existing data
  void _initializeForm() async {
    // Give Supabase auth state time to propagate after signup
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (widget.fullName != null) {
      _fullNameController.text = widget.fullName!;
    }
    
    // Set email from auth user if available  
    final currentUser = _authService.currentUser;
    if (currentUser?.email != null) {
      _emailController.text = currentUser!.email!;
    }
    
    // Load existing profile data
    _loadExistingProfile();
  }

  /// Load existing profile data for updates
  Future<void> _loadExistingProfile() async {
    try {
      final userId = _authService.currentUserId;
      if (userId != null) {
        final pilot = await _pilotRepository.getPilotByUserId(userId);
        if (pilot != null) {
          setState(() {
            _fullNameController.text = pilot.fullName;
            _emailController.text = pilot.email ?? '';
            _phoneController.text = pilot.phone ?? '';
            _nationalityController.text = pilot.nationality ?? '';
            _licenseIdController.text = pilot.licenseId ?? '';
            _emergencyNameController.text = pilot.emergencyContactName ?? '';
            _emergencyPhoneController.text = pilot.emergencyContactPhone ?? '';
          });
        }
      }
    } catch (e) {
      // Handle error loading existing profile
      setState(() {
        _errorMessage = 'Failed to load existing profile: $e';
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _licenseIdController.dispose();
    _emergencyNameController.dispose();
    _emergencyPhoneController.dispose();
    super.dispose();
  }

  /// Handle profile completion/update
  Future<void> _handleSaveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Wait a bit more and retry if user ID is not available
      String? userId = _authService.currentUserId;
      
      if (userId == null) {
        // Wait for auth state to propagate and retry
        await Future.delayed(const Duration(milliseconds: 500));
        userId = _authService.currentUserId;
      }
      
      if (userId == null) {
        setState(() {
          _errorMessage = 'Authentication in progress. Please try again in a moment.';
        });
        return;
      }

      final pilot = Pilot.create(
        userId: userId,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        nationality: _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
        licenseId: _licenseIdController.text.trim().isEmpty ? null : _licenseIdController.text.trim(),
        emergencyContactName: _emergencyNameController.text.trim().isEmpty ? null : _emergencyNameController.text.trim(),
        emergencyContactPhone: _emergencyPhoneController.text.trim().isEmpty ? null : _emergencyPhoneController.text.trim(),
      );

      // Update existing pilot profile
      await _pilotRepository.updatePilotByUserId(userId, pilot);
      print('Profile updated for user: $userId');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile updated successfully!'),
          ),
        );
        
        // Navigate back after successful update
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save profile: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Handle logout and return to login page
  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Sign out will automatically clear app state
      final result = await _authService.signOut();
      
      if (result.success && mounted) {
        // Navigate to AuthGate which will detect logout and show login page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const AuthGate()),
          (route) => false,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.error ?? 'Logout failed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Skip profile completion and go to home page
  void _skipToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const MainNavigationWrapper()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Update Profile'),
        automaticallyImplyLeading: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'logout':
                  _handleLogout();
                  break;
                case 'skip':
                  _skipToHome();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'skip',
                child: ListTile(
                  leading: Icon(Icons.home),
                  title: Text('Skip to Home'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),

                  // Error message
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.onErrorContainer),
                          ),
                          // Show retry button for authentication issues
                          if (_errorMessage!.contains('Authentication in progress')) ...[
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _isLoading ? null : () {
                                setState(() {
                                  _errorMessage = null;
                                });
                                _handleSaveProfile();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Required fields section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Required Information',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Full name field
                          TextFormField(
                            controller: _fullNameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full Name *',
                              prefixIcon: Icon(Icons.person),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your full name';
                              }
                              if (value.trim().split(' ').length < 2) {
                                return 'Please enter both first and last name';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Optional fields section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Optional Information',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This information can be added later in your profile.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Email field
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email),
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value != null && value.isNotEmpty) {
                                if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Phone field
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Phone',
                              prefixIcon: Icon(Icons.phone),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Nationality field
                          TextFormField(
                            controller: _nationalityController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nationality',
                              prefixIcon: Icon(Icons.flag),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // License ID field
                          TextFormField(
                            controller: _licenseIdController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'License ID',
                              prefixIcon: Icon(Icons.credit_card),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Emergency contact section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Emergency Contact',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Important for safety during flights.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Emergency contact name
                          TextFormField(
                            controller: _emergencyNameController,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact Name',
                              prefixIcon: Icon(Icons.contact_emergency),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Emergency contact phone
                          TextFormField(
                            controller: _emergencyPhoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                              labelText: 'Emergency Contact Phone',
                              prefixIcon: Icon(Icons.emergency),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Save button
                  FilledButton(
                    onPressed: _isLoading ? null : _handleSaveProfile,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text('Update Profile'),
                  ),
                  const SizedBox(height: 16),
                  
                  // Skip to Home button
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _skipToHome,
                    icon: const Icon(Icons.home),
                    label: const Text('Skip and Go to Home'),
                  ),
                  const SizedBox(height: 8),
                  
                  // Logout button
                  TextButton.icon(
                    onPressed: _isLoading ? null : _handleLogout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Logout'),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}