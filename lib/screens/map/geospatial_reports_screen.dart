import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

class GeospatialReportsScreen extends StatefulWidget {
  const GeospatialReportsScreen({super.key});

  @override
  State<GeospatialReportsScreen> createState() => _GeospatialReportsScreenState();
}

class _GeospatialReportsScreenState extends State<GeospatialReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _reports = [];
  final MapController _mapController = MapController();
  String _selectedReportType = 'all';

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

      // Load reports based on type
      final reportsResponse = await _supabase
          .from('geospatial_reports')
          .select('*, bus:bus_id(*)')
          .order('created_at', ascending: false);
      _reports = List<Map<String, dynamic>>.from(reportsResponse);

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> _getFilteredReports() {
    if (_selectedReportType == 'all') {
      return _reports;
    }
    return _reports.where((report) => report['type'] == _selectedReportType).toList();
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    return Card(
      child: ListTile(
        leading: Icon(
          _getReportIcon(report['type']),
          color: _getReportColor(report['type']),
        ),
        title: Text(report['title'] ?? 'Untitled Report'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type: ${report['type']}',
              style: TextStyle(
                color: _getReportColor(report['type']),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              DateFormat('MMM d, y hh:mm a')
                  .format(DateTime.parse(report['created_at'])),
            ),
          ],
        ),
        onTap: () {
          // TODO: Show report details
        },
      ),
    );
  }

  IconData _getReportIcon(String type) {
    switch (type) {
      case 'speed_violation':
        return Icons.speed;
      case 'route_deviation':
        return Icons.route;
      case 'geofence_violation':
        return Icons.location_off;
      case 'stop_violation':
        return Icons.stop;
      default:
        return Icons.report;
    }
  }

  Color _getReportColor(String type) {
    switch (type) {
      case 'speed_violation':
        return Colors.red;
      case 'route_deviation':
        return Colors.orange;
      case 'geofence_violation':
        return Colors.purple;
      case 'stop_violation':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geospatial Reports'),
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
              : Row(
                  children: [
                    // Reports List
                    SizedBox(
                      width: 300,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: DropdownButtonFormField<String>(
                              value: _selectedReportType,
                              decoration: const InputDecoration(
                                labelText: 'Report Type',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('All Reports'),
                                ),
                                DropdownMenuItem(
                                  value: 'speed_violation',
                                  child: Text('Speed Violations'),
                                ),
                                DropdownMenuItem(
                                  value: 'route_deviation',
                                  child: Text('Route Deviations'),
                                ),
                                DropdownMenuItem(
                                  value: 'geofence_violation',
                                  child: Text('Geofence Violations'),
                                ),
                                DropdownMenuItem(
                                  value: 'stop_violation',
                                  child: Text('Stop Violations'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedReportType = value;
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _getFilteredReports().length,
                              itemBuilder: (context, index) {
                                final report = _getFilteredReports()[index];
                                return Column(
                                  children: [
                                    _buildReportCard(report),
                                    const SizedBox(height: 8),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Map
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          center: LatLng(0, 0), // Default center
                          zoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.demotracking.app',
                          ),
                          MarkerLayer(
                            markers: _getFilteredReports().map((report) {
                              return Marker(
                                point: LatLng(
                                  report['latitude'] as double,
                                  report['longitude'] as double,
                                ),
                                width: 40,
                                height: 40,
                                child: Icon(
                                  _getReportIcon(report['type']),
                                  color: _getReportColor(report['type']),
                                  size: 40,
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