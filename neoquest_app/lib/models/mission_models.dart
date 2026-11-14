// lib/models/mission_models.dart
// Data models for Mission Upload System
// 20250712 10:46 V1.0: File created

import 'dart:math';

// ===============================================
// ROUTE UPLOAD MODELS
// ===============================================

class RouteUploadData {
  final String playerToken;
  final String sessionId;
  final List<RoutePoint> routePoints;
  final List<CheckpointReached> checkpointsReached;
  final double totalDistance;
  final int totalTime; // seconds

  RouteUploadData({
    required this.playerToken,
    required this.sessionId,
    required this.routePoints,
    required this.checkpointsReached,
    required this.totalDistance,
    required this.totalTime,
  });
}

class RoutePoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double? accuracy;
  final double? altitude;

  RoutePoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.accuracy,
    this.altitude,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'lng': lng,
    'timestamp': timestamp.toIso8601String(),
    'accuracy': accuracy,
    'altitude': altitude,
  };

  factory RoutePoint.fromJson(Map<String, dynamic> json) => RoutePoint(
    lat: json['lat'].toDouble(),
    lng: json['lng'].toDouble(),
    timestamp: DateTime.parse(json['timestamp']),
    accuracy: json['accuracy']?.toDouble(),
    altitude: json['altitude']?.toDouble(),
  );
}

class CheckpointReached {
  final int checkpointId;
  final String checkpointName;
  final DateTime reachedAt;
  final int pointsEarned;
  final int timeToReach; // seconds
  final double latitude;
  final double longitude;

  CheckpointReached({
    required this.checkpointId,
    required this.checkpointName,
    required this.reachedAt,
    required this.pointsEarned,
    required this.timeToReach,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'checkpointId': checkpointId,
    'checkpointName': checkpointName,
    'reachedAt': reachedAt.toIso8601String(),
    'pointsEarned': pointsEarned,
    'timeToReach': timeToReach,
    'latitude': latitude,
    'longitude': longitude,
  };

  factory CheckpointReached.fromJson(Map<String, dynamic> json) => CheckpointReached(
    checkpointId: json['checkpointId'],
    checkpointName: json['checkpointName'],
    reachedAt: DateTime.parse(json['reachedAt']),
    pointsEarned: json['pointsEarned'],
    timeToReach: json['timeToReach'],
    latitude: json['latitude'].toDouble(),
    longitude: json['longitude'].toDouble(),
  );
}

class RouteUploadResult {
  final bool success;
  final String? uploadId;
  final String? message;
  final String? error;
  final RouteStats? routeStats;

  RouteUploadResult({
    required this.success,
    this.uploadId,
    this.message,
    this.error,
    this.routeStats,
  });
}

class RouteStats {
  final double totalDistance;
  final int totalTime;
  final int pointCount;

  RouteStats({
    required this.totalDistance,
    required this.totalTime,
    required this.pointCount,
  });

  factory RouteStats.fromJson(Map<String, dynamic> json) => RouteStats(
    totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
    totalTime: json['totalTime'] ?? 0,
    pointCount: json['pointCount'] ?? 0,
  );
}

// ===============================================
// PHOTO UPLOAD MODELS
// ===============================================

class PhotoUploadData {
  final String playerToken;
  final int checkpointId;
  final String checkpointName;
  final String filePath;
  final DateTime capturedAt;
  final double? latitude;
  final double? longitude;

  PhotoUploadData({
    required this.playerToken,
    required this.checkpointId,
    required this.checkpointName,
    required this.filePath,
    required this.capturedAt,
    this.latitude,
    this.longitude,
  });
}

class PhotoUploadResult {
  final bool success;
  final int photosUploaded;
  final String? message;
  final String? error;
  final List<PhotoUploadResultItem> uploadResults;

  PhotoUploadResult({
    required this.success,
    this.photosUploaded = 0,
    this.message,
    this.error,
    this.uploadResults = const [],
  });
}

class PhotoUploadResultItem {
  final String uploadId;
  final String filename;
  final String originalName;
  final int size;
  final int? checkpointId;
  final String? checkpointName;

