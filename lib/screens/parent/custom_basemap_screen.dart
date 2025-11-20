import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CustomBasemapScreen extends StatefulWidget {
  const CustomBasemapScreen({super.key});

  @override
  State<CustomBasemapScreen> createState() => _CustomBasemapScreenState();
}

class _CustomBasemapScreenState extends State<CustomBasemapScreen> {
  SharedPreferences? _prefs;
  String _selectedBasemap = 'OpenStreetMap';
  double _zoomLevel = 15.0;
  bool _showTraffic = false;
  bool _showSatellite = false;

  final Map<String, String> _basemapOptions = {
    'OpenStreetMap': 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    'Google Maps': 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
    'Google Satellite': 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
    'Google Terrain': 'https://mt1.google.com/vt/lyrs=p&x={x}&y={y}&z={z}',
    'Google Hybrid': 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}',
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    if (_prefs != null) {
      setState(() {
        _selectedBasemap = _prefs!.getString('selected_basemap') ?? 'OpenStreetMap';
        _zoomLevel = _prefs!.getDouble('zoom_level') ?? 15.0;
        _showTraffic = _prefs!.getBool('show_traffic') ?? false;
        _showSatellite = _prefs!.getBool('show_satellite') ?? false;
      });
    }
  }

  Future<void> _saveSettings() async {
    if (_prefs != null) {
      await _prefs!.setString('selected_basemap', _selectedBasemap);
      await _prefs!.setDouble('zoom_level', _zoomLevel);
      await _prefs!.setBool('show_traffic', _showTraffic);
      await _prefs!.setBool('show_satellite', _showSatellite);
    }
  }

  Widget _buildBasemapPreview() {
    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          center: const LatLng(0, 0),
          zoom: _zoomLevel,
        ),
        children: [
          TileLayer(
            urlTemplate: _basemapOptions[_selectedBasemap]!,
            userAgentPackageName: 'com.demotracking.app',
          ),
          if (_showTraffic)
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.demotracking.app',
              additionalOptions: const {
                'opacity': '0.5',
              },
            ),
          if (_showSatellite)
            TileLayer(
              urlTemplate: 'https://mt1.google.com/vt/lyrs=s&x={x}&y={y}&z={z}',
              userAgentPackageName: 'com.demotracking.app',
              additionalOptions: const {
                'opacity': '0.5',
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customize Map'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Basemap Style',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedBasemap,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: _basemapOptions.keys.map((String basemap) {
                      return DropdownMenuItem<String>(
                        value: basemap,
                        child: Text(basemap),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() {
                          _selectedBasemap = newValue;
                        });
                        _saveSettings();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Map Settings',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Zoom Level: '),
                      Expanded(
                        child: Slider(
                          value: _zoomLevel,
                          min: 1,
                          max: 20,
                          divisions: 19,
                          label: _zoomLevel.round().toString(),
                          onChanged: (double value) {
                            setState(() {
                              _zoomLevel = value;
                            });
                          },
                          onChangeEnd: (double value) {
                            _saveSettings();
                          },
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    title: const Text('Show Traffic Layer'),
                    value: _showTraffic,
                    onChanged: (bool value) {
                      setState(() {
                        _showTraffic = value;
                      });
                      _saveSettings();
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Show Satellite Layer'),
                    value: _showSatellite,
                    onChanged: (bool value) {
                      setState(() {
                        _showSatellite = value;
                      });
                      _saveSettings();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildBasemapPreview(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 