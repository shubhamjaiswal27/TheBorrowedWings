import 'package:flutter_test/flutter_test.dart';
import 'package:location/location.dart';
import 'package:the_borrowed_wings/services/takeoff_landing_detector.dart';
import 'package:the_borrowed_wings/models/flight_fix.dart';

void main() {
  group('TakeoffLandingDetector', () {
    late TakeoffLandingDetector detector;

    setUp(() {
      detector = TakeoffLandingDetector();
    });

    group('Initial State', () {
      test('should start in waiting for takeoff state', () {
        expect(detector.currentState, FlightDetectionState.waitingForTakeoff);
        expect(detector.takeoffTimestamp, isNull);
        expect(detector.landingTimestamp, isNull);
      });
    });

    group('Takeoff Detection', () {
      test('should not detect takeoff with insufficient fixes', () {
        final locationData = _createLocationData(
          latitude: 45.0,
          longitude: 8.0,
          speed: 5.0, // Above threshold
        );

        final result = detector.processLocationUpdate(locationData, 1);

        expect(result.hasStateChange, isFalse);
        expect(result.reason, contains('Insufficient fixes'));
      });

      test('should not detect takeoff with low sustained speed', () {
        // Add several fixes with low speed
        for (int i = 1; i <= 5; i++) {
          final locationData = _createLocationData(
            latitude: 45.0 + (i * 0.0001),
            longitude: 8.0 + (i * 0.0001),
            speed: 1.0, // Below threshold (2.0 m/s)
            timestamp: DateTime.now().add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i);
          expect(result.hasStateChange, isFalse);
        }
      });

      test('should detect takeoff with sustained movement above threshold', () {
        final baseTime = DateTime.now();
        
        // Add fixes with sustained speed above threshold
        DetectionResult? takeoffResult;
        for (int i = 1; i <= 15; i++) {
          final locationData = _createLocationData(
            latitude: 45.0 + (i * 0.001), // Moving
            longitude: 8.0 + (i * 0.001),
            speed: 3.0, // Above threshold (2.0 m/s)
            timestamp: baseTime.add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i);
          if (result.hasTakeoff) {
            takeoffResult = result;
            break;
          }
        }

        expect(takeoffResult, isNotNull);
        expect(takeoffResult!.hasTakeoff, isTrue);
        expect(detector.currentState, FlightDetectionState.inFlight);
        expect(detector.takeoffTimestamp, isNotNull);
      });

      test('should not detect takeoff with short speed spike', () {
        final baseTime = DateTime.now();
        
        // Add mostly low speed fixes with a few high speed ones
        for (int i = 1; i <= 10; i++) {
          final speed = (i == 5 || i == 6) ? 4.0 : 1.0; // Short spike
          final locationData = _createLocationData(
            latitude: 45.0 + (i * 0.0001),
            longitude: 8.0 + (i * 0.0001),
            speed: speed,
            timestamp: baseTime.add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i);
          expect(result.hasTakeoff, isFalse);
        }
      });

      test('should not detect takeoff when descending rapidly', () {
        final baseTime = DateTime.now();
        
        // Add fixes with good speed but descending altitude
        for (int i = 1; i <= 12; i++) {
          final locationData = _createLocationData(
            latitude: 45.0 + (i * 0.001),
            longitude: 8.0 + (i * 0.001),
            speed: 3.0, // Above threshold
            altitude: 1000 - (i * 5), // Rapidly descending
            timestamp: baseTime.add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i);
          if (i >= 10) {
            // Should not detect takeoff due to descending
            expect(result.hasTakeoff, isFalse);
          }
        }
      });
    });

    group('Landing Detection', () {
      setUp(() {
        // First trigger takeoff
        _triggerTakeoff(detector);
      });

      test('should detect landing with sustained low speed and low movement', () {
        final baseTime = DateTime.now().add(Duration(minutes: 10));
        final baseLocation = [45.1, 8.1]; // Landing location
        
        // Add fixes with low speed and minimal movement
        DetectionResult? landingResult;
        for (int i = 1; i <= 20; i++) {
          final locationData = _createLocationData(
            latitude: baseLocation[0] + (i * 0.00001), // Minimal movement
            longitude: baseLocation[1] + (i * 0.00001),
            speed: 0.5, // Below landing threshold (1.0 m/s)
            timestamp: baseTime.add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i + 100);
          if (result.hasLanding) {
            landingResult = result;
            break;
          }
        }

        expect(landingResult, isNotNull);
        expect(landingResult!.hasLanding, isTrue);
        expect(detector.currentState, FlightDetectionState.landed);
        expect(detector.landingTimestamp, isNotNull);
      });

      test('should not detect landing with high speed', () {
        final baseTime = DateTime.now().add(Duration(minutes: 5));
        
        // Add fixes with high speed (still flying)
        for (int i = 1; i <= 20; i++) {
          final locationData = _createLocationData(
            latitude: 45.1 + (i * 0.0001),
            longitude: 8.1 + (i * 0.0001),
            speed: 5.0, // Above landing threshold
            timestamp: baseTime.add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i + 50);
          expect(result.hasLanding, isFalse);
        }
      });

      test('should not detect landing with too much position variance', () {
        final baseTime = DateTime.now().add(Duration(minutes: 5));
        
        // Add fixes with low speed but high position variance
        for (int i = 1; i <= 20; i++) {
          final locationData = _createLocationData(
            latitude: 45.1 + (i * 0.002), // High movement (>50m variance)
            longitude: 8.1 + (i * 0.002),
            speed: 0.5, // Low speed
            timestamp: baseTime.add(Duration(seconds: i)),
          );

          final result = detector.processLocationUpdate(locationData, i + 50);
          expect(result.hasLanding, isFalse);
        }
      });
    });

    group('Manual Stop Handling', () {
      test('should discard session when stopped before takeoff', () {
        // In waiting state, not yet taken off
        final result = detector.handleManualStop();

        expect(result.reason, contains('session discarded'));
        expect(result.hasStateChange, isFalse);
      });

      test('should finalize flight when stopped during flight', () {
        // Trigger takeoff first
        _triggerTakeoff(detector);
        
        expect(detector.currentState, FlightDetectionState.inFlight);
        
        final result = detector.handleManualStop();

        expect(result.hasStateChange, isTrue);
        expect(result.newState, FlightDetectionState.landed);
        expect(detector.currentState, FlightDetectionState.landed);
        expect(detector.landingTimestamp, isNotNull);
      });

      test('should handle stop when already landed', () {
        // Trigger takeoff and landing
        _triggerTakeoff(detector);
        _triggerLanding(detector);
        
        expect(detector.currentState, FlightDetectionState.landed);
        
        final result = detector.handleManualStop();

        expect(result.hasStateChange, isFalse);
        expect(result.reason, contains('Already landed'));
      });
    });

    group('State Reset', () {
      test('should reset all state for new flight', () {
        // Trigger takeoff
        _triggerTakeoff(detector);
        expect(detector.currentState, FlightDetectionState.inFlight);
        
        // Reset
        detector.reset();

        expect(detector.currentState, FlightDetectionState.waitingForTakeoff);
        expect(detector.takeoffTimestamp, isNull);
        expect(detector.landingTimestamp, isNull);
      });
    });

    group('Edge Cases', () {
      test('should handle invalid location data gracefully', () {
        final locationData = LocationData.fromMap({
          'latitude': null,
          'longitude': null,
          'timestamp': DateTime.now().millisecondsSinceEpoch.toDouble(),
        });

        expect(() {
          detector.processLocationUpdate(locationData, 1);
        }, throwsA(isA<TypeError>())); // Will throw when trying to access null lat/lon
      });

      test('should handle rapid state transitions', () {
        // Quickly trigger takeoff
        _triggerTakeoff(detector);
        expect(detector.currentState, FlightDetectionState.inFlight);
        
        // Immediately try to land
        _triggerLanding(detector);
        expect(detector.currentState, FlightDetectionState.landed);
      });
    });
  });
}

