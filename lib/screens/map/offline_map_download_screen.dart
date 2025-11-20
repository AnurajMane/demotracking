import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' show pow, log, tan, cos, pi;

class OfflineMapDownloadScreen extends StatefulWidget {
  const OfflineMapDownloadScreen({super.key});

  @override
  State<OfflineMapDownloadScreen> createState() => _OfflineMapDownloadScreenState();
}

class _OfflineMapDownloadScreenState extends State<OfflineMapDownloadScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _routes = [];
  final MapController _mapController = MapController();
  LatLngBounds? _selectedBounds;
  String _downloadStatus = '';

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

  Future<void> _downloadOfflineMap() async {
    if (_selectedBounds == null) {
      setState(() {
        _errorMessage = 'Please select an area to download';
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _downloadStatus = 'Preparing download...';
      });

      // Get app directory
      final appDir = await getApplicationDocumentsDirectory();
      final mapsDir = Directory('${appDir.path}/offline_maps');
      if (!await mapsDir.exists()) {
        await mapsDir.create(recursive: true);
      }

      // Calculate zoom levels
      final minZoom = 10;
      final maxZoom = 15;

      // Calculate tile coordinates
      final ne = _selectedBounds!.northEast;
      final sw = _selectedBounds!.southWest;

      int totalTiles = 0;
      int downloadedTiles = 0;

      // Calculate total tiles
      for (var z = minZoom; z <= maxZoom; z++) {
        final neTile = _latLngToTile(ne, z);
        final swTile = _latLngToTile(sw, z);
        totalTiles += (neTile.x - swTile.x + 1) * (neTile.y - swTile.y + 1);
      }

      // Download tiles
      for (var z = minZoom; z <= maxZoom; z++) {
        final neTile = _latLngToTile(ne, z);
        final swTile = _latLngToTile(sw, z);

        for (var x = swTile.x; x <= neTile.x; x++) {
          for (var y = swTile.y; y <= neTile.y; y++) {
            final tileUrl =
                'https://tile.openstreetmap.org/$z/$x/$y.png';
            final tileFile = File('${mapsDir.path}/$z/$x/$y.png');

            if (!await tileFile.exists()) {
              await tileFile.parent.create(recursive: true);
              final response = await HttpClient().getUrl(Uri.parse(tileUrl));
              final httpResponse = await response.close();
              final bytes = await httpResponse.fold<List<int>>(
                [],
                (previous, element) => previous..addAll(element),
              );
              await tileFile.writeAsBytes(bytes);
            }

            downloadedTiles++;
            setState(() {
              _downloadStatus =
                  'Downloading tiles: $downloadedTiles / $totalTiles';
            });
          }
        }
      }

      setState(() {
        _downloadStatus = 'Download completed!';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to download map: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  CustomPoint<int> _latLngToTile(LatLng latLng, int zoom) {
    final n = pow(2.0, zoom);
    final xtile = ((latLng.longitude + 180) / 360 * n).floor();
    final ytile = ((1 - log(tan(latLng.latitude * pi / 180) +
            1 / cos(latLng.latitude * pi / 180)) /
        pi) /
        2 *
        n)
        .floor();
    return CustomPoint(xtile, ytile);
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route),
        title: Text(route['name'] ?? 'Unnamed Route'),
        subtitle: Text(
          'Points: ${(route['coordinates'] as List).length}',
        ),
        onTap: () {
          // TODO: Center map on route
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Maps'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _downloadOfflineMap,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_downloadStatus),
                ],
              ),
            )
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
                    // Map
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: LatLng(0, 0), // Default center
                          zoom: 13,
                          onPositionChanged: (position, hasGesture) {
                            if (hasGesture) {
                              setState(() {
                                _selectedBounds = position.bounds;
                              });
                            }
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.demotracking.app',
                          ),
                          if (_selectedBounds != null)
                            PolygonLayer(
                              polygons: [
                                Polygon(
                                  points: [
                                    _selectedBounds!.northWest,
                                    _selectedBounds!.northEast,
                                    _selectedBounds!.southEast,
                                    _selectedBounds!.southWest,
                                  ],
                                  color: Colors.blue.withOpacity(0.2),
                                  borderColor: Colors.blue,
                                  borderStrokeWidth: 2,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
} 