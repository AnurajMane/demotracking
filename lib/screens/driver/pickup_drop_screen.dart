import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show sin, cos, sqrt, atan2, pi;

import 'qr_scanner_screen.dart'; // Make sure this file exists

class PickupDropScreen extends StatefulWidget {
  const PickupDropScreen({super.key});

  @override
  State<PickupDropScreen> createState() => _PickupDropScreenState();
}

class _PickupDropScreenState extends State<PickupDropScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _errorMessage = '';

  Map<String, dynamic>? _driverData;
  Map<String, dynamic>? _busData;
  Map<String, dynamic>? _routeData;
  List<Map<String, dynamic>> _stops = [];
  List<Map<String, dynamic>> _students = [];
  Position? _currentPosition;
  int _currentStopIndex = 0;
  bool _isPickupMode = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _getCurrentLocation();
  }

  Future<void> _loadData() async {
    try {
      setState(() => _isLoading = true);

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw 'User not authenticated';

      final driverResponse = await _supabase
          .from('profiles')
          .select('*, bus:bus_id(*, route:route_id(*))')
          .eq('id', userId)
          .eq('role', 'driver')
          .single();
      _driverData = driverResponse;

      if (_driverData != null) {
        _busData = _driverData!['bus'];
        _routeData = _busData?['route'];

        if (_routeData != null) {
          final stopsResponse = await _supabase
              .from('stops')
              .select('*')
              .eq('route_id', _routeData!['id'])
              .order('stop_order');
          _stops = List<Map<String, dynamic>>.from(stopsResponse);

          final studentsResponse = await _supabase
              .from('students')
              .select('*, attendance(*)')
              .eq('bus_id', _busData!['id']);
          _students = List<Map<String, dynamic>>.from(studentsResponse);
        }
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

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to get location: $e';
      });
    }
  }

  Future<void> _markAttendance(String studentId, bool isPickup) async {
    try {
      final now = DateTime.now();
      final existing = await _supabase
          .from('attendance')
          .select()
          .eq('student_id', studentId)
          .eq('bus_id', _busData!['id'])
          .eq('date', now.toIso8601String().substring(0, 10))
          .maybeSingle();

      if (existing == null) {
        await _supabase.from('attendance').insert({
          'student_id': studentId,
          'bus_id': _busData!['id'],
          'date': now.toIso8601String().substring(0, 10),
          'status': isPickup ? 'present' : 'absent',
          'parent_id': null,
        });
      }

      _loadData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to mark attendance: $e';
      });
    }
  }

  Widget _buildStopInfo() {
    if (_stops.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No stops found'),
        ),
      );
    }

    final currentStop = _stops[_currentStopIndex];
    final studentsAtStop = _students.where((student) {
      final attendance = student['attendance'] as List;
      final lastAttendance = attendance.isNotEmpty
          ? attendance.last as Map<String, dynamic>
          : null;
      return lastAttendance?['stop_id'] == currentStop['id'] &&
          lastAttendance?['type'] == (_isPickupMode ? 'dropoff' : 'pickup');
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isPickupMode ? Icons.person_add : Icons.directions_bus,
                  size: 32,
                  color: _isPickupMode ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stop ${_currentStopIndex + 1}/${_stops.length}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        '${studentsAtStop.length} students',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(),
            Text(
              'Location: ${currentStop['name']}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_currentPosition != null) ...[
              const SizedBox(height: 8),
              Text(
                'Distance: ${_calculateDistance(
                  LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                  LatLng(
                    currentStop['latitude'] as double,
                    currentStop['longitude'] as double,
                  ),
                ).toStringAsFixed(1)} km',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentList() {
    if (_stops.isEmpty) {
      return const Center(child: Text('No stops found'));
    }

    final currentStop = _stops[_currentStopIndex];
    final studentsAtStop = _students.where((student) {
      final attendance = student['attendance'] as List;
      final lastAttendance = attendance.isNotEmpty
          ? attendance.last as Map<String, dynamic>
          : null;
      return lastAttendance?['stop_id'] == currentStop['id'] &&
          lastAttendance?['type'] == (_isPickupMode ? 'dropoff' : 'pickup');
    }).toList();

    if (studentsAtStop.isEmpty) {
      return const Center(child: Text('No students at this stop'));
    }

    return ListView.builder(
      itemCount: studentsAtStop.length,
      itemBuilder: (context, index) {
        final student = studentsAtStop[index];
        return ListTile(
          leading: CircleAvatar(
            child: Text(student['name'][0].toUpperCase()),
          ),
          title: Text(student['name']),
          subtitle: Text('Grade: ${student['grade']}'),
          trailing: ElevatedButton(
            onPressed: () => _markAttendance(student['id'], _isPickupMode),
            child: Text(_isPickupMode ? 'Pickup' : 'Dropoff'),
          ),
        );
      },
    );
  }

  double _calculateDistance(LatLng a, LatLng b) {
    const double earthRadius = 6371;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;

    final a1 = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a1), sqrt(1 - a1));
    return earthRadius * c;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pickup & Dropoff'),
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
              : Column(
                  children: [
                    _buildStopInfo(),
                    Expanded(child: _buildStudentList()),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _currentStopIndex > 0
                                      ? () {
                                          setState(() {
                                            _currentStopIndex--;
                                          });
                                        }
                                      : null,
                                  icon: const Icon(Icons.arrow_back),
                                  label: const Text('Prev'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _isPickupMode = !_isPickupMode;
                                    });
                                  },
                                  icon: Icon(_isPickupMode
                                      ? Icons.person_add
                                      : Icons.directions_bus),
                                  label:
                                      Text(_isPickupMode ? 'Pickup' : 'Dropoff'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _currentStopIndex < _stops.length - 1
                                          ? () {
                                              setState(() {
                                                _currentStopIndex++;
                                              });
                                            }
                                          : null,
                                  icon: const Icon(Icons.arrow_forward),
                                  label: const Text('Next'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => QRScannerScreen(
                                    //busId: _busData!['id'],
                                    //parentId: _driverData!['id'],
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan QR/Barcode'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
