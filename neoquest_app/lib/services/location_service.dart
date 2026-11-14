// lib/services/location_service.dart
// 20250711 1015 V1.0: Initial LocationService with GPS streams, permissions, and calculations

import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _locationSubscription;
  Position? _lastKnownPosition;
  final StreamController<Position> _locationController = StreamController<Position>.broadcast();
  
  // Location settings
  static const LocationSettings _locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // Update when moved 5 meters
  );

  /// Get location stream
  Stream<Position> get locationStream => _locationController.stream;

  /// Get last known position
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Request location permissions
  Future<bool> requestLocationPermissions() async {
    try {
      print('🔐 Requesting location permissions...');
      
      // Check if location service is enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('❌ Location services are disabled');
        return false;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      print('📍 Current permission status: $permission');

      // Request permission if needed
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('❌ Location permissions are denied');
          return false;
        }
      }

      // Check for permanently denied
      if (permission == LocationPermission.deniedForever) {
        print('❌ Location permissions are permanently denied');
        return false;
      }

      print('✅ Location permissions granted: $permission');
      return true;
    } catch (e) {
      print('❌ Error requesting location permissions: $e');
      return false;
    }
  }

  /// Start location tracking
  Future<bool> startLocationTracking() async {
    try {
      print('🚀 Starting location tracking...');

      // Request permissions first
      bool hasPermission = await requestLocationPermissions();
      if (!hasPermission) {
        throw Exception('Location permissions required');
      }

      // Stop existing subscription if any
      await stopLocationTracking();

      // Start new subscription
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: _locationSettings,
      ).listen(
        (Position position) {
          _lastKnownPosition = position;
          _locationController.add(position);
          print('📍 Location update: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
        },
        onError: (error) {
          print('❌ Location stream error: $error');
        },
      );

      print('✅ Location tracking started');
      return true;
    } catch (e) {
      print('❌ Error starting location tracking: $e');
      return false;
    }
  }

  /// Stop location tracking
  Future<void> stopLocationTracking() async {
    if (_locationSubscription != null) {
      await _locationSubscription!.cancel();
      _locationSubscription = null;
      print('🛑 Location tracking stopped');
    }
  }

  /// Get current position (one-time)
  Future<Position?> getCurrentPosition() async {
    try {
      print('📍 Getting current position...');

      bool hasPermission = await requestLocationPermissions();
      if (!hasPermission) {
        throw Exception('Location permissions required');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _lastKnownPosition = position;
      print('✅ Current position: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
      return position;
    } catch (e) {
      print('❌ Error getting current position: $e');
      return null;
    }
  }

  /// Calculate distance between two points in meters
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Calculate bearing from current position to target in degrees (0-360)
  double calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.bearingBetween(lat1, lon1, lat2, lon2);
  }

  /// Check if position is within radius of target
  bool isWithinRadius(double currentLat, double currentLon, double targetLat, double targetLon, double radiusMeters) {
    double distance = calculateDistance(currentLat, currentLon, targetLat, targetLon);
    return distance <= radiusMeters;
  }

  /// Convert bearing to compass direction
  String bearingToCompass(double bearing) {
    // Normalize bearing to 0-360
    double normalizedBearing = (bearing + 360) % 360;
    
    const List<String> directions = [
      'N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'
    ];
    
    int index = ((normalizedBearing + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }

  /// Get location accuracy description
  String getAccuracyDescription(double accuracy) {
    if (accuracy <= 5) return 'Excellent';
    if (accuracy <= 10) return 'Good';
    if (accuracy <= 20) return 'Fair';
    return 'Poor';
  }

  /// Get distance in human readable format
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      double km = meters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Get location permission status for UI
  Future<LocationPermissionStatus> getPermissionStatus() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationPermissionStatus.serviceDisabled;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      switch (permission) {
        case LocationPermission.always:
        case LocationPermission.whileInUse:
          return LocationPermissionStatus.granted;
        case LocationPermission.denied:
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.unableToDetermine:
          return LocationPermissionStatus.unknown;
      }
    } catch (e) {
      print('❌ Error checking permission status: $e');
      return LocationPermissionStatus.unknown;
    }
  }

  /// Dispose resources
  void dispose() {
    stopLocationTracking();
    _locationController.close();
  }
}

/// Location permission status enum
enum LocationPermissionStatus {
  granted,
  denied,
  deniedForever,
  serviceDisabled,
  unknown,
}

/// Helper class for location calculations
class LocationHelper {
  /// Convert degrees to radians
  static double degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Convert radians to degrees
  static double radiansToDegrees(double radians) {
    return radians * (180 / pi);
  }

  /// Calculate bearing using haversine formula (more accurate)
  static double calculatePreciseBearing(double lat1, double lon1, double lat2, double lon2) {
    double dLon = degreesToRadians(lon2 - lon1);
    double lat1Rad = degreesToRadians(lat1);
    double lat2Rad = degreesToRadians(lat2);
    
    double y = sin(dLon) * cos(lat2Rad);
    double x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);
    
    double bearing = atan2(y, x);
    return (radiansToDegrees(bearing) + 360) % 360;
  }
}