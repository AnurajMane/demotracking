import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'attendance_screen.dart';
import 'live_tracking_screen.dart';
import 'offline_map_screen.dart';
import 'sos_alert_screen.dart';
import 'student_bus_location_screen.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Student data
  Map<String, dynamic>? _student;
  Map<String, dynamic>? _bus;
  Map<String, dynamic>? _route;
  List<Map<String, dynamic>> _attendanceHistory = [];
  Map<String, dynamic> _todayAttendance = {};

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

      print('Current user id: $userId');

      // Load student data
      final studentResponse = await _supabase
          .from('students')
          .select('*, profiles:parent_id(*), buses:bus_id(*)')
          .eq('id', userId)
          .maybeSingle();
      print('Student response: $studentResponse');
      _student = studentResponse;

      /*

      //if student is not found in database
      if (_student == null) {
        setState(() {
          _errorMessage = 'No student record found for this user.';
        });
        return;
      }*/

      // optional debug print at the top of the screen
      print("Student data: $_student");
      print("Bus ID: ${_student?['bus_id']}");

      // Load bus and route data if student is assigned to a bus
      if (_student?['bus_id'] != null) {
        final busResponse = await _supabase
            .from('buses')
            .select('*, routes(*)')
            .eq('id', _student!['bus_id'])
            .maybeSingle();
        _bus = busResponse;
        _route = busResponse?['routes'];
      }

      // Load attendance history
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, buses(*)')
          .eq('student_id', userId)
          .order('date', ascending: false)
          .limit(10);
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

  Widget _buildAttendanceStatus() {
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
          ],
        ),
      ),
    );
  }

  Widget _buildBusInfo() {
    if (_bus == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No bus assigned'),
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
              'Bus Information',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Bus: ${_bus!['name']}'),
            Text('Plate Number: ${_bus!['plate_number']}'),
            if (_route != null) ...[
              const SizedBox(height: 8),
              Text('Route: ${_route!['name']}'),
              Text('Time: ${_route!['start_time']} - ${_route!['end_time']}'),
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
                  subtitle: Text(attendance['time'] ?? ''),
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
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _supabase.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            }
          )
        ]
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
                      // Student Info Card
                      if (_student != null) ...[
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.blue.shade200,
                                  child: const Icon(Icons.person, size: 32, color: Colors.white),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome, ${_student!['name']}',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Grade: ${_student!['grade']}',
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Attendance Status
                      Text('Today', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildAttendanceStatus(),
                      const SizedBox(height: 16),

                      // Bus Info
                      Text('Bus', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildBusInfo(),
                      const SizedBox(height: 16),

                      // Attendance History
                      Text('Attendance History', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildAttendanceHistory(),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Text('Quick Actions', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _DashboardActionButton(
                            icon: Icons.list_alt,
                            label: 'View Full Attendance',
                            color: Colors.indigo,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const AttendanceScreen()),
                              );
                            },
                          ),
                          _DashboardActionButton(
                            icon: Icons.directions_bus,
                            label: 'Live Bus Tracking',
                            color: Colors.green,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const LiveTrackingScreen()),
                              );
                            },
                          ),
                          /*
                          _DashboardActionButton(
                            icon: Icons.map,
                            label: 'Offline Map',
                            color: Colors.orange,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const OfflineMapScreen()),
                              );
                            },
                          ),*/
                          _DashboardActionButton(
                            icon: Icons.warning_amber_rounded,
                            label: 'Send SOS Alert',
                            color: Colors.red,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const SOSAlertScreen()),
                              );
                            },
                          ),
                          _DashboardActionButton(
                            icon: Icons.location_on,
                            label: 'Bus Location Map',
                            color: Colors.blueGrey,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const StudentBusLocationScreen()),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DashboardActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(160, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
      ),
      icon: Icon(icon, size: 22),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      onPressed: onTap,
    );
  }
} 