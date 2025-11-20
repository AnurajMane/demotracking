import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';


class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Attendance data
  List<Map<String, dynamic>> _attendanceHistory = [];
  Map<String, dynamic> _todayAttendance = {};
  Map<String, dynamic>? _student;

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

      // Load student data
      final studentResponse = await _supabase
          .from('students')
          .select()
          .eq('id', userId)
          .maybeSingle();
      _student = studentResponse;

      // Load attendance history
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, buses(*)')
          .eq('student_id', userId)
          .order('date', ascending: false)
          .limit(30);
      _attendanceHistory = List<Map<String, dynamic>>.from(attendanceResponse);

      // Load today's attendance
      final today = DateTime.now();
      final todayStr = DateFormat('yyyy-MM-dd').format(today);
      final todayAttendanceResponse = await _supabase
          .from('attendance')
          .select('*, buses(*)')
          .eq('student_id', userId)
          .eq('date', todayStr)
          .maybeSingle();
      _todayAttendance = todayAttendanceResponse ?? {};

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTodayAttendance() {
    if (_todayAttendance.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No attendance record for today'),
        ),
      );
    }

    final status = _todayAttendance['status'];
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
              'Today\'s Attendance',
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
            if (_todayAttendance['time'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Time: ${_todayAttendance['time']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (_todayAttendance['buses'] != null) ...[
              const SizedBox(height: 8),
              Text(
                'Bus: ${_todayAttendance['buses']['name']}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory() {
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
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _attendanceHistory.length,
              itemBuilder: (context, index) {
                final attendance = _attendanceHistory[index];
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
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_student != null) ...[
                        Text(
                          'Welcome, ${_student!['name']}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Grade: ${_student!['grade']}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 24),
                      ],
                      _buildTodayAttendance(),
                      const SizedBox(height: 16),
                      _buildAttendanceHistory(),
                    
                    ],
                  ),
                ),
    );
  }
} 