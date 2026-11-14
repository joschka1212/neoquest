// lib/services/mission_upload_service.dart
// Mission Upload Service for NeoQuest Flutter App
// Connects to the Mission Upload Server APIs
// 20250713 16:30 V3.0: Complete integration with existing upload APIs

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import '../models/mission_models.dart';
import '../services/photo_capture_service.dart';

class MissionUploadService {
  static const String TAG = 'MissionUploadService';
  
  late String _baseUrl;
  bool _isInitialized = false;
  
  // Progress tracking
  final StreamController<UploadProgressTracker> _progressController = 
      StreamController<UploadProgressTracker>.broadcast();
  Stream<UploadProgressTracker> get progressStream => _progressController.stream;
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    print('$TAG: Initializing upload service...');
    
    try {
      // Versuche verschiedene lokale IPs
      _baseUrl = await _discoverServerUrl();
      print('$TAG: Using base URL: $_baseUrl');
      
      _isInitialized = true;
      print('✅ $TAG: Upload service initialized successfully');
      
    } catch (e) {
      print('❌ $TAG: Failed to initialize: $e');
      rethrow;
    }
  }

  Future<String> _discoverServerUrl() async {
    // Liste möglicher Server-URLs
    final possibleUrls = [
      'http://192.168.1.100:3000',
      'http://192.168.0.100:3000', 
      'http://10.0.0.100:3000',
      'http://127.0.0.1:3000',
    ];
    
    for (final url in possibleUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/health'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 2));
        
        if (response.statusCode == 200) {
          print('✅ Found server at: $url');
          return url;
        }
      } catch (e) {
        // Ignore and try next URL
      }
    }
    
    throw Exception('No server found. Please check network connection.');
  }

  void dispose() {
    _progressController.close();
  }

  // ===============================================
  // CONNECTION TESTING
  // ===============================================
  
  Future<bool> testConnection() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
      
    } catch (e) {
      print('❌ $TAG: Connection test failed: $e');
      return false;
    }
  }

  // ===============================================
  // COMPLETE MISSION UPLOAD
  // ===============================================
  
  Future<CompleteMissionUploadResult> uploadMissionFromCompass({
    required String playerToken,
    required String playerName,
    required int gameId,
    required DateTime startTime,
    required DateTime endTime,
    required int finalScore,
    required Duration totalTime,
    required Map<String, dynamic>? routeData,
    required List<Map<String, dynamic>> checkpointCompletions,  // ← Geändert zu Map
    required List<CheckpointPhoto> capturedPhotos,
    Map<String, dynamic>? gameMetadata,
  }) async {
    final result = CompleteMissionUploadResult();
    final tracker = UploadProgressTracker(
      playerToken: playerToken,
      currentStep: UploadStep.pending,
      currentStepDescription: 'Starting mission upload...',
    );
    
    _progressController.add(tracker);
    
    try {
      // Step 1: Upload GPS data (20% progress)
      tracker.updateProgress(
        UploadStep.uploadingRoute, 
        0.2, 
        description: 'Uploading GPS tracking data...'
      );
      _progressController.add(tracker);
      
      if (routeData != null && routeData['routePoints'] != null) {
        final gpsSuccess = await _uploadGPSTrack(playerToken, routeData['routePoints']);
        result.routeUploaded = gpsSuccess;
        
        if (!gpsSuccess) {
          result.errors.add('GPS track upload failed');
        }
      } else {
        result.routeUploaded = true; // No GPS data to upload
      }
      
      // Step 2: Upload photos (20-60% progress)
      if (capturedPhotos.isNotEmpty) {
        tracker.updateProgress(
          UploadStep.uploadingPhotos, 
          0.4, 
          description: 'Uploading ${capturedPhotos.length} photos...'
        );
        _progressController.add(tracker);
        
        final uploadedCount = await _uploadPhotos(
          playerToken,
          capturedPhotos,
          onProgress: (progress) {
            final totalProgress = 0.4 + (progress * 0.2); // 40-60%
            tracker.updateProgress(
              UploadStep.uploadingPhotos, 
              totalProgress, 
              description: 'Uploading photos... ${(progress * 100).toInt()}%'
            );
            _progressController.add(tracker);
          },
        );
        
        result.photosUploaded = uploadedCount;
        
        if (uploadedCount < capturedPhotos.length) {
          result.errors.add('Some photos failed to upload ($uploadedCount of ${capturedPhotos.length})');
        }
      }
      
      // Step 3: Upload complete game results (60-100% progress)
      tracker.updateProgress(
        UploadStep.completingMission, 
        0.8, 
        description: 'Finalizing mission results...'
      );
      _progressController.add(tracker);
      
      final resultsSuccess = await _uploadCompleteResults(
        playerToken,
        gameId,
        finalScore,
        totalTime,
        startTime,
        endTime,
        checkpointCompletions,
        routeData,
        gameMetadata,
      );
      
      result.missionCompleted = resultsSuccess;
      result.finalScore = finalScore;
      
      if (!resultsSuccess) {
        result.errors.add('Mission completion upload failed');
      }
      
      // Determine overall success
      result.success = result.routeUploaded && 
                      (capturedPhotos.isEmpty || result.photosUploaded > 0) &&
                      result.missionCompleted;
      
      // Final progress update
      if (result.success) {
        tracker.updateProgress(
          UploadStep.complete, 
          1.0, 
          description: 'Mission upload completed successfully!'
        );
      } else {
        tracker.updateProgress(
          UploadStep.failed, 
          0.0, 
          description: 'Mission upload failed'
        );
        for (final error in result.errors) {
          tracker.addError(error);
        }
      }
      
      _progressController.add(tracker);
      return result;
      
    } catch (e) {
      print('❌ $TAG: Complete mission upload failed: $e');
      result.success = false;
      result.errors.add('Upload failed: $e');
      
      tracker.updateProgress(
        UploadStep.failed, 
        0.0, 
        description: 'Upload error: $e'
      );
      tracker.addError(e.toString());
      _progressController.add(tracker);
      
      return result;
    }
  }

  // ===============================================
  // INTERNAL UPLOAD METHODS
  // ===============================================
  
  Future<bool> _uploadGPSTrack(String playerToken, List<dynamic> routePoints) async {
    try {
      print('$TAG: Uploading ${routePoints.length} GPS points');
      
      final gpsData = routePoints.map((point) => {
        'latitude': point['lat'] ?? point['latitude'],
        'longitude': point['lng'] ?? point['longitude'], 
        'timestamp': point['timestamp'],
        'accuracy': point['accuracy'],
        'altitude': point['altitude'],
      }).toList();
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/upload/gps-track'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $playerToken',
        },
        body: json.encode({
          'gps_data': gpsData,
        }),
      ).timeout(const Duration(seconds: 60));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ $TAG: GPS track uploaded: ${data['message']}');
        return true;
      } else {
        print('❌ $TAG: GPS upload failed: ${response.statusCode} - ${response.body}');
        return false;
      }
      
    } catch (e) {
      print('❌ $TAG: GPS upload error: $e');
      return false;
    }
  }
  
  Future<int> _uploadPhotos(
    String playerToken, 
    List<CheckpointPhoto> photos, {
    Function(double progress)? onProgress,
  }) async {
    if (photos.isEmpty) return 0;
    
    print('$TAG: Uploading ${photos.length} photos...');
    int uploadedCount = 0;
    
    try {
      for (int i = 0; i < photos.length; i++) {
        final photo = photos[i];
        onProgress?.call(i / photos.length);
        
        final success = await _uploadSinglePhoto(playerToken, photo);
        if (success) {
          uploadedCount++;
        }
      }
      
      onProgress?.call(1.0);
      print('✅ $TAG: Uploaded $uploadedCount of ${photos.length} photos');
      return uploadedCount;
      
    } catch (e) {
      print('❌ $TAG: Photo upload error: $e');
      return uploadedCount;
    }
  }

  Future<bool> _uploadSinglePhoto(String playerToken, CheckpointPhoto photo) async {
    try {
      final file = File(photo.filePath);
      if (!await file.exists()) {
        print('❌ $TAG: Photo file not found: ${photo.filePath}');
        return false;
      }
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/upload/photo'),
      );
      
      request.headers['Authorization'] = 'Bearer $playerToken';
      
      request.fields['checkpoint_id'] = photo.checkpointId.toString();
          request.fields['photo_type'] = 'checkpoint';
      
      final multipartFile = await http.MultipartFile.fromPath(
        'photo',
        photo.filePath,
        filename: path.basename(photo.filePath),
      );
      request.files.add(multipartFile);
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
      );
      
      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final data = json.decode(responseBody);
        print('✅ $TAG: Photo uploaded: ${data['message']}');
        return true;
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        print('❌ $TAG: Photo upload failed: ${streamedResponse.statusCode} - $errorBody');
        return false;
      }
      
    } catch (e) {
      print('❌ $TAG: Single photo upload error: $e');
      return false;
    }
  }
  
  Future<bool> _uploadCompleteResults(
    String playerToken,
    int gameId,
    int finalScore,
    Duration totalTime,
    DateTime startTime,
    DateTime endTime,
    List<Map<String, dynamic>> checkpointCompletions,  // ← Geändert
    Map<String, dynamic>? routeData,
    Map<String, dynamic>? gameMetadata,
  ) async {
    try {
      print('$TAG: Uploading complete game results');
      
      // Prepare game results data according to existing server format
      final gameResults = {
        'game_id': gameId,
        'final_score': finalScore,
        'completion_time': totalTime.inSeconds,
        'game_completed': true,
        'start_time': startTime.toIso8601String(),
        'end_time': endTime.toIso8601String(),
        'checkpoints_reached': checkpointCompletions.map((c) => {
          'checkpoint_id': c['checkpointId'],           // ← Map-Zugriff
          'checkpoint_name': c['checkpointName'],       // ← Map-Zugriff
          'reached_at': c['completionTime'].toIso8601String(), // ← Map-Zugriff
          'points_earned': c['pointsEarned'],           // ← Map-Zugriff
          'time_to_reach': c['timeToReach'],            // ← Map-Zugriff
          'latitude': c['latitude'],                    // ← Map-Zugriff
          'longitude': c['longitude'],                  // ← Map-Zugriff
        }).toList(),
      };
      
      // Include GPS data if available
      if (routeData != null && routeData['routePoints'] != null) {
        gameResults['gps_track'] = routeData['routePoints'];
      }
      
      // Add metadata
      if (gameMetadata != null) {
        gameResults['metadata'] = gameMetadata;
      }
      
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/api/upload/results'),
      );
      
      request.headers['Authorization'] = 'Bearer $playerToken';
      request.fields['game_results'] = json.encode(gameResults);
      request.fields['completion_time'] = totalTime.inSeconds.toString();
      request.fields['game_completed'] = 'true';
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 120),
      );
      
      if (streamedResponse.statusCode == 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        final data = json.decode(responseBody);
        print('✅ $TAG: Complete results uploaded: ${data['message']}');
        return true;
      } else {
        final errorBody = await streamedResponse.stream.bytesToString();
        print('❌ $TAG: Complete results upload failed: ${streamedResponse.statusCode} - $errorBody');
        return false;
      }
      
    } catch (e) {
      print('❌ $TAG: Complete results upload error: $e');
      return false;
    }
  }

  // ===============================================
  // QUEUE STATUS
  // ===============================================
  
  Future<Map<String, dynamic>> getQueueStatus(String playerToken) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/upload/queue-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $playerToken',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['queue_status'] ?? {};
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
      
    } catch (e) {
      print('❌ $TAG: Failed to get queue status: $e');
      return {};
    }
  }
}