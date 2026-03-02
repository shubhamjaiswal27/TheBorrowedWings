import 'package:sqflite/sqflite.dart';
import '../models/flight.dart';
import '../models/flight_fix.dart';
import '../models/glider.dart';
import 'app_database.dart';

/// Data Access Object for flight and flight fix operations.
/// 
/// Provides comprehensive CRUD operations for flights and their GPS fixes
/// with batch operations for performance.
class FlightDao {
  static const String flightTableName = 'flights';
  static const String fixTableName = 'flight_fixes';

  /// Gets database instance
  Future<Database> get _database async => await AppDatabase.instance.database;

  /// Inserts a new flight
  Future<int> insertFlight(Flight flight) async {
    final db = await _database;
    return await db.insert(flightTableName, flight.toMapForInsert());
  }

  /// Updates an existing flight
  Future<int> updateFlight(Flight flight) async {
    if (flight.id == null) {
      throw ArgumentError('Cannot update flight without ID');
    }

    final db = await _database;
    return await db.update(
      flightTableName,
      flight.toMap(),
      where: 'id = ?',
      whereArgs: [flight.id],
    );
  }

  /// Gets all flights with glider information, ordered by start time (newest first)
  Future<List<Map<String, dynamic>>> getAllFlightsWithGliders() async {
    final db = await _database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT f.*, g.manufacturer, g.model, g.glider_id, g.wing_class
      FROM $flightTableName f
      INNER JOIN gliders g ON f.glider_id = g.id
      ORDER BY f.started_at DESC
    ''');
    
    return results.map((row) {
      // Extract flight data
      final flightData = Map<String, dynamic>.from(row);
      flightData.removeWhere((key, value) => 
          ['manufacturer', 'model', 'glider_id', 'wing_class'].contains(key));
      final flight = Flight.fromMap(flightData);
      
      // Extract glider data
      final glider = Glider(
        id: flight.gliderId,
        manufacturer: row['manufacturer'] as String?,
        model: row['model'] as String,
        gliderId: row['glider_id'] as String?,
        wingClass: row['wing_class'] as String?,
        createdAt: DateTime.now(), // Not used in this context
      );
      
      return {
        'flight': flight,
        'glider': glider,
      };
    }).toList();
  }

  /// Gets a flight by ID
  Future<Flight?> getFlightById(int id) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      flightTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Flight.fromMap(maps.first);
  }

  /// Gets a flight with its glider information
  Future<Map<String, dynamic>?> getFlightWithGlider(int flightId) async {
    final db = await _database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT f.*, g.manufacturer, g.model, g.glider_id, g.wing_class
      FROM $flightTableName f
      INNER JOIN gliders g ON f.glider_id = g.id
      WHERE f.id = ?
    ''', [flightId]);
    
    if (results.isEmpty) return null;
    
    final row = results.first;
    final flightData = Map<String, dynamic>.from(row);
    flightData.removeWhere((key, value) => 
        ['manufacturer', 'model', 'glider_id', 'wing_class'].contains(key));
    final flight = Flight.fromMap(flightData);
    
    final glider = Glider(
      id: flight.gliderId,
      manufacturer: row['manufacturer'] as String?,
      model: row['model'] as String,
      gliderId: row['glider_id'] as String?,
      wingClass: row['wing_class'] as String?,
      createdAt: DateTime.now(),
    );
    
