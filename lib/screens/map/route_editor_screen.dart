import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RouteEditorScreen extends StatefulWidget {
  const RouteEditorScreen({super.key});

  @override
  State<RouteEditorScreen> createState() => _RouteEditorScreenState();
}

class _RouteEditorScreenState extends State<RouteEditorScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _routes = [];
  final MapController _mapController = MapController();
  final List<LatLng> _selectedPoints = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      // Load routes
      final routesResponse = await _supabase
          .from('routes')
          .select('*, bus:bus_id(*)')
          .order('created_at', ascending: false);
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

  Future<void> _saveRoute() async {
    if (_selectedPoints.isEmpty) {
      setState(() {
        _errorMessage = 'Please select at least one point for the route';
      });
      return;
    }

    try {
      setState(() => _isLoading = true);

      // Convert points to GeoJSON format
      final coordinates = _selectedPoints.map((point) {
        return [point.longitude, point.latitude];
      }).toList();

      // Save route to database
      await _supabase.from('routes').insert({
        'name': 'New Route ${DateTime.now().millisecondsSinceEpoch}',
        'coordinates': coordinates,
        'created_by': _supabase.auth.currentUser?.id,
      });

      // Refresh data
      _loadData();
      _selectedPoints.clear();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to save route: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text(route['name'] ?? 'Unnamed Route'),
        subtitle: Text(
          'Points: ${(route['coordinates'] as List).length}',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete),
          onPressed: () async {
            try {
              await _supabase
                  .from('routes')
                  .delete()
                  .eq('id', route['id']);
              _loadData();
            } catch (e) {
              setState(() {
                _errorMessage = 'Failed to delete route: $e';
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveRoute,
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
              : Row(
                  children: [
                    // Routes List
                    SizedBox(
                      width: 300,
                      child: ListView.builder(
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
                    ),
                    // Map Editor
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: LatLng(0, 0), // Default center
                          zoom: 13,
                          onTap: (tapPosition, point) {
                            setState(() {
                              _selectedPoints.add(point);
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.demotracking.app',
                          ),
                          PolylineLayer(
                            polylines: [
                              if (_selectedPoints.isNotEmpty)
                                Polyline(
                                  points: _selectedPoints,
                                  color: Colors.blue,
                                  strokeWidth: 3,
                                ),
                            ],
                          ),
                          MarkerLayer(
                            markers: _selectedPoints.map((point) {
                              return Marker(
                                point: point,
                                width: 20,
                                height: 20,
                                child: const Icon(
                                  Icons.location_on,
                                  color: Colors.red,
                                  size: 20,
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 