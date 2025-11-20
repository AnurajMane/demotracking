import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../utils/constants.dart';

class LocationProvider extends ChangeNotifier {
  Position? _currentPosition;
  bool _isLoading = false;
  String? _error;
  bool _isOffline = false;
  StreamSubscription<Position>? _positionStream;
  StreamSubscription<ConnectivityResult>? _connectivityStream;

  // Getters
  Position? get currentPosition => _currentPosition;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isOffline => _isOffline;

  LocationProvider() {
    _initializeLocation();
    _setupConnectivityListener();
  }

  Future<void> _initializeLocation() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _error = Constants.locationError;
          _isLoading = false;
          notifyListeners();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _error = Constants.locationError;
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Get initial position
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: Constants.locationUpdateInterval),
      );

      // Start position updates
      _startPositionUpdates();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to initialize location: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startPositionUpdates() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: Constants.locationAccuracy.toInt(),
      ),
    ).listen(
      (Position position) {
        _currentPosition = position;
        notifyListeners();
      },
      onError: (error) {
        _error = 'Location error: $error';
        notifyListeners();
      },
    );
  }

  void _setupConnectivityListener() {
    _connectivityStream?.cancel();
    _connectivityStream = Connectivity().onConnectivityChanged.listen(
      (ConnectivityResult result) {
        _isOffline = result == ConnectivityResult.none;
        notifyListeners();
      },
    );
  }

  Future<void> refreshLocation() async {
    try {
      _isLoading = true;
      notifyListeners();

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: Constants.locationUpdateInterval),
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to refresh location: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _connectivityStream?.cancel();
    super.dispose();
  }
} 