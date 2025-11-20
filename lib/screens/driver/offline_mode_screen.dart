import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class OfflineModeScreen extends StatefulWidget {
  const OfflineModeScreen({super.key});

  @override
  State<OfflineModeScreen> createState() => _OfflineModeScreenState();
}

class _OfflineModeScreenState extends State<OfflineModeScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';
  bool _isOfflineMode = false;
  List<Map<String, dynamic>> _pendingReports = [];
  List<Map<String, dynamic>> _pendingAttendance = [];

  @override
  void initState() {
    super.initState();
    _loadOfflineData();
  }

  Future<void> _loadOfflineData() async {
    try {
      setState(() => _isLoading = true);

      // Load offline mode status
      final prefs = await SharedPreferences.getInstance();
      _isOfflineMode = prefs.getBool('offline_mode') ?? false;

      // Load pending reports
      final pendingReportsJson = prefs.getString('pending_reports');
      if (pendingReportsJson != null) {
        _pendingReports = List<Map<String, dynamic>>.from(
          json.decode(pendingReportsJson),
        );
      }

      // Load pending attendance
      final pendingAttendanceJson = prefs.getString('pending_attendance');
      if (pendingAttendanceJson != null) {
        _pendingAttendance = List<Map<String, dynamic>>.from(
          json.decode(pendingAttendanceJson),
        );
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load offline data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleOfflineMode() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final newMode = !_isOfflineMode;
      await prefs.setBool('offline_mode', newMode);

      setState(() {
        _isOfflineMode = newMode;
      });

      if (!newMode) {
        // Attempt to sync data when going back online
        await _syncPendingData();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to toggle offline mode: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncPendingData() async {
    try {
      setState(() => _isLoading = true);

      // Sync pending reports
      for (final report in _pendingReports) {
        await _supabase.from('incidents').insert(report);
      }

      // Sync pending attendance
      for (final attendance in _pendingAttendance) {
        await _supabase.from('attendance').insert(attendance);
      }

      // Clear pending data
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('pending_reports');
      await prefs.remove('pending_attendance');

      setState(() {
        _pendingReports = [];
        _pendingAttendance = [];
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data synced successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to sync data: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildPendingDataCard() {
    if (_pendingReports.isEmpty && _pendingAttendance.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No pending data to sync'),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pending Data',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            if (_pendingReports.isNotEmpty) ...[
              Text(
                'Pending Reports: ${_pendingReports.length}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 8),
            ],
            if (_pendingAttendance.isNotEmpty) ...[
              Text(
                'Pending Attendance: ${_pendingAttendance.length}',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
            ],
            ElevatedButton(
              onPressed: _syncPendingData,
              child: const Text('Sync Now'),
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
        title: const Text('Offline Mode'),
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
                        onPressed: _loadOfflineData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Offline Mode Status',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _isOfflineMode ? 'Enabled' : 'Disabled',
                                    style: TextStyle(
                                      color: _isOfflineMode
                                          ? Colors.orange
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Switch(
                                    value: _isOfflineMode,
                                    onChanged: (value) => _toggleOfflineMode(),
                                  ),
                                ],
                              ),
                              if (_isOfflineMode) ...[
                                const SizedBox(height: 16),
                                const Text(
                                  'When offline mode is enabled:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  '• Data will be stored locally\n'
                                  '• Reports and attendance will be synced when online\n'
                                  '• You can continue working without internet',
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildPendingDataCard(),
                    ],
                  ),
                ),
    );
  }
} 