// lib/screens/location_test_screen.dart
// 20250711 10:16 V1.0: Test screen for LocationService functionality
// 20250801 19:20 V1.1: Refactored to use centralized AppColors

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../constants/app_colors.dart';

class LocationTestScreen extends StatefulWidget {
  const LocationTestScreen({super.key});

  @override
  State<LocationTestScreen> createState() => _LocationTestScreenState();
}

class _LocationTestScreenState extends State<LocationTestScreen> {
  final LocationService _locationService = LocationService();
  Position? _currentPosition;
  LocationPermissionStatus _permissionStatus = LocationPermissionStatus.unknown;
  bool _isTracking = false;
  String _statusMessage = 'Ready to test location services';

  // Möllersdorf test target (Bridge over Mühlbach)
  static const double targetLat = 48.02720;
  static const double targetLon = 16.30450;
  
  @override
  void initState() {
    super.initState();
    print('📍 Current Screen: ${runtimeType.toString()}');
    _checkPermissionStatus();
    _listenToLocationUpdates();
  }

  @override
  void dispose() {
    _locationService.stopLocationTracking();
    super.dispose();
  }

  Future<void> _checkPermissionStatus() async {
    final status = await _locationService.getPermissionStatus();
    setState(() {
      _permissionStatus = status;
    });
  }

  void _listenToLocationUpdates() {
    _locationService.locationStream.listen((Position position) {
      setState(() {
        _currentPosition = position;
        _statusMessage = 'Location updated successfully';
      });
    });
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _statusMessage = 'Requesting location permissions...';
    });

    final success = await _locationService.requestLocationPermissions();
    
    setState(() {
      _statusMessage = success 
          ? 'Permissions granted successfully!' 
          : 'Permission request failed';
    });

    if (success) {
      _checkPermissionStatus();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _statusMessage = 'Getting current location...';
    });

    final position = await _locationService.getCurrentPosition();
    
    setState(() {
      if (position != null) {
        _currentPosition = position;
        _statusMessage = 'Location retrieved successfully!';
      } else {
        _statusMessage = 'Failed to get current location';
      }
    });
  }

  Future<void> _toggleTracking() async {
    if (_isTracking) {
      await _locationService.stopLocationTracking();
      setState(() {
        _isTracking = false;
        _statusMessage = 'Location tracking stopped';
      });
    } else {
      setState(() {
        _statusMessage = 'Starting location tracking...';
      });

      final success = await _locationService.startLocationTracking();
      
      setState(() {
        _isTracking = success;
        _statusMessage = success 
            ? 'Location tracking started' 
            : 'Failed to start tracking';
      });
    }
  }

  Widget _buildPermissionStatus() {
    IconData icon;
    Color color;
    String text;

    switch (_permissionStatus) {
      case LocationPermissionStatus.granted:
        icon = Icons.check_circle;
        color = AppColors.success;
        text = 'Permissions Granted';
        break;
      case LocationPermissionStatus.denied:
        icon = Icons.warning;
        color = AppColors.warning;
        text = 'Permissions Denied';
        break;
      case LocationPermissionStatus.deniedForever:
        icon = Icons.block;
        color = AppColors.redAlert;
        text = 'Permanently Denied';
        break;
      case LocationPermissionStatus.serviceDisabled:
        icon = Icons.location_disabled;
        color = AppColors.redAlert;
        text = 'Location Service Disabled';
        break;
      default:
        icon = Icons.help;
        color = AppColors.disabled;
        text = 'Unknown Status';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    if (_currentPosition == null) {
      return Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.location_off,
                size: 48,
                color: AppColors.disabled,
              ),
              const SizedBox(height: 12),
              Text(
                'No location data available',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final distance = _locationService.calculateDistance(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLon,
    );

    final bearing = _locationService.calculateBearing(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLon,
    );

    final compassDirection = _locationService.bearingToCompass(bearing);
    final isNearTarget = _locationService.isWithinRadius(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      targetLat,
      targetLon,
      15.0, // 15 meter radius
    );

    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.gps_fixed,
                  color: AppColors.emeraldPrimary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.my_location, color: AppColors.emeraldPrimary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Coordinates',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}\n'
                    'Lon: ${_currentPosition!.longitude.toStringAsFixed(6)}',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.speed, color: AppColors.info, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Accuracy: ${_locationService.getAccuracyDescription(_currentPosition!.accuracy)}',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isNearTarget 
                    ? AppColors.success.withOpacity(0.1)
                    : AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isNearTarget 
                      ? AppColors.success.withOpacity(0.3)
                      : AppColors.warning.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.place,
                        color: AppColors.emeraldPrimary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Distance to Target (Möllersdorf Bridge)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Icon(
                        isNearTarget ? Icons.location_on : Icons.navigation,
                        color: isNearTarget ? AppColors.success : AppColors.warning,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_locationService.formatDistance(distance)} ${isNearTarget ? '(NEAR TARGET!)' : ''}',
                          style: TextStyle(
                            color: isNearTarget ? AppColors.success : AppColors.textPrimary,
                            fontWeight: isNearTarget ? FontWeight.bold : FontWeight.normal,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Row(
                    children: [
                      Icon(Icons.explore, color: AppColors.info, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Bearing: ${bearing.toStringAsFixed(1)}° ($compassDirection)',
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Text(
          'Location Service Test',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.primaryDark,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Permission Status
            _buildPermissionStatus(),
            
            const SizedBox(height: 20),
            
            // Status Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emeraldPrimary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.emeraldPrimary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.emeraldPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: AppColors.emeraldPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Control Buttons
            if (_permissionStatus != LocationPermissionStatus.granted) ...[
              ElevatedButton.icon(
                onPressed: _requestPermissions,
                icon: const Icon(Icons.security),
                label: const Text('Request Permissions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.warning.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            if (_permissionStatus == LocationPermissionStatus.granted) ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _getCurrentLocation,
                      icon: const Icon(Icons.my_location),
                      label: const Text('Get Location'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emeraldPrimary,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: AppColors.emeraldPrimary.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _toggleTracking,
                      icon: Icon(_isTracking ? Icons.stop : Icons.play_arrow),
                      label: Text(_isTracking ? 'Stop Tracking' : 'Start Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTracking ? AppColors.redAlert : AppColors.success,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: (_isTracking ? AppColors.redAlert : AppColors.success).withOpacity(0.4),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            
            // Location Information
            _buildLocationInfo(),
            
            const SizedBox(height: 20),
            
            // Test Target Info
            Card(
              color: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.flag,
                          color: AppColors.warning,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Test Target: Möllersdorf Bridge',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Target Coordinates:',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Lat: ${targetLat.toStringAsFixed(6)}\n'
                            'Lon: ${targetLon.toStringAsFixed(6)}',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.radio_button_unchecked,
                                color: AppColors.warning,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Detection Radius: 15 meters',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}