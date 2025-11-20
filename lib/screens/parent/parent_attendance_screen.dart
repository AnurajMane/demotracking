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
  List<Map<String, dynamic>> _children = [];
  final Map<String, List<Map<String, dynamic>>> _attendanceHistory = {};
  final Map<String, Map<String, dynamic>> _todayAttendance = {};

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
      if (userId == null) throw 'User not authenticated';

      // Load children data
      final childrenResponse = await _supabase
          .from('students')
          .select()
          .eq('parent_id', userId);
      _children = List<Map<String, dynamic>>.from(childrenResponse);

      // Load attendance history for each child
      for (final child in _children) {
        final childId = child['id'];
        
        // Load attendance history
        final attendanceResponse = await _supabase
            .from('attendance')
            .select('*, buses(*)')
            .eq('student_id', childId)
            .order('date', ascending: false)
            .limit(30);
        _attendanceHistory[childId] = List<Map<String, dynamic>>.from(attendanceResponse);

        // Load today's attendance
        final today = DateTime.now();
        final todayStr = DateFormat('yyyy-MM-dd').format(today);
        final todayAttendanceResponse = await _supabase
            .from('attendance')
            .select('*, buses(*)')
            .eq('student_id', childId)
            .eq('date', todayStr)
            .single();
        _todayAttendance[childId] = todayAttendanceResponse;
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
    final todayAttendance = _todayAttendance[child['id']];
    if (todayAttendance == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No attendance record for today'),
        ),
      );
    }

    final status = todayAttendance['status'];
    final color = status == 'present'
        ? Colors.green
        : status == 'late'
            ? Colors.orange
            : Colors.red;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${child['name']}\'s Today\'s Attendance',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  status == 'present'
                      ? Icons.check_circle
                      : status == 'late'
                          ? Icons.warning
                          : Icons.cancel,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (todayAttendance['time'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Time: ${todayAttendance['time']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (todayAttendance['buses'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Bus: ${todayAttendance['buses']['name']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory(Map<String, dynamic> child) {
    final attendanceHistory = _attendanceHistory[child['id']] ?? [];
    if (attendanceHistory.isEmpty) {
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
              '${child['name']}\'s Attendance History',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: attendanceHistory.length,
              itemBuilder: (context, index) {
                final attendance = attendanceHistory[index];
                final status = attendance['status'];
                final color = status == 'present'
                    ? Colors.green
                    : status == 'late'
                        ? Colors.orange
                        : Colors.red;

                return ListTile(
                  title: Text(DateFormat('MMM d, y').format(
                    DateTime.parse(attendance['date']),
                  )),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(attendance['time'] ?? ''),
                      if (attendance['buses'] != null)
                        Text('Bus: ${attendance['buses']['name']}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        status == 'present'
                            ? Icons.check_circle
                            : status == 'late'
                                ? Icons.warning
                                : Icons.cancel,
                        color: color,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
                      child: Text('No children registered'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _children.length,
                      itemBuilder: (context, index) {
                        final child = _children[index];
                        return Column(
                          children: [
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