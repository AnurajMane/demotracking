import 'package:flutter/material.dart';
import 'package:demotracking/services/bus_service.dart';

class StartTripScreen extends StatefulWidget {
  final String busId;
  final String busName;
  final String routeName;

  const StartTripScreen({
    super.key,
    required this.busId,
    required this.busName,
    required this.routeName,
  });

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  final BusService _busService = BusService();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _startTrip() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _busService.updateBusLocation(
        busId: widget.busId,
        latitude: 0, // Initial position will be updated by location tracking
        longitude: 0,
        speed: 0,
        status: 'active',
        driverName: 'Driver Name',
      );

      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate trip started
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to start trip: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Start Trip'),
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
                      'Trip Information',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Bus: ${widget.busName}'),
                    Text('Route: ${widget.routeName}'),
                    Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
                    Text('Time: ${DateTime.now().toString().split(' ')[1]}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage.isNotEmpty)
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
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _startTrip,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Start Trip',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 