// lib/screens/waiting_for_server_screen.dart
// Screen 3: Waiting for Server GO Signal
// SciFi Design with Amber/Emerald dual-tone and glow effects
// Polling-based status updates every 1-2 seconds
// 20250714 08:00 V1.0 Initial implementation
// 20250714 12:00 V2.0 Simplified version
// 20250801 19:06 V2.1 Refactored to use centralized AppColors
// 20250802 xx:xx V2.2 UI optimizations - Mission Briefing layout and emerald stripes

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../config/debug_config.dart';
import '../constants/app_colors.dart';
import 'compass_navigation_screen.dart'; // Temporary instead of CheckpointIntroScreen

// import 'checkpoint_intro_screen.dart';

class WaitingForServerScreen extends StatefulWidget {
  final String playerToken;
  final String playerName;
  final Map<String, dynamic> gameData;

  const WaitingForServerScreen({
    super.key,
    required this.playerToken,
    required this.playerName,
    required this.gameData,
  });

  @override
  State<WaitingForServerScreen> createState() => _WaitingForServerScreenState();
}

class _WaitingForServerScreenState extends State<WaitingForServerScreen>
    with TickerProviderStateMixin {
  
  // Session status
  String _sessionStatus = 'waiting';
  String _waitingMessage = 'Please wait until everyone is registered, then the administrator will start the countdown';
  int _countdown = 0;
  DateTime? _lastUpdated;
  
  // Game Info
  String _gameName = '';
  String _gameDescription = '';
  
  // Polling
  Timer? _pollingTimer;
  bool _isPolling = false;
  
  // Animations
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late AnimationController _circuitController;
  late AnimationController _hexagonController;
  late AnimationController _missionPulseController;
  
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _circuitAnimation;
  late Animation<double> _hexagonRotation;
  
  // Additional colors for SciFi theme (complementing AppColors)
  static const Color _amberPrimary = Color(0xFFFFC107);
  static const Color _amberSecondary = Color(0xFFFF8F00);
  static const Color _amberGlow = Color(0xFFFFE082);
  static const Color _cyanAccent = Color(0xFF06B6D4);

  @override
  void initState() {
    super.initState();
    print('📍 Current Screen: ${runtimeType.toString()}');
    _extractGameInfo();
    _initializeAnimations();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _glowController.dispose();
    _pulseController.dispose();
    _circuitController.dispose();
    _hexagonController.dispose();
    _missionPulseController.dispose();
    super.dispose();
  }

  void _extractGameInfo() {
    // Extract game info from gameData
    final gamePackage = widget.gameData['gamePackage'];
    if (gamePackage != null && gamePackage.game != null) {
      _gameName = gamePackage.game.name ?? 'NeoQuest Mission';
      _gameDescription = gamePackage.game.description ?? 'Discover the secrets of your surroundings';
    } else {
      _gameName = 'NeoQuest Mission';
      _gameDescription = 'Discover the secrets of your surroundings';
    }
    
    DebugConfig.printDebug('Game Info: $_gameName - $_gameDescription');
  }

  void _initializeAnimations() {
    // Glow effect for status panels
    _glowController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 0.8,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Pulse effect for countdown
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    // Circuit lines animation
    _circuitController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();
    
    _circuitAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_circuitController);

    // Hexagon background rotation
    _hexagonController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
    
    _hexagonRotation = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(_hexagonController);

    // Mission briefing icon pulse
    _missionPulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
  }

  void _startPolling() {
    if (_isPolling) return;
    
    _isPolling = true;
    DebugConfig.printDebug('Starting session status polling...');
    
    // Initial check
    _checkSessionStatus();
    
    // Start polling timer - check every 2 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _checkSessionStatus();
    });
  }

  void _stopPolling() {
    _isPolling = false;
    _pollingTimer?.cancel();
    DebugConfig.printDebug('Stopped session status polling');
  }

  Future<void> _checkSessionStatus() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/session/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final session = data['session'];
        
        setState(() {
          _sessionStatus = session['status'] ?? 'waiting';
          _countdown = session['countdown'] ?? 0;
          _lastUpdated = DateTime.now();
          
          // Update waiting message based on status
          switch (_sessionStatus) {
            case 'registration':
              _waitingMessage = 'Please wait until everyone is registered, then the administrator will start the countdown';
              break;
            case 'waiting':
              _waitingMessage = 'All players are ready! Waiting for the administrator...';
              break;
            case 'countdown':
              _waitingMessage = 'The game is starting soon! Get ready!';
              break;
            case 'started':
              _waitingMessage = 'The game has begun!';
              break;
            default:
              _waitingMessage = 'Connecting to server...';
          }
        });

        // Navigate when game starts
        if (_sessionStatus == 'started') {
          _stopPolling();
          _navigateToGame();
        }

        DebugConfig.printDebug('Session status: $_sessionStatus, Countdown: $_countdown');
      } else {
        DebugConfig.printDebug('Failed to get session status: ${response.statusCode}');
      }
    } catch (e) {
      DebugConfig.printDebug('Error polling session status: $e');
      // Continue polling even on errors
    }
  }

  void _navigateToGame() {
    DebugConfig.printDebug('Game started! Navigating to game...');
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CompassNavigationScreen(
          gamePackage: widget.gameData['gamePackage'],
          playerName: widget.playerName,
          token: widget.playerToken,
          startFromCheckpointOrder: 1,
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (_sessionStatus) {
      case 'registration':
      case 'waiting':
        return AppColors.emeraldPrimary;
      case 'countdown':
        return _amberPrimary;
      case 'started':
        return AppColors.emeraldPrimary;
      default:
        return _cyanAccent;
    }
  }

  String _getStatusIcon() {
    switch (_sessionStatus) {
      case 'registration':
      case 'waiting':
        return '⏳';
      case 'countdown':
        return '🚀';
      case 'started':
        return '▶️';
      default:
        return '🔗';
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildSciFiDialog(
        title: 'Game Instructions',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpSection('🎯 Game Goal', 'Navigate through various checkpoints using GPS and compass.'),
            const SizedBox(height: 16),
            _buildHelpSection('📍 Navigation', 'Follow the compass arrow to reach each checkpoint.'),
            const SizedBox(height: 16),
            _buildHelpSection('📸 Proof', 'Take photos at checkpoints for verification when required.'),
            const SizedBox(height: 16),
            _buildHelpSection('🏆 Points', 'Earn points through fast and accurate goal achievement.'),
            const SizedBox(height: 16),
            _buildHelpSection('⏰ Start', 'Wait here until the administrator starts the game.'),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: _amberPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildSciFiDialog({required String title, required Widget child}) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _amberPrimary.withOpacity(0.5), width: 2),
          boxShadow: [
            BoxShadow(
              color: _amberPrimary.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _amberPrimary,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            child,
            const SizedBox(height: 20),
            _buildGlowButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE'),
              color: _amberPrimary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowButton({
    required VoidCallback? onPressed,
    required Widget child,
    required Color color,
    bool isPulsing = false,
  }) {
    return AnimatedBuilder(
      animation: isPulsing ? _pulseAnimation : _glowAnimation,
      builder: (context, _) {
        final scale = isPulsing ? _pulseAnimation.value : 1.0;
        final glowOpacity = isPulsing ? _pulseAnimation.value : _glowAnimation.value;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(glowOpacity * 0.6),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withOpacity(0.8), width: 2),
                ),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }

  // Build the mission briefing icon
  Widget _buildMissionIcon() {
    return AnimatedBuilder(
      animation: _missionPulseController,
      builder: (context, child) {
        final scale = _missionPulseController.value * 0.2 + 0.8;
        
        return Transform.scale(
          scale: scale,
          child: SizedBox(
            width: 80,
            height: 80,
            child: Icon(
              Icons.assignment,
              size: 80,
              color: AppColors.emeraldPrimary, // Same green as download icon
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameInfoPanel() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.emeraldPrimary.withOpacity(0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.emeraldPrimary.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Game Title
              Text(
                _gameName,
                style: TextStyle(
                  color: AppColors.emeraldPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Game Description
              Text(
                _gameDescription,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildWaitingPanel() {
    // If countdown is active, show countdown instead of waiting panel
    if (_countdown > 0) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              padding: const EdgeInsets.all(20), // Reduced from 32
              decoration: BoxDecoration(
                color: AppColors.redAlert.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.redAlert, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.redAlert.withOpacity(_pulseAnimation.value * 0.6),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'GAME STARTS IN',
                    style: TextStyle(
                      color: AppColors.redAlert,
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8), // Reduced from 12
                  Text(
                    '$_countdown',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 56, // Reduced from 72
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: AppColors.redAlert.withOpacity(0.8),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'SECONDS',
                    style: TextStyle(
                      color: AppColors.redAlert,
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    // Normal waiting panel
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.inputBackground.withOpacity(0.8),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _getStatusColor().withOpacity(0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor().withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _getStatusIcon(),
                    style: const TextStyle(fontSize: 32),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'WAITING',
                    style: TextStyle(
                      color: _getStatusColor(),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _waitingMessage,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (_lastUpdated != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last updated: ${_lastUpdated!.toString().substring(11, 19)}',
                  style: TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCountdownDisplay() {
    // Countdown is now integrated into _buildWaitingPanel
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Stack(
        children: [
          // Animated hexagon background
          AnimatedBuilder(
            animation: _hexagonRotation,
            builder: (context, child) {
              return CustomPaint(
                painter: HexagonBackgroundPainter(
                  rotation: _hexagonRotation.value,
                  color: AppColors.emeraldPrimary.withOpacity(0.05),
                ),
                size: Size.infinite,
              );
            },
          ),
          
          // Animated circuit lines - only in bottom area
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 150, // Only bottom 150px
            child: AnimatedBuilder(
              animation: _circuitAnimation,
              builder: (context, child) {
                return CustomPaint(
                  painter: CircuitLinesPainter(
                    progress: _circuitAnimation.value,
                    color: AppColors.emeraldPrimary.withOpacity(0.3), // Emerald green
                  ),
                  size: Size.infinite,
                );
              },
            ),
          ),
          
          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header row with back button and help
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: _showHelpDialog,
                        icon: Icon(Icons.help_outline, color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
                
                // Content with balanced spacing
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        // Header section with tighter spacing
                        const SizedBox(height: 10), // Reduced from 20
                        _buildMissionIcon(),
                        const SizedBox(height: 16), // Reduced from 24
                        
                        // Title text
                        Text(
                          'Mission Briefing',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 24), // Reduced from 40
                        
                        // Player info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.emeraldPrimary.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.person, color: AppColors.emeraldPrimary),
                              const SizedBox(width: 8),
                              Text(
                                'AGENT: ${widget.playerName.toUpperCase()}',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20), // Reduced from 30
                        
                        // Game info panel
                        _buildGameInfoPanel(),
                        
                        const SizedBox(height: 20), // Reduced from 30
                        
                        // Waiting panel (or countdown when active)
                        _buildWaitingPanel(),
                        
                        const Spacer(), // Use spacer to push content up and distribute remaining space
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for hexagon background pattern
class HexagonBackgroundPainter extends CustomPainter {
  final double rotation;
  final Color color;

  HexagonBackgroundPainter({required this.rotation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(rotation);

    for (int i = 0; i < 20; i++) {
      for (int j = 0; j < 15; j++) {
        final x = (i - 10) * 60.0;
        final y = (j - 7) * 52.0;
        
        _drawHexagon(canvas, paint, Offset(x, y), 25);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Paint paint, Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * math.pi) / 3;
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HexagonBackgroundPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}

// Custom painter for circuit lines animation
class CircuitLinesPainter extends CustomPainter {
  final double progress;
  final Color color;

  CircuitLinesPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw animated circuit lines
    final lineCount = 8;
    for (int i = 0; i < lineCount; i++) {
      final y = (size.height / lineCount) * i;
      final animatedProgress = (progress + i * 0.1) % 1.0;
      
      final startX = size.width * animatedProgress;
      final endX = math.min(startX + 100, size.width);
      
      canvas.drawLine(
        Offset(startX, y),
        Offset(endX, y),
        paint,
      );
      
      // Add circuit nodes
      if (animatedProgress > 0.5) {
        canvas.drawCircle(
          Offset(startX + 50, y),
          3,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CircuitLinesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}