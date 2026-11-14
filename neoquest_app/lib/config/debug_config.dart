// lib/config/debug_config.dart
// Debug Configuration for Development and Testing
// 20250713 17:00 V1.0: Central debug configuration

import 'dart:math' as math;

class DebugConfig {
  // Master debug flag - Hier zentral ein/ausschalten für Produktion
  static const bool isDebugMode = true; // ← Für Release auf false setzen
  
  // Feature-spezifische Debug-Flags
  static const bool enableGpsSimulation = true;
  static const bool enableCheckpointSimulation = true;
  static const bool enableServerSimulation = true;
  static const bool enableUploadSimulation = true;
  static const bool showDebugInfo = true;
  static const bool skipPermissions = false;
  static const bool useTestData = true;
  static const bool enableQuickNavigation = true;
  
  // GPS Simulation Werte
  static const double simulatedAccuracy = 5.0;
  static const double simulatedSpeed = 1.2; // m/s (ca. 4.3 km/h Gehgeschwindigkeit)
  static const double simulatedAltitude = 180.0; // Meter über Meeresspiegel
  static const double simulatedBearing = 45.0; // Grad
  
  // Timing
  static const int simulatedDelay = 1000; // ms
  static const int simulatedWalkTime = 300; // Sekunden (5 Minuten zum Checkpoint)
  
  // Server Debug
  static const String debugServerUrl = 'http://192.168.1.100:3000';
  static const List<String> fallbackServerUrls = [
    'http://192.168.1.100:3000',
    'http://192.168.0.100:3000',
    'http://10.0.0.100:3000',
    'http://127.0.0.1:3000',
  ];
  
  // Checkpoint Simulation - Möllersdorf Koordinaten für realistische Tests
  static const Map<String, double> simulatedCheckpointLocation = {
    'latitude': 48.02720,  // Brücke über Mühlbach
    'longitude': 16.30450,
  };
  
  static const Map<String, double> simulatedPlayerStart = {
    'latitude': 48.02580,  // Münchendorferstrasse 12
    'longitude': 16.30510,
  };
  
  // Hilfsmethoden
  static bool get canSimulateGps => isDebugMode && enableGpsSimulation;
  static bool get canSimulateCheckpoints => isDebugMode && enableCheckpointSimulation;
  static bool get canSimulateServer => isDebugMode && enableServerSimulation;
  static bool get canSimulateUpload => isDebugMode && enableUploadSimulation;
  static bool get shouldShowDebugInfo => isDebugMode && showDebugInfo;
  static bool get canUseQuickNavigation => isDebugMode && enableQuickNavigation;
  
  // Debug Logging
  static void printDebug(String message) {
    if (shouldShowDebugInfo) {
      print('🐛 DEBUG: $message');
    }
  }
  
  static void printGps(String message) {
    if (canSimulateGps && shouldShowDebugInfo) {
      print('📍 GPS-SIM: $message');
    }
  }
  
  static void printCheckpoint(String message) {
    if (canSimulateCheckpoints && shouldShowDebugInfo) {
      print('🎯 CHECKPOINT-SIM: $message');
    }
  }
  
  static void printUpload(String message) {
    if (canSimulateUpload && shouldShowDebugInfo) {
      print('☁️ UPLOAD-SIM: $message');
    }
  }
  
  // Simulierte GPS-Position basierend auf Zeit und echten Checkpoint-Daten
  static Map<String, double> getSimulatedPosition(
    DateTime startTime, 
    double startLat, 
    double startLng, 
    double targetLat, 
    double targetLng
  ) {
    final elapsed = DateTime.now().difference(startTime).inSeconds;
    final progress = (elapsed / simulatedWalkTime).clamp(0.0, 1.0);
    
    // Lineare Interpolation zwischen Start und Ziel (echte Koordinaten)
    final currentLat = startLat + (targetLat - startLat) * progress;
    final currentLng = startLng + (targetLng - startLng) * progress;
    
    return {
      'latitude': currentLat,
      'longitude': currentLng,
      'progress': progress,
    };
  }
  
  // Prüfen ob simulierte Position nahe genug am echten Checkpoint ist
  static bool isSimulatedPositionNearCheckpoint(
    Map<String, double> position, 
    double targetLat, 
    double targetLng, 
    double radius
  ) {
    final distance = _calculateDistance(
      position['latitude']!,
      position['longitude']!,
      targetLat,
      targetLng,
    );
    return distance <= radius;
  }
  
  // Berechne realistische Start-Position (100-200m vom Checkpoint entfernt)
  static Map<String, double> generateStartPosition(double targetLat, double targetLng) {
    // Zufällige Richtung und Distanz
    final random = math.Random();
    final angle = random.nextDouble() * 2 * math.pi;
    final distance = 150 + random.nextDouble() * 100; // 150-250 Meter
    
    // Konvertiere zu Koordinaten (grobe Näherung)
    final deltaLat = distance * math.cos(angle) / 111000; // ~111km pro Grad
    final deltaLng = distance * math.sin(angle) / (111000 * math.cos(targetLat * math.pi / 180));
    
    return {
      'latitude': targetLat + deltaLat,
      'longitude': targetLng + deltaLng,
    };
  }
  
  // Haversine Distanz-Berechnung für Debug
  static double _calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    const double earthRadius = 6371000; // meters
    final lat1Rad = lat1 * (math.pi / 180);
    final lat2Rad = lat2 * (math.pi / 180);
    final deltaLatRad = (lat2 - lat1) * (math.pi / 180);
    final deltaLngRad = (lng2 - lng1) * (math.pi / 180);

    final a = math.sin(deltaLatRad / 2) * math.sin(deltaLatRad / 2) +
        math.cos(lat1Rad) * math.cos(lat2Rad) *
        math.sin(deltaLngRad / 2) * math.sin(deltaLngRad / 2);
    final c = 2 * math.asin(math.sqrt(a));

    return earthRadius * c;
  }
}