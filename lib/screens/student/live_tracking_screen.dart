import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class LiveTrackingScreen extends StatefulWidget {
  const LiveTrackingScreen({super.key});

  @override
  State<LiveTrackingScreen> createState() => _LiveTrackingScreenState();
}

class _LiveTrackingScreenState extends State<LiveTrackingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _busData;
  Map<String, dynamic>? _routeData;
  Position? _currentPosition;
  LatLng? _busLocation;
  double _estimatedArrivalTime = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
    _subscribeToBusLocation();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      // Load student data with bus and route information
      final studentResponse = await _supabase
          .from('students')
          .select('*, bus:bus_id(*, route:route_id(*))')
          .eq('id', userId)
          .maybeSingle();
      _studentData = studentResponse;

      if (_studentData != null) {
        _busData = _studentData!['bus'];
        _routeData = _busData?['route'];
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

  Future<void> _getCurrentLocation() async {
    try {
      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      // Get current position
      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
    }
  }

  void _subscribeToBusLocation() {
    if (_busData == null) return;

    _supabase
        .from('bus_locations')
        .stream(primaryKey: ['id'])
        .eq('bus_id', _busData!['id'])
        .listen((data) {
      if (data.isNotEmpty) {
        final location = data.first;
        setState(() {
          _busLocation = LatLng(
            location['latitude'] as double,
            location['longitude'] as double,
          );
          _estimatedArrivalTime = location['estimated_arrival_time'] as double;
        });
      }
    });
  }

  Widget _buildBusInfo() {
    if (_busData == null || _routeData == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No bus assigned'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _busData!['name'],
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        'Plate: ${_busData!['plate_number']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Route: ${_routeData!['name']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_busLocation != null) ...[
              const SizedBox(height: 8),
              Text(
                'Estimated Arrival: ${_estimatedArrivalTime.toStringAsFixed(1)} minutes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (_busLocation == null) {
      return const Center(
        child: Text('Waiting for bus location...'),
      );
    }

    return FlutterMap(
      options: MapOptions(
        center: _busLocation,
        zoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.demotracking.app',
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
            if (_currentPosition != null)
              Marker(
                point: LatLng(
                  _currentPosition!.latitude,
                  _currentPosition!.longitude,
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 40,
                ),
              ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Tracking'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadData();
              _getCurrentLocation();
            },
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
                    _buildBusInfo(),
                    Expanded(
                      child: _buildMap(),
                    ),
                  ],
                ),
    );
  }
} 