/*import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../../utils/constants.dart';

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  final _mapController = MapController();
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;
  bool _isOffline = false;
  Position? _currentPosition;
  final List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _routes = [];
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _busData;
  Map<String, dynamic>? _currentStop;
  Map<String, dynamic>? _nextStop;
  final double _distanceToStop = 0.0;
  final bool _isNearStop = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _downloadStatus = '';
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeMap();
    _loadData();
    _checkConnectivity();
    _setupConnectivityListener();
  }

  Future<void> _initializeMap() async {
    try {
      // Try to initialize FMTC
      try {
        await FlutterMapTileCaching.initialise();
        
        // Get the root directory for storing tiles
        final rootDir = await getApplicationDocumentsDirectory();
        final tilesDir = Directory('${rootDir.path}/map_tiles');
        
        if (!await tilesDir.exists()) {
          await tilesDir.create(recursive: true);
        }

        // Create a new tile provider
        final tileProvider = FlutterMapTileCaching.instance('mapStore');
        
        // Download tiles for the route area
        await _downloadRouteTiles(tileProvider);
        
        setState(() {
          _isInitialized = true;
        });
      } catch (e) {
        print('Error initializing offline map: $e');
        // Continue with online tiles if offline caching fails
        setState(() {
          _isInitialized = true;
          _error = 'Offline caching not available. Using online tiles.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to initialize map: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadRouteTiles(FlutterMapTileCaching tileProvider) async {
    if (_routes.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadStatus = 'Preparing to download map tiles...';
    });

    try {
      // Calculate bounds for the route
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      
      for (var route in _routes) {
        final coordinates = List<Map<String, dynamic>>.from(route['coordinates'] ?? []);
        for (var coord in coordinates) {
          final lat = coord['latitude'] as double;
          final lng = coord['longitude'] as double;
          minLat = minLat < lat ? minLat : lat;
          maxLat = maxLat > lat ? maxLat : lat;
          minLng = minLng < lng ? minLng : lng;
          maxLng = maxLng > lng ? maxLng : lng;
        }
      }

      // Add padding to bounds
      final padding = Constants.mapPadding;
      minLat -= padding;
      maxLat += padding;
      minLng -= padding;
      maxLng += padding;

      // Download tiles for the area
      final downloader = FlutterMapTileCaching.instance('mapStore').downloader;
      final bounds = LatLngBounds(
        LatLng(minLat, minLng),
        LatLng(maxLat, maxLng),
      );

      await downloader.downloadRegion(
        bounds: bounds,
        minZoom: 12,
        maxZoom: 18,
        onProgress: (progress) {
          setState(() {
            _downloadProgress = progress;
            _downloadStatus = 'Downloading map tiles: ${(progress * 100).toStringAsFixed(1)}%';
          });
        },
      );

      setState(() {
        _isDownloading = false;
        _downloadStatus = 'Map tiles downloaded successfully';
      });
    } catch (e) {
      setState(() {
        _isDownloading = false;
        _downloadStatus = 'Failed to download map tiles: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Offline Map'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_downloadStatus),
              if (_downloadProgress > 0)
                LinearProgressIndicator(value: _downloadProgress),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Map'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildMap(),
    );
  }

  Widget _buildMap() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        center: _currentPosition != null
            ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
            : const LatLng(0, 0),
        zoom: Constants.defaultMapZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: Constants.mapTileUrl,
          userAgentPackageName: 'com.example.demotracking',
          // Use offline tiles if available, otherwise fallback to online
          tileProvider: _isInitialized 
              ? FlutterMapTileCaching.instance('mapStore').getTileProvider()
              : null,
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
          markers: _stops.map((stop) {
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
    );
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
          .eq('user_id', userId)
          .single();
      _studentData = studentResponse;

      if (_studentData != null) {
        _busData = _studentData!['bus'];
        _routes = List<Map<String, dynamic>>.from(studentResponse['routes'] ?? []);

        // Load stops for the route
        if (_routes.isNotEmpty) {
          for (var route in _routes) {
            final stopsResponse = await _supabase
                .from('stops')
                .select('*')
                .eq('route_id', route['id'])
                .order('sequence');
            _stops.addAll(List<Map<String, dynamic>>.from(stopsResponse));
          }

          // Set initial map center to first stop
          if (_stops.isNotEmpty) {
            _currentPosition = Position(
              latitude: _stops.first['latitude'] as double,
              longitude: _stops.first['longitude'] as double,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              altitudeAccuracy: 0,
              heading: 0,
              headingAccuracy: 0,
              speed: 0,
              speedAccuracy: 0,
              isMocked: false,
            );
          }
        }
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _error = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _checkConnectivity() {
    Connectivity().checkConnectivity().then((result) {
      if (result == ConnectivityResult.none) {
        setState(() {
          _isOffline = true;
        });
      } else {
        setState(() {
          _isOffline = false;
        });
      }
    });
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((result) {
      if (result == ConnectivityResult.none) {
        setState(() {
          _isOffline = true;
        });
      } else {
        setState(() {
          _isOffline = false;
        });
      }
    });
  }
}*/