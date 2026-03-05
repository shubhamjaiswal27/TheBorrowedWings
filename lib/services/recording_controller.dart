import 'dart:async';
import 'package:location/location.dart';
import '../models/flight.dart';
import '../models/flight_fix.dart';
import '../models/glider.dart';
import '../repositories/flight_repository.dart';
import '../services/auth_service.dart';
import 'location_service.dart';
import 'takeoff_landing_detector.dart';

/// Recording state of the flight session
enum RecordingState {
  /// Not recording
  idle,
  /// Recording started, waiting for takeoff detection
  waitingForTakeoff,
  /// In flight (takeoff detected)
  inFlight,
  /// Flight completed (landed)
  landed,
  /// Recording stopped manually or due to error
  stopped,
}

/// Current status information for UI display
class RecordingStatus {
  final RecordingState state;
  final Duration recordingDuration;
  final int fixCount;
  final DateTime? takeoffTime;
  final DateTime? landingTime;
  final LocationData? lastLocation;
  final String statusMessage;
  final Map<String, dynamic> debugInfo;

  const RecordingStatus({
    required this.state,
    required this.recordingDuration,
    required this.fixCount,
    this.takeoffTime,
    this.landingTime,
    this.lastLocation,
    required this.statusMessage,
    this.debugInfo = const {},
  });

  /// Whether recording is active
  bool get isRecording => state != RecordingState.idle && state != RecordingState.stopped;

  /// Whether flight is in progress
  bool get isInFlight => state == RecordingState.inFlight;

  /// Whether waiting for takeoff
  bool get isWaitingForTakeoff => state == RecordingState.waitingForTakeoff;

  /// Whether flight has completed
  bool get isCompleted => state == RecordingState.landed;

  /// Flight duration (between takeoff and landing)
  Duration? get flightDuration {
    if (takeoffTime == null) return null;
    final endTime = landingTime ?? DateTime.now();
    return endTime.difference(takeoffTime!);
  }
}

/// Flight recording controller that manages the entire recording lifecycle.
/// 
/// Coordinates location service, takeoff/landing detection, and database operations
/// to provide a complete flight recording solution with automatic phase detection.
class RecordingController {
  final LocationService _locationService;
  final TakeoffLandingDetector _detector;
  final FlightRepository _flightRepository;
  final AuthService _authService;

  RecordingState _state = RecordingState.idle;
  StreamSubscription<LocationData>? _locationSubscription;
  final StreamController<RecordingStatus> _statusController = StreamController<RecordingStatus>.broadcast();
  
  // Current session data
  Flight? _currentFlight;
  Glider? _selectedGlider;
  DateTime? _recordingStartTime;
  final List<FlightFix> _currentFixes = [];
  int _fixSequenceNumber = 0;
  LocationData? _lastLocationData;

  // Session statistics
  Timer? _statusTimer;

  /// Stream of recording status updates
  Stream<RecordingStatus> get statusStream => _statusController.stream;

  /// Current recording state
  RecordingState get state => _state;

  /// Current flight (if any)
  Flight? get currentFlight => _currentFlight;

  /// Clear all recording state and stop any ongoing recording
  Future<void> clearState() async {
    // Stop recording if active
    if (_state != RecordingState.idle) {
      await stopRecording();
    }
    
    // Clear all session data
    _currentFlight = null;
    _selectedGlider = null;
    _recordingStartTime = null;
    _currentFixes.clear();
    _fixSequenceNumber = 0;
    _lastLocationData = null;
    
    // Cancel timers
    _statusTimer?.cancel();
    _statusTimer = null;
    
    // Reset state
    _state = RecordingState.idle;
    
    print('Recording controller state cleared');
  }

  /// Selected glider for current session
  Glider? get selectedGlider => _selectedGlider;

  RecordingController({
    LocationService? locationService,
    TakeoffLandingDetector? detector,
    FlightRepository? flightRepository,
    AuthService? authService,
  }) : _locationService = locationService ?? LocationService(),
       _detector = detector ?? TakeoffLandingDetector(),
       _flightRepository = flightRepository ?? FlightRepository(),
       _authService = authService ?? AuthService();

