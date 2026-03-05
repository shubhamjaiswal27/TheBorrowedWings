import 'package:flutter/material.dart';
import 'config/supabase_config.dart';
import 'app.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  try {
    await SupabaseConfig.initialize();
    print('✓ Supabase initialized successfully');
  } catch (e) {
    print('✗ Supabase initialization error: $e');
    // Continue anyway, but the app will show an error state
  }
  
  runApp(const ParaglidingLogApp());
}