  PhotoUploadResultItem({
    required this.uploadId,
    required this.filename,
    required this.originalName,
    required this.size,
    this.checkpointId,
    this.checkpointName,
  });

  factory PhotoUploadResultItem.fromJson(Map<String, dynamic> json) => PhotoUploadResultItem(
    uploadId: json['uploadId'],
    filename: json['filename'],
    originalName: json['originalName'],
    size: json['size'],
    checkpointId: json['checkpointId'],
    checkpointName: json['checkpointName'],
  );
}

// ===============================================
// MISSION COMPLETION MODELS
// ===============================================

class MissionCompletionData {
  final String playerToken;
  final List<CheckpointReached> checkpointsReached;
  final int finalScore;
  final DateTime completionTime;
  final double? totalDistance;
  final int? totalTime;

  MissionCompletionData({
    required this.playerToken,
    required this.checkpointsReached,
    required this.finalScore,
    required this.completionTime,
    this.totalDistance,
    this.totalTime,
  });
}

class MissionCompletionResult {
  final bool success;
  final String? message;
  final String? error;
  final int? finalScore;
  final DateTime? completionTime;
  final int? checkpointsReached;

  MissionCompletionResult({
    required this.success,
    this.message,
    this.error,
    this.finalScore,
    this.completionTime,
    this.checkpointsReached,
  });
}

// ===============================================
// UPLOAD STATUS MODELS
// ===============================================

class UploadStatus {
  final PlayerInfo player;
  final MissionStatus missionStatus;
  final UploadProgress uploadProgress;
  final List<UploadRecord> uploads;
  final MissionResults missionResults;
  final UploadTiming uploadTiming;

  UploadStatus({
    required this.player,
    required this.missionStatus,
    required this.uploadProgress,
    required this.uploads,
    required this.missionResults,
    required this.uploadTiming,
  });

  factory UploadStatus.fromJson(Map<String, dynamic> json) => UploadStatus(
    player: PlayerInfo.fromJson(json['player']),
    missionStatus: MissionStatus.fromJson(json['missionStatus']),
    uploadProgress: UploadProgress.fromJson(json['uploadProgress']),
    uploads: (json['uploads'] as List<dynamic>)
        .map((u) => UploadRecord.fromJson(u))
        .toList(),
    missionResults: MissionResults.fromJson(json['missionResults']),
    uploadTiming: UploadTiming.fromJson(json['uploadTiming']),
  );
}

class PlayerInfo {
  final int id;
  final String name;
  final String token;
  final String? email;
  final int? gameId;
  final String? gameTitle;

  PlayerInfo({
    required this.id,
    required this.name,
    required this.token,
    this.email,
    this.gameId,
    this.gameTitle,
  });

  factory PlayerInfo.fromJson(Map<String, dynamic> json) => PlayerInfo(
    id: json['id'],
    name: json['name'],
    token: json['token'],
    email: json['email'],
    gameId: json['gameId'],
    gameTitle: json['gameTitle'],
  );
}

class MissionStatus {
  final bool completed;
  final String uploadStatus;
  final int finalScore;
  final int totalScore;
  final DateTime? completionTime;
  final int completionTimeSeconds;

  MissionStatus({
    required this.completed,
    required this.uploadStatus,
    required this.finalScore,
    required this.totalScore,
    this.completionTime,
    required this.completionTimeSeconds,
  });

  factory MissionStatus.fromJson(Map<String, dynamic> json) => MissionStatus(
    completed: json['completed'] ?? false,
    uploadStatus: json['uploadStatus'] ?? 'pending',
    finalScore: json['finalScore'] ?? 0,
    totalScore: json['totalScore'] ?? 0,
    completionTime: json['completionTime'] != null 
        ? DateTime.parse(json['completionTime']) 
        : null,
    completionTimeSeconds: json['completionTimeSeconds'] ?? 0,
  );
}

class UploadProgress {
  final bool route;
  final int photos;
  final bool complete;

  UploadProgress({
    required this.route,
    required this.photos,
    required this.complete,
  });