  /// Start recording with the specified glider
  Future<bool> startRecording(Glider glider) async {
    if (_state != RecordingState.idle) {
      return false; // Already recording
    }

    // Check authentication
    if (!_authService.isAuthenticated) {
      _emitStatus('User not authenticated');
      return false;
    }

    try {
      _selectedGlider = glider;
      _recordingStartTime = DateTime.now();
      _currentFixes.clear();
      _fixSequenceNumber = 0;
      _detector.reset();

      // Initialize location service
      final locationStatus = await _locationService.initialize();
      if (locationStatus != LocationServiceStatus.ready) {
        _emitStatus('Location service not ready: $locationStatus');
        return false;
      }

      // Start location updates
      final started = await _locationService.startLocationUpdates();
      if (!started) {
        _emitStatus('Failed to start location updates');
        return false;
      }

      // Subscribe to location updates
      _locationSubscription = _locationService.locationStream.listen(
        _handleLocationUpdate,
        onError: _handleLocationError,
      );

      // Start status timer for UI updates
      _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _emitStatus('Recording started - waiting for takeoff');
      });

      _state = RecordingState.waitingForTakeoff;
      _emitStatus('Recording started with ${glider.displayName}');
      
      return true;
    } catch (e) {
      _emitStatus('Failed to start recording: $e');
      return false;
    }
  }

  /// Stop recording manually
  Future<Flight?> stopRecording() async {
    if (_state == RecordingState.idle || _state == RecordingState.stopped) {
      return null;
    }

    try {
      // Handle manual stop through detector
      final detectionResult = _detector.handleManualStop();
      
      if (detectionResult.hasStateChange) {
        await _handleDetectionResult(detectionResult);
      }

      // Stop location updates
      await _locationService.stopLocationUpdates();
      _locationSubscription?.cancel();
      _statusTimer?.cancel();

      final completedFlight = _currentFlight;

      // Save flight if we have takeoff (don't save if only waiting)
      if (_detector.takeoffTimestamp != null && _currentFixes.isNotEmpty) {
        await _saveFlight();
      }

      _state = RecordingState.stopped;
      _emitStatus('Recording stopped');

      return completedFlight;
    } catch (e) {
      _state = RecordingState.stopped;
      _emitStatus('Error stopping recording: $e');
      return null;
    }
  }

  /// Handle incoming location updates
  void _handleLocationUpdate(LocationData locationData) {
    if (!locationData.isValidForFlight) {
      return; // Skip invalid location data
    }

    _lastLocationData = locationData;
    _fixSequenceNumber++;

    // Process through detector
    final detectionResult = _detector.processLocationUpdate(locationData, _fixSequenceNumber);
    
    // Create and store fix
    final fix = FlightFix.create(
      flightId: '', // Will be set when saving
      timestamp: DateTime.now(), // Use current time instead of unreliable LocationData timestamp
      latitude: locationData.latitude!,
      longitude: locationData.longitude!,
      gpsAltitudeM: locationData.altitude?.round(),
      speedMps: locationData.speed,
      accuracyM: locationData.accuracy,
      sequenceNumber: _fixSequenceNumber,
    );

    _currentFixes.add(fix);

    // Handle detection results
    if (detectionResult.hasStateChange) {
      _handleDetectionResult(detectionResult);
    }

    // Emit current status
    _emitCurrentStatus(detectionResult.reason);
  }

  /// Handle location service errors
  void _handleLocationError(dynamic error) {
    _emitStatus('Location error: $error');
  }

  /// Handle takeoff/landing detection results
  Future<void> _handleDetectionResult(DetectionResult result) async {
    if (result.hasTakeoff) {
      _state = RecordingState.inFlight;
      _emitStatus('Takeoff detected! In flight...');
    } else if (result.hasLanding) {
      _state = RecordingState.landed;
      _emitStatus('Landing detected! Flight completed.');
      
      // Auto-save completed flight
      await _saveFlight();
    }
  }

  /// Save current flight to database
  Future<void> _saveFlight() async {
    if (_selectedGlider == null || _recordingStartTime == null) {
      return;
    }

    final userId = _authService.currentUserId;
    if (userId == null) {
      _emitStatus('User not authenticated');
      return;
    }

    try {
      // Filter fixes to only include those between takeoff and landing
      List<FlightFix> flightFixes = _currentFixes;
      
      if (_detector.takeoffTimestamp != null && _detector.landingTimestamp != null) {
        flightFixes = _currentFixes.where((fix) {
          return fix.timestamp.isAfter(_detector.takeoffTimestamp!) &&
                 fix.timestamp.isBefore(_detector.landingTimestamp!);
        }).toList();
      } else if (_detector.takeoffTimestamp != null) {
        // In case of manual stop, include fixes from takeoff onward
        flightFixes = _currentFixes.where((fix) {
          return fix.timestamp.isAfter(_detector.takeoffTimestamp!);
        }).toList();
      }

      if (flightFixes.isEmpty) {
        _emitStatus('No flight fixes to save');
        return;
      }

      // Calculate flight duration
      final duration = _detector.landingTimestamp != null && _detector.takeoffTimestamp != null
          ? _detector.landingTimestamp!.difference(_detector.takeoffTimestamp!).inSeconds
          : DateTime.now().difference(_recordingStartTime!).inSeconds;

      // Create flight record
      final flight = Flight.create(
        userId: userId,
        gliderId: _selectedGlider!.id!,
        startedAt: _recordingStartTime!,
        takeoffAt: _detector.takeoffTimestamp,
        landedAt: _detector.landingTimestamp,
        durationSec: duration,
        fixCount: flightFixes.length,
      );

      // Insert flight and get the saved flight with ID
      final savedFlight = await _flightRepository.createFlight(flight);
      _currentFlight = savedFlight;

      // Update fixes with correct flight ID and save in batch
      final fixesWithFlightId = flightFixes.map((fix) =>
          fix.copyWith(flightId: savedFlight.id!)).toList();
      
      await _flightRepository.addFlightFixesBatch(fixesWithFlightId);

      _emitStatus('Flight saved successfully!');
    } catch (e) {
      _emitStatus('Error saving flight: $e');
    }
  }

  /// Emit current recording status
  void _emitCurrentStatus(String message) {
    final recordingDuration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;

    final status = RecordingStatus(
      state: _state,
      recordingDuration: recordingDuration,
      fixCount: _currentFixes.length,
      takeoffTime: _detector.takeoffTimestamp,
      landingTime: _detector.landingTimestamp,
      lastLocation: _lastLocationData,
      statusMessage: message,
      debugInfo: {
        'detector_state': _detector.currentState.toString(),
        'glider': _selectedGlider?.displayName,
      },
    );

    _statusController.add(status);
  }

  /// Emit simple status message
  void _emitStatus(String message) {
    _emitCurrentStatus(message);
  }

  /// Get current status snapshot
  RecordingStatus getCurrentStatus() {
    final recordingDuration = _recordingStartTime != null
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;

    return RecordingStatus(
      state: _state,
      recordingDuration: recordingDuration,
      fixCount: _currentFixes.length,
      takeoffTime: _detector.takeoffTimestamp,
      landingTime: _detector.landingTimestamp,
      lastLocation: _lastLocationData,
      statusMessage: _getStatusMessage(),
    );
  }

  /// Get appropriate status message for current state
  String _getStatusMessage() {
    switch (_state) {
      case RecordingState.idle:
        return 'Ready to start recording';
      case RecordingState.waitingForTakeoff:
        return 'Recording - waiting for takeoff';
      case RecordingState.inFlight:
        return 'In flight';
      case RecordingState.landed:
        return 'Flight completed';
      case RecordingState.stopped:
        return 'Recording stopped';
    }
  }

  /// Clean up resources
  void dispose() {
    _locationSubscription?.cancel();
    _statusTimer?.cancel();
    _locationService.dispose();
    _statusController.close();
  }
}