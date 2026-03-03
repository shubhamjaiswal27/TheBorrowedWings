import 'dart:math' as math;
import 'package:location/location.dart';
import '../models/flight_fix.dart';

/// Configuration constants for takeoff and landing detection.
/// These values can be easily tweaked for different flying conditions.
class TakeoffLandingConfig {
  /// Minimum speed in m/s to consider for takeoff detection
  static const double minTakeoffSpeedMps = 2.0; // ~7.2 km/h
  
  /// Duration in seconds of sustained movement required for takeoff
  static const int takeoffSustainedMovementSec = 10;
  
  /// Maximum speed in m/s below which landing is considered
  static const double maxLandingSpeedMps = 1.0; // ~3.6 km/h
  
  /// Duration in seconds of sustained low movement for landing
  static const int landingSustainedStopSec = 15;
  
  /// Maximum distance variance in meters for landing detection
  static const double maxLandingDistanceVarianceM = 50.0;
  
  /// Minimum altitude change rate (m/s) to consider climbing vs descending
  static const double minClimbRateMps = 0.5;
  
  /// Window size for calculating movement averages
  static const int movementWindowSize = 5;
  
  /// Minimum number of fixes required before takeoff detection
  static const int minFixesForTakeoff = 3;
  
  /// Minimum number of fixes required for landing detection
  static const int minFixesForLanding = 5;
}

/// States of the flight detection state machine
enum FlightDetectionState {
  /// Recording started, waiting for takeoff detection
  waitingForTakeoff,
  /// Takeoff detected, currently in flight
  inFlight,
  /// Landing detected, flight completed
  landed,
}

/// Result of takeoff/landing detection analysis
class DetectionResult {
  final FlightDetectionState? newState;
  final DateTime? eventTimestamp;
  final String reason;
  final Map<String, dynamic> debugData;

  const DetectionResult({
    this.newState,
    this.eventTimestamp,
    required this.reason,
    this.debugData = const {},
  });

  bool get hasStateChange => newState != null;
  bool get hasTakeoff => newState == FlightDetectionState.inFlight;
  bool get hasLanding => newState == FlightDetectionState.landed;

  @override
  String toString() {
    return 'DetectionResult{newState: $newState, '
        'eventTimestamp: $eventTimestamp, reason: $reason}';
  }
}

/// Takeoff and landing detection logic with configurable thresholds.
/// 
/// Uses a sliding window approach to analyze GPS fixes and determine
/// when takeoff and landing events occur based on speed, distance, and
/// movement patterns.
class TakeoffLandingDetector {
  final List<FlightFix> _recentFixes = [];
  FlightDetectionState _currentState = FlightDetectionState.waitingForTakeoff;
  
  DateTime? _takeoffTimestamp;
  DateTime? _landingTimestamp;

  /// Current detection state
  FlightDetectionState get currentState => _currentState;

  /// Detected takeoff timestamp
  DateTime? get takeoffTimestamp => _takeoffTimestamp;

  /// Detected landing timestamp  
  DateTime? get landingTimestamp => _landingTimestamp;

  /// Process a new GPS fix and return detection result
  DetectionResult processLocationUpdate(LocationData locationData, int sequenceNumber) {
    final now = DateTime.now();
    final fix = FlightFix.create(
      flightId: '', // Will be set when saving to database
      timestamp: _getTimestamp(locationData, now),
      latitude: locationData.latitude!,
      longitude: locationData.longitude!,
      gpsAltitudeM: locationData.altitude?.round(),
      speedMps: locationData.speed,
      accuracyM: locationData.accuracy,
      sequenceNumber: sequenceNumber,
    );

    return processFlightFix(fix);
  }

