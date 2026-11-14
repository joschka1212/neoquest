// lib/screens/route_tracking_screen.dart
// 20250711 11:08 V1.0: Route tracking management and visualization screen
// 20250801 19:11 V1.1: Refactored to use centralized AppColors

import 'package:flutter/material.dart';
import 'dart:async';
import '../services/route_tracking_service.dart';
import '../constants/app_colors.dart';

class RouteTrackingScreen extends StatefulWidget {
  const RouteTrackingScreen({super.key});

  @override
  State<RouteTrackingScreen> createState() => _RouteTrackingScreenState();
}

class _RouteTrackingScreenState extends State<RouteTrackingScreen> {
  final RouteTrackingService _routeService = RouteTrackingService();
  RouteSessionStats? _currentStats;
  List<RouteSession> _allSessions = [];
  Timer? _statsTimer;
  
  // Configuration
  int _trackingInterval = 30;
  double _minimumDistance = 5.0;

  @override
  void initState() {
    super.initState();
    print('📍 Current Screen: ${runtimeType.toString()}');
    _initializeService();
    _loadSessions();
    _startStatsUpdates();
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    await _routeService.initialize();
    _routeService.configureTracking(
      intervalSeconds: _trackingInterval,
      minimumDistanceMeters: _minimumDistance,
    );
  }

  Future<void> _loadSessions() async {
    final sessions = await _routeService.getAllRouteSessions();
    setState(() {
      _allSessions = sessions;
    });
  }

