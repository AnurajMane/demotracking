import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:demotracking/config/routes.dart';
import 'package:demotracking/screens/parent/parent_attendance_screen.dart';
import 'package:demotracking/screens/parent/parent_bus_location_screen.dart';
import 'package:demotracking/screens/parent/child_tracking_screen.dart';
import 'package:demotracking/screens/parent/notifications_screen.dart';
import 'package:demotracking/screens/parent/parent_sos_alerts_screen.dart';
import 'package:demotracking/screens/parent/custom_basemap_screen.dart';

class ParentDashboardScreen extends StatefulWidget {
  const ParentDashboardScreen({super.key});

  @override
  State<ParentDashboardScreen> createState() => _ParentDashboardScreenState();
}

class _ParentDashboardScreenState extends State<ParentDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Parent data
  Map<String, dynamic>? _parent;
  List<Map<String, dynamic>> _children = [];
  List<Map<String, dynamic>> _todayAttendance = [];

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

      // Load parent data
      final parentResponse = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .maybeSingle();
      
      if (parentResponse == null) {
        // Create a profile if it doesn't exist
        final userEmail = _supabase.auth.currentUser?.email;
        final newProfile = {
          'id': userId,
          'name': userEmail?.split('@')[0] ?? 'New Parent',
          'phone': '',
          'role': 'parent',
        };
        
        await _supabase.from('profiles').insert(newProfile);
        _parent = newProfile;
      } else {
        _parent = parentResponse;
      }

      // Load children data with bus information
      final childrenResponse = await _supabase
          .from('students')
          .select('*, buses(*, routes!fk_bus_route(*))')
          .eq('parent_id', userId);
      _children = List<Map<String, dynamic>>.from(childrenResponse);

      // Load today's attendance for all children
      final today = DateTime.now();
      final todayStr = today.toIso8601String().split('T')[0];
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, students(*), buses(*)')
          .eq('parent_id', userId)
          .eq('date', todayStr);
      _todayAttendance = List<Map<String, dynamic>>.from(attendanceResponse);

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildChildrenList() {
    if (_children.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No children registered'),
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
              'Children',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6, // 60% of screen height
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _children.length,
                itemBuilder: (context, index) {
                  final child = _children[index];
                  final attendance = _todayAttendance.firstWhere(
                    (a) => a['students']['id'] == child['id'],
                    orElse: () => {},
                  );

                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(child['name'][0].toUpperCase()),
                    ),
                    title: Text(child['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Grade: ${child['grade']}'),
                        if (child['buses'] != null) ...[
                          Text('Bus: ${child['buses']['name']}'),
                          Text('Route: ${child['buses']['routes']['name']}'),
                        ],
                      ],
                    ),
                    trailing: attendance.isNotEmpty
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                attendance['status'] == 'present'
                                    ? Icons.check_circle
                                    : attendance['status'] == 'late'
                                        ? Icons.warning
                                        : Icons.cancel,
                                color: attendance['status'] == 'present'
                                    ? Colors.green
                                    : attendance['status'] == 'late'
                                        ? Colors.orange
                                        : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                attendance['status'].toUpperCase(),
                                style: TextStyle(
                                  color: attendance['status'] == 'present'
                                      ? Colors.green
                                      : attendance['status'] == 'late'
                                          ? Colors.orange
                                          : Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : const Text('No attendance'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Parent Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
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
            }, 
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
                      // Profile Card
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            colors: [Colors.blue.shade400, Colors.blue.shade200],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.shade100,
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 24),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, size: 36, color: Colors.blue.shade400),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Welcome, ${(_parent?['name'] ?? '').toString().isEmpty ? 'Parent' : _parent!['name']}',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Phone: ${(_parent?['phone'] ?? '').toString().isEmpty ? 'Not set' : _parent!['phone']}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Main Actions Grid
                      Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Wrap(
                            spacing: 18,
                            runSpacing: 18,
                            children: [
                              _dashboardButton(
                                icon: Icons.checklist,
                                iconBg: Colors.green.shade100,
                                iconColor: Colors.green.shade700,
                                label: 'Attendance',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ParentAttendanceScreen()),
                                ),
                              ),
                              _dashboardButton(
                                icon: Icons.location_on,
                                iconBg: Colors.blue.shade100,
                                iconColor: Colors.blue.shade700,
                                label: 'Bus Location',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ParentBusLocationScreen()),
                                ),
                              ),
                              _dashboardButton(
                                icon: Icons.map,
                                iconBg: Colors.orange.shade100,
                                iconColor: Colors.orange.shade700,
                                label: 'Child Tracking',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ChildTrackingScreen()),
                                ),
                              ),
                              _dashboardButton(
                                icon: Icons.notifications,
                                iconBg: Colors.purple.shade100,
                                iconColor: Colors.purple.shade700,
                                label: 'Notifications',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ParentNotificationsScreen()),
                                ),
                              ),
                              _dashboardButton(
                                icon: Icons.warning,
                                iconBg: Colors.red.shade100,
                                iconColor: Colors.red.shade700,
                                label: 'SOS Alerts',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ParentSOSAlertsScreen()),
                                ),
                              ),
                              _dashboardButton(
                                icon: Icons.map_outlined,
                                iconBg: Colors.teal.shade100,
                                iconColor: Colors.teal.shade700,
                                label: 'Custom Basemap',
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CustomBasemapScreen()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Children List
                      _buildChildrenList(),
                    ],
                  ),
                ),
    );
  }

  Widget _dashboardButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color iconBg,
    required Color iconColor,
  }) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.70, //width increase of decrease of main menu
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        onPressed: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(6),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 