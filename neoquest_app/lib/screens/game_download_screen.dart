// lib/screens/game_download_screen.dart
// 20250710 17:20 V1.0: REAL Game Download Screen with actual API integration
// 20250714 16:19 V1.1: Added sound
// 20250714 16:30 V1.2: Added auto-navigation with fade transition
// 20250721 12:55 V1.3: Download Screen shows real download progress
// 20250726 11:40 V1.4: Download progress screen simplified, improved to reflect actual download progress
// 20250726 12:38 V1.5: After Download switch to a glowing 100% download screen
// 20250726 13:10 V1.6: FIXED layout jumps - stable positioning with glow effects
// 20250726 14:15 V1.7: FIXED green glow jumping - improved container structure
// 20250726 14:30 V1.8: COMPLETE LAYOUT REDESIGN - No jumping, stable glow
// 20250726 15:20 V1.8.2: COLORS ONLY - Emerald scheme with subtle glow (NO logic changes)
// 20250801 19:02 V1.9: Refactored to use centralized AppColors

import 'package:flutter/material.dart';
import '../services/game_service.dart';
import '../models/game_models.dart';
import 'waiting_for_server_screen.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../constants/app_colors.dart';

class GameDownloadScreen extends StatefulWidget {
  final String token;
  final String gameTitle;
  final String playerName;

  const GameDownloadScreen({
    super.key,
    required this.token,
    required this.gameTitle,
    required this.playerName,
  });

  @override
  State<GameDownloadScreen> createState() => _GameDownloadScreenState();
}

