// lib/screens/mission_upload_screen.dart
// Mission Upload Screen - Final Version with existing server integration
// 20250713 16:45 V3.0: Simplified integration with working upload service
// 20250801 19:17 V3.1: Refactored to use centralized AppColors
// 20250803 15:48 V3.2: Fixed to use configured server URL from ApiService
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/api_service.dart'; // <- Verwende ApiService für Server-URL
import '../models/mission_models.dart';
import '../services/photo_capture_service.dart';
import '../constants/app_colors.dart';

class MissionUploadScreen extends StatefulWidget {
  final String playerToken;
  final String playerName;
  final int gameId;
  final DateTime startTime;
  final DateTime endTime;
  final int finalScore;
  final Duration totalTime;
  final Map<String, dynamic>? routeData;
  final List<Map<String, dynamic>> checkpointCompletions;
  final List<CheckpointPhoto> capturedPhotos;
  final Map<String, dynamic>? gameMetadata;

  const MissionUploadScreen({
    super.key,
    required this.playerToken,
    required this.playerName,
    required this.gameId,
    required this.startTime,
    required this.endTime,
    required this.finalScore,
    required this.totalTime,
    required this.routeData,
    required this.checkpointCompletions,
    required this.capturedPhotos,
    this.gameMetadata,
  });

  @override
  State<MissionUploadScreen> createState() => _MissionUploadScreenState();
}

