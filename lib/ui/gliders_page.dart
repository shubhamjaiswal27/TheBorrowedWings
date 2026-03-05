import 'package:flutter/material.dart';
import '../models/glider.dart';
import '../repositories/glider_repository.dart';
import '../services/auth_service.dart';

/// Page for managing glider equipment.
/// 
/// Allows users to create, edit, and delete glider profiles used for flight recording.
class GlidersPage extends StatefulWidget {
  const GlidersPage({super.key});

  @override
  State<GlidersPage> createState() => _GlidersPageState();
}

class _GlidersPageState extends State<GlidersPage> {
  final GliderRepository _gliderRepository = GliderRepository();
  final AuthService _authService = AuthService();
  List<Glider> _gliders = [];
  bool _isLoading = true;
  bool _hasChanges = false; // Track if any gliders were modified

  @override
  void initState() {
    super.initState();
    _loadGliders();
  }

  Future<void> _loadGliders() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Check authentication
      final userId = _authService.currentUserId;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final gliders = await _gliderRepository.getGlidersByUserId(userId);
      if (mounted) {
        setState(() {
          _gliders = gliders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Failed to load gliders: $e');
      }
    }
  }

  Future<void> _showGliderDialog({Glider? glider}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _GliderDialog(glider: glider),
    );
    
    if (result == true) {
      _hasChanges = true; // Mark that changes were made
      _loadGliders();
    }
  }

  Future<void> _deleteGlider(Glider glider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Glider'),
        content: Text('Are you sure you want to delete "${glider.displayName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Check authentication
        final userId = _authService.currentUserId;
        if (userId == null) {
          _showErrorSnackBar('User not authenticated');
          return;
        }

        await _gliderRepository.deleteGlider(glider.id!, userId);
        _hasChanges = true; // Mark that changes were made
        _loadGliders();
        _showSuccessSnackBar('Glider deleted successfully');
      } catch (e) {
        _showErrorSnackBar('Failed to delete glider: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && _hasChanges) {
          // The pop already happened, but we can't change the result here
          // So we need to use Navigator.pop manually instead
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gliders'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, _hasChanges),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showGliderDialog(),
              tooltip: 'Add Glider',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _gliders.isEmpty
                ? _buildEmptyState()
                : _buildGlidersList(),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showGliderDialog(),
          tooltip: 'Add Glider',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.paragliding,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Gliders Yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first glider to start recording flights',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showGliderDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Glider'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlidersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _gliders.length,
      itemBuilder: (context, index) {
        final glider = _gliders[index];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                glider.model.isNotEmpty ? glider.model[0].toUpperCase() : 'G',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              glider.displayName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (glider.wingClass != null && glider.wingClass!.isNotEmpty)
                  Text('Class: ${glider.wingClass}'),
                if (glider.serialNumber != null && glider.serialNumber!.isNotEmpty)
                  Text('Registration: ${glider.serialNumber}'),
              ],
            ),
            isThreeLine: false,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    _showGliderDialog(glider: glider);
                    break;
                  case 'delete':
                    _deleteGlider(glider);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete'),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _showGliderDialog(glider: glider),
          ),
        );
      },
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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _GliderDialog extends StatefulWidget {
  final Glider? glider;

  const _GliderDialog({this.glider});

  @override
  State<_GliderDialog> createState() => _GliderDialogState();
}

class _GliderDialogState extends State<_GliderDialog> {
  final _formKey = GlobalKey<FormState>();
  final GliderRepository _gliderRepository = GliderRepository();
  final AuthService _authService = AuthService();
  
  late TextEditingController _manufacturerController;
  late TextEditingController _modelController;
  late TextEditingController _serialNumberController;
  late TextEditingController _wingClassController;
  late TextEditingController _notesController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _manufacturerController = TextEditingController(text: widget.glider?.manufacturer ?? '');
    _modelController = TextEditingController(text: widget.glider?.model ?? '');
    _serialNumberController = TextEditingController(text: widget.glider?.serialNumber ?? '');
    _wingClassController = TextEditingController(text: widget.glider?.wingClass ?? '');
    _notesController = TextEditingController(text: widget.glider?.notes ?? '');
  }

  @override
  void dispose() {
    _manufacturerController.dispose();
    _modelController.dispose();
    _serialNumberController.dispose();
    _wingClassController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveGlider() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check authentication
    final userId = _authService.currentUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final glider = Glider.create(
        userId: userId,
        manufacturer: _manufacturerController.text.trim().isEmpty 
            ? null 
            : _manufacturerController.text.trim(),
        model: _modelController.text.trim(),
        serialNumber: _serialNumberController.text.trim().isEmpty 
            ? null 
            : _serialNumberController.text.trim(),
        wingClass: _wingClassController.text.trim().isEmpty 
            ? null 
            : _wingClassController.text.trim(),
        notes: _notesController.text.trim().isEmpty 
            ? null 
            : _notesController.text.trim(),
      );

      if (widget.glider == null) {
        // Create new glider
        await _gliderRepository.createGlider(glider);
      } else {
        // Update existing glider
        final updatedGlider = glider.copyWith(id: widget.glider!.id);
        await _gliderRepository.updateGlider(updatedGlider, userId);
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save glider: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.glider != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Glider' : 'Add Glider'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _manufacturerController,
                  decoration: const InputDecoration(
                    labelText: 'Manufacturer',
                    hintText: 'e.g. Ozone, Advance, Gin',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Model *',
                    hintText: 'e.g. Rush 5, Sigma 11',
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Model is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serialNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Registration / Serial',
                    hintText: 'e.g. G-ABCD, Serial Number',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _wingClassController,
                  decoration: const InputDecoration(
                    labelText: 'Wing Class',
                    hintText: 'e.g. EN-A, EN-B, EN-C',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Additional information...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveGlider,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Update' : 'Create'),
        ),
      ],
    );
  }
}