class _GameDownloadScreenState extends State<GameDownloadScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GameService _gameService = GameService();
  
  // Simple download state
  double _progress = 0.0;
  int _downloadedBytes = 0;
  int _totalBytes = 0;
  int _filesDownloaded = 0;
  int _totalFiles = 0;
  bool _isComplete = false;
  bool _hasError = false;
  String _errorMessage = '';
  GamePackage? _gamePackage;
  
  // Progress tracking for console output
  int _lastPromptedPercentage = 0;
  
  // Configuration Parameters
  static const int UPDATE_PERIOD_MS = 200;           // n: Update period for progress bar (ms)
  static const int DELAY_TO_WAITING_SCREEN_MS = 2000; // yy: Delay before switching to waiting screen (ms)  
  static const int PROMPT_PERCENTAGE = 10;            // m: Console output every m% (default: 10%)

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    print('📍 Current Screen: ${runtimeType.toString()}');
    _startHonestDownload();
  }
  
  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Start honest download with real byte counting
  Future<void> _startHonestDownload() async {
    try {
      // Determine game ID
      int gameId = 1;
      if (widget.gameTitle.toLowerCase().contains('testgame1')) {
        gameId = 1;
      }

      print('📥 [Download] Starting honest download for game $gameId');

      // Download with honest progress reporting
      final gamePackage = await _gameService.downloadGamePackageWithRealProgress(
        gameId,
        onProgress: (progress, downloadedBytes, totalBytes, filesDownloaded, totalFiles) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _downloadedBytes = downloadedBytes;
              _totalBytes = totalBytes;
              _filesDownloaded = filesDownloaded;
              _totalFiles = totalFiles;
            });
            
            // Console output every PROMPT_PERCENTAGE%
            final currentPercentage = (progress * 100).round();
            if (currentPercentage >= _lastPromptedPercentage + PROMPT_PERCENTAGE && currentPercentage <= 100) {
              _lastPromptedPercentage = (currentPercentage ~/ PROMPT_PERCENTAGE) * PROMPT_PERCENTAGE;
              print('📊 [Download] $_lastPromptedPercentage% complete: ${_formatFileSize(downloadedBytes)} / ${_formatFileSize(totalBytes)} ($filesDownloaded/$totalFiles files)');
            }
          }
        },
      );

      _gamePackage = gamePackage;

      // Mark as complete
      setState(() {
        _isComplete = true;
        _progress = 1.0;
      });

      print('✅ [Download] Complete! ${_formatFileSize(_downloadedBytes)} downloaded');

      // Play success sound (optional)
      _playSuccessSound();

      // Show completion for configured delay, then navigate
      await Future.delayed(Duration(milliseconds: DELAY_TO_WAITING_SCREEN_MS));
      _navigateToWaitingScreen();

    } catch (e) {
      print('❌ [Download] Error: $e');
      setState(() {
        _hasError = true;
        _errorMessage = e.toString();
      });
    }
  }

  // Play success sound (optional)
  Future<void> _playSuccessSound() async {
    try {
      final soundUrl = '${ApiService.baseUrl.replaceAll('/api', '')}/media/games/testgame1/assets/download_success.mp3';
      await _audioPlayer.play(UrlSource(soundUrl));
    } catch (e) {
      print('⚠️ Sound playback failed: $e');
      // Not critical - continue without sound
    }
  }

  // Navigate to waiting screen
  void _navigateToWaitingScreen() {
    if (_gamePackage != null && mounted) {
      print('🧭 Download → WaitingScreen');
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => WaitingForServerScreen(
            playerToken: widget.token,
            playerName: widget.playerName,
            gameData: {
              'gamePackage': _gamePackage,
            },
          ),
          transitionDuration: const Duration(milliseconds: 800),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  void _retryDownload() {
    setState(() {
      _hasError = false;
      _errorMessage = '';
      _isComplete = false;
      _progress = 0.0;
      _downloadedBytes = 0;
      _totalBytes = 0;
      _filesDownloaded = 0;
      _totalFiles = 0;
      _lastPromptedPercentage = 0; // Reset console output tracking
    });
    _fadeController.reset();
    _startHonestDownload();
  }

  // Format file size for display
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // Build the top icon with glow effect
  Widget _buildTopIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _pulseController.value * 0.2 + 0.8;
        final glowIntensity = _isComplete ? (_pulseController.value * 0.3 + 0.7) : 1.0;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            decoration: _isComplete ? BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.emeraldPrimary.withOpacity(glowIntensity * 0.2), // Subtle glow
                  blurRadius: 10 * glowIntensity,
                  spreadRadius: 2 * glowIntensity,
                ),
                BoxShadow(
                  color: AppColors.emeraldGlow.withOpacity(glowIntensity * 0.1), // Very subtle outer glow
                  blurRadius: 20 * glowIntensity,
                  spreadRadius: 3 * glowIntensity,
                ),
              ],
            ) : null,
            child: Icon(
              _isComplete ? Icons.check_circle : Icons.cloud_download_rounded,
              size: 80,
              color: AppColors.emeraldPrimary, // Always emerald
            ),
          ),
        );
      },
    );
  }

  // Build the progress circle with all content - STABLE LAYOUT
  Widget _buildProgressCircle() {
    return Container(
      width: 320, // Increased size to accommodate glow
      height: 320,
      alignment: Alignment.center, // Center everything
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 280,
        height: 280,
        decoration: _isComplete ? BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: AppColors.emeraldGlowShadow,
        ) : null,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer CircularProgressIndicator (larger ring)
            SizedBox(
              width: 240,
              height: 240,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 12,
                backgroundColor: AppColors.disabled.withOpacity(0.2), // Gray background ring
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.emeraldLight, // Light emerald progress
                ),
              ),
            ),
            // Inner CircularProgressIndicator (smaller ring)
            SizedBox(
              width: 200, // Smaller for concentric effect
              height: 200,
              child: CircularProgressIndicator(
                value: _progress,
                strokeWidth: 10,
                backgroundColor: AppColors.disabled.withOpacity(0.4), // Darker gray background ring
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.emeraldSecondary, // Dark emerald progress
                ),
              ),
            ),
            // Center content with fixed dimensions
            SizedBox(
              width: 180, // Fixed width for content area
              height: 120, // Fixed height for content area
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Percentage text
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary, // Always white
                      shadows: _isComplete ? AppColors.emeraldTextShadow : null,
                    ),
                    child: Text(
                      '${(_progress * 100).toInt()}%',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // File size info
                  if (_totalBytes > 0) ...[
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary, // Always gray
                        shadows: _isComplete ? AppColors.emeraldTextShadowSubtle : null,
                      ),
                      child: Text(
                        '${_formatFileSize(_downloadedBytes)} / ${_formatFileSize(_totalBytes)}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  // File count
                  if (_totalFiles > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      '$_filesDownloaded / $_totalFiles files',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textTertiary, // Always light gray
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build status text with consistent height
  Widget _buildStatusText() {
    return Container(
      height: 40, // Fixed height to prevent layout shifts
      alignment: Alignment.center,
      child: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 300),
        style: TextStyle(
          fontSize: 14,
          color: _isComplete ? AppColors.emeraldPrimary : AppColors.textSecondary,
          shadows: _isComplete ? AppColors.emeraldTextShadowSubtle : null,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: _isComplete ? BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: AppColors.emeraldPrimary.withOpacity(0.1), // Very subtle container glow
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ) : null,
          child: Text(
            _isComplete ? 'Continuing automatically...' : 'Downloading...',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: AnimatedBuilder(
        animation: _fadeAnimation,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeAnimation.value,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Header section with consistent spacing
                    const SizedBox(height: 40),
                    _buildTopIcon(),
                    const SizedBox(height: 24),
                    
                    // Title text
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 300),
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _isComplete ? AppColors.emeraldPrimary : AppColors.textPrimary,
                      ),
                      child: Text(
                        _isComplete ? 'Download Complete!' : 'Downloading Game Package',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    Text(
                      widget.gameTitle,
                      style: TextStyle(
                        fontSize: 18,
                        color: AppColors.emeraldPrimary, // Emerald instead of cyan
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 60),

                    // Main content area
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!_hasError) ...[
                            // Progress circle with stable layout
                            _buildProgressCircle(),
                            const SizedBox(height: 30),
                            // Status text with fixed height
                            _buildStatusText(),
                          ],

                          // Error State
                          if (_hasError) ...[
                            Icon(
                              Icons.error_outline,
                              size: 80,
                              color: AppColors.redAlert,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'Download Failed',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.redAlert,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage,
                              style: TextStyle(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _retryDownload,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emeraldPrimary, // Emerald instead of cyan
                                foregroundColor: AppColors.primaryDark, // Dark text on emerald button
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Retry Download',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}