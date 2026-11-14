// lib/services/api_service.dart
// Enhanced version with dynamic server URL management
// 20250803 15:03 V1.0 - Added server URL management
// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // Internal server URL storage
  static String? _baseUrl;
  
  // Default fallback URL (Android Emulator)
  static const String _defaultUrl = 'http://10.0.2.2:3000/api';
  
  // Getter for the current Base URL
  static String get baseUrl {
    return _baseUrl ?? _defaultUrl;
  }
  
  // Check if server URL is set
  static bool get isServerSet => _baseUrl != null;
  
  // Set server URL manually (from connection screen)
  static void setServerUrl(String url) {
    // Ensure URL format is correct
    String cleanUrl = url.trim();
    
    // Remove trailing slash
    if (cleanUrl.endsWith('/')) {
      cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    }
    
    // Add http:// if missing
    if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
      cleanUrl = 'http://$cleanUrl';
    }
    
    // Add /api if missing
    if (!cleanUrl.endsWith('/api')) {
      cleanUrl = '$cleanUrl/api';
    }
    
    _baseUrl = cleanUrl;
    print('🔧 Server URL set to: $_baseUrl');
  }
  
  // Clear server URL (for reset)
  static void clearServerUrl() {
    _baseUrl = null;
    print('🔄 Server URL cleared, using default: $_defaultUrl');
  }
  
  // Get current server info (for debugging)
  static Map<String, String> getServerInfo() {
    return {
      'current_url': baseUrl,
      'is_custom': _baseUrl != null ? 'true' : 'false',
      'default_url': _defaultUrl,
    };
  }
// Register Player with Details
  static Future<Map<String, dynamic>> registerPlayerWithDetails({
    required String qrToken,
    required String playerName,
    String? email,
  }) async {
    print('🌐 [ApiService] Sending registration to: $baseUrl/auth/register-with-details');
    print('🌐 [ApiService] Request data: qrToken=$qrToken, playerName=$playerName, email=$email');
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register-with-details'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'qr_token': qrToken,
        'player_name': playerName,
        'email': email,
      }),
    );

    print('🌐 [ApiService] Response status: ${response.statusCode}');
    print('🌐 [ApiService] Response body: ${response.body}');

    final data = json.decode(response.body);
    return data;
  }
  
  // Test server connection
  static Future<bool> testConnection() async {
    try {
      final healthUrl = baseUrl.replaceAll('/api', '/health');
      final response = await http.get(
        Uri.parse(healthUrl),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  // Register player with QR code
  static Future<Map<String, dynamic>> registerPlayer(String qrContent) async {
    try {
      final requestBody = {
        'qr_content': qrContent,
        'player_name': 'Test Player',
      };
      
      print('Sending registration request to: $baseUrl/auth/register');
      print('Request body: ${jsonEncode(requestBody)}');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('Registration response: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Registration failed: ${response.statusCode}',
          'details': response.body,
        };
      }
    } catch (e) {
      print('Registration error: $e');
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> createPlayer({
    required String playerName,
    String? email,
  }) async {
    print('🌐 [ApiService] Creating player: $baseUrl/auth/create-player');
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/create-player'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'player_name': playerName,
        'email': email,
      }),
    );

    print('🌐 [ApiService] Response status: ${response.statusCode}');
    final data = json.decode(response.body);
    return data;
  }

  // Token mit Player verknüpfen
  static Future<Map<String, dynamic>> linkTokenToPlayer({
    required int playerId,
    required String qrToken,
  }) async {
    print('🌐 [ApiService] Linking token: $baseUrl/auth/link-token');
    
    final response = await http.post(
      Uri.parse('$baseUrl/auth/link-token'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'player_id': playerId,
        'qr_token': qrToken,
      }),
    );

    print('🌐 [ApiService] Response status: ${response.statusCode}');
    final data = json.decode(response.body);
    return data;
  }

  // Get game data for player
  static Future<Map<String, dynamic>> getGameData(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/game/data'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return {
          'success': true,
          'data': jsonDecode(response.body),
        };
      } else {
        return {
          'success': false,
          'error': 'Failed to get game data: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Network error: $e',
      };
    }
  }
}