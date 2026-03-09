import 'dart:async';
import 'dart:math' as math;
import 'package:environment_sensors/environment_sensors.dart';

/// Service for managing barometric pressure readings and calculating pressure altitude.
/// 
/// Provides real-time pressure altitude calculations for more accurate aviation
/// altitude measurements compared to GPS altitude.
class BarometricService {
  final EnvironmentSensors _environmentSensors = EnvironmentSensors();
  StreamSubscription<double>? _pressureSubscription;
  final StreamController<double> _pressureController = StreamController<double>.broadcast();
  final StreamController<int> _altitudeController = StreamController<int>.broadcast();
  
  // Current readings
  double? _currentPressureHPa;
  double _referencePressureHPa = 1013.25; // Standard sea level pressure
  bool _isActive = false;
  bool _sensorAvailable = false;
  
  // Calibration settings
  int? _calibrationOffsetM;
  bool _needsCalibration = true;
  
  /// Stream of barometric pressure readings in hectopascals (hPa)
  Stream<double> get pressureStream => _pressureController.stream;
  
  /// Stream of calculated pressure altitude in meters
  Stream<int> get altitudeStream => _altitudeController.stream;
  
  /// Current barometric pressure in hPa
  double? get currentPressure => _currentPressureHPa;
  
  /// Current pressure altitude in meters
  int? get currentAltitude {
    if (_currentPressureHPa == null) return null;
    final rawAltitude = calculatePressureAltitude(_currentPressureHPa!, _referencePressureHPa);
    return _calibrationOffsetM != null ? rawAltitude + _calibrationOffsetM! : rawAltitude;
  }
  
  /// Whether barometric sensor is available and active
  bool get isActive => _isActive;
  
  /// Whether altitude needs GPS calibration
  bool get needsCalibration => _needsCalibration;
  
  /// Initialize barometric sensor
  Future<bool> initialize() async {
    try {
      // Check if pressure sensor is available
      _sensorAvailable = await _environmentSensors.getSensorAvailable(SensorType.Pressure);
      if (!_sensorAvailable) {
        print('Barometric pressure sensor not available on this device');
        return false;
      }
      print('Barometric pressure sensor available');
      return true;
    } catch (e) {
      print('Barometric sensor initialization error: $e');
      return false;
    }
  }
  
  /// Start barometric pressure monitoring
  Future<bool> startMonitoring() async {
    if (_isActive) return true;
    
    if (!_sensorAvailable) {
      print('Cannot start monitoring: sensor not available');
      return false;
    }
    
    try {
      _pressureSubscription = _environmentSensors.pressure.listen(
        _handlePressureUpdate,
        onError: (error) {
          print('Barometer error: $error');
          _isActive = false;
        },
      );
      
      _isActive = true;
      print('Barometric monitoring started');
      return true;
    } catch (e) {
      print('Failed to start barometric monitoring: $e');
      _isActive = false;
      return false;
    }
  }
  
  /// Stop barometric pressure monitoring
  Future<void> stopMonitoring() async {
    await _pressureSubscription?.cancel();
    _pressureSubscription = null;
    _isActive = false;
    print('Barometric monitoring stopped');
  }
  
  /// Calibrate pressure altitude using GPS reference
  void calibrateWithGPS(int gpsAltitudeM) {
    if (_currentPressureHPa == null) {
      print('Cannot calibrate: no barometric reading available');
      return;
    }
    
    final rawPressureAltitude = calculatePressureAltitude(_currentPressureHPa!, _referencePressureHPa);
    _calibrationOffsetM = gpsAltitudeM - rawPressureAltitude;
    _needsCalibration = false;
    
    print('Barometric altitude calibrated: offset ${_calibrationOffsetM}m (GPS: ${gpsAltitudeM}m, Raw pressure: ${rawPressureAltitude}m)');
  }
  
  /// Set custom reference pressure (QNH) for more accurate local altitude
  void setReferencePressure(double pressureHPa) {
    _referencePressureHPa = pressureHPa;
    _needsCalibration = false; // Manual pressure setting doesn't need GPS calibration
    print('Reference pressure set to ${pressureHPa.toStringAsFixed(2)} hPa');
  }
  
  /// Reset to standard sea level pressure
  void resetToStandardPressure() {
    _referencePressureHPa = 1013.25;
    _calibrationOffsetM = null;
    _needsCalibration = true;
    print('Reset to standard pressure (1013.25 hPa)');
  }
  
  /// Handle pressure sensor updates from environment_sensors
  void _handlePressureUpdate(double pressureHPa) {
    _currentPressureHPa = pressureHPa;
    _pressureController.add(pressureHPa);
    
    // Calculate and emit pressure altitude
    if (currentAltitude != null) {
      _altitudeController.add(currentAltitude!);
    }
  }
  
  /// Calculate pressure altitude using international standard atmosphere
  /// Formula: h = 44330 * (1 - (P/P0)^(1/5.255))
  static int calculatePressureAltitude(double pressureHPa, double referencePressureHPa) {
    if (pressureHPa <= 0 || referencePressureHPa <= 0) return 0;
    
    final altitudeM = 44330.0 * (1.0 - math.pow(pressureHPa / referencePressureHPa, 1.0 / 5.255));
    return altitudeM.round();
  }
  
  /// Get current barometric status for debugging
  Map<String, dynamic> getStatus() {
    return {
      'is_active': _isActive,
      'current_pressure_hpa': _currentPressureHPa?.toStringAsFixed(2),
      'current_altitude_m': currentAltitude,
      'reference_pressure_hpa': _referencePressureHPa.toStringAsFixed(2),
      'calibration_offset_m': _calibrationOffsetM,
      'needs_calibration': _needsCalibration,
    };
  }
  
  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _pressureController.close();
    _altitudeController.close();
  }
}