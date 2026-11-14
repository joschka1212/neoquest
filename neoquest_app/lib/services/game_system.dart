// ===============================================
// Flutter Content-Session System
// Download → Play Offline → Upload Session
// ===============================================

// pubspec.yaml dependencies:
/*
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.8.3
  http: ^1.1.0
  geolocator: ^10.1.0
  permission_handler: ^11.0.1
  image_picker: ^1.0.4
  shared_preferences: ^2.2.2
  crypto: ^3.0.3
  uuid: ^4.1.0
  path_provider: ^2.1.1
*/

// ===============================================
// 1. DATABASE MODELS & SCHEMA
// ===============================================

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

// Game Content Model
class GameContent {
  final int gameId;
  final String name;
  final String description;
  final String complexityLevel;
  final Map<String, dynamic> gameConfig;
  final List<Checkpoint> checkpoints;
  final List<Puzzle> puzzles;
  final List<Hint> hints;
  final Map<String, dynamic> settings;
  final String contentVersion;
  final DateTime downloadedAt;
  
  GameContent({
    required this.gameId,
    required this.name,
    required this.description,
    required this.complexityLevel,
    required this.gameConfig,
    required this.checkpoints,
    required this.puzzles,
    required this.hints,
    required this.settings,
    required this.contentVersion,
    required this.downloadedAt,
  });
  
  factory GameContent.fromJson(Map<String, dynamic> json) {
    return GameContent(
      gameId: json['game']['id'],
      name: json['game']['name'],
      description: json['game']['description'],
      complexityLevel: json['game']['complexity_level'],
      gameConfig: json['game']['game_config'],
      checkpoints: (json['checkpoints'] as List)
          .map((cp) => Checkpoint.fromJson(cp))
          .toList(),
      puzzles: (json['puzzles'] as List)
          .map((p) => Puzzle.fromJson(p))
          .toList(),
      hints: (json['hints'] as List)
          .map((h) => Hint.fromJson(h))
          .toList(),
      settings: json['settings'],
      contentVersion: json['content_info']['content_version'],
      downloadedAt: DateTime.parse(json['content_info']['downloaded_at']),
    );
  }
}

// Checkpoint Model
class Checkpoint {
  final int id;
  final int checkpointOrder;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final int radius;
  final String checkpointType;
  final String? qrCodeContent;
  final bool isRequired;
  final int minStayDuration;
  final Map<String, dynamic> checkpointConfig;
  
  Checkpoint({
    required this.id,
    required this.checkpointOrder,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.checkpointType,
    this.qrCodeContent,
    required this.isRequired,
    required this.minStayDuration,
    required this.checkpointConfig,
  });
  
  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      id: json['id'],
      checkpointOrder: json['checkpoint_order'],
      name: json['name'],
      description: json['description'] ?? '',
      latitude: json['latitude'].toDouble(),
      longitude: json['longitude'].toDouble(),
      radius: json['radius'],
      checkpointType: json['checkpoint_type'],
      qrCodeContent: json['qr_code_content'],
      isRequired: json['is_required'],
      minStayDuration: json['min_stay_duration'] ?? 0,
      checkpointConfig: json['checkpoint_config'] ?? {},
    );
  }
}

// Puzzle Model  
class Puzzle {
  final String puzzleId;
  final int? checkpointId;
  final String title;
  final String question;
  final String puzzleType;
  final Map<String, dynamic> puzzleConfig;
  final int points;
  final int maxAttempts;
  final int? timeLimit;
  final String difficulty;
  
  Puzzle({
    required this.puzzleId,
    this.checkpointId,
    required this.title,
    required this.question,
    required this.puzzleType,
    required this.puzzleConfig,
    required this.points,
    required this.maxAttempts,
    this.timeLimit,
    required this.difficulty,
  });
  
  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      puzzleId: json['puzzle_id'],
      checkpointId: json['checkpoint_id'],
      title: json['title'],
      question: json['question'],
      puzzleType: json['puzzle_type'],
      puzzleConfig: json['puzzle_config'],
      points: json['points'],
      maxAttempts: json['max_attempts'],
      timeLimit: json['time_limit'],
      difficulty: json['difficulty'],
    );
  }
}

// Hint Model
class Hint {
  final String hintId;
  final String? puzzleId;
  final String title;
  final String hintText;
  final String? mediaFile;
  final int pointCost;
  final String unlockCondition;
  final Map<String, dynamic> unlockConfig;
  final int hintOrder;
  
  Hint({
    required this.hintId,
    this.puzzleId,
    required this.title,
    required this.hintText,
    this.mediaFile,
    required this.pointCost,
    required this.unlockCondition,
    required this.unlockConfig,
    required this.hintOrder,
  });
  
  factory Hint.fromJson(Map<String, dynamic> json) {
    return Hint(
      hintId: json['hint_id'],
      puzzleId: json['puzzle_id'],
      title: json['title'] ?? '',
      hintText: json['hint_text'],
      mediaFile: json['media_file'],
      pointCost: json['point_cost'],
      unlockCondition: json['unlock_condition'],
      unlockConfig: json['unlock_config'] ?? {},
      hintOrder: json['hint_order'],
    );
  }
}

// ===============================================
// 2. SQLITE DATABASE MANAGER
// ===============================================

