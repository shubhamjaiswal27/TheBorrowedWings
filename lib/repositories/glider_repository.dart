import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/glider.dart';

/// Repository for glider operations using Supabase
class GliderRepository {
  static final GliderRepository _instance = GliderRepository._internal();
  factory GliderRepository() => _instance;
  GliderRepository._internal();

  final SupabaseClient _client = SupabaseConfig.client;
  static const String _tableName = 'gliders';

  /// Creates a new glider
  Future<Glider> createGlider(Glider glider) async {
    if (!glider.isValid) {
      throw ArgumentError('Glider model is required and cannot be empty');
    }

    try {
      final data = await _client
          .from(_tableName)
          .insert(glider.toMapForInsert())
          .select()
          .single();
      
      return Glider.fromMap(data);
    } catch (e) {
      throw Exception('Failed to create glider: ${e.toString()}');
    }
  }

  /// Gets all gliders for a specific user ordered by creation date (newest first)
  Future<List<Glider>> getGlidersByUserId(String userId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return data.map((json) => Glider.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to get gliders for user: ${e.toString()}');
    }
  }

  /// Gets a glider by ID (with user ownership check)
  Future<Glider?> getGliderById(String id, String userId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .eq('user_id', userId) // Ensure user owns this glider
          .maybeSingle();
      
      return data != null ? Glider.fromMap(data) : null;
    } catch (e) {
      throw Exception('Failed to get glider by ID: ${e.toString()}');
    }
  }

  /// Updates an existing glider
  Future<Glider> updateGlider(Glider glider, String userId) async {
    if (glider.id == null) {
      throw ArgumentError('Cannot update glider without ID');
    }

    if (!glider.isValid) {
      throw ArgumentError('Glider model is required and cannot be empty');
    }

    try {
      final data = await _client
          .from(_tableName)
          .update(glider.toMap())
          .eq('id', glider.id!)
          .eq('user_id', userId) // Ensure user owns this glider
          .select()
          .single();
      
      return Glider.fromMap(data);
    } catch (e) {
      throw Exception('Failed to update glider: ${e.toString()}');
    }
  }

  /// Deletes a glider by ID (with user ownership check)
  Future<void> deleteGlider(String id, String userId) async {
    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // Ensure user owns this glider
    } catch (e) {
      throw Exception('Failed to delete glider: ${e.toString()}');
    }
  }

  /// Gets the count of gliders for a specific user
  Future<int> getGliderCountByUserId(String userId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId);
      
      return (response as List).length;
    } catch (e) {
      throw Exception('Failed to get glider count: ${e.toString()}');
    }
  }

  /// Checks if a glider exists for the given user
  Future<bool> hasGliders(String userId) async {
    try {
      final count = await getGliderCountByUserId(userId);
      return count > 0;
    } catch (e) {
      throw Exception('Failed to check if user has gliders: ${e.toString()}');
    }
  }

  /// Searches gliders by model name (for the specified user)
  Future<List<Glider>> searchGlidersByModel(String userId, String modelQuery) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .ilike('model', '%$modelQuery%')
          .order('created_at', ascending: false);
      
      return data.map((json) => Glider.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to search gliders by model: ${e.toString()}');
    }
  }

  /// Gets gliders by manufacturer (for the specified user)
  Future<List<Glider>> getGlidersByManufacturer(String userId, String manufacturer) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .eq('manufacturer', manufacturer)
          .order('created_at', ascending: false);
      
      return data.map((json) => Glider.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to get gliders by manufacturer: ${e.toString()}');
    }
  }

  /// Deletes all gliders for a user (cleanup function)
  Future<void> deleteAllGlidersByUserId(String userId) async {
    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete all gliders for user: ${e.toString()}');
    }
  }
}