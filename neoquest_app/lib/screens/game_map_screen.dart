// lib/screens/game_map_screen.dart
// 20250710 17:22 V1.0: REAL Game Map Screen using actual API data
// 20250711 10:17 V1.1: Added "GPS test navigation" button
// 20250711 10:30 V1.1: Added compass navigation screen
// 20250711 10:33 V1.1: Added "Navigate to Selected" button
// 20250711 11:11 V1.2: Added Route Tracking access
// 20250711 11:44 V1.3: Added access to the photo gallery
// 20250714 10:27 V1.4: Added Waiting for Server screen
// 20250801 19:26 V1.5: Refactored to use centralized AppColors

import 'package:flutter/material.dart';
import '../models/game_models.dart';
import '../constants/app_colors.dart';
import 'location_test_screen.dart';
import 'compass_navigation_screen.dart';
import 'route_tracking_screen.dart';
import 'photo_gallery_screen.dart';
import 'waiting_for_server_screen.dart';

class GameMapScreen extends StatefulWidget {
  final GamePackage gamePackage;
  final String playerName;
  final String token;

  const GameMapScreen({
    super.key,
    required this.gamePackage,
    required this.playerName,
    required this.token,
  });

  @override
  State<GameMapScreen> createState() => _GameMapScreenState();
}

