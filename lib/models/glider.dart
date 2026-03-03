/// Glider model representing paragliding equipment used in flights.
/// 
/// Each glider has basic metadata like manufacturer, model, and registration details.
/// Gliders are selected when starting a flight recording session.
/// Each glider belongs to the authenticated user.
class Glider {
  final String? id;
  final String userId; // Foreign key to Supabase Auth user
  final String? manufacturer;
  final String model;
  final String? serialNumber;  // registration or serial number
  final String? wingClass;
  final String? notes;
  final DateTime createdAt;

  const Glider({
    this.id,
    required this.userId,
    this.manufacturer,
    required this.model,
    this.serialNumber,
    this.wingClass,
    this.notes,
    required this.createdAt,
  });

  /// Creates a new glider with current timestamp
  factory Glider.create({
    required String userId,
    String? manufacturer,
    required String model,
    String? serialNumber,
    String? wingClass,
    String? notes,
  }) {
    return Glider(
      userId: userId,
      manufacturer: manufacturer,
      model: model,
      serialNumber: serialNumber,
      wingClass: wingClass,
      notes: notes,
      createdAt: DateTime.now(),
    );
  }

  /// Creates a copy with updated fields
  Glider copyWith({
    String? id,
    String? userId,
    String? manufacturer,
    String? model,
    String? serialNumber,
    String? wingClass,
    String? notes,
    DateTime? createdAt,
  }) {
    return Glider(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
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
    if (serialNumber != null && serialNumber!.isNotEmpty) {
      parts.add('($serialNumber)');
    }
    return parts.join(' ');
  }

  /// Converts glider to Supabase map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'manufacturer': manufacturer,
      'model': model,
      'serial_number': serialNumber,
      'wing_class': wingClass,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Converts glider to map for insert operations (without id)
  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  /// Creates glider from Supabase map
  factory Glider.fromMap(Map<String, dynamic> map) {
    return Glider(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      manufacturer: map['manufacturer'] as String?,
      model: map['model'] as String,
      serialNumber: map['serial_number'] as String?,
      wingClass: map['wing_class'] as String?,
      notes: map['notes'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Validates model field is not empty
  bool get isValid {
    return model.trim().isNotEmpty;
  }

  @override
  String toString() {
    return 'Glider{id: $id, userId: $userId, displayName: $displayName, wingClass: $wingClass}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Glider &&
        other.id == id &&
        other.userId == userId &&
        other.manufacturer == manufacturer &&
        other.model == model &&
        other.serialNumber == serialNumber &&
        other.wingClass == wingClass &&
        other.notes == notes;
  }

  @override
  int get hashCode {
    return Object.hash(id, userId, manufacturer, model, serialNumber, wingClass, notes);
  }
}