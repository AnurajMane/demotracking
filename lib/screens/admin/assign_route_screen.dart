import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:demotracking/services/bus_service.dart';

class AssignRouteScreen extends StatefulWidget {
  const AssignRouteScreen({super.key});

  @override
  State<AssignRouteScreen> createState() => _AssignRouteScreenState();
}

class _AssignRouteScreenState extends State<AssignRouteScreen> {
  final BusService _busService = BusService();
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _buses = [];
  List<Map<String, dynamic>> _routes = [];
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoading = true;
  String _errorMessage = '';
  String _searchQuery = '';
  List<Map<String, dynamic>> _filteredBuses = [];
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _assignmentHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      // Load buses using BusService
      _buses = await _busService.getBuses(); // Assuming getBuses() is a method in BusService

      // Load available routes
      final routesResponse = await _supabase
          .from('routes')
          .select('id, name, start_location, end_location')
          .order('name');
      _routes = List<Map<String, dynamic>>.from(routesResponse);

      // Load available drivers
      final driversResponse = await _supabase
          .from('profiles')
          .select('id, full_name, email')
          .eq('role', 'driver')
          .order('full_name');
      _drivers = List<Map<String, dynamic>>.from(driversResponse);

      setState(() {
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load data: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkDuplicateAssignment(String driverId, String routeId) async {
    final existingAssignment = await _supabase
        .from('buses')
        .select()
        .eq('driver_id', driverId)
        .eq('route_id', routeId)
        .maybeSingle();
    
    return existingAssignment != null;
  }

  Future<void> _assignRouteAndDriver({
    required String busId,
    required String routeId,
    required String driverId,
  }) async {
    try {
      setState(() => _isLoading = true);

      // Check for duplicate assignment
      if (await _checkDuplicateAssignment(driverId, routeId)) {
        throw 'This driver is already assigned to this route';
      }

      await _supabase.from('buses').update({
        'route_id': routeId,
        'driver_id': driverId,
        'status': 'active',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', busId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Assignment successful')),
        );
        _loadData(); // Reload data to show updated assignments
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to assign: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unassignBus(String busId) async {
    try {
      setState(() => _isLoading = true);

      await _supabase.from('buses').update({
        'route_id': null,
        'driver_id': null,
        'status': 'inactive',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', busId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bus unassigned successfully')),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to unassign: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterBuses(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      _filteredBuses = _buses.where((bus) {
        final busName = bus['name'].toString().toLowerCase();
        final driverName = (bus['profiles']?['full_name'] ?? '').toString().toLowerCase();
        final routeName = (bus['routes']?['name'] ?? '').toString().toLowerCase();
        return busName.contains(_searchQuery) ||
               driverName.contains(_searchQuery) ||
               routeName.contains(_searchQuery);
      }).toList();
    });
  }

  Future<void> _loadAssignmentHistory(String busId) async {
    try {
      final history = await _supabase
          .from('bus_assignment_history')
          .select('''
                id,
                bus_id,
                driver_id,
                route_id,
                assigned_at,
                profiles (full_name),
                routes (name)
            ''')
          .eq('bus_id', busId)
          .order('assigned_at', ascending: false);

      setState(() {
        _assignmentHistory = List<Map<String, dynamic>>.from(history);
      });
    } catch (e) {
      print('Failed to load history: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Assign Routes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search buses, drivers, or routes',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _filterBuses,
            ),
          ),
          
          Expanded(
            child: ListView.builder(
              itemCount: _filteredBuses.length,
              itemBuilder: (context, index) {
                final bus = _filteredBuses[index];
                return BusAssignmentCard(
                  bus: bus,
                  onAssign: (busId, driverId, routeId) => _assignRouteAndDriver(busId: busId, driverId: driverId, routeId: routeId),
                  onUnassign: (busId) => _unassignBus(busId),
                  onViewHistory: () => _loadAssignmentHistory(bus['id']),
                  routes: _routes,
                  drivers: _drivers,
                );
              },
            ),
          ),
          
          // Display Assignment History
          if (_assignmentHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Assignment History:', style: Theme.of(context).textTheme.headlineMedium),
            Expanded(
              child: ListView.builder(
                itemCount: _assignmentHistory.length,
                itemBuilder: (context, index) {
                  final history = _assignmentHistory[index];
                  return ListTile(
                    title: Text('Bus: ${history['bus_id']}'),
                    subtitle: Text('Assigned to: ${history['profiles']['full_name']} on ${history['assigned_at']}'),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class BusAssignmentCard extends StatelessWidget {
    final Map<String, dynamic> bus;
    final Function(String, String, String) onAssign;
    final Function(String) onUnassign;
    final Function() onViewHistory;
    final List<Map<String, dynamic>> routes;
    final List<Map<String, dynamic>> drivers;

    const BusAssignmentCard({
        required this.bus,
        required this.onAssign,
        required this.onUnassign,
        required this.onViewHistory,
        required this.routes,
        required this.drivers,
    });

    @override
    Widget build(BuildContext context) {
        return Card(
            child: ExpansionTile(
                title: Text('Bus: ${bus['name']}'),
                subtitle: Text('Status: ${bus['status']}'),
                children: [
                    // Assignment controls
                    // History view
                    // Status indicators
                ],
            ),
        );
    }
} 