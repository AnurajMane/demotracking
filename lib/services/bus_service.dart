import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class BusService {
  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;

  String get currentUserId => _supabase.auth.currentUser?.id ?? '';

  // Subscribe to real-time bus location updates
  Stream<List<Map<String, dynamic>>> subscribeToBusLocations() {
    return _supabase
        .from('buses')
        .stream(primaryKey: ['id'])
        .map((data) => data.map((bus) {
              return {
                'id': bus['id'],
                'name': bus['name'],
                'location': LatLng(
                  bus['latitude'] as double,
                  bus['longitude'] as double,
                ),
                'status': bus['status'],
                'driver': bus['driver_name'],
                'driver_id': bus['driver_id'],
                'students': bus['student_count'],
                'route': bus['route_name'],
                'speed': bus['speed'],
                'lastUpdate': bus['last_updated'],
              };
            }).toList());
  }

  // Get initial bus locations
  Future<List<Map<String, dynamic>>> getBusLocations() async {
    final response = await _supabase.from('buses').select();
    return response.map((bus) {
      return {
        'id': bus['id'],
        'name': bus['name'],
        'location': LatLng(
          bus['latitude'] as double,
          bus['longitude'] as double,
        ),
        'status': bus['status'],
        'driver': bus['driver_name'],
        'driver_id': bus['driver_id'],
        'students': bus['student_count'],
        'route': bus['route_name'],
        'speed': bus['speed'],
        'lastUpdate': bus['last_updated'],
      };
    }).toList();
  }

  // Update bus location
  Future<void> updateBusLocation({
    required String busId,
    required double latitude,
    required double longitude,
    required double speed,
    required String status,
    required String driverName,
  }) async {
    await _supabase.from('buses').update({
      'latitude': latitude,
      'longitude': longitude,
      'speed': speed,
      'status': status,
      'driver_name': driverName,
      'last_updated': DateTime.now().toIso8601String(),
    }).eq('id', busId);
  }

  void subscribeToBusLocation(String busId, Function(Map<String, dynamic>) onLocationUpdate) {
    // Cancel existing subscription if any
    dispose();

    // Subscribe to bus location updates
    _channel = _supabase
        .channel('bus_location_$busId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'bus_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'bus_id',
            value: busId,
          ),
          callback: (payload) {
            onLocationUpdate(payload.newRecord);
          },
        )
        .subscribe();
  }

  void dispose() {
    _channel?.unsubscribe();
    _channel = null;
  }

  Future<List<Map<String, dynamic>>> getBuses() async {
    final response = await _supabase
        .from('buses')
        .select('''
              id,
              name,
              route_id,
              driver_id,
              status,
              routes (
                  id,
                  name
              ),
              profiles (
                  id,
                  full_name
              )
          ''');
    return List<Map<String, dynamic>>.from(response);
  }
} 