  void _startStatsUpdates() {
    _statsTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      _updateCurrentStats();
    });
  }

  Future<void> _updateCurrentStats() async {
    final stats = await _routeService.getCurrentSessionStats();
    setState(() {
      _currentStats = stats;
    });
  }

  Future<void> _startTestTracking() async {
    final success = await _routeService.startTracking(
      playerName: 'Test Player',
      playerToken: 'TEST123',
      gameId: 1,
      checkpointTarget: 'Bridge over Mühlbach',
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Route tracking started',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to start tracking',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.redAlert,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _stopTracking() async {
    await _routeService.stopTracking();
    await _loadSessions(); // Refresh sessions list
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Route tracking stopped',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.warning,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _exportSession(String sessionId) async {
    final jsonData = await _routeService.exportSessionAsJson(sessionId);
    
    if (jsonData != null) {
      // In a real app, you'd save this to file or share it
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Export Complete',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Route data exported as JSON',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Data size: ${(jsonData.length / 1024).toStringAsFixed(1)} KB',
                  style: TextStyle(
                    color: AppColors.emeraldPrimary,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'OK',
                style: TextStyle(color: AppColors.emeraldPrimary),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tracking Configuration',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Recording Interval: ${_trackingInterval}s',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.emeraldPrimary,
                    inactiveTrackColor: AppColors.disabled,
                    thumbColor: AppColors.emeraldPrimary,
                    overlayColor: AppColors.emeraldPrimary.withOpacity(0.2),
                    valueIndicatorColor: AppColors.emeraldPrimary,
                    valueIndicatorTextStyle: TextStyle(color: AppColors.primaryDark),
                  ),
                  child: Slider(
                    value: _trackingInterval.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 11,
                    label: '${_trackingInterval}s',
                    onChanged: (value) {
                      setDialogState(() {
                        _trackingInterval = value.round();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Minimum Distance: ${_minimumDistance.toStringAsFixed(1)}m',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.emeraldPrimary,
                    inactiveTrackColor: AppColors.disabled,
                    thumbColor: AppColors.emeraldPrimary,
                    overlayColor: AppColors.emeraldPrimary.withOpacity(0.2),
                    valueIndicatorColor: AppColors.emeraldPrimary,
                    valueIndicatorTextStyle: TextStyle(color: AppColors.primaryDark),
                  ),
                  child: Slider(
                    value: _minimumDistance,
                    min: 1.0,
                    max: 20.0,
                    divisions: 19,
                    label: '${_minimumDistance.toStringAsFixed(1)}m',
                    onChanged: (value) {
                      setDialogState(() {
                        _minimumDistance = value;
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _routeService.configureTracking(
                  intervalSeconds: _trackingInterval,
                  minimumDistanceMeters: _minimumDistance,
                );
              });
              Navigator.pop(context);
            },
            child: Text(
              'Apply',
              style: TextStyle(color: AppColors.emeraldPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTrackingCard() {
    if (!_routeService.isTracking) {
      return Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.location_off,
                size: 48,
                color: AppColors.disabled,
              ),
              const SizedBox(height: 12),
              Text(
                'Route Tracking Inactive',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking to record player routes',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startTestTracking,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Start Test Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: AppColors.textPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showConfigDialog,
                    icon: const Icon(Icons.settings),
                    label: const Text('Config'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: AppColors.primaryDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Active tracking display
    return Card(
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.radio_button_checked,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Recording Route',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _stopTracking,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.redAlert,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
              
              if (_currentStats != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Duration',
                        _formatDuration(_currentStats!.duration),
                        Icons.timer,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Points',
                        '${_currentStats!.pointsRecorded}',
                        Icons.location_on,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        'Distance',
                        '${_currentStats!.totalDistance.toStringAsFixed(0)}m',
                        Icons.straighten,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Player: ${_currentStats!.playerName}',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Session: ${_currentStats!.sessionId}',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        'Config: ${_trackingInterval}s interval, ${_minimumDistance}m minimum',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
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
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.emeraldPrimary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsList() {
    if (_allSessions.isEmpty) {
      return Card(
        color: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(
                Icons.route,
                size: 48,
                color: AppColors.disabled,
              ),
              const SizedBox(height: 16),
              Text(
                'No Route Sessions Yet',
                style: TextStyle(
                  fontSize: 18,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start tracking to create your first route',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Route Sessions (${_allSessions.length})',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _allSessions.length,
          itemBuilder: (context, index) {
            final session = _allSessions[index];
            return _buildSessionCard(session);
          },
        ),
      ],
    );
  }

  Widget _buildSessionCard(RouteSession session) {
    final duration = session.endTime?.difference(session.startTime) ?? 
                    DateTime.now().difference(session.startTime);
    
    final isActive = session.status == 'active';
    final statusColor = isActive ? AppColors.success : AppColors.emeraldPrimary;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.cardBackground,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.radio_button_checked : Icons.check_circle,
                  color: statusColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    session.playerName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    session.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildSessionStat(
                    'Duration',
                    _formatDuration(duration),
                    Icons.timer,
                  ),
                ),
                Expanded(
                  child: _buildSessionStat(
                    'Distance',
                    '${session.totalDistance.toStringAsFixed(0)}m',
                    Icons.straighten,
                  ),
                ),
                Expanded(
                  child: _buildSessionStat(
                    'Game ID',
                    '${session.gameId}',
                    Icons.games,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Started: ${_formatDateTime(session.startTime)}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (session.endTime != null)
                    Text(
                      'Ended: ${_formatDateTime(session.endTime!)}',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  if (session.checkpointTarget != null)
                    Text(
                      'Target: ${session.checkpointTarget}',
                      style: TextStyle(
                        color: AppColors.emeraldPrimary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showRouteDetails(session),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emeraldPrimary,
                      foregroundColor: AppColors.primaryDark,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _exportSession(session.id),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Export'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning,
                    foregroundColor: AppColors.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.emeraldPrimary, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  void _showRouteDetails(RouteSession session) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Route Details: ${session.playerName}',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: FutureBuilder<List<RoutePoint>>(
          future: _routeService.getRoutePoints(session.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SizedBox(
                height: 100,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
                  ),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Text(
                'No route points recorded',
                style: TextStyle(color: AppColors.textSecondary),
              );
            }

            final points = snapshot.data!;
            return SizedBox(
              width: double.maxFinite,
              height: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${points.length} GPS points recorded',
                    style: TextStyle(
                      color: AppColors.emeraldPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: points.length,
                      itemBuilder: (context, index) {
                        final point = points[index];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppColors.emeraldPrimary,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          title: Text(
                            '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                          subtitle: Text(
                            '${_formatDateTime(point.timestamp)} • Accuracy: ${point.accuracy?.toStringAsFixed(1)}m',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: AppColors.emeraldPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    
    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    } else {
      return '$minutes:$seconds';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month} ${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
  }

  String twoDigits(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        title: Text(
          'Route Tracking',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.primaryDark,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        actions: [
          IconButton(
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh sessions',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Current tracking status
            _buildCurrentTrackingCard(),
            
            const SizedBox(height: 24),
            
            // Sessions list
            _buildSessionsList(),
          ],
        ),
      ),
    );
  }
}