/// Glider model representing paragliding equipment used in flights.
/// 
/// Each glider has basic metadata like manufacturer, model, and registration details.
/// Gliders are selected when starting a flight recording session.
class Glider {
  final int? id;
  final String? manufacturer;
  final String model;
  final String? gliderId;  // registration or serial number
  final String? wingClass;
  final String? notes;
  final DateTime createdAt;

  const Glider({
    this.id,
    this.manufacturer,
    required this.model,
    this.gliderId,
    this.wingClass,
    this.notes,
    required this.createdAt,
  });

  /// Creates a new glider with current timestamp
  factory Glider.create({
    String? manufacturer,
    required String model,
    String? gliderId,
    String? wingClass,
    String? notes,
  }) {
    return Glider(
      manufacturer: manufacturer,
      model: model,
      gliderId: gliderId,
      wingClass: wingClass,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields
  Glider copyWith({
    int? id,
    String? manufacturer,
    String? model,
    String? gliderId,
    String? wingClass,
    String? notes,
    DateTime? createdAt,
  }) {
    return Glider(
      id: id ?? this.id,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      gliderId: gliderId ?? this.gliderId,
      wingClass: wingClass ?? this.wingClass,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Display name for UI
  String get displayName {
    final parts = <String>[];
    if (manufacturer != null && manufacturer!.isNotEmpty) {
      parts.add(manufacturer!);
    }
    parts.add(model);
    if (gliderId != null && gliderId!.isNotEmpty) {
      parts.add('($gliderId)');
    }
    return parts.join(' ');
  }

  /// Converts glider to database map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'manufacturer': manufacturer,
      'model': model,
      'glider_id': gliderId,
      'wing_class': wingClass,
      'notes': notes,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  /// Creates glider from database map
  factory Glider.fromMap(Map<String, dynamic> map) {
    return Glider(
      id: map['id'] as int?,
      manufacturer: map['manufacturer'] as String?,
      model: map['model'] as String,
      gliderId: map['glider_id'] as String?,
      wingClass: map['wing_class'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
    );
  }

  /// Returns map without ID for inserts
  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  /// Validates model field is not empty
  bool get isValid {
    return model.trim().isNotEmpty;
  }

  @override
  String toString() {
    return 'Glider{id: $id, displayName: $displayName, wingClass: $wingClass}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Glider &&
        other.id == id &&
        other.manufacturer == manufacturer &&
        other.model == model &&
        other.gliderId == gliderId &&
        other.wingClass == wingClass &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(id, manufacturer, model, gliderId, wingClass, notes);
  }
}