import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RealTimeTrackingScreen extends StatefulWidget {
  const RealTimeTrackingScreen({super.key});

  @override
  State<RealTimeTrackingScreen> createState() => _RealTimeTrackingScreenState();
}

class _RealTimeTrackingScreenState extends State<RealTimeTrackingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _buses = [];
  final Map<String, LatLng> _busLocations = {};
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToBusLocations();
  }

  @override
  void dispose() {
    _unsubscribeFromBusLocations();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      // Load buses based on user role
      final userRole = await _getUserRole(userId);
      final busesResponse = await _loadBusesForRole(userId, userRole);
      _buses = List<Map<String, dynamic>>.from(busesResponse);

      // Load initial bus locations
      for (final bus in _buses) {
        final locationResponse = await _supabase
            .from('bus_locations')
            .select('*')
            .eq('bus_id', bus['id'])
            .order('timestamp', ascending: false)
            .limit(1)
            .single();
        
        _busLocations[bus['id']] = LatLng(
          locationResponse['latitude'] as double,
          locationResponse['longitude'] as double,
        );
            }

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getUserRole(String userId) async {
    final response = await _supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .single();
    return response['role'] as String;
  }

  Future<List<Map<String, dynamic>>> _loadBusesForRole(
    String userId,
    String role,
  ) async {
    switch (role) {
      case 'admin':
        return await _supabase.from('buses').select('*');
      case 'driver':
        final driverResponse = await _supabase
            .from('drivers')
            .select('bus_id')
            .eq('user_id', userId)
            .single();
        return await _supabase
            .from('buses')
            .select('*')
            .eq('id', driverResponse['bus_id']);
      case 'parent':
        final parentResponse = await _supabase
            .from('parents')
            .select('id')
            .eq('user_id', userId)
            .single();
        final studentsResponse = await _supabase
            .from('students')
            .select('bus_id')
            .eq('parent_id', parentResponse['id']);
        final busIds = (studentsResponse as List)
            .map((student) => student['bus_id'])
            .toSet();
        return await _supabase
            .from('buses')
            .select('*')
            .inFilter('id', busIds.toList());
      default:
        return [];
    }
  }

  void _subscribeToBusLocations() {
    _supabase
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (data.isNotEmpty) {
        final location = data.first;
        final busId = location['bus_id'];
        if (_busLocations.containsKey(busId)) {
          setState(() {
            _busLocations[busId] = LatLng(
              location['latitude'] as double,
              location['longitude'] as double,
            );
          });
        }
      }
    });
  }

  void _unsubscribeFromBusLocations() {
    _supabase.dispose();
  }

  Widget _buildBusMarker(Map<String, dynamic> bus) {
    final location = _busLocations[bus['id']];
    if (location == null) return const SizedBox.shrink();

    return MarkerLayer(
      markers: [
        Marker(
          point: location,
          width: 40,
          height: 40,
          child: const Icon(
            Icons.directions_bus,
            color: Colors.blue,
            size: 40,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-Time Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buses.isEmpty
                  ? const Center(
                      child: Text('No buses found'),
                    )
                  : FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        center: LatLng(0, 0), // Default center
                        zoom: 13,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.demotracking.app',
                        ),
                        ..._buses.map(_buildBusMarker),
                      ],
                    ),
    );
  }
} 