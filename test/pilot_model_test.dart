import 'package:flutter_test/flutter_test.dart';
import 'package:the_borrowed_wings/models/pilot.dart';

void main() {
  group('Pilot Model Tests', () {
    late DateTime testDate;
    late Pilot testPilot;

    setUp(() {
      testDate = DateTime(2026, 3, 2, 10, 30, 0);
      testPilot = Pilot(
        id: 1,
        fullName: 'John Doe',
        email: 'john.doe@example.com',
        phone: '+1-555-0123',
        nationality: 'American',
        licenseId: 'PG123456',
        emergencyContactName: 'Jane Doe',
        emergencyContactPhone: '+1-555-0124',
        createdAt: testDate,
        updatedAt: testDate,
      );
    });

    test('should create Pilot with factory constructor', () {
      final pilot = Pilot.create(
        fullName: 'Test Pilot',
        email: 'test@example.com',
        phone: '+1-555-0100',
        nationality: 'Test Nation',
        licenseId: 'TEST123',
        emergencyContactName: 'Emergency Contact',
        emergencyContactPhone: '+1-555-0101',
      );

      expect(pilot.fullName, 'Test Pilot');
      expect(pilot.email, 'test@example.com');
      expect(pilot.phone, '+1-555-0100');
      expect(pilot.nationality, 'Test Nation');
      expect(pilot.licenseId, 'TEST123');
      expect(pilot.emergencyContactName, 'Emergency Contact');
      expect(pilot.emergencyContactPhone, '+1-555-0101');
      expect(pilot.id, isNull);
      expect(pilot.createdAt, isNotNull);
      expect(pilot.updatedAt, isNotNull);
      expect(pilot.createdAt, equals(pilot.updatedAt));
    });

    test('should create minimal Pilot with only required fields', () {
      final pilot = Pilot.create(fullName: 'Minimal Pilot');

      expect(pilot.fullName, 'Minimal Pilot');
      expect(pilot.email, isNull);
      expect(pilot.phone, isNull);
      expect(pilot.nationality, isNull);
      expect(pilot.licenseId, isNull);
      expect(pilot.emergencyContactName, isNull);
      expect(pilot.emergencyContactPhone, isNull);
      expect(pilot.id, isNull);
      expect(pilot.createdAt, isNotNull);
      expect(pilot.updatedAt, isNotNull);
    });

    test('should copy pilot with updated fields and new timestamp', () async {
      final originalPilot = Pilot.create(fullName: 'Original Name');
      
      // Wait a small amount to ensure different timestamps
      await Future.delayed(const Duration(milliseconds: 1));
      
      final updatedPilot = originalPilot.copyWith(
        fullName: 'Updated Name',
        email: 'updated@example.com',
      );

      expect(updatedPilot.fullName, 'Updated Name');
      expect(updatedPilot.email, 'updated@example.com');
      expect(updatedPilot.createdAt, equals(originalPilot.createdAt));
      expect(updatedPilot.updatedAt.isAfter(originalPilot.updatedAt), isTrue);
    });

    test('should convert to map correctly', () {
      final map = testPilot.toMap();

      expect(map['id'], 1);
      expect(map['full_name'], 'John Doe');
      expect(map['email'], 'john.doe@example.com');
      expect(map['phone'], '+1-555-0123');
      expect(map['nationality'], 'American');
      expect(map['license_id'], 'PG123456');
      expect(map['emergency_contact_name'], 'Jane Doe');
      expect(map['emergency_contact_phone'], '+1-555-0124');
      expect(map['created_at'], testDate.millisecondsSinceEpoch);
      expect(map['updated_at'], testDate.millisecondsSinceEpoch);
    });

    test('should convert from map correctly', () {
      final map = {
        'id': 2,
        'full_name': 'Jane Smith',
        'email': 'jane.smith@example.com',
        'phone': '+1-555-0200',
        'nationality': 'Canadian',
        'license_id': 'PG789012',
        'emergency_contact_name': 'John Smith',
        'emergency_contact_phone': '+1-555-0201',
        'created_at': testDate.millisecondsSinceEpoch,
        'updated_at': testDate.millisecondsSinceEpoch,
      };

      final pilot = Pilot.fromMap(map);

      expect(pilot.id, 2);
      expect(pilot.fullName, 'Jane Smith');
      expect(pilot.email, 'jane.smith@example.com');
      expect(pilot.phone, '+1-555-0200');
      expect(pilot.nationality, 'Canadian');
      expect(pilot.licenseId, 'PG789012');
      expect(pilot.emergencyContactName, 'John Smith');
      expect(pilot.emergencyContactPhone, '+1-555-0201');
      expect(pilot.createdAt, testDate);
      expect(pilot.updatedAt, testDate);
    });

    test('should handle null values in map conversion', () {
      final mapWithNulls = {
        'id': 3,
        'full_name': 'Minimal Pilot',
        'email': null,
        'phone': null,
        'nationality': null,
        'license_id': null,
        'emergency_contact_name': null,
        'emergency_contact_phone': null,
        'created_at': testDate.millisecondsSinceEpoch,
        'updated_at': testDate.millisecondsSinceEpoch,
      };

      final pilot = Pilot.fromMap(mapWithNulls);

      expect(pilot.id, 3);
      expect(pilot.fullName, 'Minimal Pilot');
      expect(pilot.email, isNull);
      expect(pilot.phone, isNull);
      expect(pilot.nationality, isNull);
      expect(pilot.licenseId, isNull);
      expect(pilot.emergencyContactName, isNull);
      expect(pilot.emergencyContactPhone, isNull);
      expect(pilot.createdAt, testDate);
      expect(pilot.updatedAt, testDate);
    });

    test('toMap -> fromMap roundtrip should preserve all data', () {
      final originalMap = testPilot.toMap();
      final reconstructedPilot = Pilot.fromMap(originalMap);
      final finalMap = reconstructedPilot.toMap();

      expect(finalMap, equals(originalMap));
      expect(reconstructedPilot, equals(testPilot));
    });

    test('toMap -> fromMap roundtrip should work with minimal data', () {
      final minimalPilot = Pilot.create(fullName: 'Test Name');
      final map = minimalPilot.toMap();
      final reconstructed = Pilot.fromMap(map);

      expect(reconstructed.fullName, minimalPilot.fullName);
      expect(reconstructed.email, minimalPilot.email);
      expect(reconstructed.phone, minimalPilot.phone);
      expect(reconstructed.nationality, minimalPilot.nationality);
      expect(reconstructed.licenseId, minimalPilot.licenseId);
      expect(reconstructed.emergencyContactName, minimalPilot.emergencyContactName);
      expect(reconstructed.emergencyContactPhone, minimalPilot.emergencyContactPhone);
      // Compare timestamps with millisecond precision (SQLite precision)
      expect(reconstructed.createdAt.millisecondsSinceEpoch, minimalPilot.createdAt.millisecondsSinceEpoch);
      expect(reconstructed.updatedAt.millisecondsSinceEpoch, minimalPilot.updatedAt.millisecondsSinceEpoch);
    });

    group('Email Validation', () {
      test('should validate basic email addresses', () {
        expect(Pilot.isValidEmail('test@example.com'), isTrue);
        expect(Pilot.isValidEmail('user@domain.org'), isTrue);
        // Note: More complex validation can be enhanced in future iterations
      });

      test('should reject clearly invalid email addresses', () {
        expect(Pilot.isValidEmail('invalid-email'), isFalse);
        expect(Pilot.isValidEmail('@domain.com'), isFalse);
        expect(Pilot.isValidEmail('user@'), isFalse);
        expect(Pilot.isValidEmail('user name@domain.com'), isFalse);
      });

      test('should accept null and empty email as valid (optional field)', () {
        expect(Pilot.isValidEmail(null), isTrue);
        expect(Pilot.isValidEmail(''), isTrue);
        expect(Pilot.isValidEmail('   '), isTrue);
      });
    });

    test('should implement equality correctly', () {
      final baseTime = DateTime.now();
      
      final pilot1 = Pilot(
        fullName: 'Test Pilot',
        createdAt: baseTime,
        updatedAt: baseTime,
      );
      
      final pilot2 = Pilot(
        fullName: 'Test Pilot',
        createdAt: baseTime.add(const Duration(milliseconds: 1)), // Different timestamp
        updatedAt: baseTime.add(const Duration(milliseconds: 1)),
      );
      
      final pilot3 = Pilot(
        fullName: 'Different Name',
        createdAt: baseTime,
        updatedAt: baseTime,
      );

      expect(pilot1 == pilot2, isFalse); // Different timestamps
      expect(pilot1 == pilot1, isTrue); // Same instance
      expect(pilot1 == pilot3, isFalse); // Different name
    });

    test('should implement hashCode correctly', () {
      final baseTime = DateTime.now();
      
      final pilot1 = Pilot(
        fullName: 'Test Pilot',
        createdAt: baseTime,
        updatedAt: baseTime,
      );
      
      final pilot2 = Pilot(
        fullName: 'Test Pilot',
        createdAt: baseTime.add(const Duration(milliseconds: 1)), // Different timestamp
        updatedAt: baseTime.add(const Duration(milliseconds: 1)),
      );

      expect(pilot1.hashCode, isNot(equals(pilot2.hashCode))); // Different timestamps should yield different hashes
      expect(pilot1.hashCode, equals(pilot1.hashCode)); // Consistent
    });

    test('should have meaningful toString representation', () {
      final pilot = Pilot.create(fullName: 'Test Pilot', email: 'test@example.com');
      final string = pilot.toString();

      expect(string, contains('Pilot'));
      expect(string, contains('Test Pilot'));
      expect(string, contains('test@example.com'));
      expect(string, contains('createdAt'));
      expect(string, contains('updatedAt'));
    });
  });
}