  factory UploadProgress.fromJson(Map<String, dynamic> json) => UploadProgress(
    route: json['route'] ?? false,
    photos: json['photos'] ?? 0,
    complete: json['complete'] ?? false,
  );

  double get completionPercentage {
    int completed = 0;
    int total = 3;
    
    if (route) completed++;
    if (photos > 0) completed++;
    if (complete) completed++;
    
    return completed / total;
  }

  String get statusText {
    if (complete) return 'Upload Complete';
    if (route && photos > 0) return 'Finalizing...';
    if (route) return 'Photos Pending';
    if (photos > 0) return 'Route Pending';
    return 'Upload Pending';
  }
}

class UploadRecord {
  final String uploadType;
  final String uploadStatus;
  final DateTime? uploadedAt;
  final int? fileSize;
  final Map<String, dynamic>? metadata;

  UploadRecord({
    required this.uploadType,
    required this.uploadStatus,
    this.uploadedAt,
    this.fileSize,
    this.metadata,
  });

  factory UploadRecord.fromJson(Map<String, dynamic> json) => UploadRecord(
    uploadType: json['upload_type'],
    uploadStatus: json['upload_status'],
    uploadedAt: json['uploaded_at'] != null 
        ? DateTime.parse(json['uploaded_at']) 
        : null,
    fileSize: json['file_size'],
    metadata: json['metadata'],
  );
}

class MissionResults {
  final double totalDistance;
  final int totalTime;
  final DateTime? resultCompletionTime;

  MissionResults({
    required this.totalDistance,
    required this.totalTime,
    this.resultCompletionTime,
  });

  factory MissionResults.fromJson(Map<String, dynamic> json) => MissionResults(
    totalDistance: json['totalDistance']?.toDouble() ?? 0.0,
    totalTime: json['totalTime'] ?? 0,
    resultCompletionTime: json['resultCompletionTime'] != null 
        ? DateTime.parse(json['resultCompletionTime']) 
        : null,
  );
}

class UploadTiming {
  final DateTime? lastUpload;
  final DateTime? firstUpload;

  UploadTiming({
    this.lastUpload,
    this.firstUpload,
  });

  factory UploadTiming.fromJson(Map<String, dynamic> json) => UploadTiming(
    lastUpload: json['lastUpload'] != null 
        ? DateTime.parse(json['lastUpload']) 
        : null,
    firstUpload: json['firstUpload'] != null 
        ? DateTime.parse(json['firstUpload']) 
        : null,
  );
}

// ===============================================
// LEADERBOARD MODELS
// ===============================================

class LeaderboardResult {
  final int? gameId;
  final List<LeaderboardEntry> entries;
  final LeaderboardStatistics statistics;
  final DateTime generatedAt;

  LeaderboardResult({
    this.gameId,
    required this.entries,
    required this.statistics,
    required this.generatedAt,
  });

  factory LeaderboardResult.fromJson(Map<String, dynamic> json) => LeaderboardResult(
    gameId: json['gameId'] != null ? int.tryParse(json['gameId']) : null,
    entries: (json['leaderboard'] as List<dynamic>)
        .map((e) => LeaderboardEntry.fromJson(e))
        .toList(),
    statistics: LeaderboardStatistics.fromJson(json['statistics']),
    generatedAt: DateTime.parse(json['generatedAt']),
  );
}

class LeaderboardEntry {
  final String playerName;
  final String playerToken;
  final int finalScore;
  final int completionTimeSeconds;
  final DateTime? completionTime;
  final double? totalDistance;
  final int gameId;
  final int rank;

