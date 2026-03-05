import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/pilot.dart';

/// Repository for pilot profile operations using Supabase
class PilotRepository {
  static final PilotRepository _instance = PilotRepository._internal();
  factory PilotRepository() => _instance;
  PilotRepository._internal();

  final SupabaseClient _client = SupabaseConfig.client;
  static const String _tableName = 'pilots';

  /// Creates a new pilot profile
  Future<Pilot> createPilot(Pilot pilot) async {
    try {
      final data = await _client
          .from(_tableName)
          .insert(pilot.toMapForInsert())
          .select()
          .single();
      
      return Pilot.fromMap(data);
    } catch (e) {
      throw Exception('Failed to create pilot profile: ${e.toString()}');
    }
  }

  /// Gets a pilot by their user ID
  Future<Pilot?> getPilotByUserId(String userId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      return data != null ? Pilot.fromMap(data) : null;
    } catch (e) {
      throw Exception('Failed to get pilot by user ID: ${e.toString()}');
    }
  }

  /// Gets a pilot by their ID
  Future<Pilot?> getPilotById(String id) async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .eq('id', id)
          .maybeSingle();
      
      return data != null ? Pilot.fromMap(data) : null;
    } catch (e) {
      throw Exception('Failed to get pilot by ID: ${e.toString()}');
    }
  }

  /// Updates an existing pilot profile
  Future<Pilot> updatePilot(Pilot pilot) async {
    if (pilot.id == null) {
      throw ArgumentError('Cannot update pilot without ID');
    }

    try {
      final updatedPilot = pilot.copyWith(); // This updates the updatedAt timestamp
      
      final data = await _client
          .from(_tableName)
          .update(updatedPilot.toMap())
          .eq('id', pilot.id!)
          .select()
          .single();
      
      return Pilot.fromMap(data);
    } catch (e) {
      throw Exception('Failed to update pilot profile: ${e.toString()}');
    }
  }

  /// Updates a pilot profile by user ID
  Future<Pilot> updatePilotByUserId(String userId, Pilot pilot) async {
    try {
      final updatedPilot = pilot.copyWith(userId: userId); // Ensure userId is set and update timestamp
      
      final data = await _client
          .from(_tableName)
          .update(updatedPilot.toMap())
          .eq('user_id', userId)
          .select()
          .single();
      
      return Pilot.fromMap(data);
    } catch (e) {
      throw Exception('Failed to update pilot profile by user ID: ${e.toString()}');
    }
  }

  /// Checks if a pilot profile exists for the given user ID
  Future<bool> hasPilotProfile(String userId) async {
    try {
      final data = await _client
          .from(_tableName)
          .select('id')
          .eq('user_id', userId)
          .limit(1)
          .maybeSingle();

      return data != null;
    } catch (e) {
      throw Exception('Failed to check if pilot profile exists: ${e.toString()}');
    }
  }

  /// Deletes a pilot profile by ID
  Future<void> deletePilot(String id) async {
    try {
      await _client
          .from(_tableName)
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete pilot profile: ${e.toString()}');
    }
  }

  /// Gets all pilot profiles (admin function, not typically needed)
  Future<List<Pilot>> getAllPilots() async {
    try {
      final data = await _client
          .from(_tableName)
          .select()
          .order('created_at', ascending: false);
      
      return data.map((json) => Pilot.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to get all pilots: ${e.toString()}');
    }
  }
}