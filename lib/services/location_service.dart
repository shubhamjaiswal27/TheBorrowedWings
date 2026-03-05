import 'dart:async';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as perm;

/// Location service for GPS tracking during flight recording.
/// 
/// Handles location permissions, GPS settings, and provides a stream
/// of location updates with configurable accuracy and intervals.
class LocationService {
  static const Duration _defaultLocationInterval = Duration(seconds: 1);
  static const double _defaultDistanceFilter = 0.0; // meters
  static const LocationAccuracy _defaultAccuracy = LocationAccuracy.high;

  final Location _location = Location();
  StreamSubscription<LocationData>? _locationSubscription;
  final StreamController<LocationData> _locationController = StreamController<LocationData>.broadcast();
  
  bool _isListening = false;
  LocationData? _lastKnownLocation;

  /// Clear all location state and stop tracking
  Future<void> clearState() async {
    await stopLocationUpdates();
    _lastKnownLocation = null;
  }

  /// Stream of location updates
  Stream<LocationData> get locationStream => _locationController.stream;

  /// Whether location tracking is currently active
  bool get isListening => _isListening;

  /// Last known location
  LocationData? get lastKnownLocation => _lastKnownLocation;

  /// Initialize location service and check permissions
  Future<LocationServiceStatus> initialize() async {
    try {
      // Check if location service is enabled on device
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) {
          return LocationServiceStatus.serviceDisabled;
        }
      }

      // Check and request location permission
      final permissionStatus = await perm.Permission.location.status;
      if (permissionStatus.isDenied) {
        final requestResult = await perm.Permission.location.request();
        if (requestResult.isDenied) {
          return LocationServiceStatus.permissionDenied;
        }
      }

      if (permissionStatus.isPermanentlyDenied) {
        return LocationServiceStatus.permissionPermanentlyDenied;
      }

      // Configure location settings for flight tracking
      await _location.changeSettings(
        accuracy: _defaultAccuracy,
        interval: _defaultLocationInterval.inMilliseconds,
        distanceFilter: _defaultDistanceFilter,
      );

      return LocationServiceStatus.ready;
    } catch (e) {
      return LocationServiceStatus.error;
    }
  }

  /// Start listening to location updates
  Future<bool> startLocationUpdates({
    Duration? interval,
    double? distanceFilter,
    LocationAccuracy? accuracy,
  }) async {
    if (_isListening) {
      return true; // Already listening
    }

    try {
      final status = await initialize();
      if (status != LocationServiceStatus.ready) {
        return false;
      }

      // Apply custom settings if provided
      if (interval != null || distanceFilter != null || accuracy != null) {
        await _location.changeSettings(
          accuracy: accuracy ?? _defaultAccuracy,
          interval: (interval ?? _defaultLocationInterval).inMilliseconds,
          distanceFilter: distanceFilter ?? _defaultDistanceFilter,
        );
      }

      // Start listening to location updates
      _locationSubscription = _location.onLocationChanged.listen(
        (LocationData locationData) {
          _lastKnownLocation = locationData;
          _locationController.add(locationData);
        },
        onError: (error) {
          _locationController.addError(LocationServiceError(
            'Location update error: $error',
            LocationServiceErrorType.updateFailed,
          ));
        },
      );

      _isListening = true;
      return true;
    } catch (e) {
      _locationController.addError(LocationServiceError(
        'Failed to start location updates: $e',
        LocationServiceErrorType.startFailed,
      ));
      return false;
    }
  }

  /// Stop listening to location updates
  Future<void> stopLocationUpdates() async {
    if (!_isListening) return;

    await _locationSubscription?.cancel();
    _locationSubscription = null;
    _isListening = false;
  }

  /// Get current location once (not continuous)
  Future<LocationData?> getCurrentLocation() async {
    try {
      final status = await initialize();
      if (status != LocationServiceStatus.ready) {
        return null;
      }

      return await _location.getLocation();
    } catch (e) {
      return null;
    }
  }

  /// Check if location permissions are granted
  Future<bool> hasLocationPermission() async {
    final status = await perm.Permission.location.status;
    return status.isGranted;
  }

  /// Open app settings for permission management
  Future<void> openAppSettings() async {
    await perm.openAppSettings();
  }

  /// Dispose of resources
  void dispose() {
    _locationSubscription?.cancel();
    _locationController.close();
    _isListening = false;
  }
}

/// Status of the location service initialization
enum LocationServiceStatus {
  /// Service is ready to use
  ready,
  /// Location service is disabled on device
  serviceDisabled,
  /// Location permission denied by user
  permissionDenied,
  /// Location permission permanently denied
  permissionPermanentlyDenied,
  /// Error occurred during initialization
  error,
}

/// Location service error with context
class LocationServiceError implements Exception {
  final String message;
  final LocationServiceErrorType type;

  const LocationServiceError(this.message, this.type);

  @override
  String toString() => 'LocationServiceError: $message';
}

/// Types of location service errors
enum LocationServiceErrorType {
  /// Failed to start location updates
  startFailed,
  /// Failed to get location update
  updateFailed,
  /// Permission related error
  permissionError,
  /// Service configuration error
  configurationError,
}

/// Extension methods for location data
extension LocationDataExtensions on LocationData {
  /// Whether this location has good accuracy for flight tracking
  bool get hasGoodAccuracy {
    return accuracy != null && accuracy! <= 15.0; // Within 15 meters
  }

  /// Whether this location has altitude data
  bool get hasAltitude {
    return altitude != null;
  }

  /// Whether this location has speed data
  bool get hasSpeed {
    return speed != null && speed! >= 0;
  }

  /// Speed in km/h
  double? get speedKmh {
    return speed != null ? speed! * 3.6 : null;
  }

  /// Altitude in meters as integer
  int? get altitudeMeters {
    return altitude?.round();
  }

  /// Whether location data is valid for flight tracking
  bool get isValidForFlight {
    return latitude != null && 
           longitude != null && 
           hasGoodAccuracy;
  }

  /// Create a formatted string for debugging
  String toDebugString() {
    return 'LocationData{lat: ${latitude?.toStringAsFixed(6)}, '
        'lon: ${longitude?.toStringAsFixed(6)}, '
        'alt: ${altitude?.toStringAsFixed(1)}m, '
        'speed: ${speedKmh?.toStringAsFixed(1)}km/h, '
        'accuracy: ${accuracy?.toStringAsFixed(1)}m}';
  }
}