  LeaderboardEntry({
    required this.playerName,
    required this.playerToken,
    required this.finalScore,
    required this.completionTimeSeconds,
    this.completionTime,
    this.totalDistance,
    required this.gameId,
    required this.rank,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    playerName: json['player_name'],
    playerToken: json['player_token'],
    finalScore: json['final_mission_score'],
    completionTimeSeconds: json['completion_time_seconds'],
    completionTime: json['mission_completion_timestamp'] != null 
        ? DateTime.parse(json['mission_completion_timestamp']) 
        : null,
    totalDistance: json['total_distance_meters']?.toDouble(),
    gameId: json['game_id'],
    rank: json['rank'],
  );

  String get formattedTime {
    final minutes = completionTimeSeconds ~/ 60;
    final seconds = completionTimeSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  String get formattedDistance {
    if (totalDistance == null) return 'N/A';
    if (totalDistance! < 1000) {
      return '${totalDistance!.toStringAsFixed(0)}m';
    } else {
      return '${(totalDistance! / 1000).toStringAsFixed(1)}km';
    }
  }
}

class LeaderboardStatistics {
  final int totalPlayers;
  final double averageScore;
  final int entriesShown;

  LeaderboardStatistics({
    required this.totalPlayers,
    required this.averageScore,
    required this.entriesShown,
  });

  factory LeaderboardStatistics.fromJson(Map<String, dynamic> json) => LeaderboardStatistics(
    totalPlayers: json['totalPlayers'],
    averageScore: json['averageScore']?.toDouble() ?? 0.0,
    entriesShown: json['entriesShown'],
  );
}

// ===============================================
// COMPLETE MISSION UPLOAD MODELS
// ===============================================

class CompleteMissionData {
  final String playerToken;
  final RouteUploadData? routeData;
  final List<PhotoUploadData> photos;
  final MissionCompletionData? completionData;

  CompleteMissionData({
    required this.playerToken,
    this.routeData,
    this.photos = const [],
    this.completionData,
  });
}

class CompleteMissionUploadResult {
  bool success = false;
  bool routeUploaded = false;
  int photosUploaded = 0;
  bool missionCompleted = false;
  int? finalScore;
  List<String> errors = [];

  CompleteMissionUploadResult();

  double get completionPercentage {
    int completed = 0;
    int total = 3;
    
    if (routeUploaded) completed++;
    if (photosUploaded > 0) completed++;
    if (missionCompleted) completed++;
    
    return completed / total;
  }

  String get statusText {
    if (success && missionCompleted) return 'Mission Upload Complete';
    if (routeUploaded && photosUploaded > 0) return 'Finalizing Mission...';
    if (routeUploaded) return 'Uploading Photos...';
    if (photosUploaded > 0) return 'Uploading Route...';
    return 'Starting Upload...';
  }

  Map<String, dynamic> toJson() => {
    'success': success,
    'routeUploaded': routeUploaded,
    'photosUploaded': photosUploaded,
    'missionCompleted': missionCompleted,
    'finalScore': finalScore,
    'errors': errors,
    'completionPercentage': completionPercentage,
    'statusText': statusText,
  };
}

// ===============================================
// UPLOAD PROGRESS TRACKING
// ===============================================

enum UploadStep {
  pending,
  uploadingRoute,
  uploadingPhotos,
  completingMission,
  complete,
  failed
}

class UploadProgressTracker {
  final String playerToken;
  UploadStep currentStep;
  String? currentStepDescription;
  double progress; // 0.0 to 1.0
  DateTime startTime;
  DateTime? endTime;
  List<String> errors;
  Map<String, dynamic> metadata;

  UploadProgressTracker({
    required this.playerToken,
    this.currentStep = UploadStep.pending,
    this.currentStepDescription,
    this.progress = 0.0,
    DateTime? startTime,
    this.endTime,
    this.errors = const [],
    this.metadata = const {},
  }) : startTime = startTime ?? DateTime.now();

  void updateProgress(UploadStep step, double progress, {String? description}) {
    currentStep = step;
    this.progress = progress;
    currentStepDescription = description;
    
    if (step == UploadStep.complete || step == UploadStep.failed) {
      endTime = DateTime.now();
    }
  }

  void addError(String error) {
    errors = [...errors, error];
    if (currentStep != UploadStep.failed) {
      currentStep = UploadStep.failed;
      endTime = DateTime.now();
    }
  }

  Duration? get duration {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  bool get isComplete => currentStep == UploadStep.complete;
  bool get isFailed => currentStep == UploadStep.failed;
  bool get isInProgress => !isComplete && !isFailed;

  String get stepName {
    switch (currentStep) {
      case UploadStep.pending:
        return 'Pending';
      case UploadStep.uploadingRoute:
        return 'Uploading Route';
      case UploadStep.uploadingPhotos:
        return 'Uploading Photos';
      case UploadStep.completingMission:
        return 'Completing Mission';
      case UploadStep.complete:
        return 'Complete';
      case UploadStep.failed:
        return 'Failed';
    }
  }

  Map<String, dynamic> toJson() => {
    'playerToken': playerToken,
    'currentStep': stepName,
    'currentStepDescription': currentStepDescription,
    'progress': progress,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'duration': duration?.inSeconds,
    'errors': errors,
    'metadata': metadata,
    'isComplete': isComplete,
    'isFailed': isFailed,
    'isInProgress': isInProgress,
  };

  factory UploadProgressTracker.fromJson(Map<String, dynamic> json) {
    return UploadProgressTracker(
      playerToken: json['playerToken'],
      currentStep: _stepFromString(json['currentStep']),
      currentStepDescription: json['currentStepDescription'],
      progress: json['progress']?.toDouble() ?? 0.0,
      startTime: DateTime.parse(json['startTime']),
      endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
      errors: List<String>.from(json['errors'] ?? []),
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  static UploadStep _stepFromString(String step) {
    switch (step) {
      case 'Pending': return UploadStep.pending;
      case 'Uploading Route': return UploadStep.uploadingRoute;
      case 'Uploading Photos': return UploadStep.uploadingPhotos;
      case 'Completing Mission': return UploadStep.completingMission;
      case 'Complete': return UploadStep.complete;
      case 'Failed': return UploadStep.failed;
      default: return UploadStep.pending;
    }
  }
}

// ===============================================
// HELPER EXTENSIONS
// ===============================================

extension RoutePointList on List<RoutePoint> {
  double get totalDistance {
    if (length < 2) return 0.0;
    
    double total = 0.0;
    for (int i = 1; i < length; i++) {
      total += _calculateDistance(this[i-1], this[i]);
    }
    return total;
  }

  Duration get totalDuration {
    if (isEmpty) return Duration.zero;
    final start = first.timestamp;
    final end = last.timestamp;
    return end.difference(start);
  }

  static double _calculateDistance(RoutePoint point1, RoutePoint point2) {
    // Haversine formula for accurate distance calculation (in meters)
    const double earthRadius = 6371000; // meters
    final lat1Rad = point1.lat * (pi / 180);
    final lat2Rad = point2.lat * (pi / 180);
    final deltaLatRad = (point2.lat - point1.lat) * (pi / 180);
    final deltaLngRad = (point2.lng - point1.lng) * (pi / 180);

    final a = sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(deltaLngRad / 2) * sin(deltaLngRad / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }
}

extension CheckpointReachedList on List<CheckpointReached> {
  int get totalPoints => fold(0, (sum, checkpoint) => sum + checkpoint.pointsEarned);
  
  Duration get totalTime {
    if (isEmpty) return Duration.zero;
    return Duration(seconds: fold(0, (sum, checkpoint) => sum + checkpoint.timeToReach));
  }

  List<CheckpointReached> sortedByTime() {
    final sorted = List<CheckpointReached>.from(this);
    sorted.sort((a, b) => a.reachedAt.compareTo(b.reachedAt));
    return sorted;
  }
}

extension UploadStatusHelpers on UploadStatus {
  bool get hasAnyUploads => uploadProgress.route || uploadProgress.photos > 0 || uploadProgress.complete;
  
  bool get isFullyComplete => uploadProgress.route && uploadProgress.photos > 0 && uploadProgress.complete;
  
  String get overallStatus {
    if (isFullyComplete) return 'Complete';
    if (hasAnyUploads) return 'Partial';
    return 'Pending';
  }

  List<String> get missingUploads {
    final missing = <String>[];
    if (!uploadProgress.route) missing.add('Route data');
    if (uploadProgress.photos == 0) missing.add('Photos');
    if (!uploadProgress.complete) missing.add('Mission completion');
    return missing;
  }
}