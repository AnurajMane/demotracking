import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
  Map<String, dynamic>? _parentData;
  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _sosAlerts = {};

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

      // Load parent data
      final parentResponse = await _supabase
          .from('parents')
          .select('*')
          .eq('user_id', userId)
          .single();
      _parentData = parentResponse;

      // Load children data
      final childrenResponse = await _supabase
          .from('students')
          .select('*')
          .eq('parent_id', _parentData!['id']);
      _children = List<Map<String, dynamic>>.from(childrenResponse);

      // Load SOS alerts for each child
      for (final child in _children) {
        final alertsResponse = await _supabase
            .from('sos_alerts')
            .select('*')
            .eq('student_id', child['id'])
            .order('timestamp', ascending: false);
        _sosAlerts[child['id']] =
            List<Map<String, dynamic>>.from(alertsResponse);
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

  void _subscribeToAlerts() {
    _supabase
        .from('sos_alerts')
        .stream(primaryKey: ['id'])
        .eq('parent_id', _parentData?['id'])
        .listen((data) {
      if (data.isNotEmpty) {
        final alert = data.first;
        final childId = alert['student_id'];
        if (_sosAlerts.containsKey(childId)) {
          setState(() {
            _sosAlerts[childId]!.insert(0, alert);
          });
        }
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
          .from('sos_alerts')
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
              alert['message'] ?? 'No message provided',
              style: Theme.of(context).textTheme.bodyLarge,
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
                      child: Text('No children found'),
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
                              child['name'],
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'Grade: ${child['grade']}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),
                            ...alerts.map(_buildAlertCard),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
    );
  }
} 