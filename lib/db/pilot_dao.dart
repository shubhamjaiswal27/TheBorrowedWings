import 'package:sqflite/sqflite.dart';
import '../models/pilot.dart';
import 'app_database.dart';

/// Data Access Object for pilot profile operations.
/// 
/// Implements the single row pattern where only one pilot profile exists
/// in the database (always using id=1). This ensures we have exactly one
/// pilot profile per app installation.
class PilotDao {
  static const String _tableName = 'pilot_profile';
  static const int _singleRowId = 1; // Enforce single row pattern
  
  final AppDatabase _database;

  PilotDao({AppDatabase? database}) : _database = database ?? AppDatabase.instance;

  /// Initializes the database (primarily for testing)
  Future<void> initDb() async {
    await _database.database;
  }

  /// Retrieves the single pilot profile from the database
  /// 
  /// Returns null if no profile exists yet.
  Future<Pilot?> getProfile() async {
    final db = await _database.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      _tableName,
      where: 'id = ?',
      whereArgs: [_singleRowId],
    );

    if (maps.isEmpty) {
      return null;
    }

    return Pilot.fromMap(maps.first);
  }

  /// Saves or updates the pilot profile using a transaction
  /// 
  /// This method enforces the single row pattern by always using id=1.
  /// If a profile already exists, it updates it. If not, it creates a new one.
  /// The updatedAt timestamp is automatically set to the current time.
  Future<void> upsertProfile(Pilot pilot) async {
    final db = await _database.database;
    
    // Create pilot data with forced id=1 and current updatedAt
    final pilotData = pilot.copyWith(id: _singleRowId).toMap();
    
    // Use transaction to ensure atomicity
    await db.transaction((txn) async {
      await txn.insert(
        _tableName,
        pilotData,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// Deletes the pilot profile
  /// 
  /// After calling this method, getProfile() will return null.
  Future<void> deleteProfile() async {
    final db = await _database.database;
    
    await db.transaction((txn) async {
      await txn.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [_singleRowId],
      );
    });
  }

  /// Checks if a pilot profile exists
  Future<bool> hasProfile() async {
    final profile = await getProfile();
    return profile != null;
  }

  /// Gets the count of pilot profiles (should always be 0 or 1)
  Future<int> getProfileCount() async {
    final db = await _database.database;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM $_tableName'),
    );
    return count ?? 0;
  }

  /// Deletes all pilot profiles (useful for testing)
  /// 
  /// Note: In normal operation, there should only be one profile anyway,
  /// but this method ensures a clean slate.
  Future<void> deleteAllProfiles() async {
    final db = await _database.database;
    
    await db.transaction((txn) async {
      await txn.delete(_tableName);
    });
  }
}