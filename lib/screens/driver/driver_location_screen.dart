import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:demotracking/services/bus_service.dart';

class DriverLocationScreen extends StatefulWidget {
  final String busId;
  final String busName;
  final String routeName;

  const DriverLocationScreen({
    super.key,
    required this.busId,
    required this.busName,
    required this.routeName,
  });

  @override
  State<DriverLocationScreen> createState() => _DriverLocationScreenState();
}

class _DriverLocationScreenState extends State<DriverLocationScreen> {
  final BusService _busService = BusService();
  Timer? _locationUpdateTimer;
  bool _isTracking = false;
  Position? _currentPosition;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final request = await Geolocator.requestPermission();
        if (request == LocationPermission.denied) {
          setState(() => _errorMessage = 'Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _errorMessage = 'Location permissions are permanently denied');
        return;
      }

      // Start location updates
      _startLocationUpdates();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to check location permission: $e');
    }
  }

  void _startLocationUpdates() {
    setState(() => _isTracking = true);
    
    // Update location every 30 seconds
    _locationUpdateTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _updateLocation(),
    );

    // Initial location update
    _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _busService.updateBusLocation(
        busId: widget.busId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        status: 'active',
        driverName: 'Driver Name',
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _errorMessage = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to update location: $e');
      }
    }
  }

  void _stopLocationUpdates() {
    _locationUpdateTimer?.cancel();
    setState(() => _isTracking = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.busName} - Location Tracking'),
        actions: [
          IconButton(
            icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
            onPressed: _isTracking ? _stopLocationUpdates : _startLocationUpdates,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Bus Name: ${widget.busName}'),
                    Text('Route: ${widget.routeName}'),
                    Text('Status: ${_isTracking ? 'Tracking Active' : 'Tracking Stopped'}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_currentPosition != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Location',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Latitude: ${_currentPosition!.latitude}'),
                      Text('Longitude: ${_currentPosition!.longitude}'),
                      Text('Speed: ${_currentPosition!.speed.toStringAsFixed(2)} m/s'),
                      Text('Last Updated: ${DateTime.now().toString()}'),
                    ],
                  ),
                ),
              ),
            ],
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isTracking ? _stopLocationUpdates : _startLocationUpdates,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isTracking ? Colors.red : Colors.green,
                  padding: const EdgeInsets.all(16),
                ),
                child: Text(
                  _isTracking ? 'Stop Tracking' : 'Start Tracking',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 