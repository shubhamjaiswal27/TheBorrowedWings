import 'dart:async';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import '../models/glider.dart';
import '../services/recording_controller.dart';
import '../services/location_service.dart';
import '../db/glider_dao.dart';
import 'gliders_page.dart';

/// Main recording page for the ParaglidingLog app.
/// 
/// Provides interface for starting/stopping flight recording with glider selection,
/// real-time status updates, and live flight metrics display.
class HomeRecordingPage extends StatefulWidget {
  const HomeRecordingPage({super.key});

  @override
  State<HomeRecordingPage> createState() => _HomeRecordingPageState();
}

class _HomeRecordingPageState extends State<HomeRecordingPage> {
  final RecordingController _recordingController = RecordingController();
  final GliderDao _gliderDao = GliderDao();
  
  List<Glider> _gliders = [];
  Glider? _selectedGlider;
  StreamSubscription<RecordingStatus>? _statusSubscription;
  RecordingStatus? _currentStatus;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGliders();
    _listenToRecordingStatus();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _recordingController.dispose();
    super.dispose();
  }

  Future<void> _loadGliders() async {
    try {
      final gliders = await _gliderDao.getAllGliders();
      if (mounted) {
        setState(() {
          _gliders = gliders;
          
          // Check if currently selected glider still exists in the updated list
          if (_selectedGlider != null) {
            final stillExists = gliders.any((g) => g.id == _selectedGlider!.id);
            if (!stillExists) {
              _selectedGlider = null;
            }
          }
          
          // Auto-select first glider if available and none selected
          if (_selectedGlider == null && gliders.isNotEmpty) {
            _selectedGlider = gliders.first;
          } else if (gliders.isEmpty) {
            _selectedGlider = null;
          }
        });
      }
    } catch (e) {
      _showErrorSnackBar('Failed to load gliders: $e');
    }
  }

  void _listenToRecordingStatus() {
    _statusSubscription = _recordingController.statusStream.listen(
      (status) {
        if (mounted) {
          setState(() {
            _currentStatus = status;
          });
        }
      },
      onError: (error) {
        _showErrorSnackBar('Recording error: $error');
      },
    );
  }

  Future<void> _startRecording() async {
    if (_selectedGlider == null) {
      _showErrorSnackBar('Please select a glider first');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final success = await _recordingController.startRecording(_selectedGlider!);
      if (!success) {
        _showErrorSnackBar('Failed to start recording. Check location permissions.');
      }
    } catch (e) {
      _showErrorSnackBar('Error starting recording: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final flight = await _recordingController.stopRecording();
      if (flight != null) {
        _showSuccessSnackBar('Flight recorded successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error stopping recording: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToGlidersPage() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (context) => const GlidersPage()),
    );
    
    if (result == true) {
      // Gliders were modified, reload the list
      _loadGliders();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRecording = _currentStatus?.isRecording ?? false;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('ParaglidingLog'),
        actions: [
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: () {
              Navigator.pushNamed(context, '/flights');
            },
            tooltip: 'View Flights',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Glider selection card
            _buildGliderSelectionCard(),
            const SizedBox(height: 16),
            
            // Status display card
            _buildStatusCard(),
            const SizedBox(height: 16),
            
            // Recording metrics card (when active)
            if (isRecording) ...[
              _buildMetricsCard(),
              const SizedBox(height: 16),
            ],
            
            // GPS status card
            _buildLocationCard(),
            const SizedBox(height: 24),
            
            // Main recording button
            _buildRecordingButton(isRecording),
          ],
        ),
      ),
    );
  }

  Widget _buildGliderSelectionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Glider',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: _navigateToGlidersPage,
                  icon: const Icon(Icons.settings),
                  label: const Text('Manage'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_gliders.isEmpty)
              Column(
                children: [
                  const Text('No gliders found. Add a glider to start recording.'),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _navigateToGlidersPage,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Glider'),
                  ),
                ],
              )
            else
              DropdownButton<Glider>(
                value: _selectedGlider != null && _gliders.contains(_selectedGlider) 
                    ? _selectedGlider 
                    : null,
                isExpanded: true,
                items: _gliders.map((glider) {
                  return DropdownMenuItem(
                    value: glider,
                    child: Text(glider.displayName),
                  );
                }).toList(),
                onChanged: _currentStatus?.isRecording == true
                    ? null
                    : (glider) {
                        setState(() {
                          _selectedGlider = glider;
                        });
                      },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = _currentStatus;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    if (status == null) {
      statusColor = Colors.grey;
      statusIcon = Icons.radio_button_unchecked;
      statusText = 'Ready to record';
    } else {
      switch (status.state) {
        case RecordingState.idle:
          statusColor = Colors.grey;
          statusIcon = Icons.radio_button_unchecked;
          statusText = 'Ready to record';
          break;
        case RecordingState.waitingForTakeoff:
          statusColor = Colors.orange;
          statusIcon = Icons.schedule;
          statusText = 'Waiting for takeoff...';
          break;
        case RecordingState.inFlight:
          statusColor = Colors.green;
          statusIcon = Icons.flight;
          statusText = 'In flight!';
          break;
        case RecordingState.landed:
          statusColor = Colors.blue;
          statusIcon = Icons.flight_land;
          statusText = 'Flight completed';
          break;
        case RecordingState.stopped:
          statusColor = Colors.grey;
          statusIcon = Icons.stop;
          statusText = 'Recording stopped';
          break;
      }
    }
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    statusText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (status != null && status.statusMessage.isNotEmpty)
                    Text(
                      status.statusMessage,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsCard() {
    final status = _currentStatus;
    if (status == null) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recording Metrics',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MetricItem(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: _formatDuration(status.recordingDuration),
                  ),
                ),
                Expanded(
                  child: _MetricItem(
                    icon: Icons.gps_fixed,
                    label: 'GPS Fixes',
                    value: '${status.fixCount}',
                  ),
                ),
              ],
            ),
            if (status.takeoffTime != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MetricItem(
                      icon: Icons.flight_takeoff,
                      label: 'Takeoff',
                      value: '${status.takeoffTime!.hour.toString().padLeft(2, '0')}:'
                          '${status.takeoffTime!.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                  if (status.flightDuration != null)
                    Expanded(
                      child: _MetricItem(
                        icon: Icons.flight,
                        label: 'Flight Time',
                        value: _formatDuration(status.flightDuration!),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final status = _currentStatus;
    final location = status?.lastLocation;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GPS Status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (location == null)
              const Row(
                children: [
                  Icon(Icons.gps_off, color: Colors.red),
                  SizedBox(width: 8),
                  Text('No GPS data'),
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        location.hasGoodAccuracy ? Icons.gps_fixed : Icons.gps_not_fixed,
                        color: location.hasGoodAccuracy ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Accuracy: ${location.accuracy?.toStringAsFixed(1) ?? 'Unknown'}m',
                      ),
                    ],
                  ),
                  if (location.hasAltitude) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.height, color: Colors.blue),
                        const SizedBox(width: 8),
                        Text('Altitude: ${location.altitudeMeters}m'),
                      ],
                    ),
                  ],
                  if (location.hasSpeed) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.speed, color: Colors.green),
                        const SizedBox(width: 8),
                        Text('Speed: ${location.speedKmh?.toStringAsFixed(1)}km/h'),
                      ],
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingButton(bool isRecording) {
    return SizedBox(
      height: 64,
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (isRecording ? _stopRecording : _startRecording),
        style: ElevatedButton.styleFrom(
          backgroundColor: isRecording ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isRecording ? Icons.stop : Icons.play_arrow, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    isRecording ? 'STOP RECORDING' : 'START RECORDING',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m ${seconds}s';
    }
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

class _MetricItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}