  /// Process a new flight fix and determine state changes
  DetectionResult processFlightFix(FlightFix fix) {
    // Add fix to sliding window
    _recentFixes.add(fix);
    
    // Keep only recent fixes within the analysis window
    final cutoffTime = fix.timestamp.subtract(
      Duration(seconds: math.max(
        TakeoffLandingConfig.takeoffSustainedMovementSec,
        TakeoffLandingConfig.landingSustainedStopSec,
      ) + 5)
    );
    _recentFixes.removeWhere((f) => f.timestamp.isBefore(cutoffTime));

    switch (_currentState) {
      case FlightDetectionState.waitingForTakeoff:
        return _checkForTakeoff(fix);
      
      case FlightDetectionState.inFlight:
        return _checkForLanding(fix);
      
      case FlightDetectionState.landed:
        return DetectionResult(reason: 'Already landed');
    }
  }

  /// Check if takeoff conditions are met
  DetectionResult _checkForTakeoff(FlightFix currentFix) {
    if (_recentFixes.length < TakeoffLandingConfig.minFixesForTakeoff) {
      return DetectionResult(reason: 'Insufficient fixes for takeoff detection');
    }

    // Get fixes from the sustained movement window
    final windowStart = currentFix.timestamp.subtract(
      Duration(seconds: TakeoffLandingConfig.takeoffSustainedMovementSec)
    );
    final windowFixes = _recentFixes
        .where((f) => f.timestamp.isAfter(windowStart))
        .toList();

    if (windowFixes.length < TakeoffLandingConfig.minFixesForTakeoff) {
      return DetectionResult(reason: 'Not enough fixes in takeoff window');
    }

    // Check sustained speed criteria
    final sustainedMovement = _checkSustainedMovement(
      windowFixes,
      TakeoffLandingConfig.minTakeoffSpeedMps,
    );

    if (!sustainedMovement.isSustained) {
      return DetectionResult(
        reason: 'Speed not sustained: ${sustainedMovement.averageSpeedKmh.toStringAsFixed(1)} km/h avg',
        debugData: {
          'average_speed_kmh': sustainedMovement.averageSpeedKmh,
          'min_speed_kmh': sustainedMovement.minSpeedKmh,
          'fixes_above_threshold': sustainedMovement.fixesAboveThreshold,
          'total_fixes': windowFixes.length,
        },
      );
    }

    // Check altitude trend (optional - should not be decreasing sharply)
    final altitudeTrend = _calculateAltitudeTrend(windowFixes);
    if (altitudeTrend.isDescending && altitudeTrend.ratePerSec < -TakeoffLandingConfig.minClimbRateMps) {
      return DetectionResult(
        reason: 'Descending too fast for takeoff: ${altitudeTrend.ratePerSec.toStringAsFixed(1)} m/s',
        debugData: {'altitude_rate': altitudeTrend.ratePerSec},
      );
    }

    // Takeoff detected!
    _currentState = FlightDetectionState.inFlight;
    _takeoffTimestamp = windowFixes.first.timestamp;

    return DetectionResult(
      newState: FlightDetectionState.inFlight,
      eventTimestamp: _takeoffTimestamp,
      reason: 'Takeoff detected: sustained speed ${sustainedMovement.averageSpeedKmh.toStringAsFixed(1)} km/h',
      debugData: {
        'average_speed_kmh': sustainedMovement.averageSpeedKmh,
        'altitude_trend': altitudeTrend.ratePerSec,
        'takeoff_fix_count': windowFixes.length,
      },
    );
  }

