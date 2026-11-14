// lib/screens/leaderboard_screen.dart
// Leaderboard Screen for Mission Results
// 20250712 11:04 V1.0: File created
// 20250801 19:23 V1.1: Refactored to use centralized AppColors and fixed method calls

import 'package:flutter/material.dart';
import '../services/mission_upload_service.dart';
import '../constants/app_colors.dart';

class LeaderboardScreen extends StatefulWidget {
  final int? gameId;
  final String? playerToken;

  const LeaderboardScreen({
    super.key,
    this.gameId,
    this.playerToken,
  });

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  final MissionUploadService _uploadService = MissionUploadService();
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  // Mock data for now since service methods don't exist yet
  List<MockLeaderboardEntry> _leaderboardEntries = [];
  MockPlayerStatus? _playerStatus;
  bool _isLoading = true;
  String? _error;
  
  @override
  void initState() {
    super.initState();
    print('📍 Current Screen: ${runtimeType.toString()}');
    _initializeAnimations();
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
  }

  Future<void> _loadLeaderboard() async {
    try {
      await _uploadService.initialize();
      
      // Simulate loading delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Mock leaderboard data since service methods don't exist yet
      // TODO: Replace with actual service calls when implemented
      _leaderboardEntries = _generateMockLeaderboard();
      
      // Mock player status if token provided
      if (widget.playerToken != null) {
        _playerStatus = MockPlayerStatus(
          playerName: 'Current Player',
          finalScore: 850,
          status: 'Completed',
          progress: 100,
        );
      }
      
      setState(() {
        _isLoading = false;
      });
      
      _fadeController.forward();
      
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<MockLeaderboardEntry> _generateMockLeaderboard() {
    return [
      MockLeaderboardEntry(1, 'Alex Martinez', 1250, '15:23', '2.1 km'),
      MockLeaderboardEntry(2, 'Sarah Chen', 1180, '16:45', '2.3 km'),
      MockLeaderboardEntry(3, 'Mike Johnson', 1120, '17:12', '2.0 km'),
      MockLeaderboardEntry(4, 'Emma Wilson', 1050, '18:34', '2.4 km'),
      MockLeaderboardEntry(5, 'David Brown', 980, '19:56', '2.2 km'),
      MockLeaderboardEntry(6, 'Lisa Garcia', 920, '20:15', '2.5 km'),
      MockLeaderboardEntry(7, 'Tom Anderson', 860, '21:03', '2.1 km'),
      MockLeaderboardEntry(8, 'Current Player', 850, '21:45', '2.3 km'),
      MockLeaderboardEntry(9, 'Kate Miller', 820, '22:18', '2.4 km'),
      MockLeaderboardEntry(10, 'James Davis', 780, '23:12', '2.0 km'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldPrimary.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.leaderboard,
                      color: AppColors.warning,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Leaderboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _refresh,
                icon: Icon(Icons.refresh, color: AppColors.textPrimary),
              ),
            ],
          ),
          
          if (!_isLoading && _error == null) ...[
            const SizedBox(height: 16),
            _buildStatistics(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatistics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.1),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard(
            'Total Players',
            '${_leaderboardEntries.length}',
            Icons.people,
            AppColors.info,
          ),
          _buildStatCard(
            'Completed',
            '${_leaderboardEntries.length}',
            Icons.check_circle,
            AppColors.success,
          ),
          _buildStatCard(
            'Avg Score',
            '${_calculateAverageScore()}',
            Icons.stars,
            AppColors.warning,
          ),
        ],
      ),
    );
  }

  int _calculateAverageScore() {
    if (_leaderboardEntries.isEmpty) return 0;
    final total = _leaderboardEntries.fold<int>(0, (sum, entry) => sum + entry.score);
    return (total / _leaderboardEntries.length).round();
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
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

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Loading leaderboard...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
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
                  size: 48,
                  color: AppColors.redAlert,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Failed to load leaderboard',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _refresh,
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
      );
    }

    if (_leaderboardEntries.isEmpty) {
      return Center(
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
                      color: AppColors.warning.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'No completed missions yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Be the first to complete a mission!',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        children: [
          // Player's current status (if available)
          if (_playerStatus != null && widget.playerToken != null)
            _buildPlayerStatus(),
          
          // Leaderboard list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _leaderboardEntries.length,
              itemBuilder: (context, index) {
                final entry = _leaderboardEntries[index];
                final isCurrentPlayer = widget.playerToken != null && 
                                      entry.playerName == 'Current Player';
                
                return _buildLeaderboardEntry(entry, isCurrentPlayer);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerStatus() {
    if (_playerStatus == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.emeraldPrimary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.emeraldPrimary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.emeraldPrimary.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.emeraldPrimary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: AppColors.emeraldPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Your Status: ${_playerStatus!.playerName}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.emeraldPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatusItem(
                'Score',
                '${_playerStatus!.finalScore}',
                Icons.stars,
              ),
              _buildStatusItem(
                'Status',
                _playerStatus!.status,
                Icons.upload,
              ),
              _buildStatusItem(
                'Progress',
                '${_playerStatus!.progress}%',
                Icons.progress_activity,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textSecondary, size: 16),
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
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderboardEntry(MockLeaderboardEntry entry, bool isCurrentPlayer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentPlayer 
            ? AppColors.emeraldPrimary.withOpacity(0.1)
            : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrentPlayer 
              ? AppColors.emeraldPrimary
              : AppColors.borderInactive,
          width: isCurrentPlayer ? 2 : 1,
        ),
        boxShadow: isCurrentPlayer ? [
          BoxShadow(
            color: AppColors.emeraldPrimary.withOpacity(0.2),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ] : [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank badge
          _buildRankBadge(entry.rank),
          
          const SizedBox(width: 16),
          
          // Player info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.playerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isCurrentPlayer 
                              ? AppColors.emeraldPrimary
                              : AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentPlayer) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.emeraldPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'YOU',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.time,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.straighten,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      entry.distance,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Score
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: _getScoreColor(entry.rank).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getScoreColor(entry.rank).withOpacity(0.5),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '${entry.score}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _getScoreColor(entry.rank),
                  ),
                ),
                Text(
                  'points',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge(int rank) {
    Color badgeColor;
    IconData? icon;
    
    switch (rank) {
      case 1:
        badgeColor = AppColors.warning;
        icon = Icons.emoji_events;
        break;
      case 2:
        badgeColor = AppColors.disabled;
        icon = Icons.emoji_events;
        break;
      case 3:
        badgeColor = const Color(0xFFCD7F32); // Bronze color
        icon = Icons.emoji_events;
        break;
      default:
        badgeColor = AppColors.emeraldPrimary;
        break;
    }
    
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: badgeColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: badgeColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: icon != null 
            ? Icon(
                icon,
                color: badgeColor,
                size: 24,
              )
            : Text(
                '$rank',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: badgeColor,
                ),
              ),
      ),
    );
  }

  Color _getScoreColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.warning; // Gold
      case 2:
        return AppColors.disabled; // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.emeraldPrimary;
    }
  }

  void _refresh() {
    setState(() {
      _isLoading = true;
      _error = null;
      _leaderboardEntries = [];
      _playerStatus = null;
    });
    _fadeController.reset();
    _loadLeaderboard();
  }
}

// Mock data classes until the actual service methods are implemented
class MockLeaderboardEntry {
  final int rank;
  final String playerName;
  final int score;
  final String time;
  final String distance;

  MockLeaderboardEntry(this.rank, this.playerName, this.score, this.time, this.distance);
}

class MockPlayerStatus {
  final String playerName;
  final int finalScore;
  final String status;
  final int progress;

  MockPlayerStatus({
    required this.playerName,
    required this.finalScore,
    required this.status,
    required this.progress,
  });
}