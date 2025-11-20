import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ChildTrackingScreen extends StatefulWidget {
  const ChildTrackingScreen({super.key});

  @override
  State<ChildTrackingScreen> createState() => _ChildTrackingScreenState();
}

class _ChildTrackingScreenState extends State<ChildTrackingScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _children = [];
  final Map<String, LatLng> _childLocations = {};

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToChildLocations();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      // Load children data
      final childrenResponse = await _supabase
          .from('students')
          .select()
          .eq('parent_id', userId);
      _children = List<Map<String, dynamic>>.from(childrenResponse);

      // Load initial child locations
      for (final child in _children) {
        final childId = child['id'];
        final locationResponse = await _supabase
            .from('student_locations')
            .select()
            .eq('student_id', childId)
            .order('timestamp', ascending: false)
            .limit(1)
            .single();

        _childLocations[childId] = LatLng(
          locationResponse['latitude'],
          locationResponse['longitude'],
        );
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

  void _subscribeToChildLocations() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .channel('child_locations_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'student_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: _children.map((c) => c['id']).toList(),
          ),
          callback: (payload) {
            final location = payload.newRecord;
            final childId = location['student_id'];
            setState(() {
              _childLocations[childId] = LatLng(
                location['latitude'],
                location['longitude'],
              );
            });
          },
        )
        .subscribe();
  }

  Widget _buildChildCard(Map<String, dynamic> child) {
    final location = _childLocations[child['id']];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              child['name'],
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Grade: ${child['grade']}'),
            if (location != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    center: location,
                    zoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.demotracking.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: location,
                          child: const Icon(
                            Icons.person_pin_circle,
                            color: Colors.blue,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Child Tracking'),
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
              : _children.isEmpty
                  ? const Center(
                      child: Text('No children registered'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return Column(
                          children: [
                            _buildChildCard(child),
                            const SizedBox(height: 16),
                          ],
                        );
                      },
                    ),
    );
  }
} 