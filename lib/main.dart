import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io';
import 'app.dart';
import 'db/app_database.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database factory for desktop platforms
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory
    databaseFactory = databaseFactoryFfi;
  }
  
  // Initialize database on app startup to catch any issues early
  try {
    await AppDatabase.instance.database;
    print('✓ Database initialized successfully');
  } catch (e) {
    print('✗ Database initialization error: $e');
    // Continue anyway, but log the error
  }
  
  runApp(const ParaglidingLogApp());
}