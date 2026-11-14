// lib/services/game_service.dart
// 20250710 18:28 V1.0: Real: GameService with actual API integration
// 20250721 12:55 V1.1: Real Download Progress enhancements
// lib/services/game_service.dart
// Game service for downloading game data with real progress tracking
// 20250721 14:00 V2.0: Added real package size calculation
// 20250726 11:38 V2.1: Download data amount exctraction improved

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/game_models.dart';
import 'api_service.dart';

typedef DownloadProgressCallback = void Function(double progress, int downloadedBytes, int totalBytes, int filesDownloaded, int totalFiles);

class GameService {
  static const String _gameEndpoint = '/game/data';
  
  Future<GamePackage> downloadGamePackageWithRealProgress(
    int gameId, {
    required DownloadProgressCallback onProgress,
  }) async {
    try {
      print('📥 [GameService] Starting honest download for game ID: $gameId');
      
      // Step 1: Get package info from server (30 files, 23MB)
      final packageInfo = await _getGamePackageInfo(gameId);
      final totalBytes = packageInfo['estimatedSize'] ?? 23000000; // 23 MB
      final totalFiles = packageInfo['fileCount'] ?? 30;
      
      print('📊 [GameService] Package: $totalFiles files, ${_formatFileSize(totalBytes)}');
      
      // Step 2: Start download with honest progress
      int downloadedBytes = 0;
      int filesDownloaded = 0;
      
      // Initial progress
      onProgress(0.0, downloadedBytes, totalBytes, filesDownloaded, totalFiles);
      
      // Download game data JSON first
      final gameData = await _downloadGameDataWithHonestProgress(
        gameId, 
        (bytes) {
          downloadedBytes = bytes;
          final progress = downloadedBytes / totalBytes;
          onProgress(progress, downloadedBytes, totalBytes, filesDownloaded, totalFiles);
        }
      );
      
      filesDownloaded = 1; // JSON = 1 file
      
      // Download all media files
      await _downloadAllMediaFilesHonestly(
        gameData,
        downloadedBytes,
        totalBytes,
        filesDownloaded,
        totalFiles,
        (progress, bytes, files) {
          onProgress(progress, bytes, totalBytes, files, totalFiles);
        }
      );
      
      // Parse final game package
      final gamePackage = GamePackage.fromJson(gameData);
      
      // Final progress: 100%
      onProgress(1.0, totalBytes, totalBytes, totalFiles, totalFiles);
      
      print('✅ [GameService] Honest download complete: ${gamePackage.game.name}');
      return gamePackage;
      
    } catch (e) {
      print('❌ [GameService] Download failed: $e');
      onProgress(0.0, 0, 1, 0, 1); // Error state
      rethrow;
    }
  }

  // Download game JSON with honest byte counting
  Future<Map<String, dynamic>> _downloadGameDataWithHonestProgress(
    int gameId,
    Function(int downloadedBytes) onBytesDownloaded
  ) async {
    
    final url = Uri.parse('${ApiService.baseUrl}$_gameEndpoint/$gameId');
    print('🌐 [GameService] Downloading from: $url');
    
    final request = http.Request('GET', url);
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.headers['Accept-Charset'] = 'utf-8';
    final response = await request.send();
    
    if (response.statusCode != 200) {
      throw Exception('Failed to download: ${response.statusCode}');
    }
    
    final List<int> bytes = [];
    int downloadedBytes = 0;
    
    // Stream response and count every byte
    await for (List<int> chunk in response.stream) {
      bytes.addAll(chunk);
      downloadedBytes += chunk.length;
      
      // Report honest byte progress
      onBytesDownloaded(downloadedBytes);
    }
    
    print('📦 [GameService] Game data: ${_formatFileSize(downloadedBytes)}');

    // Parse JSON with proper UTF-8 handling and UNWRAP server response
    final responseString = utf8.decode(bytes);
    final serverResponse = json.decode(responseString);

    print('📊 [GameService] Raw server response keys: ${serverResponse.keys.toList()}');

    // CRITICAL: Unwrap server response structure
    if (serverResponse.containsKey('success') && serverResponse.containsKey('data')) {
      print('🔄 [GameService] Unwrapping server response structure');
      final unwrappedData = serverResponse['data'];
      print('📊 [GameService] Unwrapped data keys: ${unwrappedData.keys.toList()}');
      return unwrappedData; // Return the actual game data
    } else {
      print('🔄 [GameService] Using direct server response');
      return serverResponse; // Return as-is
    }
  }

