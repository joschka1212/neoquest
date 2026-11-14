// lib/screens/compass_navigation_screen.dart
// 20250802 17:30 V2.4: VOLLSTÄNDIGER CODE - Komplett neu geschrieben
// - Kompassnadel zeigt Gehrichtung, Zielrichtung am Rand
// - Piep-Sound bei Richtungsausrichtung
// - Emulator auf 15s reduziert
// - Vollständige, saubere Code-Struktur

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/location_service.dart';
import '../services/route_tracking_service.dart';
import '../services/photo_capture_service.dart';
import '../services/mission_upload_service.dart';
import '../models/game_models.dart';
import '../config/debug_config.dart';
import '../constants/app_colors.dart';
import 'photo_capture_screen.dart';
import 'mission_upload_screen.dart';

class CompassNavigationScreen extends StatefulWidget {
  final GamePackage gamePackage;
  final String playerName;
  final String token;
  final int? startFromCheckpointOrder;

  const CompassNavigationScreen({
    super.key,
    required this.gamePackage,
    required this.playerName,
    required this.token,
    this.startFromCheckpointOrder,
  });

  @override
  State<CompassNavigationScreen> createState() => _CompassNavigationScreenState();
}

class _CompassNavigationScreenState extends State<CompassNavigationScreen>
    with TickerProviderStateMixin {
  
  // Services
  final LocationService _locationService = LocationService();
  final RouteTrackingService _routeService = RouteTrackingService();
  final PhotoCaptureService _photoService = PhotoCaptureService();
  final MissionUploadService _uploadService = MissionUploadService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Checkpoint state
  late List<Checkpoint> _checkpointSequence;
  int _currentCheckpointIndex = 0;
  Checkpoint get _currentCheckpoint => _checkpointSequence[_currentCheckpointIndex];
  
  // Navigation state
  Position? _currentPosition;
  double _distanceToTarget = 0.0;
  double _bearingToTarget = 0.0;
  double _currentHeading = 0.0;
  bool _isNearCheckpoint = false;
  bool _hasReachedCheckpoint = false;
  StreamSubscription<Position>? _locationSubscription;
  bool _showCardinalDirections = false;
  bool _lastDirectionAligned = false;
  
  // Proximity ring state
  bool _outerRingActive = false;
  bool _middleRingActive = false;
  bool _innerRingActive = false;
  
  // Game state
  late DateTime _gameStartTime;
  Timer? _gameTimer;
  int _gameTimeSeconds = 0;
  int _currentScore = 0;
  bool _isMissionComplete = false;
  final List<Map<String, dynamic>> _completedCheckpoints = [];
  
  // Emulator state
  bool _isEmulatorMode = false;
  DateTime? _emulatorStartTime;
  Map<String, double>? _emulatorStartPosition;
  Timer? _emulatorTimer;
  
  // Animations
  late AnimationController _pulseController;
  late AnimationController _compassController;
  late AnimationController _ringController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _compassRotation;
  late Animation<double> _ringAnimation;

  @override
  void initState() {
    super.initState();
    _initializeCheckpointSequence();
    _initializeGame();
    _initializeAnimations();
    _checkEmulatorMode();
    _startLocationTracking();
    _startGameTimer();
    _initializeUploadService();
    print('📍 Current Screen: ${runtimeType.toString()}');
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _gameTimer?.cancel();
    _emulatorTimer?.cancel();
    _pulseController.dispose();
    _compassController.dispose();
    _ringController.dispose();
    _audioPlayer.dispose();
    _locationService.stopLocationTracking();
    super.dispose();
  }

  void _initializeCheckpointSequence() {
    _checkpointSequence = List.from(widget.gamePackage.checkpoints);
    _checkpointSequence.sort((a, b) => a.checkpointOrder.compareTo(b.checkpointOrder));
    
    if (widget.startFromCheckpointOrder != null) {
      _currentCheckpointIndex = _checkpointSequence.indexWhere(
        (cp) => cp.checkpointOrder == widget.startFromCheckpointOrder
      );
      if (_currentCheckpointIndex == -1) _currentCheckpointIndex = 0;
    }
  }

  void _initializeGame() {
    _gameStartTime = DateTime.now();
    _currentScore = widget.gamePackage.game.gameConfig.scoring.basePoints;
    _startRouteTracking();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _compassController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _ringController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(
      begin: 0.95,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));

    _compassRotation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _compassController,
      curve: Curves.easeInOut,
    ));

    _ringAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _ringController,
      curve: Curves.elasticOut,
    ));
  }

  Future<void> _initializeUploadService() async {
    try {
      await _uploadService.initialize();
    } catch (e) {
      DebugConfig.printDebug('Failed to initialize upload service: $e');
    }
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _gameTimeSeconds = DateTime.now().difference(_gameStartTime).inSeconds;
      });
    });
  }

  Future<void> _startRouteTracking() async {
    try {
      await _routeService.initialize();
      _routeService.configureTracking(intervalSeconds: 20, minimumDistanceMeters: 3.0);
      await _routeService.startTracking(
        playerName: widget.playerName,
        playerToken: widget.token,
        gameId: 1,
        checkpointTarget: 'Multi-Checkpoint Mission',
      );
    } catch (e) {
      DebugConfig.printDebug('Error starting route tracking: $e');
    }
  }

  void _checkEmulatorMode() {
    if (DebugConfig.canSimulateGps) {
      _activateEmulatorMode();
    }
  }

  void _activateEmulatorMode() {
    setState(() {
      _isEmulatorMode = true;
      _emulatorStartTime = DateTime.now();
    });
    _generateEmulatorStartPosition();
    _startEmulatorMovement();
  }

  void _generateEmulatorStartPosition() {
    _emulatorStartPosition = DebugConfig.generateStartPosition(
      _currentCheckpoint.latitude,
      _currentCheckpoint.longitude,
    );
  }

  void _startEmulatorMovement() {
    _emulatorTimer?.cancel();
    _emulatorTimer = Timer.periodic(const Duration(seconds: 1), (timer) { // Häufigere Updates für 15s
      if (!_hasReachedCheckpoint && _emulatorStartTime != null && _emulatorStartPosition != null) {
        // Berechne Fortschritt für 15 Sekunden
        final elapsed = DateTime.now().difference(_emulatorStartTime!).inSeconds;
        final progress = (elapsed / 15.0).clamp(0.0, 1.0); // 15 Sekunden bis zum Ziel
        
        if (progress >= 1.0) {
          // Ziel erreicht
          final simulatedPos = {
            'latitude': _currentCheckpoint.latitude,
            'longitude': _currentCheckpoint.longitude,
            'progress': 1.0,
          };
          _updateNavigationDataFromEmulator(simulatedPos);
          timer.cancel();
        } else {
          // Interpoliere Position
          final lat = _emulatorStartPosition!['latitude']! + 
              (_currentCheckpoint.latitude - _emulatorStartPosition!['latitude']!) * progress;
          final lng = _emulatorStartPosition!['longitude']! + 
              (_currentCheckpoint.longitude - _emulatorStartPosition!['longitude']!) * progress;
          
          final simulatedPos = {
            'latitude': lat,
            'longitude': lng,
            'progress': progress,
          };
          _updateNavigationDataFromEmulator(simulatedPos);
        }
      }
    });
  }

  Future<void> _startLocationTracking() async {
    if (!_isEmulatorMode) {
      await _locationService.startLocationTracking();
      _locationSubscription = _locationService.locationStream.listen((Position position) {
        _updateNavigationData(position);
      });
      final initialPosition = await _locationService.getCurrentPosition();
      if (initialPosition != null) {
        _updateNavigationData(initialPosition);
      }
    }
  }

  void _updateNavigationData(Position position) {
    if (_isEmulatorMode) return;

    setState(() {
      _currentPosition = position;
      _currentHeading = position.heading ?? 0.0;
      _distanceToTarget = _locationService.calculateDistance(
        position.latitude, position.longitude,
        _currentCheckpoint.latitude, _currentCheckpoint.longitude,
      );
      _bearingToTarget = _locationService.calculateBearing(
        position.latitude, position.longitude,
        _currentCheckpoint.latitude, _currentCheckpoint.longitude,
      );
      _updateProximityRings();
      _checkDirectionAlignment();
      _isNearCheckpoint = _locationService.isWithinRadius(
        position.latitude, position.longitude,
        _currentCheckpoint.latitude, _currentCheckpoint.longitude,
        _currentCheckpoint.radius.toDouble(),
      );
      if (_isNearCheckpoint && !_hasReachedCheckpoint) {
        _onCheckpointReached();
      }
    });
    _compassController.forward();
  }

  void _updateNavigationDataFromEmulator(Map<String, double> simulatedPos) {
    setState(() {
      _currentHeading = _bearingToTarget + (math.Random().nextDouble() * 40 - 20);
      
      _currentPosition = Position(
        longitude: simulatedPos['longitude']!,
        latitude: simulatedPos['latitude']!,
        timestamp: DateTime.now(),
        accuracy: DebugConfig.simulatedAccuracy,
        altitude: DebugConfig.simulatedAltitude,
        altitudeAccuracy: 3.0,
        heading: _currentHeading,
        speed: DebugConfig.simulatedSpeed,
        speedAccuracy: 1.0,
        headingAccuracy: 5.0,
      );
      _distanceToTarget = _locationService.calculateDistance(
        simulatedPos['latitude']!, simulatedPos['longitude']!,
        _currentCheckpoint.latitude, _currentCheckpoint.longitude,
      );
      _bearingToTarget = _locationService.calculateBearing(
        simulatedPos['latitude']!, simulatedPos['longitude']!,
        _currentCheckpoint.latitude, _currentCheckpoint.longitude,
      );
      _updateProximityRings();
      _checkDirectionAlignment();
      _isNearCheckpoint = DebugConfig.isSimulatedPositionNearCheckpoint(
        simulatedPos,
        _currentCheckpoint.latitude, _currentCheckpoint.longitude,
        _currentCheckpoint.radius.toDouble(),
      );
      if (_isNearCheckpoint && !_hasReachedCheckpoint) {
        _onCheckpointReached();
      }
    });
    _compassController.forward();
  }

  void _updateProximityRings() {
    final checkpointRadius = _currentCheckpoint.radius.toDouble();
    final previousOuterRing = _outerRingActive;
    final previousMiddleRing = _middleRingActive;
    final previousInnerRing = _innerRingActive;
    
    _outerRingActive = _distanceToTarget <= (checkpointRadius * 9.0);
    _middleRingActive = _distanceToTarget <= (checkpointRadius * 4.5);
    _innerRingActive = _distanceToTarget <= checkpointRadius;
    
    if (previousOuterRing != _outerRingActive || 
        previousMiddleRing != _middleRingActive || 
        previousInnerRing != _innerRingActive) {
      _ringController.forward(from: 0.0);
    }
  }

  void _checkDirectionAlignment() {
    double diff = (_currentHeading - _bearingToTarget).abs();
    if (diff > 180) {
      diff = 360 - diff;
    }
    
    bool isAligned = diff < 15.0;
    
    if (isAligned && !_lastDirectionAligned) {
      _playAlignmentSound();
    }
    
    _lastDirectionAligned = isAligned;
  }

  Future<void> _playAlignmentSound() async {
    try {
      await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
    } catch (e) {
      DebugConfig.printDebug('Alignment sound failed: $e');
    }
  }

  void _onCheckpointReached() {
    _emulatorTimer?.cancel();
    setState(() {
      _hasReachedCheckpoint = true;
      _currentScore += _currentCheckpoint.checkpointConfig.pointBonus;
    });

    final completion = {
      'checkpointId': _currentCheckpoint.id,
      'checkpointName': _currentCheckpoint.name,
      'checkpointOrder': _currentCheckpoint.checkpointOrder,
      'latitude': _currentCheckpoint.latitude,
      'longitude': _currentCheckpoint.longitude,
      'completionTime': DateTime.now(),
      'pointsEarned': _currentCheckpoint.checkpointConfig.pointBonus,
      'timeToReach': _gameTimeSeconds,
      'emulatorMode': _isEmulatorMode,
    };
    _completedCheckpoints.add(completion);
    
    _routeService.recordCheckpointReached(
      checkpointId: _currentCheckpoint.id,
      checkpointName: _currentCheckpoint.name,
      latitude: _currentCheckpoint.latitude,
      longitude: _currentCheckpoint.longitude,
      pointsEarned: _currentCheckpoint.checkpointConfig.pointBonus,
      timeToReach: _gameTimeSeconds,
    );

    _checkMissionCompletion();

    if (_currentCheckpoint.checkpointConfig.photoRequired == true ||
        _currentCheckpoint.checkpointConfig.victoryPhotoRequired == true) {
      _showPhotoRequiredDialog();
    } else {
      _showCheckpointReachedDialog();
    }
  }

  void _checkMissionCompletion() {
    if (_currentCheckpointIndex >= _checkpointSequence.length - 1) {
      setState(() {
        _isMissionComplete = true;
      });
      _gameTimer?.cancel();
    }
  }

  void _proceedToNextCheckpoint() {
    if (_currentCheckpointIndex < _checkpointSequence.length - 1) {
      setState(() {
        _currentCheckpointIndex++;
        _hasReachedCheckpoint = false;
        _isNearCheckpoint = false;
        _outerRingActive = false;
        _middleRingActive = false;
        _innerRingActive = false;
      });

      if (_isEmulatorMode) {
        _emulatorStartTime = DateTime.now();
        _generateEmulatorStartPosition();
        _startEmulatorMovement();
      }
    }
  }

  String _formatGameTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showEmulatorQuickActions() {
    if (!DebugConfig.canUseQuickNavigation) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.orange),
            const SizedBox(width: 8),
            Text('Quick Actions', style: TextStyle(color: AppColors.textPrimary)),
          ],
        ),
        content: ListTile(
          leading: const Icon(Icons.fast_forward, color: Colors.blue),
          title: Text('Quick Reach', style: TextStyle(color: AppColors.textPrimary)),
          onTap: () {
            Navigator.pop(context);
            _emulatorQuickReachCheckpoint();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppColors.disabled)),
          ),
        ],
      ),
    );
  }

  void _emulatorQuickReachCheckpoint() {
    final simulatedPos = {
      'latitude': _currentCheckpoint.latitude,
      'longitude': _currentCheckpoint.longitude,
      'progress': 1.0,
    };
    _updateNavigationDataFromEmulator(simulatedPos);
  }

  void _showPhotoRequiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: Text('Photo Required!', style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Take a photo at ${_currentCheckpoint.name}',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _showCheckpointReachedDialog();
            },
            child: Text('Skip', style: TextStyle(color: AppColors.disabled)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _openPhotoCapture();
            },
            child: const Text('Take Photo'),
          ),
        ],
      ),
    );
  }

  Future<void> _openPhotoCapture() async {
    try {
      await _photoService.initialize();
      final result = await Navigator.push<CheckpointPhoto>(
        context,
        MaterialPageRoute(
          builder: (context) => PhotoCaptureScreen(
            checkpoint: _currentCheckpoint,
            sessionId: _routeService.currentSessionId ?? 'manual_session',
            playerName: widget.playerName,
            currentLatitude: _currentPosition?.latitude,
            currentLongitude: _currentPosition?.longitude,
            onPhotoTaken: () {},
          ),
        ),
      );
      _showCheckpointReachedDialog(photoTaken: result != null);
    } catch (e) {
      _showCheckpointReachedDialog(photoTaken: false);
    }
  }

  void _showCheckpointReachedDialog({bool photoTaken = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.primaryDark,
        title: Text(
          _isMissionComplete ? 'Mission Complete!' : 'Checkpoint Reached!',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _currentCheckpoint.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.emeraldPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '+${_currentCheckpoint.checkpointConfig.pointBonus} Points',
              style: TextStyle(fontSize: 16, color: AppColors.emeraldPrimary),
            ),
          ],
        ),
        actions: [
          if (!_isMissionComplete)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _proceedToNextCheckpoint();
              },
              child: Text('Continue', style: TextStyle(color: AppColors.emeraldPrimary)),
            ),
          if (_isMissionComplete)
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _uploadMissionResults();
              },
              child: const Text('Upload Results'),
            ),
        ],
      ),
    );
  }

  Future<void> _uploadMissionResults() async {
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  Widget _buildCompassWidget() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isNearCheckpoint ? _pulseAnimation.value : 1.0,
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              children: [
                // HAUPTKOMPASS (zuerst, im Hintergrund)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryDark,
                            AppColors.primaryDark.withOpacity(0.8),
                          ],
                        ),
                        border: Border.all(
                          color: AppColors.emeraldPrimary,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldPrimary.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // PROXIMITY RINGE
                          Center(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              width: 240,
                              height: 240,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _outerRingActive ? AppColors.emeraldSecondary : AppColors.disabled,
                                  width: _outerRingActive ? 3 : 1,
                                ),
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 600),
                                  width: 160,
                                  height: 160,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _middleRingActive ? AppColors.emeraldSecondary : AppColors.disabled,
                                      width: _middleRingActive ? 3 : 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 600),
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _innerRingActive ? AppColors.emeraldSecondary : Colors.transparent,
                                        border: _innerRingActive ? null : Border.all(
                                          color: AppColors.disabled,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // KOMPASS HINTERGRUND
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black.withOpacity(0.1),
                                ),
                                child: CustomPaint(
                                  painter: CompassPainter(
                                    showCardinalDirections: _showCardinalDirections,
                                    deviceHeading: 0,
                                    showTickMarks: false,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // KOMPASSNADEL
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Center(
                              child: Transform.rotate(
                                angle: (_currentHeading * math.pi / 180),
                                child: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 95,
                                        left: 97.5,
                                        child: Container(
                                          width: 5,
                                          height: 105,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                              colors: [Colors.white, Color(0xFFE5E7EB)],
                                            ),
                                            borderRadius: BorderRadius.circular(2.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // NADEL-MITTELPUNKT
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Center(
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: AppColors.primaryDark, width: 1),
                                ),
                              ),
                            ),
                          ),
                          
                          // EMULATOR INDIKATOR
                          if (_isEmulatorMode && DebugConfig.isDebugMode)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange, width: 2),
                                ),
                                child: const Icon(Icons.bug_report, color: Colors.white, size: 20),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // ZIELRICHTUNGSINDIKATOR (oben drauf, gut sichtbar)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Center(
                    child: Transform.rotate(
                      angle: (_bearingToTarget * math.pi / 180),
                      child: SizedBox(
                        width: 290, // Etwas größer für bessere Sichtbarkeit
                        height: 290,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 142, // (290 - 6) / 2 = 142
                              child: Container(
                                width: 6,
                                height: 30, // Länger für bessere Sichtbarkeit
                                decoration: BoxDecoration(
                                  color: AppColors.emeraldPrimary,
                                  borderRadius: BorderRadius.circular(3),
                                  // Schatten für bessere Sichtbarkeit
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.emeraldPrimary.withOpacity(0.8),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
              // HEADER
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _showCardinalDirections = !_showCardinalDirections;
                      });
                    },
                    icon: Icon(
                      _showCardinalDirections ? Icons.explore : Icons.explore_off,
                      color: _showCardinalDirections ? AppColors.emeraldPrimary : AppColors.disabled,
                    ),
                  ),
                  if (_isEmulatorMode && DebugConfig.canUseQuickNavigation)
                    IconButton(
                      onPressed: _showEmulatorQuickActions,
                      icon: const Icon(Icons.bug_report, color: Colors.orange),
                    ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_currentScore pts',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // NAVIGATION ICON
              Icon(
                Icons.my_location,
                size: 48,
                color: AppColors.emeraldPrimary,
              ),

              const SizedBox(height: 16),

              // CHECKPOINT INFO
              Column(
                children: [
                  Text(
                    _currentCheckpoint.name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Checkpoint ${_currentCheckpoint.checkpointOrder}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.emeraldPrimary,
                        ),
                      ),
                      if (_isMissionComplete) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 16),
                      ],
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // HAUPTKOMPASS WIDGET
              Expanded(
                child: Center(
                  child: _buildCompassWidget(),
                ),
              ),

              const SizedBox(height: 30),

              // DISTANZ UND NAVIGATION INFO
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primaryDark.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.emeraldPrimary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.straighten, color: AppColors.emeraldPrimary, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          _locationService.formatDistance(_distanceToTarget),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Distance',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.explore, color: AppColors.emeraldPrimary, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          '${_bearingToTarget.toStringAsFixed(0)}°',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          _locationService.bearingToCompass(_bearingToTarget),
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.timer, color: AppColors.emeraldPrimary, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          _formatGameTime(_gameTimeSeconds),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          'Time',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // STATUS NACHRICHT
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isNearCheckpoint 
                      ? AppColors.emeraldPrimary.withOpacity(0.2) 
                      : (_isEmulatorMode 
                          ? Colors.orange.withOpacity(0.1)
                          : AppColors.emeraldPrimary.withOpacity(0.1)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isNearCheckpoint 
                        ? AppColors.emeraldPrimary.withOpacity(0.5)
                        : (_isEmulatorMode 
                            ? Colors.orange.withOpacity(0.3)
                            : AppColors.emeraldPrimary.withOpacity(0.3)),
                  ),
                ),
                child: Text(
                  _isNearCheckpoint 
                      ? '🎉 You\'re at checkpoint ${_currentCheckpoint.checkpointOrder}!'
                      : (_isEmulatorMode 
                          ? '🐛 Emulator: Navigating to checkpoint ${_currentCheckpoint.checkpointOrder}'
                          : '🧭 Follow the arrow to checkpoint ${_currentCheckpoint.checkpointOrder}'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _isNearCheckpoint 
                        ? AppColors.emeraldPrimary 
                        : (_isEmulatorMode ? Colors.orange : AppColors.emeraldPrimary),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 16),

              // EMERGENCY STOP BUTTON
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    _routeService.stopTracking();
                    _emulatorTimer?.cancel();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.stop),
                  label: Text(_isEmulatorMode ? 'End Emulation' : 'End Navigation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Custom Painter für Kompass Hintergrund
class CompassPainter extends CustomPainter {
  final bool showCardinalDirections;
  final double deviceHeading;
  final bool showTickMarks;
  
  CompassPainter({
    this.showCardinalDirections = false,
    this.deviceHeading = 0,
    this.showTickMarks = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..color = AppColors.disabled.withOpacity(0.2)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, radius - 10, paint);
    
    if (showCardinalDirections) {
      final textPainter = TextPainter(
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );
      
      final directions = ['N', 'E', 'S', 'W'];
      final angles = [0, 90, 180, 270];
      
      for (int i = 0; i < directions.length; i++) {
        final angle = (angles[i] - deviceHeading) * math.pi / 180;
        final x = center.dx + (radius - 25) * math.sin(angle);
        final y = center.dy - (radius - 25) * math.cos(angle);
        
        textPainter.text = TextSpan(
          text: directions[i],
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, y - textPainter.height / 2),
        );
      }
    }
    
    if (showTickMarks) {
      final tickPaint = Paint()
        ..color = AppColors.disabled.withOpacity(0.3)
        ..strokeWidth = 1;
      
      for (int i = 0; i < 12; i++) {
        final angle = (i * 30) * math.pi / 180;
        final startRadius = radius - 20;
        final endRadius = radius - 15;
        
        final startX = center.dx + startRadius * math.sin(angle);
        final startY = center.dy - startRadius * math.cos(angle);
        final endX = center.dx + endRadius * math.sin(angle);
        final endY = center.dy - endRadius * math.cos(angle);
        
        canvas.drawLine(
          Offset(startX, startY),
          Offset(endX, endY),
          tickPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CompassPainter oldDelegate) {
    return oldDelegate.showCardinalDirections != showCardinalDirections ||
           oldDelegate.deviceHeading != deviceHeading ||
           oldDelegate.showTickMarks != showTickMarks;
  }
}