  /// Check if landing conditions are met
  DetectionResult _checkForLanding(FlightFix currentFix) {
    if (_recentFixes.length < TakeoffLandingConfig.minFixesForLanding) {
      return DetectionResult(reason: 'Insufficient fixes for landing detection');
    }

    // Get fixes from the sustained stop window
    final windowStart = currentFix.timestamp.subtract(
      Duration(seconds: TakeoffLandingConfig.landingSustainedStopSec)
    );
    final windowFixes = _recentFixes
        .where((f) => f.timestamp.isAfter(windowStart))
        .toList();

    if (windowFixes.length < TakeoffLandingConfig.minFixesForLanding) {
      return DetectionResult(reason: 'Not enough fixes in landing window');
    }

    // Check sustained low speed
    final sustainedStop = _checkSustainedMovement(
      windowFixes,
      TakeoffLandingConfig.maxLandingSpeedMps,
      isForLanding: true,
    );

    if (!sustainedStop.isSustained) {
      return DetectionResult(
        reason: 'Speed too high for landing: ${sustainedStop.averageSpeedKmh.toStringAsFixed(1)} km/h avg',
        debugData: {
          'average_speed_kmh': sustainedStop.averageSpeedKmh,
          'max_speed_kmh': sustainedStop.maxSpeedKmh,
        },
      );
    }

    // Check position variance (should be low for landing)
    final positionVariance = _calculatePositionVariance(windowFixes);
    if (positionVariance.maxDistanceM > TakeoffLandingConfig.maxLandingDistanceVarianceM) {
      return DetectionResult(
        reason: 'Too much movement for landing: ${positionVariance.maxDistanceM.toStringAsFixed(1)}m variance',
        debugData: {'position_variance_m': positionVariance.maxDistanceM},
      );
    }

    // Landing detected!
    _currentState = FlightDetectionState.landed;
    _landingTimestamp = windowFixes.last.timestamp;

    return DetectionResult(
      newState: FlightDetectionState.landed,
      eventTimestamp: _landingTimestamp,
      reason: 'Landing detected: sustained low speed ${sustainedStop.averageSpeedKmh.toStringAsFixed(1)} km/h',
      debugData: {
        'average_speed_kmh': sustainedStop.averageSpeedKmh,
        'position_variance_m': positionVariance.maxDistanceM,
        'landing_fix_count': windowFixes.length,
      },
    );
  }

  /// Check if movement is sustained above/below threshold
  MovementAnalysis _checkSustainedMovement(
    List<FlightFix> fixes,
    double thresholdMps, {
    bool isForLanding = false,
  }) {
    if (fixes.isEmpty) {
      return MovementAnalysis(
        isSustained: false,
        averageSpeedKmh: 0,
        minSpeedKmh: 0,
        maxSpeedKmh: 0,
        fixesAboveThreshold: 0,
      );
    }

    final speeds = fixes
        .where((f) => f.speedMps != null)
        .map((f) => f.speedMps!)
        .toList();

    if (speeds.isEmpty) {
      return MovementAnalysis(
        isSustained: false,
        averageSpeedKmh: 0,
        minSpeedKmh: 0,
        maxSpeedKmh: 0,
        fixesAboveThreshold: 0,
      );
    }

    final avgSpeed = speeds.reduce((a, b) => a + b) / speeds.length;
    final minSpeed = speeds.reduce(math.min);
    final maxSpeed = speeds.reduce(math.max);

    if (isForLanding) {
      // For landing: all speeds should be below threshold
      final fixesBelowThreshold = speeds.where((s) => s <= thresholdMps).length;
      final isSustained = fixesBelowThreshold >= (speeds.length * 0.8); // 80% of fixes

      return MovementAnalysis(
        isSustained: isSustained,
        averageSpeedKmh: avgSpeed * 3.6,
        minSpeedKmh: minSpeed * 3.6,
        maxSpeedKmh: maxSpeed * 3.6,
        fixesAboveThreshold: speeds.length - fixesBelowThreshold,
      );
    } else {
      // For takeoff: most speeds should be above threshold
      final fixesAboveThreshold = speeds.where((s) => s >= thresholdMps).length;
      final isSustained = fixesAboveThreshold >= (speeds.length * 0.7); // 70% of fixes

      return MovementAnalysis(
        isSustained: isSustained,
        averageSpeedKmh: avgSpeed * 3.6,
        minSpeedKmh: minSpeed * 3.6,
        maxSpeedKmh: maxSpeed * 3.6,
        fixesAboveThreshold: fixesAboveThreshold,
      );
    }
  }

