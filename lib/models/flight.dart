/// Flight model representing a recorded paragliding flight session.
/// 
/// Each flight is associated with a glider and contains GPS fix data.
/// Flights track takeoff and landing times detected automatically.
class Flight {
  final int? id;
  final int gliderId;
  final DateTime startedAt;
  final DateTime? takeoffAt;
  final DateTime? landedAt;
  final int durationSec;
  final int fixCount;
  final String? igcPath;
  final DateTime createdAt;

  const Flight({
    this.id,
    required this.gliderId,
    required this.startedAt,
    this.takeoffAt,
    this.landedAt,
    required this.durationSec,
    required this.fixCount,
    this.igcPath,
    required this.createdAt,
  });

  /// Creates a new flight with current timestamp
  factory Flight.create({
    required int gliderId,
    required DateTime startedAt,
    DateTime? takeoffAt,
    DateTime? landedAt,
    int durationSec = 0,
    int fixCount = 0,
    String? igcPath,
  }) {
    return Flight(
      gliderId: gliderId,
      startedAt: startedAt,
      takeoffAt: takeoffAt,
      landedAt: landedAt,
      durationSec: durationSec,
      fixCount: fixCount,
      igcPath: igcPath,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields
  Flight copyWith({
    int? id,
    int? gliderId,
    DateTime? startedAt,
    DateTime? takeoffAt,
    DateTime? landedAt,
    int? durationSec,
    int? fixCount,
    String? igcPath,
    DateTime? createdAt,
  }) {
    return Flight(
      id: id ?? this.id,
      gliderId: gliderId ?? this.gliderId,
      startedAt: startedAt ?? this.startedAt,
      takeoffAt: takeoffAt ?? this.takeoffAt,
      landedAt: landedAt ?? this.landedAt,
      durationSec: durationSec ?? this.durationSec,
      fixCount: fixCount ?? this.fixCount,
      igcPath: igcPath ?? this.igcPath,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Whether this flight has completed (has takeoff and landing)
  bool get isCompleted {
    return takeoffAt != null && landedAt != null;
  }

  /// Whether this flight is currently in progress
  bool get isInProgress {
    return takeoffAt != null && landedAt == null;
  }

  /// Whether this flight is waiting for takeoff
  bool get isWaitingForTakeoff {
    return takeoffAt == null;
  }

  /// Actual flight duration (between takeoff and landing)
  Duration? get flightDuration {
    if (takeoffAt == null || landedAt == null) return null;
    return landedAt!.difference(takeoffAt!);
  }

  /// Total recording duration
  Duration get recordingDuration {
    return Duration(seconds: durationSec);
  }

  /// Formatted flight duration string
  String get formattedFlightDuration {
    final duration = flightDuration;
    if (duration == null) return '--:--';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Formatted recording duration string
  String get formattedRecordingDuration {
    final duration = recordingDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  /// Formatted date for display
  String get formattedDate {
    return '${startedAt.day}/${startedAt.month}/${startedAt.year}';
  }

  /// Time range string for display
  String get timeRange {
    final start = '${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}';
    
    if (landedAt != null) {
      final end = '${landedAt!.hour.toString().padLeft(2, '0')}:${landedAt!.minute.toString().padLeft(2, '0')}';
      return '$start - $end';
    } else if (takeoffAt != null) {
      return '$start - In Progress';
    } else {
      return '$start - Waiting';
    }
  }

  /// Converts flight to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'glider_id': gliderId,
      'started_at': startedAt.millisecondsSinceEpoch,
      'takeoff_at': takeoffAt?.millisecondsSinceEpoch,
      'landed_at': landedAt?.millisecondsSinceEpoch,
      'duration_sec': durationSec,
      'fix_count': fixCount,
      'igc_path': igcPath,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Creates flight from database map
  factory Flight.fromMap(Map<String, dynamic> map) {
    return Flight(
      id: map['id'] as int?,
      gliderId: map['glider_id'] as int,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      takeoffAt: map['takeoff_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['takeoff_at'] as int)
          : null,
      landedAt: map['landed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['landed_at'] as int)
          : null,
      durationSec: map['duration_sec'] as int,
      fixCount: map['fix_count'] as int,
      igcPath: map['igc_path'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Returns map without ID for inserts
  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  @override
  String toString() {
    return 'Flight{id: $id, gliderId: $gliderId, startedAt: $startedAt, '
        'isCompleted: $isCompleted, duration: $formattedRecordingDuration, fixCount: $fixCount}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Flight &&
        other.id == id &&
        other.gliderId == gliderId &&
        other.startedAt == startedAt &&
        other.takeoffAt == takeoffAt &&
        other.landedAt == landedAt &&
        other.durationSec == durationSec &&
        other.fixCount == fixCount;
  }

  @override
  int get hashCode {
    return Object.hash(id, gliderId, startedAt, takeoffAt, landedAt, durationSec, fixCount);
  }
}