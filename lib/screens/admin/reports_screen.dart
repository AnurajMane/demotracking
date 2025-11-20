import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = true;
  String _errorMessage = '';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  String _selectedReportType = 'attendance';

  // Report data
  Map<String, dynamic> _attendanceReport = {};
  Map<String, dynamic> _busUtilizationReport = {};
  Map<String, dynamic> _routeEfficiencyReport = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      setState(() => _isLoading = true);

      /*// Load attendance report
      final attendanceResponse = await _supabase
          .from('attendance')
          .select('*, students(name), buses!fk_bus(name)')
          .gte('date', _startDate.toIso8601String())
          .lte('date', _endDate.toIso8601String());

      _attendanceReport = _processAttendanceData(attendanceResponse);
*/
      // Load bus utilization report
      final busResponse = await _supabase
          .from('buses')
          .select('*, bus_locations(*)')
          .gte('bus_locations.timestamp', _startDate.toIso8601String())
          .lte('bus_locations.timestamp', _endDate.toIso8601String());

      _busUtilizationReport = _processBusUtilizationData(busResponse as List<dynamic>?);

      // Load route efficiency report
      final routeResponse = await _supabase
          .from('routes')
          .select('*, buses!fk_bus_route(*)')
          .gte('buses.last_updated', _startDate.toIso8601String())
          .lte('buses.last_updated', _endDate.toIso8601String());

      _routeEfficiencyReport = _processRouteEfficiencyData(routeResponse as List<dynamic>?);

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load reports: $e';
          _isLoading = false;
        });
      }
    }
  }

  Map<String, dynamic> _processAttendanceData(List<dynamic>? data) {
    if (data == null || data.isEmpty) {
      return {
        'total': 0,
        'present': 0,
        'absent': 0,
        'late': 0,
        'attendanceRate': 0.0,
      };
    }
    final totalStudents = data.length;
    final presentCount = data.where((record) => record['status'] == 'present').length;
    final absentCount = data.where((record) => record['status'] == 'absent').length;
    final lateCount = data.where((record) => record['status'] == 'late').length;

    return {
      'total': totalStudents,
      'present': presentCount,
      'absent': absentCount,
      'late': lateCount,
      'attendanceRate': totalStudents > 0 ? (presentCount / totalStudents) * 100 : 0.0,
    };
  }

  Map<String, dynamic> _processBusUtilizationData(List<dynamic>? data) {
    if (data == null || data.isEmpty) {
      return {
        'total': 0,
        'active': 0,
        'utilizationRate': 0.0,
        'averageStudents': 0.0,
      };
    }
    final totalBuses = data.length;
    final activeBuses = data.where((bus) => bus['status'] == 'active').length;
    final averageStudents = data.fold<double>(
      0,
      (sum, bus) => sum + (bus['student_count'] ?? 0),
    ) / totalBuses;

    return {
      'total': totalBuses,
      'active': activeBuses,
      'utilizationRate': totalBuses > 0 ? (activeBuses / totalBuses) * 100 : 0.0,
      'averageStudents': averageStudents,
    };
  }

  Map<String, dynamic> _processRouteEfficiencyData(List<dynamic>? data) {
    if (data == null || data.isEmpty) {
      return {
        'total': 0,
        'active': 0,
        'efficiencyRate': 0.0,
        'averageBuses': 0.0,
      };
    }
    final totalRoutes = data.length;
    final activeRoutes = data.where((route) =>
      (route['buses'] as List?)?.any((bus) => bus['status'] == 'active') ?? false
    ).length;
    final averageBusesPerRoute = data.fold<double>(
      0,
      (sum, route) => sum + ((route['buses'] as List?)?.length ?? 0),
    ) / totalRoutes;

    return {
      'total': totalRoutes,
      'active': activeRoutes,
      'efficiencyRate': totalRoutes > 0 ? (activeRoutes / totalRoutes) * 100 : 0.0,
      'averageBuses': averageBusesPerRoute,
    };
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDateRange,
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
                        onPressed: _loadReports,
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
                      Text(
                        'Date Range: ${DateFormat('MMM d, y').format(_startDate)} - ${DateFormat('MMM d, y').format(_endDate)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'attendance',
                            label: Text('Attendance'),
                            icon: Icon(Icons.people),
                          ),
                          ButtonSegment(
                            value: 'utilization',
                            label: Text('Bus Utilization'),
                            icon: Icon(Icons.directions_bus),
                          ),
                          ButtonSegment(
                            value: 'efficiency',
                            label: Text('Route Efficiency'),
                            icon: Icon(Icons.route),
                          ),
                        ],
                        selected: {_selectedReportType},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _selectedReportType = newSelection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      if (_selectedReportType == 'attendance') ...[
                        _buildAttendanceReport(),
                      ] else if (_selectedReportType == 'utilization') ...[
                        _buildBusUtilizationReport(),
                      ] else ...[
                        _buildRouteEfficiencyReport(),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildAttendanceReport() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Total Students',
              _attendanceReport['total'].toString(),
              Icons.people,
            ),
            _buildMetricRow(
              'Present',
              _attendanceReport['present'].toString(),
              Icons.check_circle,
              color: Colors.green,
            ),
            _buildMetricRow(
              'Absent',
              _attendanceReport['absent'].toString(),
              Icons.cancel,
              color: Colors.red,
            ),
            _buildMetricRow(
              'Late',
              _attendanceReport['late'].toString(),
              Icons.warning,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (_attendanceReport['attendanceRate'] ?? 0.0) / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                (_attendanceReport['attendanceRate'] ?? 0.0) >= 90
                    ? Colors.green
                    : (_attendanceReport['attendanceRate'] ?? 0.0) >= 80
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Attendance Rate: ${(_attendanceReport['attendanceRate'] ?? 0.0).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusUtilizationReport() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bus Utilization Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Total Buses',
              _busUtilizationReport['total'].toString(),
              Icons.directions_bus,
            ),
            _buildMetricRow(
              'Active Buses',
              _busUtilizationReport['active'].toString(),
              Icons.check_circle,
              color: Colors.green,
            ),
            _buildMetricRow(
              'Average Students per Bus',
              _busUtilizationReport['averageStudents'].toStringAsFixed(1),
              Icons.people,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (_busUtilizationReport['utilizationRate'] ?? 0.0) / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                (_busUtilizationReport['utilizationRate'] ?? 0.0) >= 90
                    ? Colors.green
                    : (_busUtilizationReport['utilizationRate'] ?? 0.0) >= 80
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Utilization Rate: ${(_busUtilizationReport['utilizationRate'] ?? 0.0).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteEfficiencyReport() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Route Efficiency Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildMetricRow(
              'Total Routes',
              _routeEfficiencyReport['total'].toString(),
              Icons.route,
            ),
            _buildMetricRow(
              'Active Routes',
              _routeEfficiencyReport['active'].toString(),
              Icons.check_circle,
              color: Colors.green,
            ),
            _buildMetricRow(
              'Average Buses per Route',
              _routeEfficiencyReport['averageBuses'].toStringAsFixed(1),
              Icons.directions_bus,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: (_routeEfficiencyReport['efficiencyRate'] ?? 0.0) / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(
                (_routeEfficiencyReport['efficiencyRate'] ?? 0.0) >= 90
                    ? Colors.green
                    : (_routeEfficiencyReport['efficiencyRate'] ?? 0.0) >= 80
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Efficiency Rate: ${(_routeEfficiencyReport['efficiencyRate'] ?? 0.0).toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
} 