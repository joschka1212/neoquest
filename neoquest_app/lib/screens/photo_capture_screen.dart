// lib/screens/photo_capture_screen.dart
// 20250711 12:00 V1.1: Complete camera interface for checkpoint photo capture with preview and confirmation
// 20250801 XX:XX V1.2: Refactored to use centralized AppColors

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:io';
import '../services/photo_capture_service.dart';
import '../models/game_models.dart';
import '../constants/app_colors.dart';

class PhotoCaptureScreen extends StatefulWidget {
  final Checkpoint checkpoint;
  final String sessionId;
  final String playerName;
  final double? currentLatitude;
  final double? currentLongitude;
  final VoidCallback? onPhotoTaken;

  const PhotoCaptureScreen({
    super.key,
    required this.checkpoint,
    required this.sessionId,
    required this.playerName,
    this.currentLatitude,
    this.currentLongitude,
    this.onPhotoTaken,
  });

  @override
  State<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends State<PhotoCaptureScreen>
    with WidgetsBindingObserver {
  final PhotoCaptureService _photoService = PhotoCaptureService();
  
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  bool _hasPermissions = false;
  String _statusMessage = 'Initializing camera...';
  CheckpointPhoto? _capturedPhoto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    print('📍 Current Screen: ${runtimeType.toString()}');
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _photoService.disposeCamera();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isCameraInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _photoService.disposeCamera();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    setState(() {
      _statusMessage = 'Requesting camera permissions...';
    });

    try {
      // Request permissions
      final hasPermissions = await _photoService.requestCameraPermissions();
      if (!hasPermissions) {
        setState(() {
          _statusMessage = 'Camera permissions required';
          _hasPermissions = false;
        });
        return;
      }

      setState(() {
        _hasPermissions = true;
        _statusMessage = 'Initializing camera...';
      });

      // Initialize camera
      final success = await _photoService.initializeCamera();
      if (success) {
        setState(() {
          _isCameraInitialized = true;
          _statusMessage = 'Camera ready';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to initialize camera';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Camera error: $e';
      });
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing || !_isCameraInitialized) return;

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing photo...';
    });

    try {
      final photo = await _photoService.captureCheckpointPhoto(
        sessionId: widget.sessionId,
        checkpointId: widget.checkpoint.id,
        checkpointName: widget.checkpoint.name,
        playerName: widget.playerName,
        latitude: widget.currentLatitude,
        longitude: widget.currentLongitude,
      );

      if (photo != null) {
        setState(() {
          _capturedPhoto = photo;
          _statusMessage = 'Photo captured successfully!';
        });
      } else {
        setState(() {
          _statusMessage = 'Failed to capture photo';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Capture error: $e';
      });
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<void> _retakePhoto() async {
    if (_capturedPhoto != null) {
      // Delete the captured photo
      await _photoService.deletePhoto(_capturedPhoto!.id);
    }

    setState(() {
      _capturedPhoto = null;
      _statusMessage = 'Camera ready';
    });
  }

  void _confirmPhoto() {
    // Call callback if provided
    widget.onPhotoTaken?.call();
    
    // Show success message and go back
    Navigator.pop(context, _capturedPhoto);
  }

  Widget _buildCameraPreview() {
    if (!_hasPermissions) {
      return _buildPermissionRequest();
    }

    if (!_isCameraInitialized) {
      return _buildLoadingState();
    }

    final cameraController = _photoService.cameraController;
    if (cameraController == null) {
      return _buildErrorState('Camera not available');
    }

    return Stack(
      children: [
        // Camera preview
        SizedBox.expand(
          child: CameraPreview(cameraController),
        ),
        
        // Camera overlay
        _buildCameraOverlay(),
      ],
    );
  }

  Widget _buildCameraOverlay() {
    return Column(
      children: [
        // Top info bar
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primaryDark.withOpacity(0.8),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close, 
                        color: AppColors.textPrimary, 
                        size: 28
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            widget.checkpoint.name,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            'Checkpoint ${widget.checkpoint.checkpointOrder} Photo',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Balance the close button
                  ],
                ),
                
                if (widget.checkpoint.checkpointConfig.photoInstructions != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.emeraldPrimary.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldPrimary.withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.textPrimary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.checkpoint.checkpointConfig.photoInstructions!,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const Spacer(),

        // Bottom controls
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                AppColors.primaryDark.withOpacity(0.9),
                Colors.transparent,
              ],
            ),
          ),
          child: SafeArea(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Gallery button (future feature)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground.withOpacity(0.8),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.borderInactive,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.photo_library,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ),

                // Capture button
                GestureDetector(
                  onTap: _isCapturing ? null : _capturePhoto,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: _isCapturing ? AppColors.disabled : AppColors.textPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.emeraldPrimary,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.emeraldPrimary.withOpacity(0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: _isCapturing
                        ? Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
                            ),
                          )
                        : Icon(
                            Icons.camera_alt,
                            color: AppColors.primaryDark,
                            size: 32,
                          ),
                  ),
                ),

                // Switch camera button
                GestureDetector(
                  onTap: () {
                    // TODO: Implement camera switching
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground.withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.borderInactive,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.flip_camera_ios,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoPreview() {
    if (_capturedPhoto == null) return Container();

    return Stack(
      children: [
        // Photo preview
        SizedBox.expand(
          child: Image.file(
            File(_capturedPhoto!.filePath),
            fit: BoxFit.cover,
          ),
        ),

        // Preview overlay
        Column(
          children: [
            // Top bar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primaryDark.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle, 
                          color: AppColors.success, 
                          size: 28
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Photo Captured!',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info, 
                            color: AppColors.textPrimary, 
                            size: 16
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Size: ${_capturedPhoto!.formattedFileSize} • ${_capturedPhoto!.imageWidth}x${_capturedPhoto!.imageHeight}',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Spacer(),

            // Bottom controls
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.primaryDark.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Retake button
                    ElevatedButton.icon(
                      onPressed: _retakePhoto,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retake'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                      ),
                    ),

                    // Confirm button
                    ElevatedButton.icon(
                      onPressed: _confirmPhoto,
                      icon: const Icon(Icons.check),
                      label: const Text('Use Photo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.primaryDark,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        shadowColor: AppColors.success.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPermissionRequest() {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: 64,
                  color: AppColors.emeraldPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Permission Required',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'To capture checkpoint photos, please allow camera access in your device settings.',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.settings),
                label: const Text('Request Permission'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.emeraldPrimary.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.redAlert.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.redAlert,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Camera Error',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                error,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _initializeCamera,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emeraldPrimary,
                  foregroundColor: AppColors.primaryDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                  shadowColor: AppColors.emeraldPrimary.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: _capturedPhoto != null 
          ? _buildPhotoPreview()
          : _buildCameraPreview(),
    );
  }
}