class _MissionUploadScreenState extends State<MissionUploadScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late Animation<double> _progressAnimation;
  late Animation<double> _pulseAnimation;
  
  double _uploadProgress = 0.0;
  String _currentStep = 'Preparing upload...';
  bool _isUploading = false;
  bool _uploadComplete = false;
  bool _uploadFailed = false;
  String? _errorMessage;
  Map<String, dynamic>? _uploadResult;

  @override
  void initState() {
    super.initState();
    print('📍 Current Screen: ${runtimeType.toString()}');
    print('🌐 [MissionUpload] Using server URL: ${ApiService.baseUrl}');
    _initializeAnimations();
    _initializeUpload();
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  Future<void> _initializeUpload() async {
    try {
      // Test connection first using ApiService
      final connected = await ApiService.testConnection();
      if (!connected) {
        setState(() {
          _uploadFailed = true;
          _errorMessage = 'Could not connect to server. Please check your connection.';
        });
        return;
      }

      // Start upload process automatically
      _startUpload();
      
    } catch (e) {
      setState(() {
        _uploadFailed = true;
        _errorMessage = 'Failed to initialize upload: $e';
      });
    }
  }

  Future<void> _startUpload() async {
    setState(() {
      _isUploading = true;
      _uploadFailed = false;
      _uploadComplete = false;
      _errorMessage = null;
      _uploadProgress = 0.0;
    });

    try {
      await _uploadMissionData();
    } catch (e) {
      print('❌ [MissionUpload] Upload error: $e');
      setState(() {
        _isUploading = false;
        _uploadFailed = true;
        _errorMessage = 'Upload error: $e';
      });
    }
  }

  Future<void> _uploadMissionData() async {
    print('📤 [MissionUpload] Starting mission upload...');
    
    // Step 1: Upload route data (30%)
    await _updateProgress(0.1, 'Uploading GPS route...');
    
    try {
      if (widget.routeData != null) {
        await _uploadRoute();
      }
      await _updateProgress(0.3, 'Route uploaded successfully');
    } catch (e) {
      print('⚠️ Route upload failed: $e');
      await _updateProgress(0.3, 'Route upload failed (continuing...)');
    }

    // Step 2: Upload photos (60%)
    await _updateProgress(0.4, 'Uploading photos...');
    
    int photosUploaded = 0;
    for (int i = 0; i < widget.capturedPhotos.length; i++) {
      try {
        await _uploadPhoto(widget.capturedPhotos[i]);
        photosUploaded++;
        final photoProgress = 0.4 + (0.2 * (i + 1) / widget.capturedPhotos.length);
        await _updateProgress(photoProgress, 'Uploaded photo ${i + 1}/${widget.capturedPhotos.length}');
      } catch (e) {
        print('⚠️ Photo upload failed: $e');
      }
    }

    // Step 3: Complete mission (100%)
    await _updateProgress(0.8, 'Completing mission...');
    
    try {
      await _completeMission();
      await _updateProgress(1.0, 'Mission completed successfully!');
      
      setState(() {
        _isUploading = false;
        _uploadComplete = true;
        _uploadResult = {
          'routeUploaded': widget.routeData != null,
          'photosUploaded': photosUploaded,
          'totalPhotos': widget.capturedPhotos.length,
          'missionCompleted': true,
          'finalScore': widget.finalScore,
        };
      });
      
    } catch (e) {
      throw Exception('Failed to complete mission: $e');
    }
  }

  Future<void> _updateProgress(double progress, String step) async {
    setState(() {
      _uploadProgress = progress;
      _currentStep = step;
    });
    _progressController.animateTo(progress);
    
    // Small delay for smooth UI updates
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _uploadRoute() async {
    if (widget.routeData == null) return;
    
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/mission/upload-route'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.playerToken}',
      },
      body: json.encode({
        'player_token': widget.playerToken,
        'game_id': widget.gameId,
        'route_data': widget.routeData,
        'start_time': widget.startTime.toIso8601String(),
        'end_time': widget.endTime.toIso8601String(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Route upload failed: ${response.statusCode}');
    }
    
    print('✅ Route uploaded successfully');
  }

  Future<void> _uploadPhoto(CheckpointPhoto photo) async {
    // Create multipart request for photo upload
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiService.baseUrl}/mission/upload-photo'),
    );
    
    request.headers['Authorization'] = 'Bearer ${widget.playerToken}';
    
    request.fields['player_token'] = widget.playerToken;
    request.fields['game_id'] = widget.gameId.toString();
    request.fields['checkpoint_id'] = photo.checkpointId.toString();
    request.fields['timestamp'] = photo.timestamp.toIso8601String();
    
    if (photo.latitude != null) {
      request.fields['latitude'] = photo.latitude.toString();
    }
    if (photo.longitude != null) {
      request.fields['longitude'] = photo.longitude.toString();
    }
    
    // Add photo file
    request.files.add(await http.MultipartFile.fromPath(
      'photo',
      photo.filePath, // <- Korrigiert: filePath statt imagePath
    ));
    
    final response = await request.send();
    
    if (response.statusCode != 200) {
      throw Exception('Photo upload failed: ${response.statusCode}');
    }
    
    print('✅ Photo uploaded: ${photo.filePath}'); // <- Korrigiert: filePath statt imagePath
  }

  Future<void> _completeMission() async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/mission/complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${widget.playerToken}',
      },
      body: json.encode({
        'player_token': widget.playerToken,
        'game_id': widget.gameId,
        'final_score': widget.finalScore,
        'total_time_seconds': widget.totalTime.inSeconds,
        'checkpoint_completions': widget.checkpointCompletions,
        'game_metadata': widget.gameMetadata,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Mission completion failed: ${response.statusCode}');
    }
    
    print('✅ Mission completed successfully');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              const SizedBox(height: 40),
              
              // Progress Circle
              _buildProgressCircle(),
              
              const SizedBox(height: 40),
              
              // Status Information
              _buildStatusInfo(),
              
              const SizedBox(height: 30),
              
              // Upload Summary
              _buildUploadSummary(),
              
              const Spacer(),
              
              // Action Buttons
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _uploadComplete || _uploadFailed ? () => Navigator.pop(context) : null,
              icon: Icon(
                Icons.arrow_back, 
                color: _uploadComplete || _uploadFailed ? AppColors.textPrimary : AppColors.disabled,
              ),
            ),
            Expanded(
              child: Text(
                'Mission Upload',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Player: ${widget.playerName}',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.emeraldPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Final Score: ${widget.finalScore} points',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.warning,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressCircle() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isUploading ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _getProgressColor().withOpacity(0.1),
              border: Border.all(
                color: _getProgressColor(),
                width: 4,
              ),
              boxShadow: [
                BoxShadow(
                  color: _getProgressColor().withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background circle
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 8,
                    backgroundColor: AppColors.disabled.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.disabled.withOpacity(0.2),
                    ),
                  ),
                ),
                
                // Progress circle
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _progressAnimation,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: _uploadProgress,
                        strokeWidth: 8,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(_getProgressColor()),
                      );
                    },
                  ),
                ),
                
                // Center content
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getProgressIcon(),
                        size: 40,
                        color: _getProgressColor(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(_uploadProgress * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getProgressColor(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getProgressColor().withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _getProgressColor().withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _getStatusTitle(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _getProgressColor(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentStep,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.redAlert.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.redAlert.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.redAlert,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.redAlert,
                        fontSize: 12,
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
    );
  }

  Widget _buildUploadSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderInactive,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _uploadResult != null ? 'Upload Results' : 'Upload Summary',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          if (_uploadResult != null) ...[
            _buildDetailRow(
              'GPS Track',
              _uploadResult!['routeUploaded'] ? 'Uploaded ✓' : 'Failed ✗',
              _uploadResult!['routeUploaded'] ? AppColors.success : AppColors.redAlert,
            ),
            
            _buildDetailRow(
              'Photos',
              '${_uploadResult!['photosUploaded']}/${_uploadResult!['totalPhotos']} uploaded',
              _uploadResult!['photosUploaded'] > 0 ? AppColors.success : AppColors.warning,
            ),
            
            _buildDetailRow(
              'Mission Status',
              _uploadResult!['missionCompleted'] ? 'Completed ✓' : 'Failed ✗',
              _uploadResult!['missionCompleted'] ? AppColors.success : AppColors.redAlert,
            ),
            
            _buildDetailRow(
              'Final Score',
              '${_uploadResult!['finalScore']} points',
              AppColors.warning,
            ),
          ] else ...[
            _buildDetailRow(
              'Server',
              ApiService.baseUrl.replaceAll('/api', '').replaceAll('http://', ''),
              AppColors.emeraldPrimary,
            ),
            
            _buildDetailRow(
              'GPS Track',
              widget.routeData != null ? 'Ready to upload' : 'No data',
              widget.routeData != null ? AppColors.emeraldPrimary : AppColors.disabled,
            ),
            
            _buildDetailRow(
              'Photos',
              '${widget.capturedPhotos.length} to upload',
              widget.capturedPhotos.isNotEmpty ? AppColors.emeraldPrimary : AppColors.disabled,
            ),
            
            _buildDetailRow(
              'Checkpoints',
              '${widget.checkpointCompletions.length} completed',
              widget.checkpointCompletions.isNotEmpty ? AppColors.emeraldPrimary : AppColors.disabled,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [        
        if (_uploadFailed && !_isUploading) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _retryUpload(),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: AppColors.warning.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: (_uploadComplete || _uploadFailed) && !_isUploading 
                  ? AppColors.emeraldGlowShadow 
                  : null,
            ),
            child: ElevatedButton.icon(
              onPressed: (_uploadComplete || _uploadFailed) && !_isUploading 
                  ? () => Navigator.pop(context) 
                  : null,
              icon: const Icon(Icons.home),
              label: Text(_uploadComplete ? 'Continue' : 'Back to Game'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emeraldPrimary,
                foregroundColor: AppColors.primaryDark,
                disabledBackgroundColor: AppColors.disabled,
                disabledForegroundColor: AppColors.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getProgressColor() {
    if (_uploadComplete) return AppColors.success;
    if (_uploadFailed) return AppColors.redAlert;
    if (_isUploading) return AppColors.emeraldPrimary;
    return AppColors.warning;
  }

  IconData _getProgressIcon() {
    if (_uploadComplete) return Icons.check_circle;
    if (_uploadFailed) return Icons.error;
    if (_isUploading) return Icons.cloud_upload;
    return Icons.upload;
  }

  String _getStatusTitle() {
    if (_uploadComplete) return 'Upload Complete';
    if (_uploadFailed) return 'Upload Failed';
    if (_isUploading) return 'Uploading Mission Data';
    return 'Preparing Upload';
  }

  void _retryUpload() {
    setState(() {
      _uploadFailed = false;
      _uploadComplete = false;
      _uploadResult = null;
      _uploadProgress = 0.0;
      _errorMessage = null;
      _currentStep = 'Preparing upload...';
      _progressController.reset();
    });
    _startUpload();
  }
}