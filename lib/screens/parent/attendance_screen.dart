import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ParentAttendanceScreen extends StatefulWidget {
  const ParentAttendanceScreen({super.key});

  @override
  State<ParentAttendanceScreen> createState() => _ParentAttendanceScreenState();
}

class _ParentAttendanceScreenState extends State<ParentAttendanceScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Data
  Map<String, dynamic>? _parentData;
  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _attendanceHistory = {};

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
          .select('*, bus:bus_id(*)')
          .eq('parent_id', _parentData!['id']);
      _children = List<Map<String, dynamic>>.from(childrenResponse);

      // Load attendance history for each child
      for (final child in _children) {
        final attendanceResponse = await _supabase
            .from('attendance')
            .select('*, stop:stop_id(*)')
            .eq('student_id', child['id'])
            .order('timestamp', ascending: false);
        _attendanceHistory[child['id']] =
            List<Map<String, dynamic>>.from(attendanceResponse);
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

  Widget _buildTodayAttendance(Map<String, dynamic> child) {
    final today = DateTime.now();
    final todayAttendance = _attendanceHistory[child['id']]?.where((record) {
      final recordDate = DateTime.parse(record['timestamp']);
      return recordDate.year == today.year &&
          recordDate.month == today.month &&
          recordDate.day == today.day;
    }).toList();

    if (todayAttendance == null || todayAttendance.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 8),
              Text('No attendance recorded today'),
            ],
          ),
        ),
      );
    }

    final pickup = todayAttendance.firstWhere(
      (record) => record['type'] == 'pickup',
      orElse: () => <String, dynamic>{},
    );
    final dropoff = todayAttendance.firstWhere(
      (record) => record['type'] == 'dropoff',
      orElse: () => <String, dynamic>{},
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  pickup != null ? Icons.check_circle : Icons.pending,
                  color: pickup != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Pickup: ${pickup != null ? 'Completed' : 'Pending'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            ...[
            const SizedBox(height: 8),
            Text(
              'Time: ${DateFormat('hh:mm a').format(DateTime.parse(pickup['timestamp']))}',
            ),
            Text(
              'Stop: ${pickup['stop']['name']}',
            ),
          ],
            const Divider(),
            Row(
              children: [
                Icon(
                  dropoff != null ? Icons.check_circle : Icons.pending,
                  color: dropoff != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  'Dropoff: ${dropoff != null ? 'Completed' : 'Pending'}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            ...[
            const SizedBox(height: 8),
            Text(
              'Time: ${DateFormat('hh:mm a').format(DateTime.parse(dropoff['timestamp']))}',
            ),
            Text(
              'Stop: ${dropoff['stop']['name']}',
            ),
          ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory(Map<String, dynamic> child) {
    final history = _attendanceHistory[child['id']] ?? [];
    if (history.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No attendance history'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: history.length,
              itemBuilder: (context, index) {
                final record = history[index];
                return ListTile(
                  leading: Icon(
                    record['type'] == 'pickup'
                        ? Icons.person_add
                        : Icons.directions_bus,
                    color: record['type'] == 'pickup'
                        ? Colors.green
                        : Colors.blue,
                  ),
                  title: Text(
                    record['type'] == 'pickup' ? 'Pickup' : 'Dropoff',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('MMM d, y hh:mm a')
                            .format(DateTime.parse(record['timestamp'])),
                      ),
                      Text('Stop: ${record['stop']['name']}'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
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
                            if (child['bus'] != null)
                              Text(
                                'Bus: ${child['bus']['name']}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            const SizedBox(height: 16),
                            _buildTodayAttendance(child),
                            const SizedBox(height: 16),
                            _buildAttendanceHistory(child),
                            const SizedBox(height: 24),
                          ],
                        );
                      },
                    ),
    );
  }
} 