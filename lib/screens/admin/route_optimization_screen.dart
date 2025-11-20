import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

class RouteOptimizationScreen extends StatefulWidget {
  const RouteOptimizationScreen({super.key});

  @override
  State<RouteOptimizationScreen> createState() => _RouteOptimizationScreenState();
}

class _RouteOptimizationScreenState extends State<RouteOptimizationScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _selectedRoute;
  List<LatLng> _optimizedPath = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load routes with their stops, ordered by stop_order
      final routesResponse = await _supabase
          .from('routes')
          .select('''
            *,
            stops!route_id (
              *
            )
          ''')
          .order('name');

      for (var route in routesResponse) {
        if (route['stops'] != null) {
          route['stops'].sort((a, b) {
            final aOrder = a['stop_order'];
            final bOrder = b['stop_order'];
            if (aOrder == null && bOrder == null) return 0;
            if (aOrder == null) return 1;
            if (bOrder == null) return -1;
            return (aOrder as int).compareTo(bOrder as int);
          });
        }
      }
      _routes = List<Map<String, dynamic>>.from(routesResponse);

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _optimizeRoute(Map<String, dynamic> route) async {
    try {
      setState(() => _isLoading = true);

      final stops = List<Map<String, dynamic>>.from(route['stops'] as List);
      if (stops.isEmpty) {
        throw 'No stops found for this route';
      }

      // Find start and end points
      final startStop = stops.firstWhere(
        (stop) => stop['is_start_point'] == true,
        orElse: () => stops.first,
      );
      final endStop = stops.firstWhere(
        (stop) => stop['is_end_point'] == true,
        orElse: () => stops.last,
      );

      // Get intermediate stops
      final intermediateStops = stops.where((stop) =>
        stop['id'] != startStop['id'] &&
        stop['id'] != endStop['id']
      ).toList();

      // Create optimized path starting with start point
      List<LatLng> optimizedPath = [
        LatLng(startStop['latitude'], startStop['longitude'])
      ];

      // Process intermediate stops using nearest neighbor
      List<Map<String, dynamic>> remainingStops = [...intermediateStops];
      while (remainingStops.isNotEmpty) {
        final currentPoint = optimizedPath.last;
        
        // Find nearest unvisited stop
        remainingStops.sort((a, b) {
          final distA = _calculateDistance(
            currentPoint,
            LatLng(a['latitude'], a['longitude'])
          );
          final distB = _calculateDistance(
            currentPoint,
            LatLng(b['latitude'], b['longitude'])
          );
          return distA.compareTo(distB);
        });

        final nearestStop = remainingStops.removeAt(0);
        optimizedPath.add(LatLng(
          nearestStop['latitude'],
          nearestStop['longitude']
        ));
      }

      // Add end point
      optimizedPath.add(LatLng(endStop['latitude'], endStop['longitude']));

      setState(() {
        _selectedRoute = route;
        _optimizedPath = optimizedPath;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to optimize route: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }
  //K-NN & ETA
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

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final isSelected = _selectedRoute?['id'] == route['id'];
    final stops = route['stops'] as List;

    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () => _optimizeRoute(route),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      route['name'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          route['name'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${stops.length} stops',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.blue,
                    ),
                ],
              ),
              if (isSelected && _optimizedPath.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 300, // Increased height for better visibility
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _optimizedPath.first,
                      initialZoom: 13,
                      boundsOptions: const FitBoundsOptions(padding: EdgeInsets.all(30)),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.demotracking.app',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _optimizedPath,
                            color: Colors.blue,
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: _optimizedPath.asMap().entries.map((entry) {
                          final index = entry.key;
                          final point = entry.value;
                          final isStart = index == 0;
                          final isEnd = index == _optimizedPath.length - 1;
                          
                          return Marker(
                            point: point,
                            width: 30,
                            height: 30,
                            child: Icon(
                              isStart ? Icons.play_circle :
                              isEnd ? Icons.stop_circle :
                              Icons.location_on,
                              color: isStart ? Colors.green :
                                     isEnd ? Colors.red :
                                     Colors.orange,
                              size: 30,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Optimization'),
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
              : _routes.isEmpty
                  ? const Center(
                      child: Text('No routes found'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _routes.length,
                      itemBuilder: (context, index) {
                        final route = _routes[index];
                        return Column(
                          children: [
                            _buildRouteCard(route),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    ),
    );
  }
} 