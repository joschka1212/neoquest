// File: lib/models/game_models.dart
// 20250710 1716 V1.0 REAL Game Data Models based on actual API response




class GamePackage {
  final Game game;
  final List<Checkpoint> checkpoints;
  final List<Puzzle> puzzles;
  final GameIntro intro;
  final DownloadInfo downloadInfo;

  GamePackage({
    required this.game,
    required this.checkpoints,
    required this.puzzles,
    required this.intro,
    required this.downloadInfo,
  });

  factory GamePackage.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 GamePackage.fromJson input: ${json.keys}');
      
      // Debug the 'game' field
      if (json['game'] == null) {
        print('❌ "game" field is null in JSON');
        print('📊 Available fields: ${json.keys.toList()}');
        throw Exception('Missing "game" field in GamePackage JSON');
      }
      
      print('✅ "game" field found: ${json['game']}');
      
      // Debug the 'checkpoints' field  
      if (json['checkpoints'] == null) {
        print('❌ "checkpoints" field is null in JSON');
        print('📊 Available fields: ${json.keys.toList()}');
        throw Exception('Missing "checkpoints" field in GamePackage JSON');
      }
      
      print('✅ "checkpoints" field found: ${json['checkpoints'].length} items');
      
      return GamePackage(
        game: Game.fromJson(json['game']),
        checkpoints: (json['checkpoints'] as List)
            .map((checkpoint) => Checkpoint.fromJson(checkpoint))
            .toList(),
        
        // ADD MISSING REQUIRED PARAMETERS:
        puzzles: json['puzzles'] != null 
            ? (json['puzzles'] as List)
                .map((puzzle) => Puzzle.fromJson(puzzle))
                .toList()
            : [], // Empty list if no puzzles
        
        intro: json['intro'] != null 
            ? GameIntro.fromJson(json['intro'])
            : GameIntro(files: []), // Default empty intro
        
        downloadInfo: json['download_info'] != null 
            ? DownloadInfo.fromJson(json['download_info'])
            : DownloadInfo(
                timestamp: DateTime.now().toIso8601String(),
                totalPuzzles: 0,
                totalCheckpoints: json['checkpoints']?.length ?? 0,
                mediaBaseUrl: '',
              ), // Default download info
      );
    } catch (e) {
      print('❌ GamePackage.fromJson error: $e');
      print('📊 JSON structure: $json');
      rethrow;
    }
  }
}

// ----------------------------------------------------------

class Game {
  final int id;
  final String name;
  final String description;
  final String gameType;
  final String complexityLevel;
  final GameConfig gameConfig;
  final String? startAudioPath;
  final String mediaBaseUrl;

  Game({
    required this.id,
    required this.name,
    required this.description,
    required this.gameType,
    required this.complexityLevel,
    required this.gameConfig,
    this.startAudioPath,
    required this.mediaBaseUrl,
  });

  factory Game.fromJson(Map<String, dynamic> json) {
    return Game(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      gameType: json['game_type'],
      complexityLevel: json['complexity_level'],
      gameConfig: GameConfig.fromJson(json['game_config']),
      startAudioPath: json['start_audio_path'],
      mediaBaseUrl: json['media_base_url'],
    );
  }
}

class GameConfig {
  final ScoringConfig scoring;
  final FeaturesConfig features;
  final TimeLimitsConfig timeLimits;

  GameConfig({
    required this.scoring,
    required this.features,
    required this.timeLimits,
  });

  factory GameConfig.fromJson(Map<String, dynamic> json) {
    return GameConfig(
      scoring: ScoringConfig.fromJson(json['scoring']),
      features: FeaturesConfig.fromJson(json['features']),
      timeLimits: TimeLimitsConfig.fromJson(json['time_limits']),
    );
  }
}

class ScoringConfig {
  final bool timeBonus;
  final int basePoints;
  final int completionBonus;
  final int timePenaltyPerMinute;

  ScoringConfig({
    required this.timeBonus,
    required this.basePoints,
    required this.completionBonus,
    required this.timePenaltyPerMinute,
  });

  factory ScoringConfig.fromJson(Map<String, dynamic> json) {
    return ScoringConfig(
      timeBonus: json['time_bonus'],
      basePoints: json['base_points'],
      completionBonus: json['completion_bonus'],
      timePenaltyPerMinute: json['time_penalty_per_minute'],
    );
  }
}

class FeaturesConfig {
  final bool hasHints;
  final bool hasPuzzles;
  final bool hasCheckpoints;
  final bool hintsCostPoints;
  final bool puzzlesUnlockHints;
  final bool locationBasedTriggers;

  FeaturesConfig({
    required this.hasHints,
    required this.hasPuzzles,
    required this.hasCheckpoints,
    required this.hintsCostPoints,
    required this.puzzlesUnlockHints,
    required this.locationBasedTriggers,
  });

