import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/flight.dart';
import '../models/flight_fix.dart';

/// Repository for flight operations using Supabase
class FlightRepository {
  static final FlightRepository _instance = FlightRepository._internal();
  factory FlightRepository() => _instance;
  FlightRepository._internal();

  final SupabaseClient _client = SupabaseConfig.client;
  static const String _flightTableName = 'flights';
  static const String _fixTableName = 'flight_fixes';

  /// Creates a new flight
  Future<Flight> createFlight(Flight flight) async {
    try {
      final data = await _client
          .from(_flightTableName)
          .insert(flight.toMapForInsert())
          .select()
          .single();
      
      return Flight.fromMap(data);
    } catch (e) {
      throw Exception('Failed to create flight: ${e.toString()}');
    }
  }

  /// Updates an existing flight
  Future<Flight> updateFlight(Flight flight, String userId) async {
    if (flight.id == null) {
      throw ArgumentError('Cannot update flight without ID');
    }

    try {
      final data = await _client
          .from(_flightTableName)
          .update(flight.toMap())
          .eq('id', flight.id!)
          .eq('user_id', userId) // Ensure user owns this flight
          .select()
          .single();
      
      return Flight.fromMap(data);
    } catch (e) {
      throw Exception('Failed to update flight: ${e.toString()}');
    }
  }

