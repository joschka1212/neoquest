// lib/services/route_tracking_service.dart
// 20250711 11:06 V1.0: Background route tracking with offline storage and configurable intervals

import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'location_service.dart';

class RouteTrackingService {
  static final RouteTrackingService _instance = RouteTrackingService._internal();
  factory RouteTrackingService() => _instance;
  RouteTrackingService._internal();

  Database? _database;
  Timer? _trackingTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isTracking = false;
  String? _currentSessionId;
  
  // Tracking configuration
  int _trackingIntervalSeconds = 30; // Default: record every 30 seconds
  double _minimumDistanceMeters = 5.0; // Only record if moved 5+ meters
  
  final LocationService _locationService = LocationService();
  Position? _lastRecordedPosition;

  /// Initialize the database
  Future<void> initialize() async {
    if (_database != null) return;

    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'neoquest_routes.db');

      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createDatabase,
      );

      print('✅ Route tracking database initialized');
    } catch (e) {
      print('❌ Error initializing route database: $e');
    }
  }

  /// Create database tables
  Future<void> _createDatabase(Database db, int version) async {
    // Route sessions table
    await db.execute('''
      CREATE TABLE route_sessions (
        id TEXT PRIMARY KEY,
        player_name TEXT NOT NULL,
        player_token TEXT NOT NULL,
        game_id INTEGER NOT NULL,
        checkpoint_target TEXT,
        start_time INTEGER NOT NULL,
        end_time INTEGER,
        total_distance REAL DEFAULT 0,
        total_points INTEGER DEFAULT 0,
        status TEXT DEFAULT 'active'
      )
    ''');

    // Route points table
    await db.execute('''
      CREATE TABLE route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        bearing REAL,
        speed REAL,
        timestamp INTEGER NOT NULL,
        distance_from_previous REAL DEFAULT 0,
        FOREIGN KEY (session_id) REFERENCES route_sessions (id)
      )
    ''');

    // Checkpoints reached table
    await db.execute('''
      CREATE TABLE checkpoints_reached (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        checkpoint_id INTEGER NOT NULL,
        checkpoint_name TEXT NOT NULL,
        reached_at INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        points_earned INTEGER DEFAULT 0,
        time_to_reach INTEGER,
        FOREIGN KEY (session_id) REFERENCES route_sessions (id)
      )
    ''');

    print('✅ Route tracking database tables created');
  }

  /// Configure tracking parameters
  void configureTracking({
    int? intervalSeconds,
    double? minimumDistanceMeters,
  }) {
    if (intervalSeconds != null) {
      _trackingIntervalSeconds = intervalSeconds;
    }
    if (minimumDistanceMeters != null) {
      _minimumDistanceMeters = minimumDistanceMeters;
    }
    
    print('🔧 Route tracking configured: ${_trackingIntervalSeconds}s interval, ${_minimumDistanceMeters}m minimum distance');
  }

  /// Start route tracking for a game session
  Future<bool> startTracking({
    required String playerName,
    required String playerToken,
    required int gameId,
    String? checkpointTarget,
  }) async {
    try {
      if (_isTracking) {
        print('⚠️ Route tracking already active');
        return false;
      }

      await initialize();
      
      // Create new session
      _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      
      await _database!.insert('route_sessions', {
        'id': _currentSessionId,
        'player_name': playerName,
        'player_token': playerToken,
        'game_id': gameId,
        'checkpoint_target': checkpointTarget,
        'start_time': DateTime.now().millisecondsSinceEpoch,
        'status': 'active',
      });

      // Start location tracking
      await _locationService.startLocationTracking();
      
      // Start periodic recording
      _trackingTimer = Timer.periodic(
        Duration(seconds: _trackingIntervalSeconds),
        _recordCurrentPosition,
      );

      _isTracking = true;
      print('🚀 Route tracking started for session: $_currentSessionId');
      print('📍 Recording every ${_trackingIntervalSeconds}s, minimum ${_minimumDistanceMeters}m movement');
      
      return true;
    } catch (e) {
      print('❌ Error starting route tracking: $e');
      return false;
    }
  }

  /// Stop route tracking
  Future<void> stopTracking() async {
    if (!_isTracking || _currentSessionId == null) return;

    try {
      // Stop timer and location tracking
      _trackingTimer?.cancel();
      _locationSubscription?.cancel();
      
      // Update session end time
      await _database!.update(
        'route_sessions',
        {
          'end_time': DateTime.now().millisecondsSinceEpoch,
          'status': 'completed',
        },
        where: 'id = ?',
        whereArgs: [_currentSessionId],
      );

      // Calculate total distance
      await _calculateSessionTotalDistance();

      _isTracking = false;
      print('🛑 Route tracking stopped for session: $_currentSessionId');
      _currentSessionId = null;
      _lastRecordedPosition = null;
    } catch (e) {
      print('❌ Error stopping route tracking: $e');
    }
  }

  /// Record current position
  Future<void> _recordCurrentPosition(Timer timer) async {
    if (!_isTracking || _currentSessionId == null) return;

    try {
      final position = _locationService.lastKnownPosition;
      if (position == null) return;

      // Check if moved enough distance
      if (_lastRecordedPosition != null) {
        final distance = _locationService.calculateDistance(
          _lastRecordedPosition!.latitude,
          _lastRecordedPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        
        if (distance < _minimumDistanceMeters) {
          return; // Not moved enough, skip recording
        }
      }

      // Calculate distance from previous point
      double distanceFromPrevious = 0.0;
      if (_lastRecordedPosition != null) {
        distanceFromPrevious = _locationService.calculateDistance(
          _lastRecordedPosition!.latitude,
          _lastRecordedPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }

      // Record the position
      await _database!.insert('route_points', {
        'session_id': _currentSessionId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'altitude': position.altitude,
        'accuracy': position.accuracy,
        'bearing': position.heading,
        'speed': position.speed,
        'timestamp': position.timestamp.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch,
        'distance_from_previous': distanceFromPrevious,
      });

      _lastRecordedPosition = position;
      print('📍 Route point recorded: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}');
    } catch (e) {
      print('❌ Error recording position: $e');
    }
  }

  /// Record checkpoint reached
  Future<void> recordCheckpointReached({
    required int checkpointId,
    required String checkpointName,
    required double latitude,
    required double longitude,
    required int pointsEarned,
    int? timeToReach,
  }) async {
    if (!_isTracking || _currentSessionId == null) return;

    try {
      await _database!.insert('checkpoints_reached', {
        'session_id': _currentSessionId,
        'checkpoint_id': checkpointId,
        'checkpoint_name': checkpointName,
        'reached_at': DateTime.now().millisecondsSinceEpoch,
        'latitude': latitude,
        'longitude': longitude,
        'points_earned': pointsEarned,
        'time_to_reach': timeToReach,
      });

      print('🎯 Checkpoint recorded: $checkpointName (+$pointsEarned points)');
    } catch (e) {
      print('❌ Error recording checkpoint: $e');
    }
  }

  /// Calculate total distance for current session
  Future<void> _calculateSessionTotalDistance() async {
    if (_currentSessionId == null) return;

    try {
      final points = await _database!.query(
        'route_points',
        where: 'session_id = ?',
        whereArgs: [_currentSessionId],
        orderBy: 'timestamp ASC',
      );

      double totalDistance = 0.0;
      for (int i = 1; i < points.length; i++) {
        totalDistance += points[i]['distance_from_previous'] as double;
      }

      await _database!.update(
        'route_sessions',
        {'total_distance': totalDistance},
        where: 'id = ?',
        whereArgs: [_currentSessionId],
      );

      print('📏 Total distance calculated: ${_locationService.formatDistance(totalDistance)}');
    } catch (e) {
      print('❌ Error calculating total distance: $e');
    }
  }

  /// Get current session statistics
  Future<RouteSessionStats?> getCurrentSessionStats() async {
    if (!_isTracking || _currentSessionId == null) return null;

    try {
      final sessionData = await _database!.query(
        'route_sessions',
        where: 'id = ?',
        whereArgs: [_currentSessionId],
      );

      if (sessionData.isEmpty) return null;

      final pointsCount = Sqflite.firstIntValue(await _database!.rawQuery(
        'SELECT COUNT(*) FROM route_points WHERE session_id = ?',
        [_currentSessionId],
      )) ?? 0;

      final checkpointsCount = Sqflite.firstIntValue(await _database!.rawQuery(
        'SELECT COUNT(*) FROM checkpoints_reached WHERE session_id = ?',
        [_currentSessionId],
      )) ?? 0;

      final session = sessionData.first;
      final startTime = DateTime.fromMillisecondsSinceEpoch(session['start_time'] as int);
      final duration = DateTime.now().difference(startTime);

      return RouteSessionStats(
        sessionId: _currentSessionId!,
        playerName: session['player_name'] as String,
        startTime: startTime,
        duration: duration,
        pointsRecorded: pointsCount,
        checkpointsReached: checkpointsCount,
        totalDistance: session['total_distance'] as double? ?? 0.0,
        isActive: _isTracking,
      );
    } catch (e) {
      print('❌ Error getting session stats: $e');
      return null;
    }
  }

  /// Get all route sessions
  Future<List<RouteSession>> getAllRouteSessions() async {
    await initialize();
    
    try {
      final sessions = await _database!.query(
        'route_sessions',
        orderBy: 'start_time DESC',
      );

      return sessions.map((session) => RouteSession.fromMap(session)).toList();
    } catch (e) {
      print('❌ Error getting route sessions: $e');
      return [];
    }
  }

  /// Get route points for a session
  Future<List<RoutePoint>> getRoutePoints(String sessionId) async {
    await initialize();
    
    try {
      final points = await _database!.query(
        'route_points',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC',
      );

      return points.map((point) => RoutePoint.fromMap(point)).toList();
    } catch (e) {
      print('❌ Error getting route points: $e');
      return [];
    }
  }

  /// Export session data as JSON
  Future<String?> exportSessionAsJson(String sessionId) async {
    try {
      final session = await _database!.query(
        'route_sessions',
        where: 'id = ?',
        whereArgs: [sessionId],
      );

      if (session.isEmpty) return null;

      final points = await getRoutePoints(sessionId);
      final checkpoints = await _database!.query(
        'checkpoints_reached',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );

      final exportData = {
        'session': session.first,
        'route_points': points.map((p) => p.toMap()).toList(),
        'checkpoints_reached': checkpoints,
        'export_timestamp': DateTime.now().toIso8601String(),
      };

      return jsonEncode(exportData);
    } catch (e) {
      print('❌ Error exporting session: $e');
      return null;
    }
  }

  /// Get tracking status
  bool get isTracking => _isTracking;
  String? get currentSessionId => _currentSessionId;
  int get trackingInterval => _trackingIntervalSeconds;
  double get minimumDistance => _minimumDistanceMeters;

  /// Dispose resources
  Future<void> dispose() async {
    await stopTracking();
    await _database?.close();
    _database = null;
  }
}

/// Route session data model
class RouteSession {
  final String id;
  final String playerName;
  final String playerToken;
  final int gameId;
  final String? checkpointTarget;
  final DateTime startTime;
  final DateTime? endTime;
  final double totalDistance;
  final int totalPoints;
  final String status;

  RouteSession({
    required this.id,
    required this.playerName,
    required this.playerToken,
    required this.gameId,
    this.checkpointTarget,
    required this.startTime,
    this.endTime,
    required this.totalDistance,
    required this.totalPoints,
    required this.status,
  });

  factory RouteSession.fromMap(Map<String, dynamic> map) {
    return RouteSession(
      id: map['id'],
      playerName: map['player_name'],
      playerToken: map['player_token'],
      gameId: map['game_id'],
      checkpointTarget: map['checkpoint_target'],
      startTime: DateTime.fromMillisecondsSinceEpoch(map['start_time']),
      endTime: map['end_time'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['end_time'])
          : null,
      totalDistance: map['total_distance'] ?? 0.0,
      totalPoints: map['total_points'] ?? 0,
      status: map['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'player_name': playerName,
      'player_token': playerToken,
      'game_id': gameId,
      'checkpoint_target': checkpointTarget,
      'start_time': startTime.millisecondsSinceEpoch,
      'end_time': endTime?.millisecondsSinceEpoch,
      'total_distance': totalDistance,
      'total_points': totalPoints,
      'status': status,
    };
  }
}

/// Route point data model
class RoutePoint {
  final int? id;
  final String sessionId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? bearing;
  final double? speed;
  final DateTime timestamp;
  final double distanceFromPrevious;

  RoutePoint({
    this.id,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.bearing,
    this.speed,
    required this.timestamp,
    required this.distanceFromPrevious,
  });

  factory RoutePoint.fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      id: map['id'],
      sessionId: map['session_id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      altitude: map['altitude'],
      accuracy: map['accuracy'],
      bearing: map['bearing'],
      speed: map['speed'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      distanceFromPrevious: map['distance_from_previous'] ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'accuracy': accuracy,
      'bearing': bearing,
      'speed': speed,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'distance_from_previous': distanceFromPrevious,
    };
  }
}

/// Current session statistics
class RouteSessionStats {
  final String sessionId;
  final String playerName;
  final DateTime startTime;
  final Duration duration;
  final int pointsRecorded;
  final int checkpointsReached;
  final double totalDistance;
  final bool isActive;

  RouteSessionStats({
    required this.sessionId,
    required this.playerName,
    required this.startTime,
    required this.duration,
    required this.pointsRecorded,
    required this.checkpointsReached,
    required this.totalDistance,
    required this.isActive,
  });
}