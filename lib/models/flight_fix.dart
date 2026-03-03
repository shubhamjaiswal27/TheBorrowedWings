import 'dart:math' as math;

/// FlightFix model representing a single GPS waypoint in a flight.
/// 
/// Contains timestamp, coordinates, altitude, speed, and accuracy data
/// collected during flight recording.
class FlightFix {
  final String? id;
  final String flightId; // Foreign key to flights table
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final int? gpsAltitudeM;
  final int? pressureAltitudeM;
  final double? speedMps;
  final double? accuracyM;
  final int sequenceNumber;

  const FlightFix({
    this.id,
    required this.flightId,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.gpsAltitudeM,
    this.pressureAltitudeM,
    this.speedMps,
    this.accuracyM,
    required this.sequenceNumber,
  });

  /// Creates a new flight fix
  factory FlightFix.create({
    required String flightId,
    required DateTime timestamp,
    required double latitude,
    required double longitude,
    int? gpsAltitudeM,
    int? pressureAltitudeM,
    double? speedMps,
    double? accuracyM,
    required int sequenceNumber,
  }) {
    return FlightFix(
      flightId: flightId,
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      gpsAltitudeM: gpsAltitudeM,
      pressureAltitudeM: pressureAltitudeM,
      speedMps: speedMps,
      accuracyM: accuracyM,
      sequenceNumber: sequenceNumber,
    );
  }

  /// Creates a copy with updated fields
  FlightFix copyWith({
    String? id,
    String? flightId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    int? gpsAltitudeM,
    int? pressureAltitudeM,
    double? speedMps,
    double? accuracyM,
    int? sequenceNumber,
  }) {
    return FlightFix(
      id: id ?? this.id,
      flightId: flightId ?? this.flightId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAltitudeM: gpsAltitudeM ?? this.gpsAltitudeM,
      pressureAltitudeM: pressureAltitudeM ?? this.pressureAltitudeM,
      speedMps: speedMps ?? this.speedMps,
      accuracyM: accuracyM ?? this.accuracyM,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  /// Best available altitude (prefers GPS over pressure altitude)
  int? get bestAltitudeM {
    return gpsAltitudeM ?? pressureAltitudeM;
  }

  /// Speed in km/h for display
  double? get speedKmh {
    return speedMps != null ? speedMps! * 3.6 : null;
  }

  /// Formatted time string (HH:MM:SS)
  String get formattedTime {
    return '${timestamp.hour.toString().padLeft(2, '0')}:'
        '${timestamp.minute.toString().padLeft(2, '0')}:'
        '${timestamp.second.toString().padLeft(2, '0')}';
  }

  /// Formatted coordinates string for display
  String get formattedCoordinates {
    final lat = latitude.toStringAsFixed(6);
    final lon = longitude.toStringAsFixed(6);
    return '$lat, $lon';
  }

  /// Whether this fix has good GPS accuracy
  bool get hasGoodAccuracy {
    return accuracyM != null && accuracyM! <= 10.0; // Within 10 meters
  }

  /// Whether this fix has altitude data
  bool get hasAltitude {
    return gpsAltitudeM != null || pressureAltitudeM != null;
  }

  /// Whether this fix has speed data
  bool get hasSpeed {
    return speedMps != null;
  }

  /// Distance to another fix in meters (Haversine formula)
  double distanceToFix(FlightFix other) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    final lat1Rad = latitude * (3.14159 / 180);
    final lat2Rad = other.latitude * (3.14159 / 180);
    final deltaLatRad = (other.latitude - latitude) * (3.14159 / 180);
    final deltaLonRad = (other.longitude - longitude) * (3.14159 / 180);

    final a = (deltaLatRad / 2).sin() * (deltaLatRad / 2).sin() +
        lat1Rad.cos() * lat2Rad.cos() *
        (deltaLonRad / 2).sin() * (deltaLonRad / 2).sin();
    final c = 2 * (a.sqrt()).asin();

    return earthRadius * c;
  }

  /// Time interval to another fix in seconds
  double timeIntervalToFix(FlightFix other) {
    return other.timestamp.difference(timestamp).inMilliseconds / 1000.0;
  }

  /// Converts flight fix to Supabase map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'flight_id': flightId,
      't': timestamp.toIso8601String(),
      'lat': latitude,
      'lon': longitude,
      'gps_alt_m': gpsAltitudeM,
      'pressure_alt_m': pressureAltitudeM,
      'speed_mps': speedMps,
      'accuracy_m': accuracyM,
      'seq': sequenceNumber,
    };
  }

  /// Creates flight fix from Supabase map
  factory FlightFix.fromMap(Map<String, dynamic> map) {
    return FlightFix(
      id: map['id'] as String?,
      flightId: map['flight_id'] as String,
      timestamp: DateTime.parse(map['t'] as String),
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lon'] as num).toDouble(),
      gpsAltitudeM: map['gps_alt_m'] as int?,
      pressureAltitudeM: map['pressure_alt_m'] as int?,
      speedMps: (map['speed_mps'] as num?)?.toDouble(),
      accuracyM: (map['accuracy_m'] as num?)?.toDouble(),
      sequenceNumber: map['seq'] as int,
    );
  }

  /// Returns map without ID for inserts
  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  /// Validates that coordinates are valid
  bool get isValid {
    return latitude >= -90 && latitude <= 90 && 
           longitude >= -180 && longitude <= 180;
  }

  @override
  String toString() {
    return 'FlightFix{id: $id, seq: $sequenceNumber, time: $formattedTime, '
        'lat: ${latitude.toStringAsFixed(6)}, lon: ${longitude.toStringAsFixed(6)}, '
        'alt: ${bestAltitudeM}m, speed: ${speedKmh?.toStringAsFixed(1)}km/h}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FlightFix &&
        other.id == id &&
        other.flightId == flightId &&
        other.timestamp == timestamp &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.sequenceNumber == sequenceNumber;
  }

  @override
  int get hashCode {
    return Object.hash(id, flightId, timestamp, latitude, longitude, sequenceNumber);
  }
}

/// Extension methods for math operations
extension MathExtensions on double {
  double sin() => math.sin(this);
  double cos() => math.cos(this);
  double asin() => math.asin(this);
  double sqrt() => math.sqrt(this);
}