  /// Gets all flights for a user with glider information, ordered by start time (newest first)
  Future<List<Map<String, dynamic>>> getFlightsWithGlidersByUserId(String userId) async {
    try {
      final data = await _client
          .from(_flightTableName)
          .select('''
            *,
            gliders!inner(manufacturer, model, glider_id, wing_class)
          ''')
          .eq('user_id', userId)
          .order('started_at', ascending: false);
      
      return data.map((row) {
        // Extract flight data
        final flightData = Map<String, dynamic>.from(row);
        final gliderData = flightData.remove('gliders') as Map<String, dynamic>;
        
        // Create flight object
        final flight = Flight.fromMap(flightData);
        
        // Return combined data
        return {
          'flight': flight,
          'glider_manufacturer': gliderData['manufacturer'],
          'glider_model': gliderData['model'], 
          'glider_id': gliderData['glider_id'],
          'glider_wing_class': gliderData['wing_class'],
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to get flights with gliders: ${e.toString()}');
    }
  }

  /// Gets a flight by ID (with user ownership check)
  Future<Flight?> getFlightById(String id, String userId) async {
    try {
      final data = await _client
          .from(_flightTableName)
          .select()
          .eq('id', id)
          .eq('user_id', userId) // Ensure user owns this flight
          .maybeSingle();
      
      return data != null ? Flight.fromMap(data) : null;
    } catch (e) {
      throw Exception('Failed to get flight by ID: ${e.toString()}');
    }
  }

  /// Gets flights by glider ID for a specific user
  Future<List<Flight>> getFlightsByGliderId(String gliderId, String userId) async {
    try {
      final data = await _client
          .from(_flightTableName)
          .select()
          .eq('glider_id', gliderId)
          .eq('user_id', userId)
          .order('started_at', ascending: false);
      
      return data.map((json) => Flight.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to get flights by glider ID: ${e.toString()}');
    }
  }

  /// Deletes a flight by ID (with user ownership check)
  Future<void> deleteFlight(String id, String userId) async {
    try {
      // Delete flight fixes first (cascade should handle this, but explicitly doing it for safety)
      await _client
          .from(_fixTableName)
          .delete()
          .eq('flight_id', id);
      
      // Delete the flight
      await _client
          .from(_flightTableName)
          .delete()
          .eq('id', id)
          .eq('user_id', userId); // Ensure user owns this flight
    } catch (e) {
      throw Exception('Failed to delete flight: ${e.toString()}');
    }
  }

  /// Gets the count of flights for a specific user
  Future<int> getFlightCountByUserId(String userId) async {
    try {
      final flights = await _client
          .from(_flightTableName)
          .select('id')
          .eq('user_id', userId);
      
      return flights.length;
    } catch (e) {
      throw Exception('Failed to get flight count: ${e.toString()}');
    }
  }

  /// Adds a flight fix to a flight
  Future<FlightFix> addFlightFix(FlightFix fix) async {
    try {
      final data = await _client
          .from(_fixTableName)
          .insert(fix.toMapForInsert())
          .select()
          .single();
      
      return FlightFix.fromMap(data);
    } catch (e) {
      throw Exception('Failed to add flight fix: ${e.toString()}');
    }
  }

  /// Adds multiple flight fixes to a flight in batch
  Future<List<FlightFix>> addFlightFixesBatch(List<FlightFix> fixes) async {
    if (fixes.isEmpty) return [];

    try {
      final data = await _client
          .from(_fixTableName)
          .insert(fixes.map((fix) => fix.toMapForInsert()).toList())
          .select();
      
      return data.map((json) => FlightFix.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to add flight fixes batch: ${e.toString()}');
    }
  }

  /// Gets all flight fixes for a flight, ordered by sequence number
  Future<List<FlightFix>> getFlightFixesByFlightId(String flightId) async {
    try {
      final data = await _client
          .from(_fixTableName)
          .select()
          .eq('flight_id', flightId)
          .order('seq', ascending: true);
      
      return data.map((json) => FlightFix.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to get flight fixes: ${e.toString()}');
    }
  }

  /// Gets flight fixes in a specific sequence range
  Future<List<FlightFix>> getFlightFixesInRange(
    String flightId, 
    int startSeq, 
    int endSeq,
  ) async {
    try {
      final data = await _client
          .from(_fixTableName)
          .select()
          .eq('flight_id', flightId)
          .gte('seq', startSeq)
          .lte('seq', endSeq)
          .order('seq', ascending: true);
      
      return data.map((json) => FlightFix.fromMap(json)).toList();
    } catch (e) {
      throw Exception('Failed to get flight fixes in range: ${e.toString()}');
    }
  }

  /// Gets the latest flight fix for a flight
  Future<FlightFix?> getLatestFlightFix(String flightId) async {
    try {
      final data = await _client
          .from(_fixTableName)
          .select()
          .eq('flight_id', flightId)
          .order('seq', ascending: false)
          .limit(1)
          .maybeSingle();
      
      return data != null ? FlightFix.fromMap(data) : null;
    } catch (e) {
      throw Exception('Failed to get latest flight fix: ${e.toString()}');
    }
  }

  /// Gets flight statistics for a user
  Future<Map<String, dynamic>> getFlightStatsByUserId(String userId) async {
    try {
      final flights = await _client
          .from(_flightTableName)
          .select('duration_sec, fix_count, takeoff_at, landed_at')
          .eq('user_id', userId);

      int totalFlights = flights.length;
      int completedFlights = 0;
      int totalDuration = 0;
      int totalFixes = 0;

      for (final flight in flights) {
        totalDuration += flight['duration_sec'] as int;
        totalFixes += flight['fix_count'] as int;
        if (flight['takeoff_at'] != null && flight['landed_at'] != null) {
          completedFlights++;
        }
      }

      return {
        'total_flights': totalFlights,
        'completed_flights': completedFlights,
        'total_duration_seconds': totalDuration,
        'total_fixes': totalFixes,
        'average_duration_seconds': totalFlights > 0 ? totalDuration / totalFlights : 0,
        'average_fixes_per_flight': totalFlights > 0 ? totalFixes / totalFlights : 0,
      };
    } catch (e) {
      throw Exception('Failed to get flight statistics: ${e.toString()}');
    }
  }

  /// Deletes all flights and fixes for a user (cleanup function)
  Future<void> deleteAllFlightsByUserId(String userId) async {
    try {
      // Get all flight IDs for this user
      final flightIds = await _client
          .from(_flightTableName)
          .select('id')
          .eq('user_id', userId);

      if (flightIds.isNotEmpty) {
        final ids = flightIds.map((f) => f['id'] as String).toList();
        
        // Delete all flight fixes
        await _client
            .from(_fixTableName)
            .delete()
            .inFilter('flight_id', ids);
      }
      
      // Delete all flights
      await _client
          .from(_flightTableName)
          .delete()
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Failed to delete all flights for user: ${e.toString()}');
    }
  }
}