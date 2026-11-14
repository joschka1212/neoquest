// lib/constants/app_colors.dart
// Central color definitions for the NeoQuest App
// Emerald Color Scheme - Consistent across all screens
// Version 1.0 - 2025-08-01

import 'package:flutter/material.dart';

class AppColors {
  // Prevents instantiation of this utility class
  AppColors._();

  // === PRIMARY COLORS ===
  
  /// Main background - Very dark black
  static const Color primaryDark = Color(0xFF0A0A0A);
  
  /// Emerald primary color - Main accent for buttons, icons, highlights
  static const Color emeraldPrimary = Color(0xFF10B981);
  
  /// Emerald secondary - Darker emerald for contrasts and variations
  static const Color emeraldSecondary = Color(0xFF047857);
  
  /// Emerald glow - Lighter emerald for glow effects and shadows
  static const Color emeraldGlow = Color(0xFF6EE7B7);
  
  /// Emerald light - Light emerald for progress bars and subtle accents
  static const Color emeraldLight = Color(0xFF34D399);

  // === TEXT COLORS ===
  
  /// Primary text - Pure white for main texts
  static const Color textPrimary = Colors.white;
  
  /// Secondary text - 70% white for less important texts
  static const Color textSecondary = Colors.white70;
  
  /// Tertiary text - 54% white for very subtle texts
  static const Color textTertiary = Colors.white54;

  // === SYSTEM COLORS ===
  
  /// Alert/Error color - Red alert for error messages
  static const Color redAlert = Color(0xFFEF4444);
  
  /// Success color - Uses emeraldPrimary for success messages
  static const Color success = emeraldPrimary;
  
  /// Warning color - Amber for warnings
  static const Color warning = Color(0xFFF59E0B);
  
  /// Info color - Blue tones for information
  static const Color info = Color(0xFF3B82F6);

  // === UI ELEMENT COLORS ===
  
  /// Background for cards/containers - Slightly brightened black
  static const Color cardBackground = Color(0xFF1A1A1A);
  
  /// Background for input fields
  static const Color inputBackground = Color(0xFF2A2A2A);
  
  /// Border color for inactive elements
  static const Color borderInactive = Color(0xFF404040);
  
  /// Border color for active elements
  static const Color borderActive = emeraldPrimary;
  
  /// Disabled element color
  static const Color disabled = Color(0xFF666666);

  // === OVERLAY & TRANSPARENCIES ===
  
  /// Dark overlay for modals/dialogs
  static const Color overlayDark = Color(0x80000000);
  
  /// Emerald with various transparencies for glow effects
  static Color emeraldGlow10 = emeraldGlow.withOpacity(0.1);
  static Color emeraldGlow20 = emeraldGlow.withOpacity(0.2);
  static Color emeraldGlow30 = emeraldGlow.withOpacity(0.3);
  
  static Color emeraldPrimary10 = emeraldPrimary.withOpacity(0.1);
  static Color emeraldPrimary20 = emeraldPrimary.withOpacity(0.2);
  static Color emeraldPrimary30 = emeraldPrimary.withOpacity(0.3);

  // === GRADIENT DEFINITIONS ===
  
  /// Emerald gradient for buttons and highlights
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [emeraldLight, emeraldPrimary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  /// Dark gradient for backgrounds
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF0A0A0A), Color(0xFF1A1A1A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // === SHADOW DEFINITIONS ===
  
  /// Emerald glow shadow - for complete elements
  static List<BoxShadow> get emeraldGlowShadow => [
    BoxShadow(
      color: emeraldPrimary.withOpacity(0.15),
      blurRadius: 15,
      spreadRadius: 3,
    ),
    BoxShadow(
      color: emeraldGlow.withOpacity(0.08),
      blurRadius: 25,
      spreadRadius: 5,
    ),
  ];
  
  /// Subtle emerald shadow - for text and smaller elements
  static List<Shadow> get emeraldTextShadow => [
    Shadow(
      color: emeraldPrimary.withOpacity(0.3),
      blurRadius: 5,
    ),
  ];
  
  /// Very subtle emerald shadow - for less prominent elements
  static List<Shadow> get emeraldTextShadowSubtle => [
    Shadow(
      color: emeraldPrimary.withOpacity(0.2),
      blurRadius: 3,
    ),
  ];

  // === USAGE EXAMPLES (Comments) ===
  
  /*
  USAGE IN SCREENS:

  import '../constants/app_colors.dart';

  // Background
  backgroundColor: AppColors.primaryDark,

  // Primary button
  ElevatedButton(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.emeraldPrimary,
      foregroundColor: AppColors.primaryDark,
    ),
    child: Text('Button'),
  )

  // Text with glow
  Text(
    'Glowing Text',
    style: TextStyle(
      color: AppColors.textPrimary,
      shadows: AppColors.emeraldTextShadow,
    ),
  )

  // Container with glow
  Container(
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      boxShadow: AppColors.emeraldGlowShadow,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ...,
  )

  // Progress indicator
  CircularProgressIndicator(
    valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldLight),
    backgroundColor: AppColors.disabled,
  )
  */
}