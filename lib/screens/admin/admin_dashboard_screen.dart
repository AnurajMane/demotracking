import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:demotracking/config/routes.dart';
import 'package:provider/provider.dart';
import 'package:demotracking/providers/auth_provider.dart';
import 'package:demotracking/screens/admin/manage_users_screen.dart';
import 'package:demotracking/screens/admin/settings_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  // Dashboard statistics
  int _totalStudents = 0;
  int _totalBuses = 0;
  int _totalRoutes = 0;
  int _activeDrivers = 0;

  // Add faint color palette and accent colors
  static const faintBlue = Color(0xFFE3F2FD);
  static const faintGreen = Color(0xFFE8F5E9);
  static const faintOrange = Color(0xFFFFF3E0);
  static const faintPurple = Color(0xFFF3E5F5);
  static const faintGrey = Color(0xFFF5F5F5);

  static const blueText = Color(0xFF1976D2);
  static const greenText = Color(0xFF388E3C);
  static const orangeText = Color(0xFFF57C00);
  static const purpleText = Color(0xFF7B1FA2);
  static const greyText = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      setState(() => _isLoading = true);

      // Load total students (profiles with student role)
      final studentsResponse = await _supabase
          .from('profiles')
          .select('count')
          .eq('role', 'student')
          .single();
      _totalStudents = (studentsResponse['count'] as int?) ?? 0;

      // Load total buses
      final busesResponse = await _supabase
          .from('buses')
          .select('count')
          .single();
      _totalBuses = (busesResponse['count'] as int?) ?? 0;

      // Load total routes
      final routesResponse = await _supabase
          .from('routes')
          .select('count')
          .single();
      _totalRoutes = (routesResponse['count'] as int?) ?? 0;

      // Load active drivers
      final driversResponse = await _supabase
          .from('profiles')
          .select('count')
          .eq('role', 'driver')
          .single();
      _activeDrivers = (driversResponse['count'] as int?) ?? 0;

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load statistics: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildStatCard({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    // Choose faint background based on color
    Color bgColor = faintGrey;
    Color iconColor = color;
    if (color == Colors.blue) {
      bgColor = faintBlue;
      iconColor = blueText;
    } else if (color == Colors.green) {
      bgColor = faintGreen;
      iconColor = greenText;
    } else if (color == Colors.orange) {
      bgColor = faintOrange;
      iconColor = orangeText;
    } else if (color == Colors.purple) {
      bgColor = faintPurple;
      iconColor = purpleText;
    }

    return SizedBox(
      height: 130,
      child: Card(
        elevation: 0,
        color: bgColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  icon,
                  size: 28,
                  color: iconColor,
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildManagementCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      color: bgColor,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: Icon(icon, size: 32, color: iconColor),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: iconColor)),
        subtitle: Text(subtitle),
        trailing: Icon(Icons.chevron_right, color: greyText),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: faintBlue,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStatistics,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              await authProvider.signOut();
              if (mounted) {
                Navigator.pushReplacementNamed(context, AppRoutes.login);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overview',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1,
                        children: [
                          _buildStatCard(
                            title: 'Total\nStudents',
                            value: _totalStudents,
                            icon: Icons.school,
                            color: Colors.blue,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ManageUsersScreen(
                                  initialFilter: 'student',
                                ),
                              ),
                            ),
                          ),
                          _buildStatCard(
                            title: 'Total\nBuses',
                            value: _totalBuses,
                            icon: Icons.directions_bus,
                            color: Colors.green,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.manageBuses,
                            ),
                          ),
                          _buildStatCard(
                            title: 'Total\nRoutes',
                            value: _totalRoutes,
                            icon: Icons.route,
                            color: Colors.orange,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.manageRoutes,
                            ),
                          ),
                          _buildStatCard(
                            title: 'Active\nDrivers',
                            value: _activeDrivers,
                            icon: Icons.person,
                            color: Colors.purple,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ManageUsersScreen(
                                  initialFilter: 'driver',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildManagementCard(
                        title: 'Track All Buses',
                        subtitle: 'Monitor real-time location of all buses',
                        icon: Icons.location_on,
                        iconColor: blueText,
                        bgColor: faintBlue,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.trackAllBuses,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Manage Users',
                        subtitle: 'Add, edit, or remove users',
                        icon: Icons.people,
                        iconColor: greenText,
                        bgColor: faintGreen,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.manageUsers,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Assign Routes',
                        subtitle: 'Assign routes to buses and drivers',
                        icon: Icons.alt_route,
                        iconColor: orangeText,
                        bgColor: faintOrange,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.assignRoute,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Route Optimization',
                        subtitle: 'Optimize bus routes for efficiency',
                        icon: Icons.timeline,
                        iconColor: purpleText,
                        bgColor: faintPurple,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.routeOptimization,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Reports',
                        subtitle: 'View and generate reports',
                        icon: Icons.assessment,
                        iconColor: blueText,
                        bgColor: faintBlue,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.reports,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Notifications',
                        subtitle: 'Send notifications to users',
                        icon: Icons.notifications,
                        iconColor: orangeText,
                        bgColor: faintOrange,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.notifications,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Geospatial Data',
                        subtitle: 'Manage geofencing and location data',
                        icon: Icons.map,
                        iconColor: greenText,
                        bgColor: faintGreen,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.geospatialData,
                        ),
                      ),
                      _buildManagementCard(
                        title: 'Settings',
                        subtitle: 'Manage application settings',
                        icon: Icons.settings,
                        iconColor: greyText,
                        bgColor: faintGrey,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.setttings,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}