class _GameMapScreenState extends State<GameMapScreen>
    with TickerProviderStateMixin {
  late AnimationController _mapController;
  late Animation<double> _mapAnimation;
  
  int _selectedCheckpoint = 0;

  @override
  void initState() {
    super.initState();
    
    _mapController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _mapAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mapController,
      curve: Curves.easeOutQuart,
    ));
    print('📍 Current Screen: ${runtimeType.toString()}');
    _mapController.forward();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  IconData _getCheckpointIcon(String type) {
    switch (type) {
      case 'start':
        return Icons.play_circle_filled;
      case 'finish':
        return Icons.emoji_events;
      case 'intermediate':
        return Icons.location_on;
      default:
        return Icons.place;
    }
  }

  Color _getCheckpointColor(String type) {
    switch (type) {
      case 'start':
        return AppColors.success;
      case 'finish':
        return AppColors.warning;
      case 'intermediate':
        return AppColors.emeraldPrimary;
      default:
        return AppColors.disabled;
    }
  }

  void _startAdventure() {
    // Navigate to waiting for server instead of direct compass navigation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WaitingForServerScreen(
          playerToken: widget.token,
          playerName: widget.playerName,
          gameData: {
            'gamePackage': widget.gamePackage,
            'gameId': widget.gamePackage.game.id,
            'gameName': widget.gamePackage.game.name,
            'checkpoints': widget.gamePackage.checkpoints,
            'puzzles': widget.gamePackage.puzzles,
            'intro': widget.gamePackage.intro,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.gamePackage.game;
    final checkpoints = widget.gamePackage.checkpoints;
    final selectedCheckpoint = checkpoints[_selectedCheckpoint];

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
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
                        icon: Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              game.name,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Welcome ${widget.playerName}!',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.emeraldPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.success.withOpacity(0.5),
                          ),
                        ),
                        child: Text(
                          '${checkpoints.length} Stops',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    game.description,
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Map Container
            Expanded(
              flex: 3,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.emeraldPrimary.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emeraldPrimary.withOpacity(0.1),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: AnimatedBuilder(
                  animation: _mapAnimation,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _mapAnimation.value,
                      child: Transform.scale(
                        scale: 0.8 + (_mapAnimation.value * 0.2),
                        child: Stack(
                          children: [
                            // Map Background
                            Container(
                              width: double.infinity,
                              height: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppColors.cardBackground,
                                    AppColors.inputBackground,
                                  ],
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Route Line
                                  CustomPaint(
                                    size: Size.infinite,
                                    painter: RoutePainter(
                                      checkpoints: checkpoints,
                                      selectedIndex: _selectedCheckpoint,
                                    ),
                                  ),
                                  
                                  // Checkpoints
                                  ...checkpoints.asMap().entries.map((entry) {
                                    final index = entry.key;
                                    final checkpoint = entry.value;
                                    
                                    // Calculate position (simplified layout)
                                    final double x = 0.2 + (index * 0.6 / (checkpoints.length - 1));
                                    final double y = 0.3 + (index % 2 == 0 ? 0.0 : 0.4);
                                    
                                    return Positioned(
                                      left: x * MediaQuery.of(context).size.width * 0.8,
                                      top: y * 300,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedCheckpoint = index;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          width: _selectedCheckpoint == index ? 60 : 50,
                                          height: _selectedCheckpoint == index ? 60 : 50,
                                          decoration: BoxDecoration(
                                            color: _getCheckpointColor(checkpoint.checkpointType),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.textPrimary,
                                              width: _selectedCheckpoint == index ? 3 : 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _getCheckpointColor(checkpoint.checkpointType)
                                                    .withOpacity(0.4),
                                                blurRadius: _selectedCheckpoint == index ? 15 : 8,
                                                spreadRadius: _selectedCheckpoint == index ? 3 : 1,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _getCheckpointIcon(checkpoint.checkpointType),
                                            color: AppColors.textPrimary,
                                            size: _selectedCheckpoint == index ? 30 : 24,
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),

                            // Map Title
                            Positioned(
                              top: 20,
                              left: 20,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryDark.withOpacity(0.8),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.emeraldPrimary.withOpacity(0.3),
                                  ),
                                ),
                                child: Text(
                                  'Möllersdorf Route',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // Checkpoint Details
            Expanded(
              flex: 2,
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
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
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getCheckpointColor(selectedCheckpoint.checkpointType),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _getCheckpointColor(selectedCheckpoint.checkpointType).withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            _getCheckpointIcon(selectedCheckpoint.checkpointType),
                            color: AppColors.textPrimary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Stop ${selectedCheckpoint.checkpointOrder}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.emeraldPrimary,
                                ),
                              ),
                              Text(
                                selectedCheckpoint.name,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${selectedCheckpoint.checkpointConfig.pointBonus} pts',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.warning,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Text(
                      selectedCheckpoint.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Special Features
                    if (selectedCheckpoint.checkpointConfig.photoRequired == true) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.camera_alt,
                            color: AppColors.emeraldPrimary,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Photo required',
                            style: TextStyle(
                              color: AppColors.emeraldPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    if (selectedCheckpoint.checkpointConfig.safetyWarning != null) ...[
                      Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: AppColors.warning,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedCheckpoint.checkpointConfig.safetyWarning!,
                              style: TextStyle(
                                color: AppColors.warning,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],

                    // GPS Coordinates
                    Row(
                      children: [
                        Icon(
                          Icons.gps_fixed,
                          color: AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${selectedCheckpoint.latitude.toStringAsFixed(5)}, ${selectedCheckpoint.longitude.toStringAsFixed(5)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Navigate to Checkpoint Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CompassNavigationScreen(
                                startFromCheckpointOrder: selectedCheckpoint.checkpointOrder,
                                gamePackage: widget.gamePackage,
                                playerName: widget.playerName,
                                token: widget.token,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate to This Checkpoint'),
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
                  ],
                ),
              ),
            ),

            // Action Buttons
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  // Row 1: GPS Test and Route Tracking
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LocationTestScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.gps_fixed),
                          label: const Text('GPS Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emeraldPrimary,
                            foregroundColor: AppColors.primaryDark,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.emeraldPrimary.withOpacity(0.4),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RouteTrackingScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.route),
                          label: const Text('Routes'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.info,
                            foregroundColor: AppColors.textPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            shadowColor: AppColors.info.withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Row 2: Photo Gallery
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const PhotoGalleryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Photo Gallery'),
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
                  
                  // Row 3: Start Adventure Button
                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppColors.emeraldGlowShadow,
                      ),
                      child: ElevatedButton(
                        onPressed: _startAdventure,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: AppColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 6,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.navigation,
                              color: AppColors.textPrimary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Join Adventure',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Custom Route Painter
class RoutePainter extends CustomPainter {
  final List<Checkpoint> checkpoints;
  final int selectedIndex;

  RoutePainter({
    required this.checkpoints,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.emeraldPrimary.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final selectedPaint = Paint()
      ..color = AppColors.emeraldPrimary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    // Draw route line connecting checkpoints
    for (int i = 0; i < checkpoints.length - 1; i++) {
      final x1 = 0.2 + (i * 0.6 / (checkpoints.length - 1));
      final y1 = 0.3 + (i % 2 == 0 ? 0.0 : 0.4);
      final x2 = 0.2 + ((i + 1) * 0.6 / (checkpoints.length - 1));
      final y2 = 0.3 + ((i + 1) % 2 == 0 ? 0.0 : 0.4);

      canvas.drawLine(
        Offset(x1 * size.width, y1 * size.height),
        Offset(x2 * size.width, y2 * size.height),
        i == selectedIndex || i + 1 == selectedIndex ? selectedPaint : paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}