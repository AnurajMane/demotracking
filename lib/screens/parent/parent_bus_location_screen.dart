import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:demotracking/services/bus_service.dart';

class ParentBusLocationScreen extends StatefulWidget {
  const ParentBusLocationScreen({super.key});

  @override
  State<ParentBusLocationScreen> createState() => _ParentBusLocationScreenState();
}

class _ParentBusLocationScreenState extends State<ParentBusLocationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final BusService _busService = BusService();
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _children = [];
  final Map<String, LatLng> _busLocations = {};
  final Map<String, String> _estimatedArrivals = {};
  LatLng? _currentLocation;
  DateTime? _lastUpdate;
  String? _busId;

  @override
  void initState() {
    super.initState();
    _loadData();
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

      // Load children data with bus information
      final childrenResponse = await _supabase
          .from('students')
          .select('*, buses(*, routes!fk_bus_route(*))')
          .eq('parent_id', userId);
      _children = List<Map<String, dynamic>>.from(childrenResponse);

      // Load initial bus locations
      for (final child in _children) {
        if (child['buses'] != null) {
          final busId = child['buses']['id'];
          final locationResponse = await _supabase
              .from('bus_locations')
              .select()
              .eq('bus_id', busId)
              .order('timestamp', ascending: false)
              .limit(1)
              .single();

          _busLocations[busId] = LatLng(
            locationResponse['latitude'],
            locationResponse['longitude'],
          );
                }
      }

      setState(() {});
      _subscribeToBusLocation();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToBusLocation() {
    if (_busId != null) {
      _busService.subscribeToBusLocation(_busId!, (location) {
        setState(() {
          _currentLocation = LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          );
          _lastUpdate = DateTime.parse(location['created_at']);
        });
      });
    }
  }

  void _updateEstimatedArrival(String busId) {
    // Calculate estimated arrival time based on distance and speed
    // This is a simplified calculation - you might want to use a more sophisticated algorithm
    final distance = 5.0; // Example distance in kilometers
    final speed = 40.0; // Example speed in km/h
    final minutes = (distance / speed * 60).round();
    _estimatedArrivals[busId] = '$minutes minutes';
  }

  Widget _buildBusInfo(Map<String, dynamic> child) {
    if (child['buses'] == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No bus assigned'),
        ),
      );
    }

    final bus = child['buses'];
    final busId = bus['id'];
    final location = _busLocations[busId];
    final estimatedArrival = _estimatedArrivals[busId];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${child['name']}\'s Bus',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Bus: ${bus['name']}'),
            Text('Plate Number: ${bus['plate_number']}'),
            Text('Route: ${bus['routes']['name']}'),
            if (estimatedArrival != null)
              Text('Estimated Arrival: $estimatedArrival'),
            if (location != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    center: location,
                    zoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.demotracking.app',
                    ),
                    MarkerLayer(
                      markers: [
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bus Locations'),
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
              : _children.isEmpty
                  ? const Center(
                      child: Text('No children registered'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return Column(
                          children: [
                            _buildBusInfo(child),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
    );
  }
} 