/// Helper function to create LocationData for testing
LocationData _createLocationData({
  required double latitude,
  required double longitude,
  double? speed,
  double? altitude,
  DateTime? timestamp,
  double? accuracy,
}) {
  return LocationData.fromMap({
    'latitude': latitude,
    'longitude': longitude,
    'speed': speed,
    'altitude': altitude,
    'timestamp': (timestamp ?? DateTime.now()).millisecondsSinceEpoch.toDouble(),
    'accuracy': accuracy ?? 5.0,
  });
}

/// Helper function to trigger takeoff detection
void _triggerTakeoff(TakeoffLandingDetector detector) {
  final baseTime = DateTime.now();
  
  // Add enough fixes with sustained speed to trigger takeoff
  for (int i = 1; i <= 15; i++) {
    final locationData = _createLocationData(
      latitude: 45.0 + (i * 0.001),
      longitude: 8.0 + (i * 0.001),
      speed: 3.0, // Above takeoff threshold
      altitude: 1000.0 + i, // Slightly climbing
      timestamp: baseTime.add(Duration(seconds: i)),
    );

    final result = detector.processLocationUpdate(locationData, i);
    if (result.hasTakeoff) break;
  }
}

/// Helper function to trigger landing detection
void _triggerLanding(TakeoffLandingDetector detector) {
  final baseTime = DateTime.now().add(Duration(minutes: 10));
  final baseLocation = [45.1, 8.1];
  
  // Add fixes with low speed and minimal movement
  for (int i = 1; i <= 20; i++) {
    final locationData = _createLocationData(
      latitude: baseLocation[0] + (i * 0.00001), // Minimal movement
      longitude: baseLocation[1] + (i * 0.00001),
      speed: 0.3, // Below landing threshold
      timestamp: baseTime.add(Duration(seconds: i)),
    );

    final result = detector.processLocationUpdate(locationData, i + 200);
    if (result.hasLanding) break;
  }
}