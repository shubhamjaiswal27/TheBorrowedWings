import 'package:sqflite/sqflite.dart';
import '../models/glider.dart';
import 'app_database.dart';

/// Data Access Object for glider operations.
/// 
/// Provides CRUD operations for gliders with proper error handling and validation.
class GliderDao {
  static const String tableName = 'gliders';

  /// Gets database instance
  Future<Database> get _database async => await AppDatabase.instance.database;

  /// Inserts a new glider
  Future<int> insertGlider(Glider glider) async {
    if (!glider.isValid) {
      throw ArgumentError('Glider model is required and cannot be empty');
    }

    try {
      final db = await _database;
      final gliderMap = glider.toMapForInsert();
      
      final result = await db.insert(tableName, gliderMap);
      return result;
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  /// Gets all gliders ordered by creation date (newest first)
  Future<List<Glider>> getAllGliders() async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => Glider.fromMap(map)).toList();
  }

  /// Gets a glider by ID
  Future<Glider?> getGliderById(int id) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) {
      return null;
    }

    return Glider.fromMap(maps.first);
  }

  /// Updates an existing glider
  Future<int> updateGlider(Glider glider) async {
    if (glider.id == null) {
      throw ArgumentError('Cannot update glider without ID');
    }
    if (!glider.isValid) {
      throw ArgumentError('Glider model is required and cannot be empty');
    }

    final db = await _database;
    return await db.update(
      tableName,
      glider.toMap(),
      where: 'id = ?',
      whereArgs: [glider.id],
    );
  }

  /// Deletes a glider by ID
  Future<int> deleteGlider(int id) async {
    final db = await _database;
    return await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Checks if a glider exists by ID
  Future<bool> gliderExists(int id) async {
    final db = await _database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $tableName WHERE id = ?',
      [id],
    ));
    return (count ?? 0) > 0;
  }

  /// Searches gliders by model or manufacturer
  Future<List<Glider>> searchGliders(String query) async {
    final db = await _database;
    final String searchPattern = '%${query.toLowerCase()}%';
    
    final List<Map<String, dynamic>> maps = await db.query(
      tableName,
      where: 'LOWER(model) LIKE ? OR LOWER(manufacturer) LIKE ? OR LOWER(glider_id) LIKE ?',
      whereArgs: [searchPattern, searchPattern, searchPattern],
      orderBy: 'created_at DESC',
    );
    
    return maps.map((map) => Glider.fromMap(map)).toList();
  }

  /// Gets recently used gliders (based on flight activity)
  Future<List<Glider>> getRecentlyUsedGliders({int limit = 5}) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT g.* FROM $tableName g
      INNER JOIN flights f ON g.id = f.glider_id
      ORDER BY f.started_at DESC
      LIMIT ?
    ''', [limit]);
    
    return maps.map((map) => Glider.fromMap(map)).toList();
  }

  /// Gets gliders with flight statistics
  Future<List<Map<String, dynamic>>> getGlidersWithStats() async {
    final db = await _database;
    final List<Map<String, dynamic>> results = await db.rawQuery('''
      SELECT g.*,
        COUNT(f.id) as flight_count,
        MAX(f.started_at) as last_flight_at
      FROM $tableName g
      LEFT JOIN flights f ON g.id = f.glider_id
      GROUP BY g.id
      ORDER BY g.created_at DESC
    ''');
    
    return results.map((row) {
      final glider = Glider.fromMap(row);
      return {
        'glider': glider,
        'flight_count': row['flight_count'] ?? 0,
        'last_flight_at': row['last_flight_at'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(row['last_flight_at'] as int)
            : null,
      };
    }).toList();
  }

  /// Gets count of all gliders
  Future<int> getGliderCount() async {
    final db = await _database;
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM $tableName',
    ));
    return count ?? 0;
  }

  /// Deletes all gliders (for testing)
  Future<void> deleteAllGliders() async {
    final db = await _database;
    await db.delete(tableName);
  }
}