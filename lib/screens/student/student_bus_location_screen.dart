import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:demotracking/services/bus_service.dart';

class StudentBusLocationScreen extends StatefulWidget {
  const StudentBusLocationScreen({super.key});

  @override
  State<StudentBusLocationScreen> createState() => _StudentBusLocationScreenState();
}

class _StudentBusLocationScreenState extends State<StudentBusLocationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BusService _busService = BusService();
  bool _isLoading = false;
  String _errorMessage = '';

  // Bus data
  Map<String, dynamic>? _bus;
  Map<String, dynamic>? _route;
  LatLng? _busLocation;
  String _estimatedArrival = '';

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToBusLocation();
  }

  @override
  void dispose() {
    _busService.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      // Load student data with bus information
      final studentResponse = await _supabase
          .from('students')
          .select('*, buses(*, routes:routes!fk_bus_route(*))')
          .eq('id', userId)
          .maybeSingle();

      if (studentResponse == null || studentResponse['buses'] == null) {
        throw 'No bus assigned';
      }

      setState(() {
        _bus = studentResponse['buses'];
        _route = _bus?['routes'];
      });

      // Load initial bus location
      final locationResponse = await _supabase
          .from('bus_locations')
          .select()
          .eq('bus_id', _bus!['id'])
          .order('timestamp', ascending: false)
          .limit(1)
          .single();

      setState(() {
        _busLocation = LatLng(
          locationResponse['latitude'],
          locationResponse['longitude'],
        );
      });
        } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToBusLocation() {
    if (_bus == null) return;

    _busService.subscribeToBusLocation(_bus!['id'], (location) {
      if (mounted) {
        setState(() {
          _busLocation = LatLng(location['latitude'], location['longitude']);
          _updateEstimatedArrival();
        });
      }
    });
  }

  void _updateEstimatedArrival() {
    if (_busLocation == null || _route == null) return;

    // Calculate estimated arrival time based on distance and speed
    // This is a simplified calculation - you might want to use a more sophisticated algorithm
    final distance = 5.0; // Example distance in kilometers
    final speed = 40.0; // Example speed in km/h
    final minutes = (distance / speed * 60).round();
    _estimatedArrival = '$minutes minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Location'),
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
              : Column(
                  children: [
                    if (_bus != null && _route != null) ...[
                      Card(
                        margin: const EdgeInsets.all(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bus Information',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Text('Bus: ${_bus!['name']}'),
                              Text('Plate Number: ${_bus!['plate_number']}'),
                              Text('Route: ${_route!['name']}'),
                              if (_estimatedArrival.isNotEmpty)
                                Text('Estimated Arrival: $_estimatedArrival'),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: _busLocation == null
                            ? const Center(
                                child: Text('Waiting for bus location...'),
                              )
                            : FlutterMap(
                                options: MapOptions(
                                  center: _busLocation,
                                  zoom: 15,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate:
                                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName:
                                        'com.demotracking.app',
                                  ),
                                  MarkerLayer(
                                    markers: [
                                      Marker(
                                        point: _busLocation!,
                                        child: const Icon(
                                          Icons.directions_bus,
                                          color: Colors.blue,
                                          size: 40,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
    );
  }
} 