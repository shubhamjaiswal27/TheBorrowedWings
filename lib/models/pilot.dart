/// Pilot model representing a paragliding pilot's profile information.
/// 
/// This model is tied 1:1 with Supabase Auth users via the userId field.
/// Each authenticated user must have exactly one pilot profile.
class Pilot {
  final String? id;
  final String userId; // Foreign key to Supabase Auth user
  final String fullName;
  final String? email;
  final String? phone;
  final String? nationality;
  final String? licenseId;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Pilot({
    this.id,
    required this.userId,
    required this.fullName,
    this.email,
    this.phone,
    this.nationality,
    this.licenseId,
    this.emergencyContactName,
    this.emergencyContactPhone,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a new pilot with current timestamps
  factory Pilot.create({
    required String userId,
    required String fullName,
    String? email,
    String? phone,
    String? nationality,
    String? licenseId,
    String? emergencyContactName,
    String? emergencyContactPhone,
  }) {
    final now = DateTime.now();
    return Pilot(
      userId: userId,
      fullName: fullName,
      email: email,
      phone: phone,
      nationality: nationality,
      licenseId: licenseId,
      emergencyContactName: emergencyContactName,
      emergencyContactPhone: emergencyContactPhone,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Creates an updated copy with new updatedAt timestamp
  Pilot copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? email,
    String? phone,
    String? nationality,
    String? licenseId,
    String? emergencyContactName,
    String? emergencyContactPhone,
    DateTime? createdAt,
  }) {
    return Pilot(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      nationality: nationality ?? this.nationality,
      licenseId: licenseId ?? this.licenseId,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone: emergencyContactPhone ?? this.emergencyContactPhone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: DateTime.now(), // Always update timestamp on copy
    );
  }

  /// Converts pilot to Supabase map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'nationality': nationality,
      'license_id': licenseId,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Converts pilot to map for insert operations (without id)
  Map<String, dynamic> toMapForInsert() {
    final map = toMap();
    map.remove('id');
    return map;
  }

  /// Creates pilot from Supabase map
  factory Pilot.fromMap(Map<String, dynamic> map) {
    return Pilot(
      id: map['id'] as String?,
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      nationality: map['nationality'] as String?,
      licenseId: map['license_id'] as String?,
      emergencyContactName: map['emergency_contact_name'] as String?,
      emergencyContactPhone: map['emergency_contact_phone'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  /// Email validation helper
  /// Uses a simple, permissive approach suitable for pilot profiles
  static bool isValidEmail(String? email) {
    if (email == null || email.trim().isEmpty) return true; // Optional field
    
    final trimmed = email.trim();
    
    // Simple checks: must contain @, no spaces, and have a dot after @
    if (!trimmed.contains('@')) return false;
    if (trimmed.contains(' ')) return false;
    
    final parts = trimmed.split('@');
    if (parts.length != 2) return false; // Exactly one @
    
    final local = parts[0];
    final domain = parts[1];
    
    // Basic checks
    if (local.isEmpty || domain.isEmpty) return false;
    if (!domain.contains('.')) return false;
    
    // Domain should have something after the last dot (TLD)
    final lastDotIndex = domain.lastIndexOf('.');
    if (lastDotIndex == -1 || lastDotIndex >= domain.length - 2) return false;
    
    return true;
  }

  @override
  String toString() {
    return 'Pilot{id: $id, userId: $userId, fullName: $fullName, email: $email, '
        'phone: $phone, nationality: $nationality, licenseId: $licenseId, '
        'emergencyContactName: $emergencyContactName, '
        'emergencyContactPhone: $emergencyContactPhone, '
        'createdAt: $createdAt, updatedAt: $updatedAt}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Pilot &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          fullName == other.fullName &&
          email == other.email &&
          phone == other.phone &&
          nationality == other.nationality &&
          licenseId == other.licenseId &&
          emergencyContactName == other.emergencyContactName &&
          emergencyContactPhone == other.emergencyContactPhone &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        fullName,
        email,
        phone,
        nationality,
        licenseId,
        emergencyContactName,
        emergencyContactPhone,
        createdAt,
        updatedAt,
      );
}