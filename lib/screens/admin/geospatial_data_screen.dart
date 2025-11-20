import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeospatialDataScreen extends StatefulWidget {
  const GeospatialDataScreen({super.key});

  @override
  State<GeospatialDataScreen> createState() => _GeospatialDataScreenState();
}

class _GeospatialDataScreenState extends State<GeospatialDataScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _selectedStop;
  Map<String, dynamic>? _selectedRoute;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load stops and routes
      final stopsResponse = await _supabase
          .from('stops')
          .select('*, routes(*)')
          .order('name');
      _stops = List<Map<String, dynamic>>.from(stopsResponse);

      final routesResponse = await _supabase
          .from('routes')
          .select('*, stops(*)')
          .order('name');
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

  Widget _buildStopCard(Map<String, dynamic> stop) {
    final isSelected = _selectedStop?['id'] == stop['id'];
    final routesRaw = stop['routes'];
    final List<Map<String, dynamic>> routes = routesRaw is List
        ? List<Map<String, dynamic>>.from(routesRaw)
        : routesRaw is Map
            ? [Map<String, dynamic>.from(routesRaw)]
            : [];

    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedStop = stop;
          });
        },
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
                      stop['name'][0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop['name'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${routes.length} routes',
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
              if (isSelected) ...[
                const SizedBox(height: 8),
                Text(
                  'Coordinates: ${stop['latitude']}, ${stop['longitude']}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Routes:',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                ...routes.map((route) => Padding(
                      padding: const EdgeInsets.only(left: 16, top: 4),
                      child: Text(route['name']),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final isSelected = _selectedRoute?['id'] == route['id'];
    final stopsRaw = route['stops'];
    final List<Map<String, dynamic>> stops = stopsRaw is List
        ? List<Map<String, dynamic>>.from(stopsRaw)
        : stopsRaw is Map
            ? [Map<String, dynamic>.from(stopsRaw)]
            : [];

    return Card(
      color: isSelected ? Colors.blue.shade50 : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRoute = route;
          });
        },
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
              if (isSelected && stops.isNotEmpty) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      center: LatLng(
                        stops.first['latitude'] as double,
                        stops.first['longitude'] as double,
                      ),
                      zoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.demotracking.app',
                      ),
                      MarkerLayer(
                        markers: stops.map((stop) {
                          return Marker(
                            point: LatLng(
                              stop['latitude'] as double,
                              stop['longitude'] as double,
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Geospatial Data'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Stops'),
              Tab(text: 'Routes'),
            ],
          ),
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
                : TabBarView(
                    children: [
                      _stops.isEmpty
                          ? const Center(child: Text('No stops found'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _stops.length,
                              itemBuilder: (context, index) {
                                final stop = _stops[index];
                                return Column(
                                  children: [
                                    _buildStopCard(stop),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                      _routes.isEmpty
                          ? const Center(child: Text('No routes found'))
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
                    ],
                  ),
      ),
    );
  }
} 