  /// Calculate altitude trend over fixes
  AltitudeTrend _calculateAltitudeTrend(List<FlightFix> fixes) {
    final fixesWithAlt = fixes.where((f) => f.bestAltitudeM != null).toList();
    
    if (fixesWithAlt.length < 2) {
      return AltitudeTrend(ratePerSec: 0, isAscending: false, isDescending: false);
    }

    final first = fixesWithAlt.first;
    final last = fixesWithAlt.last;
    
    final altChange = last.bestAltitudeM! - first.bestAltitudeM!;
    final timeChange = last.timestamp.difference(first.timestamp).inMilliseconds / 1000.0;
    
    if (timeChange <= 0) {
      return AltitudeTrend(ratePerSec: 0, isAscending: false, isDescending: false);
    }
    
    final rate = altChange / timeChange;
    
    return AltitudeTrend(
      ratePerSec: rate,
      isAscending: rate > TakeoffLandingConfig.minClimbRateMps,
      isDescending: rate < -TakeoffLandingConfig.minClimbRateMps,
    );
  }

  /// Calculate position variance for landing detection
  PositionVariance _calculatePositionVariance(List<FlightFix> fixes) {
    if (fixes.length < 2) {
      return PositionVariance(maxDistanceM: 0, averageDistanceM: 0);
    }

    final distances = <double>[];
    for (int i = 1; i < fixes.length; i++) {
      final distance = fixes[i-1].distanceToFix(fixes[i]);
      distances.add(distance);
    }

    final maxDistance = distances.isNotEmpty ? distances.reduce(math.max) : 0.0;
    final avgDistance = distances.isNotEmpty 
        ? distances.reduce((a, b) => a + b) / distances.length 
        : 0.0;

    return PositionVariance(
      maxDistanceM: maxDistance,
      averageDistanceM: avgDistance,
    );
  }

  /// Reset detector state (for new flight)
  void reset() {
    _recentFixes.clear();
    _currentState = FlightDetectionState.waitingForTakeoff;
    _takeoffTimestamp = null;
    _landingTimestamp = null;
  }

  /// Handle manual stop button press
  DetectionResult handleManualStop() {
    switch (_currentState) {
      case FlightDetectionState.waitingForTakeoff:
        return DetectionResult(
          reason: 'Manual stop before takeoff - session discarded',
        );
      
      case FlightDetectionState.inFlight:
        // Use last fix as landing
        final lastFix = _recentFixes.isNotEmpty ? _recentFixes.last : null;
        _currentState = FlightDetectionState.landed;
        _landingTimestamp = lastFix?.timestamp ?? DateTime.now();
        
        return DetectionResult(
          newState: FlightDetectionState.landed,
          eventTimestamp: _landingTimestamp,
          reason: 'Manual stop during flight - using last position as landing',
        );
      
      case FlightDetectionState.landed:
        return DetectionResult(reason: 'Already landed');
    }
  }

  /// Helper method to safely extract timestamp from LocationData
  DateTime _getTimestamp(LocationData locationData, DateTime fallback) {
    // For now, just return the fallback time since LocationData timestamp
    // access is inconsistent across different versions of the location package
    return fallback;
  }
}

/// Analysis result for movement patterns
class MovementAnalysis {
  final bool isSustained;
  final double averageSpeedKmh;
  final double minSpeedKmh;
  final double maxSpeedKmh;
  final int fixesAboveThreshold;

  const MovementAnalysis({
    required this.isSustained,
    required this.averageSpeedKmh,
    required this.minSpeedKmh,
    required this.maxSpeedKmh,
    required this.fixesAboveThreshold,
  });
}

/// Altitude trend analysis
class AltitudeTrend {
  final double ratePerSec;
  final bool isAscending;
  final bool isDescending;

  const AltitudeTrend({
    required this.ratePerSec,
    required this.isAscending,
    required this.isDescending,
  });
}

/// Position variance analysis for landing detection
class PositionVariance {
  final double maxDistanceM;
  final double averageDistanceM;

  const PositionVariance({
    required this.maxDistanceM,
    required this.averageDistanceM,
  });
}