    return {
      'flight': flight,
      'glider': glider,
    };
  }

  /// Deletes a flight and all its fixes
  Future<int> deleteFlight(int id) async {
    final db = await _database;
    // Fixes will be deleted automatically due to CASCADE constraint
    return await db.delete(
      flightTableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Insert flight fixes in batch for performance
  Future<void> insertFlightFixesBatch(List<FlightFix> fixes) async {
    if (fixes.isEmpty) return;
    
    final db = await _database;
    final batch = db.batch();
    
    for (final fix in fixes) {
      batch.insert(fixTableName, fix.toMapForInsert());
    }
    
    await batch.commit(noResult: true);
  }

  /// Insert a single flight fix
  Future<int> insertFlightFix(FlightFix fix) async {
    final db = await _database;
    return await db.insert(fixTableName, fix.toMapForInsert());
  }

  /// Gets all fixes for a flight, ordered by sequence number
  Future<List<FlightFix>> getFlightFixes(int flightId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      fixTableName,
      where: 'flight_id = ?',
      whereArgs: [flightId],
      orderBy: 'seq ASC',
    );
    
    return maps.map((map) => FlightFix.fromMap(map)).toList();
  }

  /// Gets fixes for a flight within a time range
  Future<List<FlightFix>> getFlightFixesInTimeRange(
    int flightId,
    DateTime startTime,
    DateTime endTime,
  ) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      fixTableName,
      where: 'flight_id = ? AND t >= ? AND t <= ?',
      whereArgs: [
        flightId,
        startTime.millisecondsSinceEpoch,
        endTime.millisecondsSinceEpoch,
      ],
      orderBy: 'seq ASC',
    );
    
    return maps.map((map) => FlightFix.fromMap(map)).toList();
  }

  /// Gets first few fixes for preview
  Future<List<FlightFix>> getFlightFixesPreview(int flightId, {int limit = 5}) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      fixTableName,
      where: 'flight_id = ?',
      whereArgs: [flightId],
      orderBy: 'seq ASC',
      limit: limit,
    );
    
    return maps.map((map) => FlightFix.fromMap(map)).toList();
  }

  /// Gets last few fixes for preview
  Future<List<FlightFix>> getFlightFixesLast(int flightId, {int limit = 5}) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      fixTableName,
      where: 'flight_id = ?',
      whereArgs: [flightId],
      orderBy: 'seq DESC',
      limit: limit,
    );
    
    // Reverse to get chronological order
    final fixes = maps.map((map) => FlightFix.fromMap(map)).toList();
    return fixes.reversed.toList();
  }

  /// Gets count of fixes for a flight
  Future<int> getFlightFixCount(int flightId) async {
    final db = await _database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $fixTableName WHERE flight_id = ?',
      [flightId],
    ));
    return count ?? 0;
  }

  /// Gets flights for a specific glider
  Future<List<Flight>> getFlightsForGlider(int gliderId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      flightTableName,
      where: 'glider_id = ?',
      whereArgs: [gliderId],
      orderBy: 'started_at DESC',
    );
    
    return maps.map((map) => Flight.fromMap(map)).toList();
  }

  /// Gets flight statistics
  Future<Map<String, dynamic>> getFlightStatistics() async {
    final db = await _database;
    final results = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_flights,
        COUNT(CASE WHEN takeoff_at IS NOT NULL AND landed_at IS NOT NULL THEN 1 END) as completed_flights,
        AVG(CASE WHEN takeoff_at IS NOT NULL AND landed_at IS NOT NULL 
          THEN (landed_at - takeoff_at) / 1000.0 END) as avg_flight_duration_sec,
        SUM(fix_count) as total_fixes,
        MAX(started_at) as last_flight_at
      FROM $flightTableName
    ''');
    
    if (results.isEmpty) {
      return {
        'total_flights': 0,
        'completed_flights': 0,
        'avg_flight_duration_sec': 0.0,
        'total_fixes': 0,
        'last_flight_at': null,
      };
    }
    
    final row = results.first;
    return {
      'total_flights': row['total_flights'] ?? 0,
      'completed_flights': row['completed_flights'] ?? 0,
      'avg_flight_duration_sec': row['avg_flight_duration_sec'] ?? 0.0,
      'total_fixes': row['total_fixes'] ?? 0,
      'last_flight_at': row['last_flight_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(row['last_flight_at'] as int)
          : null,
    };
  }

  /// Gets flights within a date range
  Future<List<Flight>> getFlightsInDateRange(DateTime start, DateTime end) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      flightTableName,
      where: 'started_at >= ? AND started_at <= ?',
      whereArgs: [
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'started_at DESC',
    );
    
    return maps.map((map) => Flight.fromMap(map)).toList();
  }

  /// Updates flight IGC export path
  Future<int> updateFlightIgcPath(int flightId, String igcPath) async {
    final db = await _database;
    return await db.update(
      flightTableName,
      {'igc_path': igcPath},
      where: 'id = ?',
      whereArgs: [flightId],
    );
  }

  /// Checks if a flight exists
  Future<bool> flightExists(int id) async {
    final db = await _database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $flightTableName WHERE id = ?',
      [id],
    ));
    return (count ?? 0) > 0;
  }

  /// Deletes all flights and fixes (for testing)
  Future<void> deleteAllFlights() async {
    final db = await _database;
    await db.delete(fixTableName);
    await db.delete(flightTableName);
  }
}