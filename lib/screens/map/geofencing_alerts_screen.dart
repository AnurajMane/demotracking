import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class GeofencingAlertsScreen extends StatefulWidget {
  const GeofencingAlertsScreen({super.key});

  @override
  State<GeofencingAlertsScreen> createState() => _GeofencingAlertsScreenState();
}

class _GeofencingAlertsScreenState extends State<GeofencingAlertsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  List<Map<String, dynamic>> _geofences = [];
  List<Map<String, dynamic>> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _subscribeToAlerts();
  }

  @override
  void dispose() {
    _unsubscribeFromAlerts();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Get current user's ID
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw 'User not authenticated';
      }

      // Load geofences
      final geofencesResponse = await _supabase
          .from('geofences')
          .select('*, bus:bus_id(*)')
          .order('created_at', ascending: false);
      _geofences = List<Map<String, dynamic>>.from(geofencesResponse);

      // Load alerts
      final alertsResponse = await _supabase
          .from('geofence_alerts')
          .select('*, geofence:geofence_id(*, bus:bus_id(*))')
          .order('timestamp', ascending: false);
      _alerts = List<Map<String, dynamic>>.from(alertsResponse);

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToAlerts() {
    _supabase
        .from('geofence_alerts')
        .stream(primaryKey: ['id'])
        .listen((data) {
      if (data.isNotEmpty) {
        setState(() {
          _alerts.insert(0, data.first);
        });
      }
    });
  }

  void _unsubscribeFromAlerts() {
    _supabase.dispose();
  }

  Future<void> _updateAlertStatus(
    String alertId,
    String status,
  ) async {
    try {
      await _supabase
          .from('geofence_alerts')
          .update({'status': status})
          .eq('id', alertId);

      // Refresh data
      _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update alert status: $e';
      });
    }
  }

  Widget _buildGeofenceCard(Map<String, dynamic> geofence) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: geofence['bus'] != null ? Colors.blue : Colors.grey,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        geofence['name'] ?? 'Unnamed Geofence',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (geofence['bus'] != null)
                        Text(
                          'Bus: ${geofence['bus']['name']}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Radius: ${geofence['radius']} meters',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Type: ${geofence['type']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(Map<String, dynamic> alert) {
    final statusColor = {
      'pending': Colors.orange,
      'acknowledged': Colors.blue,
      'resolved': Colors.green,
    }[alert['status']] ?? Colors.grey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning,
                  color: statusColor,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status: ${alert['status'].toUpperCase()}',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MMM d, y hh:mm a')
                            .format(DateTime.parse(alert['timestamp'])),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Geofence: ${alert['geofence']['name'] ?? 'Unnamed'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (alert['geofence']['bus'] != null)
              Text(
                'Bus: ${alert['geofence']['bus']['name']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            Text(
              'Event: ${alert['event_type']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (alert['status'] == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _updateAlertStatus(alert['id'], 'acknowledged'),
                    child: const Text('Acknowledge'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _updateAlertStatus(alert['id'], 'resolved'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Resolve'),
                  ),
                ],
              ),
            ],
          ],
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
          title: const Text('Geofencing'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Geofences'),
              Tab(text: 'Alerts'),
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
                      // Geofences Tab
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _geofences.length,
                        itemBuilder: (context, index) {
                          final geofence = _geofences[index];
                          return Column(
                            children: [
                              _buildGeofenceCard(geofence),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                      // Alerts Tab
                      ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alerts.length,
                        itemBuilder: (context, index) {
                          final alert = _alerts[index];
                          return Column(
                            children: [
                              _buildAlertCard(alert),
                              const SizedBox(height: 16),
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