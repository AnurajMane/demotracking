import 'package:flutter/material.dart';
import 'package:demotracking/services/bus_service.dart';
import 'package:demotracking/screens/driver/driver_location_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:demotracking/screens/driver/incident_report_screen.dart';
import 'package:demotracking/screens/driver/navigation_screen.dart';
import 'package:demotracking/screens/driver/offline_mode_screen.dart';
import 'package:demotracking/screens/driver/pickup_drop_screen.dart';
import 'package:demotracking/screens/driver/start_trip_screen.dart';

class DriverDashboardScreen extends StatefulWidget {
  const DriverDashboardScreen({super.key});

  @override
  State<DriverDashboardScreen> createState() => _DriverDashboardScreenState();
}

class _DriverDashboardScreenState extends State<DriverDashboardScreen> {
  final BusService _busService = BusService();
  Map<String, dynamic>? _assignedBus;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadAssignedBus();
  }

  Future<void> _loadAssignedBus() async {
    try {
      final buses = await _busService.getBusLocations();
      final assignedBus = buses.where(
        (bus) => bus['driver_id'] == _busService.currentUserId,
      ).toList();

      if (mounted) {
        setState(() {
          _assignedBus = assignedBus.isNotEmpty ? assignedBus.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load assigned bus: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const faintBlue = Color(0xFFE3F2FD);
    const faintRed = Color(0xFFFFEBEE);
    const faintGreen = Color(0xFFE8F5E9);
    const faintTeal = Color(0xFFE0F2F1);
    const faintPurple = Color(0xFFF3E5F5);
    const faintGrey = Color(0xFFF5F5F5);

    const blueText = Color(0xFF1976D2);
    const redText = Color(0xFFD32F2F);
    const greenText = Color(0xFF388E3C);
    const tealText = Color(0xFF00897B);
    const purpleText = Color(0xFF7B1FA2);
    const greyText = Color(0xFF757575);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FB), // Light background
      appBar: AppBar(
        title: const Text('Driver Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.lightBlue[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAssignedBus,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            }, 
          ),
        ],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadAssignedBus,
                        icon: Icon(Icons.refresh),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.lightBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                )
              : _assignedBus == null
                  ? const Center(
                      child: Text('No bus assigned to you yet.', style: TextStyle(fontSize: 18)),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.directions_bus, color: Colors.lightBlue, size: 32),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Assigned Bus',
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.lightBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Bus Name: ${_assignedBus!['name']}', style: TextStyle(fontSize: 16)),
                                  Text('Route: ${_assignedBus!['route']}', style: TextStyle(fontSize: 16)),
                                  Text('Status: ${_assignedBus!['status']}', style: TextStyle(fontSize: 16)),
                                  Text('Students: ${_assignedBus!['students']}', style: TextStyle(fontSize: 16)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_assignedBus!['status'] == 'active') ...[
                            Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.location_on, color: Colors.green, size: 32),
                                        const SizedBox(width: 10),
                                        Text(
                                          'Current Location',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text('Latitude: ${_assignedBus!['location'].latitude}', style: TextStyle(fontSize: 16)),
                                    Text('Longitude: ${_assignedBus!['location'].longitude}', style: TextStyle(fontSize: 16)),
                                    Text('Speed: ${_assignedBus!['speed']}', style: TextStyle(fontSize: 16)),
                                    Text('Last Update: ${_assignedBus!['lastUpdate']}', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Start Location Tracking
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DriverLocationScreen(
                                        busId: _assignedBus!['id'],
                                        busName: _assignedBus!['name'],
                                        routeName: _assignedBus!['route'],
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.gps_fixed, color: blueText),
                                label: const Text('Start Location Tracking', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: faintBlue,
                                  foregroundColor: blueText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Report Incident
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => IncidentReportScreen()),
                                  );
                                },
                                icon: Icon(Icons.report_problem, color: redText),
                                label: const Text('Report Incident', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: faintRed,
                                  foregroundColor: redText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Navigation
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => NavigationScreen()),
                                  );
                                },
                                icon: Icon(Icons.navigation, color: blueText),
                                label: const Text('Navigation', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: faintBlue,
                                  foregroundColor: blueText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Offline Mode
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => OfflineModeScreen()),
                                  );
                                },
                                icon: Icon(Icons.offline_bolt, color: greyText),
                                label: const Text('Offline Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: faintGrey,
                                  foregroundColor: greyText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Pickup/Dropoff
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => PickupDropScreen(),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.local_taxi, color: tealText),
                                label: const Text('Pickup/Dropoff', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: faintTeal,
                                  foregroundColor: tealText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Start Trip
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => StartTripScreen(
                                        busId: _assignedBus!['id'],
                                        busName: _assignedBus!['name'],
                                        routeName: _assignedBus!['route'],
                                      ),
                                    ),
                                  );
                                },
                                icon: Icon(Icons.directions_bus, color: purpleText),
                                label: const Text('Start Trip', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: faintPurple,
                                  foregroundColor: purpleText,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
    );
  }
} 