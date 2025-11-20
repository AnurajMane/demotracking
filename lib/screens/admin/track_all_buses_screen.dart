import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:demotracking/services/bus_service.dart';

class TrackAllBusesScreen extends StatefulWidget {
  const TrackAllBusesScreen({super.key});

  @override
  State<TrackAllBusesScreen> createState() => _TrackAllBusesScreenState();
}

class _TrackAllBusesScreenState extends State<TrackAllBusesScreen> {
  final MapController _mapController = MapController();
  final BusService _busService = BusService();
  List<Map<String, dynamic>> _buses = [];
  bool _isLoading = true;
  Position? _currentPosition;
  StreamSubscription? _busSubscription;
  // Default center (can be set to your school's location)
  final LatLng _defaultCenter = const LatLng(18.915778, 73.343201);

  @override
  void initState() {
    super.initState();
    _initializeBusTracking();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _busSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeBusTracking() async {
    try {
      // Get initial bus locations
      final initialBuses = await _busService.getBusLocations();
      if (mounted) {
        setState(() {
          _buses = initialBuses;
          _isLoading = false;
        });
      }

      // Subscribe to real-time updates
      _busSubscription = _busService.subscribeToBusLocations().listen(
        (updatedBuses) {
          if (mounted) {
            setState(() {
              _buses = updatedBuses;
            });
          }
        },
        onError: (error) {
          _showError('Failed to receive bus updates: ${error.toString()}');
        },
      );
    } catch (e) {
      _showError('Failed to initialize bus tracking: ${e.toString()}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final request = await Geolocator.requestPermission();
        if (request == LocationPermission.denied) {
          _showError('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showError('Location permissions are permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _mapController.move(
            LatLng(position.latitude, position.longitude),
            15.0,
          );
        });
      }
    } catch (e) {
      _showError('Failed to get location: ${e.toString()}');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _loadBuses() async {
    try {
      final updatedBuses = await _busService.getBusLocations();
      if (mounted) {
        setState(() {
          _buses = updatedBuses;
        });
      }
    } catch (e) {
      _showError('Failed to load buses: ${e.toString()}');
    }
  }

  void _showBusDetails(Map<String, dynamic> bus) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bus['name'] ?? 'N/A',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _detailRow('Driver', bus['driver'] ?? 'N/A'),
            _detailRow('Status', bus['status'] ?? 'N/A'),
            _detailRow('Students', bus['students']?.toString() ?? '0'),
            _detailRow('Route', bus['route'] ?? 'N/A'),
            _detailRow('Speed', bus['speed']?.toString() ?? 'N/A'),
            _detailRow('Last Update', bus['lastUpdate'] ?? 'N/A'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _mapController.move(bus['location'], 16.0);
                },
                child: const Text('Focus on Map'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(value ?? 'N/A'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Buses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBuses,
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _getCurrentLocation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: _defaultCenter,
                    zoom: 13,
                    onMapReady: () {
                      if (_currentPosition == null) {
                        _mapController.move(_defaultCenter, 13);
                      }
                    },
                  ),
                  nonRotatedChildren: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.demotracking.app',
                      errorImage: const NetworkImage(
                        'https://tile.openstreetmap.org/0/0/0.png',
                      ),
                    ),
                    MarkerLayer(
                      markers: _buses.map((bus) {
                        return Marker(
                          point: bus['location'],
                          width: 100,
                          height: 51,
                          child: GestureDetector(
                            onTap: () => _showBusDetails(bus),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.directions_bus,
                                  color: bus['status'] == 'active'
                                      ? Colors.green
                                      : Colors.red,
                                  size: 30,
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    bus['name'] ?? 'N/A',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  children: const [],
                ),
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Active Buses: ${_buses.length}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ..._buses.map((bus) => ListTile(
                                leading: Icon(
                                  Icons.directions_bus,
                                  color: bus['status'] == 'active'
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(bus['name'] ?? 'N/A'),
                                subtitle: Text(
                                  'Driver: ${bus['driver'] ?? 'N/A'}\nStudents: ${bus['students']?.toString() ?? '0'}',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.info),
                                  onPressed: () => _showBusDetails(bus),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
} 