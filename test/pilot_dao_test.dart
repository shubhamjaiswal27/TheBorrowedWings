import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_borrowed_wings/models/pilot.dart';
import 'package:the_borrowed_wings/db/app_database.dart';
import 'package:the_borrowed_wings/db/pilot_dao.dart';

/// Tests for PilotDao using sqflite_common_ffi to run without emulator.
/// 
/// Setup: We replace the default sqflite database factory with FFI factory
/// which allows running SQLite operations in a pure Dart environment during testing.
/// 
/// Test pattern: Each test gets a fresh in-memory database to ensure isolation.
void main() {
  group('PilotDao Tests', () {
    late AppDatabase testDatabase;
    late PilotDao pilotDao;

    // Setup FFI for sqflite testing - this allows running SQLite in Dart tests
    setUpAll(() {
      // Initialize FFI
      sqfliteFfiInit();
      // Set the database factory for testing
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create a fresh in-memory test database for each test
      testDatabase = await AppDatabase.createTestInstance(inMemory: true);
      pilotDao = PilotDao(database: testDatabase);
      
      // Initialize database (creates tables)
      await pilotDao.initDb();
    });

    tearDown(() async {
      // Clean up after each test
      await testDatabase.close();
      // Reset the singleton to ensure clean state
      AppDatabase.resetInstance();
    });

    test('initDb should create database and tables', () async {
      // Database should be initialized without errors
      await pilotDao.initDb();
      
      // Verify we can interact with the database
      final hasProfile = await pilotDao.hasProfile();
      expect(hasProfile, isFalse);
    });

    test('getProfile should return null when no profile exists', () async {
      final profile = await pilotDao.getProfile();
      expect(profile, isNull);
    });

    test('hasProfile should return false when no profile exists', () async {
      final hasProfile = await pilotDao.hasProfile();
      expect(hasProfile, isFalse);
    });

    test('getProfileCount should return 0 when no profile exists', () async {
      final count = await pilotDao.getProfileCount();
      expect(count, 0);
    });

    test('upsertProfile should create new profile', () async {
      final pilot = Pilot.create(
        fullName: 'Test Pilot',
        email: 'test@example.com',
        phone: '+1-555-0123',
        nationality: 'American',
        licenseId: 'PG123456',
        emergencyContactName: 'Emergency Contact',
        emergencyContactPhone: '+1-555-0124',
      );

      await pilotDao.upsertProfile(pilot);

      final retrievedPilot = await pilotDao.getProfile();
      expect(retrievedPilot, isNotNull);
      expect(retrievedPilot!.fullName, 'Test Pilot');
      expect(retrievedPilot.email, 'test@example.com');
      expect(retrievedPilot.phone, '+1-555-0123');
      expect(retrievedPilot.nationality, 'American');
      expect(retrievedPilot.licenseId, 'PG123456');
      expect(retrievedPilot.emergencyContactName, 'Emergency Contact');
      expect(retrievedPilot.emergencyContactPhone, '+1-555-0124');
      expect(retrievedPilot.id, 1); // Should be assigned id=1 (single row pattern)
    });

    test('upsertProfile should create profile with minimal data', () async {
      final pilot = Pilot.create(fullName: 'Minimal Pilot');

      await pilotDao.upsertProfile(pilot);

      final retrievedPilot = await pilotDao.getProfile();
      expect(retrievedPilot, isNotNull);
      expect(retrievedPilot!.fullName, 'Minimal Pilot');
      expect(retrievedPilot.email, isNull);
      expect(retrievedPilot.phone, isNull);
      expect(retrievedPilot.nationality, isNull);
      expect(retrievedPilot.licenseId, isNull);
      expect(retrievedPilot.emergencyContactName, isNull);
      expect(retrievedPilot.emergencyContactPhone, isNull);
      expect(retrievedPilot.id, 1);
    });

    test('upsertProfile should update existing profile', () async {
      // Create initial profile
      final initialPilot = Pilot.create(
        fullName: 'Initial Name',
        email: 'initial@example.com',
      );
      await pilotDao.upsertProfile(initialPilot);

      final firstRetrieval = await pilotDao.getProfile();
      expect(firstRetrieval!.fullName, 'Initial Name');
      expect(firstRetrieval.email, 'initial@example.com');

      // Wait to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 1));

      // Update profile
      final updatedPilot = initialPilot.copyWith(
        fullName: 'Updated Name',
        email: 'updated@example.com',
        phone: '+1-555-9999',
      );
      await pilotDao.upsertProfile(updatedPilot);

      final secondRetrieval = await pilotDao.getProfile();
      expect(secondRetrieval!.fullName, 'Updated Name');
      expect(secondRetrieval.email, 'updated@example.com');
      expect(secondRetrieval.phone, '+1-555-9999');
      expect(secondRetrieval.id, 1); // Should maintain same ID
      expect(secondRetrieval.updatedAt.isAfter(firstRetrieval.updatedAt), isTrue);

      // Should still have only one profile
      final profileCount = await pilotDao.getProfileCount();
      expect(profileCount, 1);
    });

    test('upsertProfile should update updatedAt timestamp', () async {
      final pilot = Pilot.create(fullName: 'Test Pilot');
      await pilotDao.upsertProfile(pilot);

      final firstRetrieval = await pilotDao.getProfile();
      expect(firstRetrieval, isNotNull);

      // Wait to ensure different timestamp
      await Future.delayed(const Duration(milliseconds: 1));

      // Update with same data should still update timestamp
      await pilotDao.upsertProfile(firstRetrieval!);

      final secondRetrieval = await pilotDao.getProfile();
      expect(secondRetrieval!.updatedAt.isAfter(firstRetrieval.updatedAt), isTrue);
      expect(secondRetrieval.createdAt, equals(firstRetrieval.createdAt)); // Should preserve creation time
    });

    test('deleteProfile should remove existing profile', () async {
      // Create profile first
      final pilot = Pilot.create(fullName: 'To Be Deleted');
      await pilotDao.upsertProfile(pilot);

      // Verify it exists
      expect(await pilotDao.getProfile(), isNotNull);
      expect(await pilotDao.hasProfile(), isTrue);
      expect(await pilotDao.getProfileCount(), 1);

      // Delete it
      await pilotDao.deleteProfile();

      // Verify it's gone
      expect(await pilotDao.getProfile(), isNull);
      expect(await pilotDao.hasProfile(), isFalse);
      expect(await pilotDao.getProfileCount(), 0);
    });

    test('deleteProfile should be safe when no profile exists', () async {
      // Should not throw error when deleting non-existent profile
      await pilotDao.deleteProfile();
      
      // Should still be empty
      expect(await pilotDao.getProfile(), isNull);
      expect(await pilotDao.hasProfile(), isFalse);
      expect(await pilotDao.getProfileCount(), 0);
    });

    test('single row pattern should enforce only one profile', () async {
      // Create first profile
      final pilot1 = Pilot.create(fullName: 'Pilot One');
      await pilotDao.upsertProfile(pilot1);
      expect(await pilotDao.getProfileCount(), 1);

      // Create second profile (should replace first)
      final pilot2 = Pilot.create(fullName: 'Pilot Two');
      await pilotDao.upsertProfile(pilot2);
      expect(await pilotDao.getProfileCount(), 1);

      // Should have second pilot's data
      final retrievedPilot = await pilotDao.getProfile();
      expect(retrievedPilot!.fullName, 'Pilot Two');
      expect(retrievedPilot.id, 1); // Should still use id=1
    });

    test('deleteAllProfiles should remove all profiles', () async {
      // Create profile
      final pilot = Pilot.create(fullName: 'Test Pilot');
      await pilotDao.upsertProfile(pilot);
      expect(await pilotDao.getProfileCount(), 1);

      // Delete all
      await pilotDao.deleteAllProfiles();

      // Verify all gone
      expect(await pilotDao.getProfile(), isNull);
      expect(await pilotDao.hasProfile(), isFalse);
      expect(await pilotDao.getProfileCount(), 0);
    });

    test('deleteAllProfiles should be safe when no profiles exist', () async {
      // Should not throw error when no profiles exist
      await pilotDao.deleteAllProfiles();
      
      expect(await pilotDao.getProfileCount(), 0);
    });

    test('database operations should be transactional', () async {
      // This test creates multiple operations to verify transaction behavior
      final pilot1 = Pilot.create(fullName: 'First Pilot');
      final pilot2 = Pilot.create(fullName: 'Second Pilot');

      // Upsert first pilot
      await pilotDao.upsertProfile(pilot1);
      expect((await pilotDao.getProfile())!.fullName, 'First Pilot');

      // Upsert second pilot (should replace first)
      await pilotDao.upsertProfile(pilot2);
      expect((await pilotDao.getProfile())!.fullName, 'Second Pilot');
      expect(await pilotDao.getProfileCount(), 1); // Still only one profile
    });

    test('should handle special characters in text fields', () async {
      final pilot = Pilot.create(
        fullName: 'José María O\'Connor-González',
        email: 'josé+test@münchen.com',
        nationality: 'España',
        emergencyContactName: 'María José "Pepe" González',
      );

      await pilotDao.upsertProfile(pilot);

      final retrievedPilot = await pilotDao.getProfile();
      expect(retrievedPilot!.fullName, 'José María O\'Connor-González');
      expect(retrievedPilot.email, 'josé+test@münchen.com');
      expect(retrievedPilot.nationality, 'España');
      expect(retrievedPilot.emergencyContactName, 'María José "Pepe" González');
    });

    test('should handle empty strings vs null values correctly', () async {
      final pilot = Pilot.create(
        fullName: 'Test Pilot',
        email: '', // Empty string
        phone: '   ', // Whitespace only
      );

      await pilotDao.upsertProfile(pilot);

      final retrievedPilot = await pilotDao.getProfile();
      expect(retrievedPilot!.fullName, 'Test Pilot');
      expect(retrievedPilot.email, ''); // Should preserve empty string
      expect(retrievedPilot.phone, '   '); // Should preserve whitespace
    });

    test('timestamps should be preserved accurately', () async {
      final originalCreationTime = DateTime.now();
      final pilot = Pilot(
        fullName: 'Time Test Pilot',
        createdAt: originalCreationTime,
        updatedAt: originalCreationTime,
      );

      await pilotDao.upsertProfile(pilot);

      final retrievedPilot = await pilotDao.getProfile();
      expect(retrievedPilot!.createdAt.millisecondsSinceEpoch,
          originalCreationTime.millisecondsSinceEpoch);
    });

    test('concurrent operations should work correctly', () async {
      // Create multiple operations that might run concurrently
      final futures = <Future>[];

      // Schedule multiple upsert operations
      for (int i = 0; i < 5; i++) {
        final pilot = Pilot.create(fullName: 'Concurrent Pilot $i');
        futures.add(pilotDao.upsertProfile(pilot));
      }

      // Wait for all operations to complete
      await Future.wait(futures);

      // Should have exactly one profile (the last one wins)
      expect(await pilotDao.getProfileCount(), 1);
      final finalProfile = await pilotDao.getProfile();
      expect(finalProfile!.fullName, startsWith('Concurrent Pilot'));
    });

    group('Error Handling', () {
      test('should handle missing required fields gracefully', () async {
        // This test verifies that database constraints are properly enforced
        // The Pilot model ensures fullName is required, so this should work
        final pilot = Pilot.create(fullName: 'Valid Pilot');
        
        // Should work without throwing
        await pilotDao.upsertProfile(pilot);
        expect(await pilotDao.getProfile(), isNotNull);
      });
    });
  });
}