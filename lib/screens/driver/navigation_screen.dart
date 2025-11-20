import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  State<NavigationScreen> createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _busData;
  Map<String, dynamic>? _routeData;
  List<Map<String, dynamic>> _stops = [];
  Position? _currentPosition;
  int _currentStopIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      // Load driver data with bus and route information
      final driverResponse = await _supabase
          .from('drivers')
          .select('*, bus:bus_id(*, route:route_id(*))')
          .eq('user_id', userId)
          .maybeSingle();
      _driverData = driverResponse;

      if (_driverData != null) {
        _busData = _driverData!['bus'];
        _routeData = _busData?['route'];

        // Load stops for the route
        if (_routeData != null) {
          final stopsResponse = await _supabase
              .from('stops')
              .select('*')
              .eq('route_id', _routeData!['id'])
              .order('sequence');
          _stops = List<Map<String, dynamic>>.from(stopsResponse);
        }
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

  void _updateBusLocation() async {
    if (_currentPosition == null || _busData == null) return;

    try {
      await _supabase.from('bus_locations').upsert({
        'bus_id': _busData!['id'],
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'estimated_arrival_time': _calculateEstimatedArrivalTime(),
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update bus location: $e';
      });
    }
  }

  double _calculateEstimatedArrivalTime() {
    if (_currentPosition == null || _stops.isEmpty) return 0;

    final currentLatLng = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    final nextStopLatLng = LatLng(
      _stops[_currentStopIndex]['latitude'] as double,
      _stops[_currentStopIndex]['longitude'] as double,
    );

    return _calculateDistance(currentLatLng, nextStopLatLng) / 30; // Assuming 30 km/h average speed
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371; // km
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;

    final a1 = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a1), sqrt(1 - a1));
    return earthRadius * c;
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
            Text(
              'Current Stop: ${_currentStopIndex + 1}/${_stops.length}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'ETA: ${_calculateEstimatedArrivalTime().toStringAsFixed(1)} minutes',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    if (_currentPosition == null) {
      return const Center(
        child: Text('Waiting for location...'),
      );
    }

    return FlutterMap(
      options: MapOptions(
        center: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        zoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.demotracking.app',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: _stops.map((stop) {
                return LatLng(
                  stop['latitude'] as double,
                  stop['longitude'] as double,
                );
              }).toList(),
              color: Colors.blue,
              strokeWidth: 3,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            // Current bus location
            Marker(
              point: LatLng(
                _currentPosition!.latitude,
                _currentPosition!.longitude,
              ),
              child: const Icon(
                Icons.directions_bus,
                color: Colors.blue,
                size: 40,
              ),
            ),
            // Route stops
            ..._stops.map((stop) {
              return Marker(
                point: LatLng(
                  stop['latitude'] as double,
                  stop['longitude'] as double,
                ),
                child: Icon(
                  Icons.location_on,
                  color: _stops.indexOf(stop) == _currentStopIndex
                      ? Colors.green
                      : Colors.red,
                  size: 30,
                ),
              );
            }),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigation'),
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
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _currentStopIndex > 0
                                ? () {
                                    setState(() {
                                      _currentStopIndex--;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous Stop'),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _updateBusLocation();
                            },
                            icon: const Icon(Icons.update),
                            label: const Text('Update Location'),
                          ),
                          ElevatedButton.icon(
                            onPressed: _currentStopIndex < _stops.length - 1
                                ? () {
                                    setState(() {
                                      _currentStopIndex++;
                                    });
                                  }
                                : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text('Next Stop'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 