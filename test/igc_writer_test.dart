import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:the_borrowed_wings/models/flight.dart';
import 'package:the_borrowed_wings/models/flight_fix.dart';
import 'package:the_borrowed_wings/models/glider.dart';
import 'package:the_borrowed_wings/models/pilot.dart';
import 'package:the_borrowed_wings/db/app_database.dart';
import 'package:the_borrowed_wings/db/flight_dao.dart';
import 'package:the_borrowed_wings/db/glider_dao.dart';
import 'package:the_borrowed_wings/db/pilot_dao.dart';
import 'package:the_borrowed_wings/igc/igc_writer.dart';
import 'package:the_borrowed_wings/igc/igc_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('IGC Writer Tests', () {
    late AppDatabase testDb;
    late FlightDao flightDao;
    late GliderDao gliderDao;
    late PilotDao pilotDao;
    late IgcWriter igcWriter;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create test database instance
      testDb = await AppDatabase.createTestInstance();
      flightDao = FlightDao();
      gliderDao = GliderDao();
      pilotDao = PilotDao();
      
      // Use system temp directory for test outputs to avoid platform channel issues
      final tempDir = Directory.systemTemp.createTempSync('igc_test');
      igcWriter = IgcWriter(
        flightDao: flightDao, 
        pilotDao: pilotDao,
        testOutputDir: tempDir.path,
      );
    });

    tearDown(() async {
      await testDb.close();
    });

    group('IGC Format Validation', () {
      test('should generate valid A record', () {
        final aRecord = IgcUtils.generateARecord();
        
        expect(aRecord, startsWith('A'));
        expect(aRecord, equals('AFLTPARAGLIDINGLOG'));
        expect(aRecord.length, lessThan(50)); // Reasonable length
      });

      test('should generate valid HFDTE record', () {
        final testDate = DateTime(2024, 3, 15, 14, 30, 0);
        final dateRecord = IgcUtils.generateDateHeader(testDate);
        
        expect(dateRecord, equals('HFDTE150324'));
        expect(dateRecord, startsWith('HFDTE'));
        expect(dateRecord.length, equals(11));
      });

      test('should generate valid pilot header', () {
        const pilotName = 'John Smith-Doe';
        final pilotRecord = IgcUtils.generatePilotHeader(pilotName);
        
        expect(pilotRecord, startsWith('HFPLTPILOTINCHARGE:'));
        expect(pilotRecord, contains('JOHN SMITH-DOE'));
      });

      test('should generate valid glider type header', () {
        const manufacturer = 'Ozone';
        const model = 'Rush 5';
        final gliderRecord = IgcUtils.generateGliderTypeHeader(manufacturer, model);
        
        expect(gliderRecord, startsWith('HFGTYGLIDERTYPE:'));
        expect(gliderRecord, contains('OZONE RUSH 5'));
      });

      test('should handle empty glider manufacturer', () {
        const model = 'Unknown Wing';
        final gliderRecord = IgcUtils.generateGliderTypeHeader('', model);
        
        expect(gliderRecord, equals('HFGTYGLIDERTYPE:UNKNOWN WING'));
      });
    });

    group('B Record Formatting', () {
      test('should format B record correctly', () {
        final timestamp = DateTime(2024, 3, 15, 14, 30, 45);
        const latitude = 45.123456;
        const longitude = 8.567890;
        const pressureAlt = 1234;
        const gpsAlt = 1250;

        final bRecord = IgcUtils.generateBRecord(
          timestamp,
          latitude,
          longitude,
          pressureAlt,
          gpsAlt,
        );

        expect(bRecord, startsWith('B'));
        expect(bRecord, equals('B1430454507407N00834073EA0123401250'));
        expect(bRecord.length, equals(35));
      });

      test('should handle negative coordinates correctly', () {
        final timestamp = DateTime(2024, 3, 15, 12, 0, 0);
        const latitude = -45.0;
        const longitude = -8.0;
        
        final bRecord = IgcUtils.generateBRecord(
          timestamp,
          latitude,
          longitude,
          1000,
          1000,
        );

        expect(bRecord, contains('S')); // South hemisphere
        expect(bRecord, contains('W')); // West hemisphere
        expect(bRecord, equals('B1200004500000S00800000WA0100001000'));
      });

      test('should handle null altitudes', () {
        final timestamp = DateTime(2024, 3, 15, 12, 0, 0);
        
        final bRecord = IgcUtils.generateBRecord(
          timestamp,
          45.0,
          8.0,
          null,
          null,
        );

        expect(bRecord, endsWith('A0000000000'));
      });

      test('should clamp extreme altitudes', () {
        final timestamp = DateTime(2024, 3, 15, 12, 0, 0);
        
        final bRecord = IgcUtils.generateBRecord(
          timestamp,
          45.0,
          8.0,
          150000, // Way too high
          -50000, // Way too low
        );

        // Should be clamped to max values
        expect(bRecord, contains('99999')); // Max altitude
      });
    });

    group('Coordinate Formatting', () {
      test('should format latitude correctly', () {
        expect(IgcUtils.formatLatitude(45.123456), equals('4507407N'));
        expect(IgcUtils.formatLatitude(-45.123456), equals('4507407S'));
        expect(IgcUtils.formatLatitude(0.0), equals('0000000N'));
        expect(IgcUtils.formatLatitude(90.0), equals('9000000N'));
        expect(IgcUtils.formatLatitude(-90.0), equals('9000000S'));
      });

      test('should format longitude correctly', () {
        expect(IgcUtils.formatLongitude(8.567890), equals('00834073E'));
        expect(IgcUtils.formatLongitude(-8.567890), equals('00834073W'));
        expect(IgcUtils.formatLongitude(0.0), equals('00000000E'));
        expect(IgcUtils.formatLongitude(180.0), equals('18000000E'));
        expect(IgcUtils.formatLongitude(-180.0), equals('18000000W'));
      });

      test('should format time correctly', () {
        final time1 = DateTime(2024, 3, 15, 9, 5, 3);
        expect(IgcUtils.formatTime(time1), equals('090503'));
        
        final time2 = DateTime(2024, 3, 15, 23, 59, 59);
        expect(IgcUtils.formatTime(time2), equals('235959'));
      });

      test('should format altitude correctly', () {
        expect(IgcUtils.formatAltitude(0), equals('00000'));
        expect(IgcUtils.formatAltitude(1234), equals('01234'));
        expect(IgcUtils.formatAltitude(null), equals('00000'));
        expect(IgcUtils.formatAltitude(-100), equals('99900')); // Negative handling
      });
    });

    group('Filename Generation', () {
      test('should generate valid IGC filename', () {
        final flightDate = DateTime(2024, 3, 15, 14, 30, 0);
        const gliderModel = 'Rush 5';
        
        final filename = IgcUtils.generateIgcFilename(flightDate, gliderModel);
        
        expect(filename, equals('rush5_20240315_1430.igc'));
        expect(filename, endsWith('.igc'));
      });

      test('should sanitize problematic characters in filename', () {
        final flightDate = DateTime(2024, 3, 15, 14, 30, 0);
        const gliderModel = 'Wing/Model*Test!';
        
        final filename = IgcUtils.generateIgcFilename(flightDate, gliderModel);
        
        expect(filename, contains('wingmode')); // Truncated to 8 chars
        expect(filename, isNot(contains('/')));
        expect(filename, isNot(contains('*')));
        expect(filename, isNot(contains('!')));
      });

      test('should handle empty glider model', () {
        final flightDate = DateTime(2024, 3, 15, 14, 30, 0);
        
        final filename = IgcUtils.generateIgcFilename(flightDate, '');
        
        expect(filename, equals('20240315_1430.igc'));
      });
    });

    group('Full IGC Export', () {
      test('should export complete flight successfully', () async {
        // Create test pilot
        final pilot = Pilot.create(
          fullName: 'Test Pilot',
          email: 'test@example.com',
        );
        await pilotDao.upsertProfile(pilot);

        // Create test glider
        final glider = Glider.create(
          manufacturer: 'Test Wings',
          model: 'Test Model',
          gliderId: 'TEST-123',
          wingClass: 'EN-A',
        );
        final gliderId = await gliderDao.insertGlider(glider);

        // Create test flight
        final flightStart = DateTime.now().subtract(Duration(hours: 1));
        final takeoffTime = flightStart.add(Duration(minutes: 5));
        final landingTime = takeoffTime.add(Duration(minutes: 30));
        
        final flight = Flight.create(
          gliderId: gliderId,
          startedAt: flightStart,
          takeoffAt: takeoffTime,
          landedAt: landingTime,
          durationSec: 2100, // 35 minutes
          fixCount: 10,
        );
        final flightId = await flightDao.insertFlight(flight);

        // Create test fixes
        final fixes = <FlightFix>[];
        for (int i = 0; i < 10; i++) {
          fixes.add(FlightFix.create(
            flightId: flightId,
            timestamp: takeoffTime.add(Duration(minutes: i * 3)),
            latitude: 45.0 + (i * 0.001),
            longitude: 8.0 + (i * 0.001),
            gpsAltitudeM: 1000 + (i * 50),
            speedMps: 5.0 + (i * 0.5),
            accuracyM: 5.0,
            sequenceNumber: i,
          ));
        }
        await flightDao.insertFlightFixesBatch(fixes);

        // Export flight
        final result = await igcWriter.exportFlight(flightId);

        expect(result.success, isTrue);
        expect(result.filePath, isNotNull);
        expect(result.fixCount, equals(10));

        // Verify file exists and has content
        final file = File(result.filePath!);
        expect(await file.exists(), isTrue);
        
        final content = await file.readAsString();
        expect(content.isNotEmpty, isTrue);
        
        // Verify IGC format
        final lines = content.split('\n');
        expect(lines.first.trim(), startsWith('A')); // A record first
        expect(lines.any((line) => line.startsWith('HFDTE')), isTrue); // Date header
        expect(lines.any((line) => line.startsWith('HFPLT')), isTrue); // Pilot header
        expect(lines.where((line) => line.startsWith('B')), hasLength(10)); // B records
      });

      test('should handle flight with no fixes', () async {
        // Create minimal flight with no fixes
        final glider = Glider.create(model: 'Test Wing');
        final gliderId = await gliderDao.insertGlider(glider);
        
        final flight = Flight.create(
          gliderId: gliderId,
          startedAt: DateTime.now(),
          fixCount: 0,
        );
        final flightId = await flightDao.insertFlight(flight);

        final result = await igcWriter.exportFlight(flightId);

        expect(result.success, isFalse);
        expect(result.error, contains('No flight fixes'));
      });

      test('should handle non-existent flight', () async {
        final result = await igcWriter.exportFlight(99999);

        expect(result.success, isFalse);
        expect(result.error, contains('Flight not found'));
      });
    });

    group('IGC Content Validation', () {
      test('should validate correct IGC content', () {
        const validIgc = '''AFLTPARAGLIDINGLOG
HFDTE150324
HFPLTPILOTINCHARGE:TEST PILOT
B143045451407406805407340A0123401250
B143046451407506805407440A0123501260''';

        expect(IgcWriter.validateIgcContent(validIgc), isTrue);
      });

      test('should reject IGC without A record', () {
        const invalidIgc = '''HFDTE150324
B143045451407406805407340A0123401250''';

        expect(IgcWriter.validateIgcContent(invalidIgc), isFalse);
      });

      test('should reject IGC without date header', () {
        const invalidIgc = '''AFLTPARAGLIDINGLOG
HFPLTPILOTINCHARGE:TEST PILOT
B143045451407406805407340A0123401250''';

        expect(IgcWriter.validateIgcContent(invalidIgc), isFalse);
      });

      test('should reject IGC without B records', () {
        const invalidIgc = '''AFLTPARAGLIDINGLOG
HFDTE150324
HFPLTPILOTINCHARGE:TEST PILOT''';

        expect(IgcWriter.validateIgcContent(invalidIgc), isFalse);
      });

      test('should reject IGC with malformed B records', () {
        const invalidIgc = '''AFLTPARAGLIDINGLOG
HFDTE150324
B14304545140740680540734'''; // Too short

        expect(IgcWriter.validateIgcContent(invalidIgc), isFalse);
      });
    });

    group('Deterministic Output', () {
      test('should produce identical output for same input', () async {
        // Create test data
        final pilot = Pilot.create(fullName: 'Consistent Pilot');
        await pilotDao.upsertProfile(pilot);
        
        final glider = Glider.create(
          manufacturer: 'Consistent',
          model: 'Wing',
          gliderId: 'SAME-123',
        );
        final gliderId = await gliderDao.insertGlider(glider);
        
        final fixedTime = DateTime(2024, 3, 15, 14, 30, 0);
        final flight = Flight.create(
          gliderId: gliderId,
          startedAt: fixedTime,
          takeoffAt: fixedTime.add(Duration(minutes: 5)),
          landedAt: fixedTime.add(Duration(minutes: 35)),
          durationSec: 1800,
          fixCount: 3,
        );
        final flightId = await flightDao.insertFlight(flight);
        
        // Create deterministic fixes
        final fixes = [
          FlightFix.create(
            flightId: flightId,
            timestamp: fixedTime.add(Duration(minutes: 5)),
            latitude: 45.123456,
            longitude: 8.654321,
            gpsAltitudeM: 1000,
            sequenceNumber: 0,
          ),
          FlightFix.create(
            flightId: flightId,
            timestamp: fixedTime.add(Duration(minutes: 20)),
            latitude: 45.124456,
            longitude: 8.655321,
            gpsAltitudeM: 1200,
            sequenceNumber: 1,
          ),
          FlightFix.create(
            flightId: flightId,
            timestamp: fixedTime.add(Duration(minutes: 35)),
            latitude: 45.125456,
            longitude: 8.656321,
            gpsAltitudeM: 1000,
            sequenceNumber: 2,
          ),
        ];
        await flightDao.insertFlightFixesBatch(fixes);

        // Export multiple times
        final result1 = await igcWriter.exportFlight(flightId);
        final content1 = await File(result1.filePath!).readAsString();
        
        final result2 = await igcWriter.exportFlight(flightId);
        final content2 = await File(result2.filePath!).readAsString();

        expect(content1, equals(content2));
      });
    });
  });
}

// Note: This requires a FlightDao extension or mock for testing
extension FlightDaoTestExtension on FlightDao {
  // In a real implementation, you'd inject the GliderDao or use dependency injection
  // For testing purposes, we'd need to expose or mock the GliderDao
  // This is a simplified approach for the test
}