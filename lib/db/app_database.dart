import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

/// Main database class responsible for SQLite database initialization and management.
/// 
/// Handles database creation, schema versioning, and migration logic.
/// Supports both file-based databases (production) and in-memory databases (testing).
class AppDatabase {
  static const String _databaseName = 'the_borrowed_wings.db';
  static const int _databaseVersion = 1;
  
  // Singleton pattern
  AppDatabase._privateConstructor() : _isTestInstance = false;
  static final AppDatabase instance = AppDatabase._privateConstructor();
  
  static Database? _database;
  
  // For testing only
  Database? _testDatabase;
  final bool _isTestInstance;

  AppDatabase._testConstructor() : _isTestInstance = true;

  /// Gets the database instance, initializing if necessary
  Future<Database> get database async {
    if (_isTestInstance) {
      _testDatabase ??= await _initDatabase(inMemory: true);
      return _testDatabase!;
    } else {
      _database ??= await _initDatabase();
      return _database!;
    }
  }

  /// Initializes the database with proper path and version management
  /// 
  /// For testing, you can set [inMemory] to true to create an in-memory database
  /// that doesn't require file system access.
  Future<Database> _initDatabase({String? customPath, bool inMemory = false}) async {
    String path;
    
    if (inMemory) {
      // Use in-memory database for testing
      path = ':memory:';
    } else if (customPath != null) {
      path = customPath;
    } else {
      // Production path using path_provider
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      path = join(documentsDirectory.path, _databaseName);
    }
    
    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates a test database instance with custom configuration
  /// This method is specifically for testing and bypasses the singleton pattern
  static Future<AppDatabase> createTestInstance({bool inMemory = true}) async {
    final testInstance = AppDatabase._testConstructor();
    // The database will be initialized lazily when first accessed
    return testInstance;
  }

  /// Creates database tables on first initialization
  Future<void> _onCreate(Database db, int version) async {
    await _createPilotTable(db);
  }

  /// Handles database migrations when version changes
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future migrations here
    // For now, we only have version 1, so no migrations needed
    if (oldVersion < 1) {
      await _createPilotTable(db);
    }
  }

  /// Creates the pilot_profile table
  /// 
  /// Note: We enforce the single row pattern by using id=1 as primary key
  /// and handling upserts in the DAO layer.
  Future<void> _createPilotTable(Database db) async {
    await db.execute('''
      CREATE TABLE pilot_profile (
        id INTEGER PRIMARY KEY,
        full_name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        nationality TEXT,
        license_id TEXT,
        emergency_contact_name TEXT,
        emergency_contact_phone TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  /// Closes the database connection
  Future<void> close() async {
    if (_isTestInstance) {
      final db = _testDatabase;
      if (db != null) {
        await db.close();
        _testDatabase = null;
      }
    } else {
      final db = _database;
      if (db != null) {
        await db.close();
        _database = null;
      }
    }
  }

  /// Resets the singleton instance (useful for testing)
  static void resetInstance() {
    _database = null;
  }

  /// Deletes the database file (useful for testing)
  /// Note: This only works for file-based databases, not in-memory ones
  Future<void> deleteDatabase() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
    
    try {
      Directory documentsDirectory = await getApplicationDocumentsDirectory();
      String path = join(documentsDirectory.path, _databaseName);
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // Ignore errors when path_provider is not available (testing)
    }
  }
}