  Future<void> _downloadAllMediaFilesHonestly(
    Map<String, dynamic> gameData,
    int initialBytes,
    int totalBytes,
    int initialFiles,
    int totalFiles,
    Function(double progress, int bytes, int files) onProgress
  ) async {
    
    // Extract media URLs
    final mediaUrls = _extractMediaUrls(gameData);
    print('📁 [GameService] Downloading ${mediaUrls.length} media files...');
    
    int currentDownloadedBytes = initialBytes;
    int currentFilesDownloaded = initialFiles;
    
    // Download each file and count bytes honestly
    for (int i = 0; i < mediaUrls.length; i++) {
      final url = mediaUrls[i];
      final fileName = _getFileNameFromUrl(url);
      
      try {
        final fileBytes = await _downloadSingleFileHonestly(
          url,
          (fileDownloadedBytes) {
            // Update progress with current file's bytes
            final totalCurrentBytes = currentDownloadedBytes + fileDownloadedBytes;
            final progress = totalCurrentBytes / totalBytes;
            onProgress(progress, totalCurrentBytes, currentFilesDownloaded);
            
            // Small delay for smooth UI updates (configurable UPDATE_PERIOD_MS)
            // Note: This delay is implemented in UI layer, not here
          }
        );
        
        // File complete - add to totals
        currentDownloadedBytes += fileBytes.length;
        currentFilesDownloaded++;
        
        // Update progress after file completion
        final progress = currentDownloadedBytes / totalBytes;
        onProgress(progress, currentDownloadedBytes, currentFilesDownloaded);
        
      } catch (e) {
        print('⚠️ [GameService] Failed to download $fileName: $e');
        // Skip failed files but continue counting
        currentFilesDownloaded++;
      }
    }
    
    print('📦 [GameService] All files downloaded: ${_formatFileSize(currentDownloadedBytes)}');
  }

  // Download single file with honest byte counting
  Future<List<int>> _downloadSingleFileHonestly(
    String url,
    Function(int downloadedBytes) onBytesDownloaded
  ) async {
    
    final request = http.Request('GET', Uri.parse(url));
    final response = await request.send();
    
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    
    final List<int> bytes = [];
    int downloadedBytes = 0;
    
    // Count every byte honestly
    await for (List<int> chunk in response.stream) {
      bytes.addAll(chunk);
      downloadedBytes += chunk.length;
      
      // Report progress every chunk
      onBytesDownloaded(downloadedBytes);
    }
    
    return bytes;
  }

  // Extract media URLs from game data
  List<String> _extractMediaUrls(Map<String, dynamic> gameData) {
    final List<String> urls = [];
    
    // Safely get base URL
    String baseUrl = '';
    try {
      baseUrl = gameData['game']?['media_base_url'] ?? 
                 gameData['download_info']?['media_base_url'] ?? 
                 '';
    } catch (e) {
      print('⚠️ [GameService] Could not get media_base_url: $e');
      return urls; // Return empty list if no base URL
    }
    
    if (baseUrl.isEmpty) {
      print('⚠️ [GameService] No media_base_url found, skipping media downloads');
      return urls;
    }
    
    print('🔗 [GameService] Using media base URL: $baseUrl');
    
    // Intro files
    try {
      if (gameData['intro']?['files'] != null) {
        for (String file in gameData['intro']['files']) {
          urls.add('$baseUrl/intro/$file');
        }
      }
    } catch (e) {
      print('⚠️ [GameService] Error processing intro files: $e');
    }
    
    // Checkpoint media files
    try {
      if (gameData['checkpoints'] != null) {
        for (var checkpoint in gameData['checkpoints']) {
          if (checkpoint['media_files'] != null) {
            for (String file in checkpoint['media_files']) {
              urls.add('$baseUrl/checkpoints/$file');
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ [GameService] Error processing checkpoint files: $e');
    }
    
    // Puzzle files
    try {
      if (gameData['puzzles'] != null) {
        for (var puzzle in gameData['puzzles']) {
          if (puzzle['files'] != null) {
            final files = puzzle['files'];
            final dir = puzzle['directory_name'] ?? 'unknown';
            
            if (files['main'] != null) urls.add('$baseUrl/puzzles/$dir/${files['main']}');
            if (files['reward'] != null) urls.add('$baseUrl/puzzles/$dir/${files['reward']}');
            if (files['solution'] != null) urls.add('$baseUrl/puzzles/$dir/${files['solution']}');
            
            if (files['hints'] != null) {
              for (String hint in files['hints']) {
                urls.add('$baseUrl/puzzles/$dir/$hint');
              }
            }
          }
        }
      }
    } catch (e) {
      print('⚠️ [GameService] Error processing puzzle files: $e');
    }
    
    print('📁 [GameService] Found ${urls.length} media URLs to download');
    return urls;
  }

  // Get filename from URL
  String _getFileNameFromUrl(String url) {
    return url.split('/').last.split('?').first;
  }

  // Get package info from server
  Future<Map<String, dynamic>> _getGamePackageInfo(int gameId) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/game/package-info/$gameId'),
        headers: {'Content-Type': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('📦 [GameService] Server info: ${data['package']}');
        return data['package'];
      }
    } catch (e) {
      print('⚠️ [GameService] Package info failed: $e');
    }
    
    // Fallback values
    return {
      'estimatedSize': 23000000, // 23 MB
      'fileCount': 30,
    };
  }

  // Format file size
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Original method (unchanged)
  Future<GamePackage> downloadGamePackage(int gameId) async {
    final response = await http.get(
      Uri.parse('${ApiService.baseUrl}$_gameEndpoint/$gameId'),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return GamePackage.fromJson(data);
    } else {
      throw Exception('Failed to download game: ${response.statusCode}');
    }
  }
}