  factory FeaturesConfig.fromJson(Map<String, dynamic> json) {
    return FeaturesConfig(
      hasHints: json['has_hints'],
      hasPuzzles: json['has_puzzles'],
      hasCheckpoints: json['has_checkpoints'],
      hintsCostPoints: json['hints_cost_points'],
      puzzlesUnlockHints: json['puzzles_unlock_hints'],
      locationBasedTriggers: json['location_based_triggers'],
    );
  }
}

class TimeLimitsConfig {
  final int maxGameDuration;

  TimeLimitsConfig({required this.maxGameDuration});

  factory TimeLimitsConfig.fromJson(Map<String, dynamic> json) {
    return TimeLimitsConfig(
      maxGameDuration: json['max_game_duration'],
    );
  }
}

class Checkpoint {
  final int id;
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final int checkpointOrder;
  final String checkpointType;
  final int radius;
  final String qrCodeContent;
  final bool isRequired;
  final int minStayDuration;
  final CheckpointConfig checkpointConfig;
  final List<String> mediaFiles;

  Checkpoint({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.checkpointOrder,
    required this.checkpointType,
    required this.radius,
    required this.qrCodeContent,
    required this.isRequired,
    required this.minStayDuration,
    required this.checkpointConfig,
    required this.mediaFiles,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      latitude: double.parse(json['latitude']),
      longitude: double.parse(json['longitude']),
      checkpointOrder: json['checkpoint_order'],
      checkpointType: json['checkpoint_type'],
      radius: json['radius'],
      qrCodeContent: json['qr_code_content'],
      isRequired: json['is_required'],
      minStayDuration: json['min_stay_duration'],
      checkpointConfig: CheckpointConfig.fromJson(json['checkpoint_config']),
      mediaFiles: List<String>.from(json['media_files']),
    );
  }
}

class CheckpointConfig {
  final List<String> mediaFiles;
  final int pointBonus;
  final String? welcomeMessage;
  final String? photoInstructions;
  final String? safetyWarning;
  final String? completionMessage;
  final int minStayDuration;
  final bool? photoRequired;
  final bool? victoryPhotoRequired;
  final bool? celebration;

  CheckpointConfig({
    required this.mediaFiles,
    required this.pointBonus,
    this.welcomeMessage,
    this.photoInstructions,
    this.safetyWarning,
    this.completionMessage,
    required this.minStayDuration,
    this.photoRequired,
    this.victoryPhotoRequired,
    this.celebration,
  });

  factory CheckpointConfig.fromJson(Map<String, dynamic> json) {
    return CheckpointConfig(
      mediaFiles: List<String>.from(json['media_files']),
      pointBonus: json['point_bonus'],
      welcomeMessage: json['welcome_message'],
      photoInstructions: json['photo_instructions'],
      safetyWarning: json['safety_warning'],
      completionMessage: json['completion_message'],
      minStayDuration: json['min_stay_duration'],
      photoRequired: json['photo_required'],
      victoryPhotoRequired: json['victory_photo_required'],
      celebration: json['celebration'],
    );
  }
}

class Puzzle {
  // Puzzles array is empty in our data, but keeping structure for future
  final int id;
  final String question;
  final String answer;

  Puzzle({
    required this.id,
    required this.question,
    required this.answer,
  });

  factory Puzzle.fromJson(Map<String, dynamic> json) {
    return Puzzle(
      id: json['id'],
      question: json['question'],
      answer: json['answer'],
    );
  }
}

class GameIntro {
  final List<String> files;

  GameIntro({required this.files});

  factory GameIntro.fromJson(Map<String, dynamic> json) {
    return GameIntro(
      files: List<String>.from(json['files']),
    );
  }
}

class DownloadInfo {
  final String timestamp;
  final int totalPuzzles;
  final int totalCheckpoints;
  final String mediaBaseUrl;

  DownloadInfo({
    required this.timestamp,
    required this.totalPuzzles,
    required this.totalCheckpoints,
    required this.mediaBaseUrl,
  });

  factory DownloadInfo.fromJson(Map<String, dynamic> json) {
    return DownloadInfo(
      timestamp: json['timestamp'],
      totalPuzzles: json['total_puzzles'],
      totalCheckpoints: json['total_checkpoints'],
      mediaBaseUrl: json['media_base_url'],
    );
  }
}

// Game Summary for Map Display
class GameSummary {
  final String name;
  final String description;
  final int totalCheckpoints;
  final String gameType;
  final List<CheckpointSummary> route;

  GameSummary({
    required this.name,
    required this.description,
    required this.totalCheckpoints,
    required this.gameType,
    required this.route,
  });

  factory GameSummary.fromGamePackage(GamePackage package) {
    return GameSummary(
      name: package.game.name,
      description: package.game.description,
      totalCheckpoints: package.checkpoints.length,
      gameType: package.game.gameType,
      route: package.checkpoints
          .map((cp) => CheckpointSummary(
                name: cp.name,
                latitude: cp.latitude,
                longitude: cp.longitude,
                type: cp.checkpointType,
                order: cp.checkpointOrder,
              ))
          .toList(),
    );
  }
}

class CheckpointSummary {
  final String name;
  final double latitude;
  final double longitude;
  final String type;
  final int order;

  CheckpointSummary({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.order,
  });
}