class GameDatabase {
  static Database? _database;
  static const String dbName = 'neoquest_offline.db';
  static const int dbVersion = 1;
  
  static Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }
  
  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), dbName);
    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _createDatabase,
    );
  }
  
  static Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE game_content (
        game_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        complexity_level TEXT,
        game_config TEXT,
        settings TEXT,
        content_version TEXT,
        downloaded_at TEXT,
        expires_at TEXT
      )
    ''');
    
    await db.execute('''
      CREATE TABLE checkpoints (
        id INTEGER PRIMARY KEY,
        game_id INTEGER,
        checkpoint_order INTEGER,
        name TEXT NOT NULL,
        description TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius INTEGER,
        checkpoint_type TEXT,
        qr_code_content TEXT,
        is_required INTEGER,
        min_stay_duration INTEGER,
        checkpoint_config TEXT,
        FOREIGN KEY (game_id) REFERENCES game_content (game_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE puzzles (
        puzzle_id TEXT PRIMARY KEY,
        game_id INTEGER,
        checkpoint_id INTEGER,
        title TEXT NOT NULL,
        question TEXT NOT NULL,
        puzzle_type TEXT,
        puzzle_config TEXT,
        points INTEGER,
        max_attempts INTEGER,
        time_limit INTEGER,
        difficulty TEXT,
        FOREIGN KEY (game_id) REFERENCES game_content (game_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE hints (
        hint_id TEXT PRIMARY KEY,
        game_id INTEGER,
        puzzle_id TEXT,
        title TEXT,
        hint_text TEXT NOT NULL,
        media_file TEXT,
        point_cost INTEGER,
        unlock_condition TEXT,
        unlock_config TEXT,
        hint_order INTEGER,
        FOREIGN KEY (game_id) REFERENCES game_content (game_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE game_sessions (
        session_id TEXT PRIMARY KEY,
        game_id INTEGER,
        player_token TEXT,
        start_time TEXT,
        end_time TEXT,
        current_points INTEGER,
        game_state TEXT,
        session_status TEXT,
        created_at TEXT,
        FOREIGN KEY (game_id) REFERENCES game_content (game_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE gps_tracks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        altitude REAL,
        accuracy REAL,
        speed REAL,
        bearing REAL,
        timestamp TEXT,
        track_context TEXT,
        FOREIGN KEY (session_id) REFERENCES game_sessions (session_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE checkpoint_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        checkpoint_id INTEGER,
        arrival_time TEXT,
        departure_time TEXT,
        latitude REAL,
        longitude REAL,
        accuracy REAL,
        verification_method TEXT,
        verification_data TEXT,
        FOREIGN KEY (session_id) REFERENCES game_sessions (session_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE puzzle_attempts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        puzzle_id TEXT,
        attempt_number INTEGER,
        submitted_answer TEXT,
        is_correct INTEGER,
        points_earned INTEGER,
        time_taken INTEGER,
        attempted_at TEXT,
        attempt_context TEXT,
        FOREIGN KEY (session_id) REFERENCES game_sessions (session_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE hint_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        hint_id TEXT,
        points_cost INTEGER,
        used_at TEXT,
        usage_context TEXT,
        FOREIGN KEY (session_id) REFERENCES game_sessions (session_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE media_files (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT,
        file_path TEXT,
        original_filename TEXT,
        file_size INTEGER,
        mime_type TEXT,
        taken_at TEXT,
        media_metadata TEXT,
        FOREIGN KEY (session_id) REFERENCES game_sessions (session_id)
      )
    ''');
  }
  
  // Clear all data (for fresh downloads)
  static Future<void> clearGameData(int gameId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('media_files', where: 'session_id IN (SELECT session_id FROM game_sessions WHERE game_id = ?)', whereArgs: [gameId]);
      await txn.delete('hint_usage', where: 'session_id IN (SELECT session_id FROM game_sessions WHERE game_id = ?)', whereArgs: [gameId]);
      await txn.delete('puzzle_attempts', where: 'session_id IN (SELECT session_id FROM game_sessions WHERE game_id = ?)', whereArgs: [gameId]);
      await txn.delete('checkpoint_visits', where: 'session_id IN (SELECT session_id FROM game_sessions WHERE game_id = ?)', whereArgs: [gameId]);
      await txn.delete('gps_tracks', where: 'session_id IN (SELECT session_id FROM game_sessions WHERE game_id = ?)', whereArgs: [gameId]);
      await txn.delete('game_sessions', where: 'game_id = ?', whereArgs: [gameId]);
      await txn.delete('hints', where: 'game_id = ?', whereArgs: [gameId]);
      await txn.delete('puzzles', where: 'game_id = ?', whereArgs: [gameId]);
      await txn.delete('checkpoints', where: 'game_id = ?', whereArgs: [gameId]);
      await txn.delete('game_content', where: 'game_id = ?', whereArgs: [gameId]);
    });
  }
}

// ===============================================
// 3. CONTENT DOWNLOAD SERVICE
// ===============================================

class ContentDownloadService {
  static const String baseUrl = 'http://localhost:3000/api';
  
  static Future<GameContent> downloadGameContent(int gameId, String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/game/$gameId?token=$token'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          return GameContent.fromJson(data);
        } else {
          throw Exception('Server error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to download game content: $e');
    }
  }
  
  static Future<void> saveGameContent(GameContent content) async {
    final db = await GameDatabase.database;
    
    await db.transaction((txn) async {
      // Save game content
      await txn.insert('game_content', {
        'game_id': content.gameId,
        'name': content.name,
        'description': content.description,
        'complexity_level': content.complexityLevel,
        'game_config': jsonEncode(content.gameConfig),
        'settings': jsonEncode(content.settings),
        'content_version': content.contentVersion,
        'downloaded_at': content.downloadedAt.toIso8601String(),
        'expires_at': DateTime.now().add(Duration(hours: 24)).toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      
      // Save checkpoints
      for (final checkpoint in content.checkpoints) {
        await txn.insert('checkpoints', {
          'id': checkpoint.id,
          'game_id': content.gameId,
          'checkpoint_order': checkpoint.checkpointOrder,
          'name': checkpoint.name,
          'description': checkpoint.description,
          'latitude': checkpoint.latitude,
          'longitude': checkpoint.longitude,
          'radius': checkpoint.radius,
          'checkpoint_type': checkpoint.checkpointType,
          'qr_code_content': checkpoint.qrCodeContent,
          'is_required': checkpoint.isRequired ? 1 : 0,
          'min_stay_duration': checkpoint.minStayDuration,
          'checkpoint_config': jsonEncode(checkpoint.checkpointConfig),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      
      // Save puzzles
      for (final puzzle in content.puzzles) {
        await txn.insert('puzzles', {
          'puzzle_id': puzzle.puzzleId,
          'game_id': content.gameId,
          'checkpoint_id': puzzle.checkpointId,
          'title': puzzle.title,
          'question': puzzle.question,
          'puzzle_type': puzzle.puzzleType,
          'puzzle_config': jsonEncode(puzzle.puzzleConfig),
          'points': puzzle.points,
          'max_attempts': puzzle.maxAttempts,
          'time_limit': puzzle.timeLimit,
          'difficulty': puzzle.difficulty,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      
      // Save hints
      for (final hint in content.hints) {
        await txn.insert('hints', {
          'hint_id': hint.hintId,
          'game_id': content.gameId,
          'puzzle_id': hint.puzzleId,
          'title': hint.title,
          'hint_text': hint.hintText,
          'media_file': hint.mediaFile,
          'point_cost': hint.pointCost,
          'unlock_condition': hint.unlockCondition,
          'unlock_config': jsonEncode(hint.unlockConfig),
          'hint_order': hint.hintOrder,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
  
  static Future<GameContent?> getStoredGameContent(int gameId) async {
    final db = await GameDatabase.database;
    
    // Check if content exists and is not expired
    final gameResult = await db.query(
      'game_content',
      where: 'game_id = ? AND expires_at > ?',
      whereArgs: [gameId, DateTime.now().toIso8601String()],
    );
    
    if (gameResult.isEmpty) return null;
    
    final gameData = gameResult.first;
    
    // Load checkpoints
    final checkpointsResult = await db.query(
      'checkpoints',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'checkpoint_order',
    );
    
    // Load puzzles
    final puzzlesResult = await db.query(
      'puzzles',
      where: 'game_id = ?',
      whereArgs: [gameId],
    );
    
    // Load hints  
    final hintsResult = await db.query(
      'hints',
      where: 'game_id = ?',
      whereArgs: [gameId],
      orderBy: 'hint_order',
    );
    
    return GameContent(
      gameId: gameData['game_id'] as int,
      name: gameData['name'] as String,
      description: gameData['description'] as String,
      complexityLevel: gameData['complexity_level'] as String,
      gameConfig: jsonDecode(gameData['game_config'] as String),
      settings: jsonDecode(gameData['settings'] as String),
      contentVersion: gameData['content_version'] as String,
      downloadedAt: DateTime.parse(gameData['downloaded_at'] as String),
      checkpoints: checkpointsResult.map((cp) => Checkpoint(
        id: cp['id'] as int,
        checkpointOrder: cp['checkpoint_order'] as int,
        name: cp['name'] as String,
        description: cp['description'] as String,
        latitude: cp['latitude'] as double,
        longitude: cp['longitude'] as double,
        radius: cp['radius'] as int,
        checkpointType: cp['checkpoint_type'] as String,
        qrCodeContent: cp['qr_code_content'] as String?,
        isRequired: (cp['is_required'] as int) == 1,
        minStayDuration: cp['min_stay_duration'] as int,
        checkpointConfig: jsonDecode(cp['checkpoint_config'] as String),
      )).toList(),
      puzzles: puzzlesResult.map((p) => Puzzle(
        puzzleId: p['puzzle_id'] as String,
        checkpointId: p['checkpoint_id'] as int?,
        title: p['title'] as String,
        question: p['question'] as String,
        puzzleType: p['puzzle_type'] as String,
        puzzleConfig: jsonDecode(p['puzzle_config'] as String),
        points: p['points'] as int,
        maxAttempts: p['max_attempts'] as int,
        timeLimit: p['time_limit'] as int?,
        difficulty: p['difficulty'] as String,
      )).toList(),
      hints: hintsResult.map((h) => Hint(
        hintId: h['hint_id'] as String,
        puzzleId: h['puzzle_id'] as String?,
        title: h['title'] as String,
        hintText: h['hint_text'] as String,
        mediaFile: h['media_file'] as String?,
        pointCost: h['point_cost'] as int,
        unlockCondition: h['unlock_condition'] as String,
        unlockConfig: jsonDecode(h['unlock_config'] as String),
        hintOrder: h['hint_order'] as int,
      )).toList(),
    );
  }
}

// ===============================================
// 4. OFFLINE GAME ENGINE
// ===============================================

class OfflineGameEngine {
  String? _currentSessionId;
  GameContent? _gameContent;
  Map<String, dynamic> _gameState = {};
  Timer? _gpsTimer;
  
  // Initialize game session
  Future<String> startGameSession(GameContent gameContent, String playerToken) async {
    _gameContent = gameContent;
    _currentSessionId = Uuid().v4();
    
    _gameState = {
      'current_points': gameContent.gameConfig['scoring']?['base_points'] ?? 1000,
      'visited_checkpoints': <int>[],
      'solved_puzzles': <String>[],
      'used_hints': <String>[],
      'start_time': DateTime.now().toIso8601String(),
      'checkpoint_arrival_times': <String, String>{},
      'photos_taken': <String>[],
    };
    
    final db = await GameDatabase.database;
    await db.insert('game_sessions', {
      'session_id': _currentSessionId,
      'game_id': gameContent.gameId,
      'player_token': playerToken,
      'start_time': _gameState['start_time'],
      'current_points': _gameState['current_points'],
      'game_state': jsonEncode(_gameState),
      'session_status': 'started',
      'created_at': DateTime.now().toIso8601String(),
    });
    
    // Start GPS tracking
    await _startGpsTracking();
    
    return _currentSessionId!;
  }
  
  // GPS Tracking
  Future<void> _startGpsTracking() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled');
    }
    
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    _gpsTimer = Timer.periodic(Duration(seconds: 30), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        await _recordGpsPoint(position);
      } catch (e) {
        print('GPS tracking error: $e');
      }
    });
  }
  
  Future<void> _recordGpsPoint(Position position) async {
    if (_currentSessionId == null) return;
    
    final db = await GameDatabase.database;
    await db.insert('gps_tracks', {
      'session_id': _currentSessionId,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'altitude': position.altitude,
      'accuracy': position.accuracy,
      'speed': position.speed,
      'bearing': position.heading,
      'timestamp': DateTime.now().toIso8601String(),
      'track_context': jsonEncode({
        'battery_level': 'unknown', // Would need battery_plus package
        'network_status': 'offline',
      }),
    });
  }
  
  // Checkpoint Detection
  Future<List<Checkpoint>> getNearbyCheckpoints(Position currentPosition, {double radiusKm = 1.0}) async {
    if (_gameContent == null) return [];
    
    List<Checkpoint> nearbyCheckpoints = [];
    
    for (final checkpoint in _gameContent!.checkpoints) {
      final distance = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        checkpoint.latitude,
        checkpoint.longitude,
      );
      
      if (distance <= radiusKm * 1000) { // Convert km to meters
        nearbyCheckpoints.add(checkpoint);
      }
    }
    
    // Sort by distance
    nearbyCheckpoints.sort((a, b) {
      final distanceA = Geolocator.distanceBetween(
        currentPosition.latitude, currentPosition.longitude,
        a.latitude, a.longitude,
      );
      final distanceB = Geolocator.distanceBetween(
        currentPosition.latitude, currentPosition.longitude,
        b.latitude, b.longitude,
      );
      return distanceA.compareTo(distanceB);
    });
    
    return nearbyCheckpoints;
  }
  
  // Visit Checkpoint
  Future<bool> visitCheckpoint(Checkpoint checkpoint, Position currentPosition, {String? qrCodeContent}) async {
    if (_currentSessionId == null || _gameContent == null) return false;
    
    // Check distance
    final distance = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      checkpoint.latitude,
      checkpoint.longitude,
    );
    
    bool canVisit = distance <= checkpoint.radius;
    
    // QR Code verification
    String verificationMethod = 'gps';
    if (qrCodeContent != null && qrCodeContent == checkpoint.qrCodeContent) {
      verificationMethod = 'qr_code';
      canVisit = true; // QR code overrides distance
    }
    
    if (!canVisit) return false;
    
    // Check if already visited
    List<int> visitedCheckpoints = List<int>.from(_gameState['visited_checkpoints']);
    if (visitedCheckpoints.contains(checkpoint.id)) return false;
    
    // Record visit
    final db = await GameDatabase.database;
    final now = DateTime.now().toIso8601String();
    
    await db.insert('checkpoint_visits', {
      'session_id': _currentSessionId,
      'checkpoint_id': checkpoint.id,
      'arrival_time': now,
      'latitude': currentPosition.latitude,
      'longitude': currentPosition.longitude,
      'accuracy': currentPosition.accuracy,
      'verification_method': verificationMethod,
      'verification_data': jsonEncode({
        'qr_content': qrCodeContent,
        'distance': distance,
      }),
    });
    
    // Update game state
    visitedCheckpoints.add(checkpoint.id);
    _gameState['visited_checkpoints'] = visitedCheckpoints;
    _gameState['checkpoint_arrival_times'][checkpoint.id.toString()] = now;
    
    // Add points
    final pointBonus = checkpoint.checkpointConfig['point_bonus'] ?? 0;
    _gameState['current_points'] = (_gameState['current_points'] as int) + pointBonus;
    
    await _updateGameState();
    
    return true;
  }
  
  // Puzzle Solving (Level 4-5)
  Future<bool> solvePuzzle(String puzzleId, dynamic answer) async {
    if (_currentSessionId == null || _gameContent == null) return false;
    
    final puzzle = _gameContent!.puzzles.firstWhere(
      (p) => p.puzzleId == puzzleId,
      orElse: () => throw Exception('Puzzle not found'),
    );
    
    // Validate answer based on puzzle type
    bool isCorrect = _validatePuzzleAnswer(puzzle, answer);
    
    // Record attempt
    final db = await GameDatabase.database;
    await db.insert('puzzle_attempts', {
      'session_id': _currentSessionId,
      'puzzle_id': puzzleId,
      'attempt_number': 1, // Would need to track attempts
      'submitted_answer': jsonEncode(answer),
      'is_correct': isCorrect ? 1 : 0,
      'points_earned': isCorrect ? puzzle.points : 0,
      'time_taken': 0, // Would need to track time
      'attempted_at': DateTime.now().toIso8601String(),
      'attempt_context': jsonEncode({}),
    });
    
    if (isCorrect) {
      List<String> solvedPuzzles = List<String>.from(_gameState['solved_puzzles']);
      solvedPuzzles.add(puzzleId);
      _gameState['solved_puzzles'] = solvedPuzzles;
      _gameState['current_points'] = (_gameState['current_points'] as int) + puzzle.points;
      await _updateGameState();
    }
    
    return isCorrect;
  }
  
  bool _validatePuzzleAnswer(Puzzle puzzle, dynamic answer) {
    final config = puzzle.puzzleConfig;
    
    switch (puzzle.puzzleType) {
      case 'boolean':
        return answer == config['correct_answer'];
      case 'integer':
        final correct = config['correct_answer'] as int;
        final tolerance = config['tolerance'] ?? 0;
        final submitted = int.tryParse(answer.toString()) ?? 0;
        return (submitted - correct).abs() <= tolerance;
      case 'text':
        final correct = config['correct_answer'] as String;
        final submitted = answer.toString();
        final normalization = config['normalization'] ?? {};
        
        String normalizedCorrect = correct;
        String normalizedSubmitted = submitted;
        
        if (normalization['case'] == 'lower') {
          normalizedCorrect = normalizedCorrect.toLowerCase();
          normalizedSubmitted = normalizedSubmitted.toLowerCase();
        } else if (normalization['case'] == 'upper') {
          normalizedCorrect = normalizedCorrect.toUpperCase();
          normalizedSubmitted = normalizedSubmitted.toUpperCase();
        }
        
        if (normalization['strip_spaces'] == true) {
          normalizedCorrect = normalizedCorrect.replaceAll(' ', '');
          normalizedSubmitted = normalizedSubmitted.replaceAll(' ', '');
        }
        
        return normalizedCorrect == normalizedSubmitted;
      case 'multiple_choice':
        return answer == config['correct_answer'];
      default:
        return false;
    }
  }
  
  // Use Hint (Level 2-5)
  Future<bool> useHint(String hintId) async {
    if (_currentSessionId == null || _gameContent == null) return false;
    
    final hint = _gameContent!.hints.firstWhere(
      (h) => h.hintId == hintId,
      orElse: () => throw Exception('Hint not found'),
    );
    
    // Check if player has enough points
    final currentPoints = _gameState['current_points'] as int;
    if (currentPoints < hint.pointCost) return false;
    
    // Check unlock conditions
    if (!_isHintUnlocked(hint)) return false;
    
    // Record hint usage
    final db = await GameDatabase.database;
    await db.insert('hint_usage', {
      'session_id': _currentSessionId,
      'hint_id': hintId,
      'points_cost': hint.pointCost,
      'used_at': DateTime.now().toIso8601String(),
      'usage_context': jsonEncode({}),
    });
    
    // Update game state
    List<String> usedHints = List<String>.from(_gameState['used_hints']);
    usedHints.add(hintId);
    _gameState['used_hints'] = usedHints;
    _gameState['current_points'] = currentPoints - hint.pointCost;
    
    await _updateGameState();
    return true;
  }
  
  bool _isHintUnlocked(Hint hint) {
    switch (hint.unlockCondition) {
      case 'immediate':
        return true;
      case 'puzzle_solved':
        final requiredPuzzles = hint.unlockConfig['required_puzzles'] as List?;
        if (requiredPuzzles == null) return true;
        final solvedPuzzles = _gameState['solved_puzzles'] as List;
        return requiredPuzzles.every((puzzle) => solvedPuzzles.contains(puzzle));
      default:
        return true;
    }
  }
  
  // Take Photo
  Future<String?> takePhoto(String type, {int? checkpointId, String? puzzleId}) async {
    if (_currentSessionId == null) return null;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      
      if (image == null) return null;
      
      // Get current position for metadata
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition();
      } catch (e) {
        print('Could not get position for photo: $e');
      }
      
      // Record in database
      final db = await GameDatabase.database;
      await db.insert('media_files', {
        'session_id': _currentSessionId,
        'file_path': image.path,
        'original_filename': image.name,
        'file_size': await File(image.path).length(),
        'mime_type': 'image/jpeg',
        'taken_at': DateTime.now().toIso8601String(),
        'media_metadata': jsonEncode({
          'type': type,
          'checkpoint_id': checkpointId,
          'puzzle_id': puzzleId,
          'latitude': position?.latitude,
          'longitude': position?.longitude,
          'accuracy': position?.accuracy,
        }),
      });
      
      // Update game state
      List<String> photos = List<String>.from(_gameState['photos_taken']);
      photos.add(image.path);
      _gameState['photos_taken'] = photos;
      await _updateGameState();
      
      return image.path;
    } catch (e) {
      print('Error taking photo: $e');
      return null;
    }
  }
  
  // Complete Game Session
  Future<Map<String, dynamic>> completeGameSession() async {
    if (_currentSessionId == null || _gameContent == null) {
      throw Exception('No active game session');
    }
    
    // Stop GPS tracking
    _gpsTimer?.cancel();
    
    // Calculate final score
    final basePoints = _gameState['current_points'] as int;
    final gameConfig = _gameContent!.gameConfig;
    final scoring = gameConfig['scoring'] ?? {};
    
    int finalScore = basePoints;
    
    // Time bonus/penalty calculation
    if (scoring['time_bonus'] == true) {
      final startTime = DateTime.parse(_gameState['start_time']);
      final endTime = DateTime.now();
      final elapsedMinutes = endTime.difference(startTime).inMinutes;
      final timePenalty = (scoring['time_penalty_per_minute'] ?? 0) * elapsedMinutes;
      finalScore -= timePenalty as int;
    }
    
    // Completion bonus
    if (scoring['completion_bonus'] != null) {
      finalScore += scoring['completion_bonus'] as int;
    }
    
    // Ensure minimum score
    finalScore = math.max(finalScore, 0);
    
    // Update session in database
    final db = await GameDatabase.database;
    final endTime = DateTime.now().toIso8601String();
    
    _gameState['end_time'] = endTime;
    _gameState['final_score'] = finalScore;
    _gameState['completed'] = true;
    
    await db.update(
      'game_sessions',
      {
        'end_time': endTime,
        'current_points': finalScore,
        'game_state': jsonEncode(_gameState),
        'session_status': 'completed',
      },
      where: 'session_id = ?',
      whereArgs: [_currentSessionId],
    );
    
    final sessionData = {
      'session_id': _currentSessionId,
      'final_score': finalScore,
      'total_time_seconds': DateTime.parse(endTime).difference(DateTime.parse(_gameState['start_time'])).inSeconds,
      'checkpoints_visited': (_gameState['visited_checkpoints'] as List).length,
      'puzzles_solved': (_gameState['solved_puzzles'] as List).length,
      'hints_used': (_gameState['used_hints'] as List).length,
      'photos_taken': (_gameState['photos_taken'] as List).length,
    };
    
    _currentSessionId = null;
    _gameContent = null;
    _gameState = {};
    
    return sessionData;
  }
  
  Future<void> _updateGameState() async {
    if (_currentSessionId == null) return;
    
    final db = await GameDatabase.database;
    await db.update(
      'game_sessions',
      {
        'current_points': _gameState['current_points'],
        'game_state': jsonEncode(_gameState),
      },
      where: 'session_id = ?',
      whereArgs: [_currentSessionId],
    );
  }
  
  // Get current game state
  Map<String, dynamic> getCurrentGameState() {
    return Map<String, dynamic>.from(_gameState);
  }
  
  // Stop GPS tracking
  void stopGpsTracking() {
    _gpsTimer?.cancel();
  }
}

// ===============================================
// 5. SESSION UPLOAD SERVICE
// ===============================================

class SessionUploadService {
  static const String baseUrl = 'http://localhost:3000/api';
  
  static Future<Map<String, dynamic>> uploadSession(String sessionId, String playerToken) async {
    final db = await GameDatabase.database;
    
    // Get session data
    final sessionResult = await db.query(
      'game_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    
    if (sessionResult.isEmpty) {
      throw Exception('Session not found');
    }
    
    final sessionData = sessionResult.first;
    final gameState = jsonDecode(sessionData['game_state'] as String);
    
    // Get GPS tracks
    final gpsResult = await db.query(
      'gps_tracks',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp',
    );
    
    // Get checkpoint visits
    final checkpointResult = await db.query(
      'checkpoint_visits',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'arrival_time',
    );
    
    // Get puzzle attempts
    final puzzleResult = await db.query(
      'puzzle_attempts',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'attempted_at',
    );
    
    // Get hint usage
    final hintResult = await db.query(
      'hint_usage',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'used_at',
    );
    
    // Get media files
    final mediaResult = await db.query(
      'media_files',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
    
    // Prepare upload data
    final uploadData = {
      'token': playerToken,
      'game_id': sessionData['game_id'].toString(),
      'session_data': jsonEncode({
        'session_id': sessionId,
        'start_time': sessionData['start_time'],
        'end_time': sessionData['end_time'],
        'session_status': sessionData['session_status'],
        'game_state': gameState,
      }),
      'gps_track': jsonEncode(gpsResult.map((row) => {
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'altitude': row['altitude'],
        'accuracy': row['accuracy'],
        'speed': row['speed'],
        'bearing': row['bearing'],
        'timestamp': row['timestamp'],
        'context': jsonDecode(row['track_context'] as String? ?? '{}'),
      }).toList()),
      'checkpoint_visits': jsonEncode(checkpointResult.map((row) => {
        'checkpoint_id': row['checkpoint_id'],
        'arrival_time': row['arrival_time'],
        'departure_time': row['departure_time'],
        'latitude': row['latitude'],
        'longitude': row['longitude'],
        'accuracy': row['accuracy'],
        'verification_method': row['verification_method'],
        'verification_data': jsonDecode(row['verification_data'] as String? ?? '{}'),
      }).toList()),
      'puzzle_attempts': jsonEncode(puzzleResult.map((row) => {
        'puzzle_id': row['puzzle_id'],
        'attempt_number': row['attempt_number'],
        'submitted_answer': jsonDecode(row['submitted_answer'] as String),
        'is_correct': (row['is_correct'] as int) == 1,
        'points_earned': row['points_earned'],
        'time_taken': row['time_taken'],
        'attempted_at': row['attempted_at'],
        'context': jsonDecode(row['attempt_context'] as String? ?? '{}'),
      }).toList()),
      'hint_usage': jsonEncode(hintResult.map((row) => {
        'hint_id': row['hint_id'],
        'points_cost': row['points_cost'],
        'used_at': row['used_at'],
        'context': jsonDecode(row['usage_context'] as String? ?? '{}'),
      }).toList()),
      'final_score': sessionData['current_points'].toString(),
      'session_metadata': jsonEncode({
        'app_version': '1.0.0',
        'device_platform': Platform.operatingSystem,
        'upload_timestamp': DateTime.now().toIso8601String(),
        'total_gps_points': gpsResult.length,
        'total_media_files': mediaResult.length,
      }),
    };
    
    try {
      // Create multipart request for file uploads
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/session/upload'),
      );
      
      // Add form data
      uploadData.forEach((key, value) {
        request.fields[key] = value;
      });
      
      // Add media files
      for (final media in mediaResult) {
        final filePath = media['file_path'] as String;
        if (await File(filePath).exists()) {
          request.files.add(await http.MultipartFile.fromPath(
            'media_files',
            filePath,
            filename: media['original_filename'] as String?,
          ));
        }
      }
      
      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success']) {
          // Mark session as uploaded
          await db.update(
            'game_sessions',
            {'session_status': 'uploaded'},
            where: 'session_id = ?',
            whereArgs: [sessionId],
          );
          
          return data['upload_summary'];
        } else {
          throw Exception('Server error: ${data['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload session: $e');
    }
  }
  
  static Future<List<Map<String, dynamic>>> getPendingUploads() async {
    final db = await GameDatabase.database;
    
    final result = await db.query(
      'game_sessions',
      where: 'session_status = ?',
      whereArgs: ['completed'],
      orderBy: 'created_at DESC',
    );
    
    return result.map((row) => {
      'session_id': row['session_id'],
      'game_id': row['game_id'],
      'start_time': row['start_time'],
      'end_time': row['end_time'],
      'final_score': row['current_points'],
      'created_at': row['created_at'],
    }).toList();
  }
}

// ===============================================
// 6. GAME MANAGER (MAIN CONTROLLER)
// ===============================================

class GameManager {
  static final GameManager _instance = GameManager._internal();
  factory GameManager() => _instance;
  GameManager._internal();
  
  OfflineGameEngine? _gameEngine;
  GameContent? _currentGameContent;
  
  // Download and setup game
  Future<void> initializeGame(int gameId, String playerToken) async {
    try {
      // Try to load from local storage first
      _currentGameContent = await ContentDownloadService.getStoredGameContent(gameId);
      
      // If not found or expired, download fresh content
      if (_currentGameContent == null) {
        print('Downloading fresh game content...');
        _currentGameContent = await ContentDownloadService.downloadGameContent(gameId, playerToken);
        await ContentDownloadService.saveGameContent(_currentGameContent!);
        print('Game content downloaded and saved locally');
      } else {
        print('Using cached game content');
      }
      
      _gameEngine = OfflineGameEngine();
      
    } catch (e) {
      throw Exception('Failed to initialize game: $e');
    }
  }
  
  // Start game session
  Future<String> startGame(String playerToken) async {
    if (_currentGameContent == null || _gameEngine == null) {
      throw Exception('Game not initialized. Call initializeGame first.');
    }
    
    return await _gameEngine!.startGameSession(_currentGameContent!, playerToken);
  }
  
  // Get nearby checkpoints
  Future<List<Checkpoint>> getNearbyCheckpoints({double radiusKm = 1.0}) async {
    if (_gameEngine == null) return [];
    
    final position = await Geolocator.getCurrentPosition();
    return await _gameEngine!.getNearbyCheckpoints(position, radiusKm: radiusKm);
  }
  
  // Visit checkpoint
  Future<bool> visitCheckpoint(int checkpointId, {String? qrCodeContent}) async {
    if (_gameEngine == null || _currentGameContent == null) return false;
    
    final checkpoint = _currentGameContent!.checkpoints.firstWhere(
      (cp) => cp.id == checkpointId,
      orElse: () => throw Exception('Checkpoint not found'),
    );
    
    final position = await Geolocator.getCurrentPosition();
    return await _gameEngine!.visitCheckpoint(checkpoint, position, qrCodeContent: qrCodeContent);
  }
  
  // Solve puzzle
  Future<bool> solvePuzzle(String puzzleId, dynamic answer) async {
    if (_gameEngine == null) return false;
    return await _gameEngine!.solvePuzzle(puzzleId, answer);
  }
  
  // Use hint
  Future<bool> useHint(String hintId) async {
    if (_gameEngine == null) return false;
    return await _gameEngine!.useHint(hintId);
  }
  
  // Take photo
  Future<String?> takePhoto(String type, {int? checkpointId, String? puzzleId}) async {
    if (_gameEngine == null) return null;
    return await _gameEngine!.takePhoto(type, checkpointId: checkpointId, puzzleId: puzzleId);
  }
  
  // Complete game
  Future<Map<String, dynamic>> completeGame() async {
    if (_gameEngine == null) {
      throw Exception('No active game session');
    }
    return await _gameEngine!.completeGameSession();
  }
  
  // Upload session
  Future<Map<String, dynamic>> uploadSession(String sessionId, String playerToken) async {
    return await SessionUploadService.uploadSession(sessionId, playerToken);
  }
  
  // Get current game state
  Map<String, dynamic>? getCurrentGameState() {
    return _gameEngine?.getCurrentGameState();
  }
  
  // Get game content
  GameContent? getGameContent() {
    return _currentGameContent;
  }
  
  // Clean up
  void dispose() {
    _gameEngine?.stopGpsTracking();
    _gameEngine = null;
    _currentGameContent = null;
  }
}

// ===============================================
// 7. USAGE EXAMPLE
// ===============================================

/*
// Example usage in your Flutter app:

class GameScreen extends StatefulWidget {
  final String playerToken;
  final int gameId;
  
  const GameScreen({Key? key, required this.playerToken, required this.gameId}) : super(key: key);
  
  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameManager _gameManager = GameManager();
  String? _currentSessionId;
  bool _isLoading = true;
  String _status = 'Initializing...';
  
  @override
  void initState() {
    super.initState();
    _initializeGame();
  }
  
  Future<void> _initializeGame() async {
    try {
      setState(() => _status = 'Downloading game content...');
      await _gameManager.initializeGame(widget.gameId, widget.playerToken);
      
      setState(() => _status = 'Starting game session...');
      _currentSessionId = await _gameManager.startGame(widget.playerToken);
      
      setState(() {
        _isLoading = false;
        _status = 'Game ready! Find your first checkpoint.';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = 'Error: $e';
      });
    }
  }
  
  Future<void> _visitNearestCheckpoint() async {
    try {
      final nearbyCheckpoints = await _gameManager.getNearbyCheckpoints(radiusKm: 0.5);
      if (nearbyCheckpoints.isNotEmpty) {
        final success = await _gameManager.visitCheckpoint(nearbyCheckpoints.first.id);
        setState(() => _status = success ? 'Checkpoint visited!' : 'Too far from checkpoint');
      } else {
        setState(() => _status = 'No checkpoints nearby');
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }
  
  Future<void> _completeGame() async {
    try {
      final result = await _gameManager.completeGame();
      final uploadResult = await _gameManager.uploadSession(_currentSessionId!, widget.playerToken);
      
      setState(() => _status = 'Game completed! Score: ${result['final_score']}');
      
      // Navigate to results screen
      // Navigator.push(context, MaterialPageRoute(builder: (context) => ResultsScreen(result: result)));
      
    } catch (e) {
      setState(() => _status = 'Error completing game: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('NeoQuest')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(_status),
            ],
          ),
        ),
      );
    }
    
    final gameState = _gameManager.getCurrentGameState();
    final gameContent = _gameManager.getGameContent();
    
    return Scaffold(
      appBar: AppBar(
        title: Text(gameContent?.name ?? 'NeoQuest'),
        actions: [
          IconButton(
            icon: Icon(Icons.camera_alt),
            onPressed: () => _gameManager.takePhoto('checkpoint'),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Game Progress', style: Theme.of(context).textTheme.headlineSmall),
                    SizedBox(height: 8),
                    Text('Points: ${gameState?['current_points'] ?? 0}'),
                    Text('Checkpoints: ${gameState?['visited_checkpoints']?.length ?? 0}/${gameContent?.checkpoints.length ?? 0}'),
                    Text('Puzzles Solved: ${gameState?['solved_puzzles']?.length ?? 0}'),
                    Text('Hints Used: ${gameState?['used_hints']?.length ?? 0}'),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Text('Status: $_status'),
            SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    ElevatedButton(
                      onPressed: _visitNearestCheckpoint,
                      child: Text('Visit Nearest Checkpoint'),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _completeGame,
                      child: Text('Complete Game'),
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
  
  @override
  void dispose() {
    _gameManager.dispose();
    super.dispose();
  }
}
*/