import 'package:flutter/material.dart';
import '../models/pilot.dart';
import '../repositories/pilot_repository.dart';
import '../services/auth_service.dart';

/// Pilot Profile page with view/edit modes, logout functionality, and form validation.
/// 
/// Features:
/// - View mode: displays pilot information in a clean layout
/// - Edit mode: form with validation for editing pilot details
/// - FloatingActionButton toggles between modes
/// - Logout functionality
/// - Persists data to Supabase database
/// - Requires authentication (user must be logged in)
class PilotProfilePage extends StatefulWidget {
  const PilotProfilePage({super.key});

  @override
  State<PilotProfilePage> createState() => _PilotProfilePageState();
}

class _PilotProfilePageState extends State<PilotProfilePage> {
  final PilotRepository _pilotRepository = PilotRepository();
  final AuthService _authService = AuthService();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Controllers for form fields
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _nationalityController;
  late final TextEditingController _licenseIdController;
  late final TextEditingController _emergencyContactNameController;
  late final TextEditingController _emergencyContactPhoneController;

  bool _isEditMode = false;
  bool _isLoading = true;
  Pilot? _currentPilot;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPilotProfile();
  }

  void _initializeControllers() {
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _nationalityController = TextEditingController();
    _licenseIdController = TextEditingController();
    _emergencyContactNameController = TextEditingController();
    _emergencyContactPhoneController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nationalityController.dispose();
    _licenseIdController.dispose();
    _emergencyContactNameController.dispose();
    _emergencyContactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _loadPilotProfile() async {
    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        // User not authenticated, this shouldn't happen due to AuthGate
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final pilot = await _pilotRepository.getPilotByUserId(userId);
      setState(() {
        _currentPilot = pilot;
        _isLoading = false;
        if (pilot == null) {
          _isEditMode = true; // Start in edit mode if no profile exists
        } else {
          _populateControllers(pilot);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Failed to load pilot profile: $e');
    }
  }

  void _populateControllers(Pilot pilot) {
    _fullNameController.text = pilot.fullName;
    _emailController.text = pilot.email ?? '';
    _phoneController.text = pilot.phone ?? '';
    _nationalityController.text = pilot.nationality ?? '';
    _licenseIdController.text = pilot.licenseId ?? '';
    _emergencyContactNameController.text = pilot.emergencyContactName ?? '';
    _emergencyContactPhoneController.text = pilot.emergencyContactPhone ?? '';
  }

  void _clearControllers() {
    _fullNameController.clear();
    _emailController.clear();
    _phoneController.clear();
    _nationalityController.clear();
    _licenseIdController.clear();
    _emergencyContactNameController.clear();
    _emergencyContactPhoneController.clear();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      final pilot = _currentPilot?.copyWith(
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        nationality: _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
        licenseId: _licenseIdController.text.trim().isEmpty ? null : _licenseIdController.text.trim(),
        emergencyContactName: _emergencyContactNameController.text.trim().isEmpty ? null : _emergencyContactNameController.text.trim(),
        emergencyContactPhone: _emergencyContactPhoneController.text.trim().isEmpty ? null : _emergencyContactPhoneController.text.trim(),
      ) ?? Pilot.create(
        userId: userId,
        fullName: _fullNameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        nationality: _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
        licenseId: _licenseIdController.text.trim().isEmpty ? null : _licenseIdController.text.trim(),
        emergencyContactName: _emergencyContactNameController.text.trim().isEmpty ? null : _emergencyContactNameController.text.trim(),
        emergencyContactPhone: _emergencyContactPhoneController.text.trim().isEmpty ? null : _emergencyContactPhoneController.text.trim(),
      );

      final savedPilot = (_currentPilot != null) 
          ? await _pilotRepository.updatePilotByUserId(userId, pilot)
          : await _pilotRepository.createPilot(pilot);

      setState(() {
        _currentPilot = savedPilot;
        _isEditMode = false;
      });

      _showSuccessSnackBar(_currentPilot!.id == null ? 'Profile created successfully!' : 'Profile updated successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to save profile: $e');
    }
  }

  Future<void> _deleteProfile() async {
    if (_currentPilot == null) return;

    final confirmed = await _showDeleteConfirmationDialog();
    if (!confirmed) return;

    try {
      final userId = _authService.currentUserId;
      if (userId == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      await _pilotRepository.deletePilotByUserId(userId);
      setState(() {
        _currentPilot = null;
        _isEditMode = true;
      });
      _clearControllers();
      _showSuccessSnackBar('Profile deleted successfully!');
    } catch (e) {
      _showErrorSnackBar('Failed to delete profile: $e');
    }
  }

  void _toggleEditMode() {
    setState(() {
      if (_isEditMode && _currentPilot != null) {
        // Cancel edit - restore original values
        _populateControllers(_currentPilot!);
      }
      _isEditMode = !_isEditMode;
    });
  }

  /// Handle user logout with confirmation
  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _authService.signOut();
        // Navigation will be handled by AuthGate listening to auth state changes
      } catch (e) {
        _showErrorSnackBar('Failed to logout: $e');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<bool> _showDeleteConfirmationDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile'),
        content: const Text('Are you sure you want to delete your pilot profile? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilot Profile'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // Logout button (always visible)
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
          // Delete button (only visible when profile exists and not in edit mode)
          if (_currentPilot != null && !_isEditMode)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteProfile,
              tooltip: 'Delete Profile',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: _currentPilot != null || _isEditMode
          ? FloatingActionButton(
              onPressed: _isEditMode ? _saveProfile : _toggleEditMode,
              child: Icon(_isEditMode ? Icons.save : Icons.edit),
              tooltip: _isEditMode ? 'Save Profile' : 'Edit Profile',
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isEditMode) {
      return _buildEditForm();
    } else if (_currentPilot != null) {
      return _buildViewMode();
    } else {
      return _buildEmptyState();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 120,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 24),
            Text(
              'No Pilot Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(
              'Create your pilot profile to track your paragliding adventures.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isEditMode = true),
              icon: const Icon(Icons.add),
              label: const Text('Create Profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    final pilot = _currentPilot!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar section
          Center(
            child: CircleAvatar(
              radius: 60,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 60,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 32),
          
          // Personal Information
          _buildSection(
            'Personal Information',
            [
              _buildViewField('Full Name', pilot.fullName),
              if (pilot.email != null) _buildViewField('Email', pilot.email!),
              if (pilot.phone != null) _buildViewField('Phone', pilot.phone!),
              if (pilot.nationality != null) _buildViewField('Nationality', pilot.nationality!),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // License Information
          if (pilot.licenseId != null)
            _buildSection(
              'License Information',
              [
                _buildViewField('License ID', pilot.licenseId!),
              ],
            ),
          
          if (pilot.licenseId != null) const SizedBox(height: 24),
          
          // Emergency Contact
          if (pilot.emergencyContactName != null || pilot.emergencyContactPhone != null)
            _buildSection(
              'Emergency Contact',
              [
                if (pilot.emergencyContactName != null)
                  _buildViewField('Contact Name', pilot.emergencyContactName!),
                if (pilot.emergencyContactPhone != null)
                  _buildViewField('Contact Phone', pilot.emergencyContactPhone!),
              ],
            ),
          
          const SizedBox(height: 24),
          
          // Metadata
          _buildSection(
            'Profile Information',
            [
              _buildViewField('Created', _formatDateTime(pilot.createdAt)),
              _buildViewField('Last Updated', _formatDateTime(pilot.updatedAt)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: children.expand((widget) => [widget, const SizedBox(height: 12)]).take(children.length * 2 - 1).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewField(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildEditForm() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar placeholder
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Personal Information
            Text(
              'Personal Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Full name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                hintText: 'pilot@example.com',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (!Pilot.isValidEmail(value)) {
                  return 'Please enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
                hintText: '+1 (555) 123-4567',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _nationalityController,
              decoration: const InputDecoration(
                labelText: 'Nationality',
                border: OutlineInputBorder(),
                hintText: 'e.g., American, British, German',
              ),
            ),
            const SizedBox(height: 32),
            
            // License Information
            Text(
              'License Information',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _licenseIdController,
              decoration: const InputDecoration(
                labelText: 'License ID',
                border: OutlineInputBorder(),
                hintText: 'Your paragliding license number',
              ),
            ),
            const SizedBox(height: 32),
            
            // Emergency Contact
            Text(
              'Emergency Contact',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emergencyContactNameController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _emergencyContactPhoneController,
              decoration: const InputDecoration(
                labelText: 'Emergency Contact Phone',
                border: OutlineInputBorder(),
                hintText: '+1 (555) 123-4567',
              ),
              keyboardType: TextInputType.phone,
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            Row(
              children: [
                if (_currentPilot != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _toggleEditMode,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveProfile,
                    child: Text(_currentPilot == null ? 'Create Profile' : 'Save Changes'),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}