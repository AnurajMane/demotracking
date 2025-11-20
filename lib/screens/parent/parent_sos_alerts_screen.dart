import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class ParentSOSAlertsScreen extends StatefulWidget {
  const ParentSOSAlertsScreen({super.key});

  @override
  State<ParentSOSAlertsScreen> createState() => _ParentSOSAlertsScreenState();
}

class _ParentSOSAlertsScreenState extends State<ParentSOSAlertsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _sosAlerts = {};
  Map<String, dynamic>? _selectedAlert;

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToSOSAlerts();
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

      // Load SOS alerts for each child
      for (final child in _children) {
        final childId = child['id'];
        final alertsResponse = await _supabase
            .from('sos_alerts')
            .select('*, students(*)')
            .eq('student_id', childId)
            .order('created_at', ascending: false)
            .limit(10);
        _sosAlerts[childId] = List<Map<String, dynamic>>.from(alertsResponse);
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

  void _subscribeToSOSAlerts() {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    _supabase
        .channel('sos_alerts_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sos_alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: _children.map((c) => c['id']).toList(),
          ),
          callback: (payload) {
            final alert = payload.newRecord;
            final childId = alert['student_id'];
            if (_sosAlerts.containsKey(childId)) {
              setState(() {
                _sosAlerts[childId]!.insert(0, alert);
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _updateAlertStatus(Map<String, dynamic> alert, String status) async {
    try {
      await _supabase
          .from('sos_alerts')
          .update({'status': status})
          .eq('id', alert['id']);

      setState(() {
        final childId = alert['student_id'];
        final alerts = _sosAlerts[childId]!;
        final index = alerts.indexWhere((a) => a['id'] == alert['id']);
        if (index != -1) {
          alerts[index]['status'] = status;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Alert status updated to $status'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update alert status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final child = _children.firstWhere(
      (c) => c['id'] == alert['student_id'],
      orElse: () => {'name': 'Unknown Student'},
    );

    final status = alert['status'];
    final color = status == 'resolved'
        ? Colors.green
        : status == 'in_progress'
            ? Colors.orange
            : Colors.red;

    return Card(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedAlert = _selectedAlert?['id'] == alert['id'] ? null : alert;
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
                    backgroundColor: color,
                    child: const Icon(Icons.warning, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          child['name'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          DateFormat('MMM d, y HH:mm').format(
                            DateTime.parse(alert['created_at']),
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(alert['message']),
              if (_selectedAlert?['id'] == alert['id']) ...[
                const SizedBox(height: 16),
                if (alert['latitude'] != null && alert['longitude'] != null)
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        center: LatLng(
                          alert['latitude'],
                          alert['longitude'],
                        ),
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
                              point: LatLng(
                                alert['latitude'],
                                alert['longitude'],
                              ),
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (status != 'resolved') ...[
                      TextButton.icon(
                        onPressed: () => _updateAlertStatus(alert, 'in_progress'),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Mark In Progress'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => _updateAlertStatus(alert, 'resolved'),
                        icon: const Icon(Icons.check),
                        label: const Text('Resolve'),
                      ),
                    ],
                  ],
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
        title: const Text('SOS Alerts'),
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
                        final alerts = _sosAlerts[child['id']] ?? [];
                        if (alerts.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${child['name']}\'s Alerts',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            ...alerts.map(_buildAlertCard),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
    );
  }
} 