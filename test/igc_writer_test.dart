import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:path/path.dart' as path;
import 'package:the_borrowed_wings/models/flight.dart';
import 'package:the_borrowed_wings/models/flight_fix.dart';
import 'package:the_borrowed_wings/models/glider.dart';
import 'package:the_borrowed_wings/models/pilot.dart';
import 'package:the_borrowed_wings/repositories/flight_repository.dart';
import 'package:the_borrowed_wings/repositories/pilot_repository.dart';
import 'package:the_borrowed_wings/repositories/glider_repository.dart';
import 'package:the_borrowed_wings/services/auth_service.dart';
import 'package:the_borrowed_wings/igc/igc_writer.dart';
import 'package:the_borrowed_wings/igc/igc_utils.dart';

import 'igc_writer_test.mocks.dart';

@GenerateMocks([
  FlightRepository,
  PilotRepository,
  GliderRepository,
  AuthService,
])

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('IGC Writer Tests', () {
    late MockFlightRepository mockFlightRepository;
    late MockPilotRepository mockPilotRepository;
    late MockGliderRepository mockGliderRepository;
    late MockAuthService mockAuthService;
    late IgcWriter igcWriter;
    late Directory tempDir;

    const testUserId = 'test-user-123';
    const testFlightId = 'flight-uuid-123';
    const testGliderId = 'glider-uuid-123';
    const testPilotId = 'pilot-uuid-123';

    setUp(() {
      mockFlightRepository = MockFlightRepository();
      mockPilotRepository = MockPilotRepository();
      mockGliderRepository = MockGliderRepository();
      mockAuthService = MockAuthService();

      // Create temp directory for test outputs
      tempDir = Directory.systemTemp.createTempSync('igc_test');

      igcWriter = IgcWriter(
        flightRepository: mockFlightRepository,
        pilotRepository: mockPilotRepository,
        gliderRepository: mockGliderRepository,
        authService: mockAuthService,
        testOutputDir: tempDir.path,
      );

      // Mock auth service to return test user ID
      when(mockAuthService.currentUserId).thenReturn(testUserId);
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
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
        final gliderRecord = IgcUtils.generateGliderTypeHeader(
          manufacturer,
          model,
        );

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
        expect(
          IgcUtils.formatAltitude(-100),
          equals('99900'),
        ); // Negative handling
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
        // Create test data
        final testDate = DateTime(2024, 3, 15, 14, 30, 0);
        final takeoffTime = testDate.add(const Duration(minutes: 5));
        final landingTime = takeoffTime.add(const Duration(minutes: 30));

        final pilot = Pilot(
          id: testPilotId,
          userId: testUserId,
          fullName: 'Test Pilot',
          email: 'test@example.com',
          createdAt: testDate,
          updatedAt: testDate,
        );

        final glider = Glider(
          id: testGliderId,
          userId: testUserId,
          manufacturer: 'Test Wings',
          model: 'Test Model',
          serialNumber: 'TEST-123',
          wingClass: 'EN-A',
          createdAt: testDate,
        );

        final flight = Flight(
          id: testFlightId,
          userId: testUserId,
          gliderId: testGliderId,
          startedAt: testDate,
          takeoffAt: takeoffTime,
          landedAt: landingTime,
          durationSec: 1800,
          fixCount: 5,
          createdAt: testDate,
        );

        final fixes = List.generate(
          5,
          (i) => FlightFix(
            id: 'fix-$i',
            flightId: testFlightId,
            timestamp: takeoffTime.add(Duration(minutes: i * 6)),
            latitude: 45.0 + (i * 0.001),
            longitude: 8.0 + (i * 0.001),
            gpsAltitudeM: 1000 + (i * 50),
            speedMps: 5.0 + (i * 0.5),
            accuracyM: 5.0,
            sequenceNumber: i,
          ),
        );

        // Setup mocks
        when(mockFlightRepository.getFlightById(testFlightId, testUserId))
            .thenAnswer((_) async => flight);
        when(mockGliderRepository.getGliderById(testGliderId, testUserId))
            .thenAnswer((_) async => glider);
        when(mockPilotRepository.getPilotByUserId(testUserId))
            .thenAnswer((_) async => pilot);
        when(mockFlightRepository.getFlightFixesInRange(testFlightId, any, any))
            .thenAnswer((_) async => fixes);
        when(mockFlightRepository.updateFlight(any, testUserId))
            .thenAnswer((_) async => flight);

        // Export flight
        final result = await igcWriter.exportFlight(testFlightId);

        expect(result.success, isTrue);
        expect(result.filePath, isNotNull);
        expect(result.fixCount, equals(5));

        // Verify file exists and has content
        final file = File(result.filePath!);
        expect(await file.exists(), isTrue);

        final content = await file.readAsString();
        expect(content.isNotEmpty, isTrue);

        // Verify IGC format
        final lines = content.split('\n');
        expect(lines.first.trim(), startsWith('A')); // A record first
        expect(
          lines.any((line) => line.startsWith('HFDTE')),
          isTrue,
        ); // Date header
        expect(
          lines.any((line) => line.startsWith('HFPLT')),
          isTrue,
        ); // Pilot header
        expect(
          lines.where((line) => line.startsWith('B')),
          hasLength(5),
        ); // B records
      });

      test('should handle flight with no fixes', () async {
        final flight = Flight(
          id: testFlightId,
          userId: testUserId,
          gliderId: testGliderId,
          startedAt: DateTime.now(),
          fixCount: 0,
          durationSec: 0,
          createdAt: DateTime.now(),
        );

        final glider = Glider(
          id: testGliderId,
          userId: testUserId,
          model: 'Test Wing',
          createdAt: DateTime.now(),
        );

        // Setup mocks
        when(mockFlightRepository.getFlightById(testFlightId, testUserId))
            .thenAnswer((_) async => flight);
        when(mockGliderRepository.getGliderById(testGliderId, testUserId))
            .thenAnswer((_) async => glider);
        when(mockPilotRepository.getPilotByUserId(testUserId))
            .thenAnswer((_) async => null);
        when(mockFlightRepository.getFlightFixesByFlightId(testFlightId))
            .thenAnswer((_) async => []);

        final result = await igcWriter.exportFlight(testFlightId);

        expect(result.success, isFalse);
        expect(result.error, contains('No flight fixes to export'));
      });

      test('should handle non-existent flight', () async {
        // Setup mock to return null for non-existent flight
        when(mockFlightRepository.getFlightById('non-existent', testUserId))
            .thenAnswer((_) async => null);

        final result = await igcWriter.exportFlight('non-existent');

        expect(result.success, isFalse);
        expect(result.error, contains('Flight not found'));
      });

      test('should handle unauthenticated user', () async {
        // Setup mock to return null user ID
        when(mockAuthService.currentUserId).thenReturn(null);

        final result = await igcWriter.exportFlight(testFlightId);

        expect(result.success, isFalse);
        expect(result.error, contains('User not authenticated'));
      });

      test('should handle missing glider', () async {
        final flight = Flight(
          id: testFlightId,
          userId: testUserId,
          gliderId: testGliderId,
          startedAt: DateTime.now(),
          fixCount: 5,
          durationSec: 1800,
          createdAt: DateTime.now(),
        );

        // Setup mocks
        when(mockFlightRepository.getFlightById(testFlightId, testUserId))
            .thenAnswer((_) async => flight);
        when(mockGliderRepository.getGliderById(testGliderId, testUserId))
            .thenAnswer((_) async => null);

        final result = await igcWriter.exportFlight(testFlightId);

        expect(result.success, isFalse);
        expect(result.error, contains('Glider not found'));
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
  });
}
