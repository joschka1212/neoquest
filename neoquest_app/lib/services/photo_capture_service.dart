// lib/services/photo_capture_service.dart
// 20250711 11:30 V1.0: Photo capture service for checkpoint evidence with offline storage

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:sqflite/sqflite.dart';

class PhotoCaptureService {
  static final PhotoCaptureService _instance = PhotoCaptureService._internal();
  factory PhotoCaptureService() => _instance;
  PhotoCaptureService._internal();

  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  Database? _database;

  /// Initialize camera service
  Future<bool> initialize() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        print('❌ No cameras available on device');
        return false;
      }

      // Initialize database
      await _initializeDatabase();

      print('✅ Photo capture service initialized with ${_cameras.length} cameras');
      return true;
    } catch (e) {
      print('❌ Error initializing photo capture service: $e');
      return false;
    }
  }

  /// Initialize SQLite database for photo metadata
  Future<void> _initializeDatabase() async {
    if (_database != null) return;

    try {
      final databasesPath = await getDatabasesPath();
      final dbPath = path.join(databasesPath, 'neoquest_photos.db');

      _database = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE checkpoint_photos (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              session_id TEXT NOT NULL,
              checkpoint_id INTEGER NOT NULL,
              checkpoint_name TEXT NOT NULL,
              player_name TEXT NOT NULL,
              file_path TEXT NOT NULL,
              thumbnail_path TEXT,
              latitude REAL,
              longitude REAL,
              timestamp INTEGER NOT NULL,
              file_size INTEGER,
              image_width INTEGER,
              image_height INTEGER,
              upload_status TEXT DEFAULT 'pending'
            )
          ''');
        },
      );

      print('✅ Photo database initialized');
    } catch (e) {
      print('❌ Error initializing photo database: $e');
    }
  }

  /// Request camera permissions
  Future<bool> requestCameraPermissions() async {
    try {
      // Fotos landen im App-eigenen Ordner (getApplicationDocumentsDirectory),
      // dafuer ist keine Speicher-Berechtigung noetig. Permission.storage wird
      // ab Android 13 immer abgelehnt und darf die Kamera nicht blockieren.
      final cameraStatus = await Permission.camera.request();

      print('📷 Camera permission: $cameraStatus');

      return cameraStatus.isGranted;
    } catch (e) {
      print('❌ Error requesting camera permissions: $e');
      return false;
    }
  }

  /// Initialize camera for capture
  Future<bool> initializeCamera({CameraLensDirection direction = CameraLensDirection.back}) async {
    try {
      if (!_isInitialized) {
        bool initialized = await initialize();
        if (!initialized) return false;
      }

      // Dispose existing controller
      await disposeCamera();

      // Find camera with requested direction
      CameraDescription? camera;
      try {
        camera = _cameras.firstWhere((c) => c.lensDirection == direction);
      } catch (e) {
        // Fallback to first available camera
        camera = _cameras.first;
      }

      // Initialize camera controller
      _cameraController = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      _isInitialized = true;

      print('✅ Camera initialized: ${camera.name}');
      return true;
    } catch (e) {
      print('❌ Error initializing camera: $e');
      return false;
    }
  }

  /// Capture photo at checkpoint
  Future<CheckpointPhoto?> captureCheckpointPhoto({
    required String sessionId,
    required int checkpointId,
    required String checkpointName,
    required String playerName,
    double? latitude,
    double? longitude,
  }) async {
    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) {
        throw Exception('Camera not initialized');
      }

      // Create photos directory
      final directory = await _getPhotosDirectory();
      
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'checkpoint_${checkpointId}_${sessionId}_$timestamp.jpg';
      final filePath = path.join(directory.path, filename);

      // Capture photo
      final XFile photoFile = await _cameraController!.takePicture();
      
      // Move to app directory and process
      final File finalFile = await File(photoFile.path).copy(filePath);
      
      // Get image dimensions and file size
      final Uint8List imageBytes = await finalFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);
      final int fileSize = imageBytes.length;

      // Create thumbnail
      final String? thumbnailPath = await _createThumbnail(finalFile, directory);

      // Save photo metadata to database
      final photoId = await _database!.insert('checkpoint_photos', {
        'session_id': sessionId,
        'checkpoint_id': checkpointId,
        'checkpoint_name': checkpointName,
        'player_name': playerName,
        'file_path': filePath,
        'thumbnail_path': thumbnailPath,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp,
        'file_size': fileSize,
        'image_width': image?.width,
        'image_height': image?.height,
        'upload_status': 'pending',
      });

      // Clean up temporary file
      await File(photoFile.path).delete();

      print('📸 Photo captured: $filename (${(fileSize / 1024).toStringAsFixed(1)} KB)');

      return CheckpointPhoto(
        id: photoId,
        sessionId: sessionId,
        checkpointId: checkpointId,
        checkpointName: checkpointName,
        playerName: playerName,
        filePath: filePath,
        thumbnailPath: thumbnailPath,
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.fromMillisecondsSinceEpoch(timestamp),
        fileSize: fileSize,
        imageWidth: image?.width,
        imageHeight: image?.height,
        uploadStatus: 'pending',
      );
    } catch (e) {
      print('❌ Error capturing photo: $e');
      return null;
    }
  }

  /// Create thumbnail for photo
  Future<String?> _createThumbnail(File originalFile, Directory directory) async {
    try {
      final Uint8List imageBytes = await originalFile.readAsBytes();
      final img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) return null;

      // Create thumbnail (150x150 max, maintaining aspect ratio)
      final img.Image thumbnail = img.copyResize(
        image,
        width: 150,
        height: 150,
        interpolation: img.Interpolation.average,
      );

      // Save thumbnail
      final String thumbnailFilename = '${path.basenameWithoutExtension(originalFile.path)}_thumb.jpg';
      final String thumbnailPath = path.join(directory.path, thumbnailFilename);
      
      final File thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(img.encodeJpg(thumbnail, quality: 80));

      print('🖼️ Thumbnail created: ${(await thumbnailFile.length() / 1024).toStringAsFixed(1)} KB');
      return thumbnailPath;
    } catch (e) {
      print('❌ Error creating thumbnail: $e');
      return null;
    }
  }

  /// Get photos directory
  Future<Directory> _getPhotosDirectory() async {
    final Directory appDir = await getApplicationDocumentsDirectory();
    final Directory photosDir = Directory(path.join(appDir.path, 'checkpoint_photos'));
    
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    
    return photosDir;
  }

  /// Get all photos for a session
  Future<List<CheckpointPhoto>> getSessionPhotos(String sessionId) async {
    await _initializeDatabase();
    
    try {
      final List<Map<String, dynamic>> photos = await _database!.query(
        'checkpoint_photos',
        where: 'session_id = ?',
        whereArgs: [sessionId],
        orderBy: 'timestamp ASC',
      );

      return photos.map((photo) => CheckpointPhoto.fromMap(photo)).toList();
    } catch (e) {
      print('❌ Error getting session photos: $e');
      return [];
    }
  }

  /// Get all photos for a checkpoint
  Future<List<CheckpointPhoto>> getCheckpointPhotos(int checkpointId) async {
    await _initializeDatabase();
    
    try {
      final List<Map<String, dynamic>> photos = await _database!.query(
        'checkpoint_photos',
        where: 'checkpoint_id = ?',
        whereArgs: [checkpointId],
        orderBy: 'timestamp DESC',
      );

      return photos.map((photo) => CheckpointPhoto.fromMap(photo)).toList();
    } catch (e) {
      print('❌ Error getting checkpoint photos: $e');
      return [];
    }
  }

  /// Delete photo
  Future<bool> deletePhoto(int photoId) async {
    try {
      // Get photo info
      final List<Map<String, dynamic>> photos = await _database!.query(
        'checkpoint_photos',
        where: 'id = ?',
        whereArgs: [photoId],
      );

      if (photos.isEmpty) return false;

      final photo = photos.first;
      
      // Delete files
      final File photoFile = File(photo['file_path']);
      if (await photoFile.exists()) {
        await photoFile.delete();
      }

      if (photo['thumbnail_path'] != null) {
        final File thumbnailFile = File(photo['thumbnail_path']);
        if (await thumbnailFile.exists()) {
          await thumbnailFile.delete();
        }
      }

      // Delete from database
      await _database!.delete(
        'checkpoint_photos',
        where: 'id = ?',
        whereArgs: [photoId],
      );

      print('🗑️ Photo deleted: $photoId');
      return true;
    } catch (e) {
      print('❌ Error deleting photo: $e');
      return false;
    }
  }

  /// Get storage statistics
  Future<PhotoStorageStats> getStorageStats() async {
    await _initializeDatabase();
    
    try {
      final List<Map<String, dynamic>> result = await _database!.rawQuery('''
        SELECT 
          COUNT(*) as total_photos,
          SUM(file_size) as total_size,
          COUNT(CASE WHEN upload_status = 'pending' THEN 1 END) as pending_uploads
        FROM checkpoint_photos
      ''');

      final stats = result.first;
      
      return PhotoStorageStats(
        totalPhotos: stats['total_photos'] ?? 0,
        totalSizeBytes: stats['total_size'] ?? 0,
        pendingUploads: stats['pending_uploads'] ?? 0,
      );
    } catch (e) {
      print('❌ Error getting storage stats: $e');
      return PhotoStorageStats(totalPhotos: 0, totalSizeBytes: 0, pendingUploads: 0);
    }
  }

  /// Check if camera is available
  bool get isCameraAvailable => _cameras.isNotEmpty;

  /// Check if camera is initialized
  bool get isCameraInitialized => _cameraController?.value.isInitialized ?? false;

  /// Get camera controller for preview
  CameraController? get cameraController => _cameraController;

  /// Dispose camera resources
  Future<void> disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  /// Dispose all resources
  Future<void> dispose() async {
    await disposeCamera();
    await _database?.close();
    _database = null;
  }
}

/// Checkpoint photo data model
class CheckpointPhoto {
  final int id;
  final String sessionId;
  final int checkpointId;
  final String checkpointName;
  final String playerName;
  final String filePath;
  final String? thumbnailPath;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;
  final int fileSize;
  final int? imageWidth;
  final int? imageHeight;
  final String uploadStatus;

  CheckpointPhoto({
    required this.id,
    required this.sessionId,
    required this.checkpointId,
    required this.checkpointName,
    required this.playerName,
    required this.filePath,
    this.thumbnailPath,
    this.latitude,
    this.longitude,
    required this.timestamp,
    required this.fileSize,
    this.imageWidth,
    this.imageHeight,
    required this.uploadStatus,
  });

  factory CheckpointPhoto.fromMap(Map<String, dynamic> map) {
    return CheckpointPhoto(
      id: map['id'],
      sessionId: map['session_id'],
      checkpointId: map['checkpoint_id'],
      checkpointName: map['checkpoint_name'],
      playerName: map['player_name'],
      filePath: map['file_path'],
      thumbnailPath: map['thumbnail_path'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp']),
      fileSize: map['file_size'],
      imageWidth: map['image_width'],
      imageHeight: map['image_height'],
      uploadStatus: map['upload_status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'checkpoint_id': checkpointId,
      'checkpoint_name': checkpointName,
      'player_name': playerName,
      'file_path': filePath,
      'thumbnail_path': thumbnailPath,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'file_size': fileSize,
      'image_width': imageWidth,
      'image_height': imageHeight,
      'upload_status': uploadStatus,
    };
  }

  /// Get human readable file size
  String get formattedFileSize {
    if (fileSize < 1024) {
      return '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// Check if file exists
  Future<bool> get fileExists async {
    return await File(filePath).exists();
  }

  /// Check if thumbnail exists
  Future<bool> get thumbnailExists async {
    if (thumbnailPath == null) return false;
    return await File(thumbnailPath!).exists();
  }
}

/// Photo storage statistics
class PhotoStorageStats {
  final int totalPhotos;
  final int totalSizeBytes;
  final int pendingUploads;

  PhotoStorageStats({
    required this.totalPhotos,
    required this.totalSizeBytes,
    required this.pendingUploads,
  });

  String get formattedTotalSize {
    if (totalSizeBytes < 1024) {
      return '$totalSizeBytes B';
    } else if (totalSizeBytes < 1024 * 1024) {
      return '${(totalSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(totalSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }
}