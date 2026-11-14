// lib/config/smart_network_config.dart
import 'package:http/http.dart' as http;

class SmartNetworkConfig {
  static const int serverPort = 3000;
  static const Duration connectionTimeout = Duration(seconds: 3);
  
  // Cached working URL
  static String? _cachedWorkingUrl;
  static DateTime? _lastCheck;
  static const Duration cacheValidDuration = Duration(minutes: 5);
  
  /// Generate potential server URLs to try
  static List<String> _generateServerUrls() {
    return [
      // Android Emulator default
      'http://10.0.2.2:$serverPort',
      
      // Common LAN IP ranges
      'http://192.168.1.100:$serverPort',
      'http://192.168.1.101:$serverPort',
      'http://192.168.1.102:$serverPort',
      'http://192.168.30.97:$serverPort',
      'http://192.168.30.98:$serverPort',
      'http://192.168.30.99:$serverPort',
      'http://192.168.0.100:$serverPort',
      'http://192.168.0.101:$serverPort',
      
      // Localhost variants
      'http://127.0.0.1:$serverPort',
      'http://localhost:$serverPort',
    ];
  }
  
  /// Test if a URL is reachable
  static Future<bool> _testUrl(String url) async {
    try {
      print('🔍 Testing: $url');
      
      final response = await http.get(
        Uri.parse('$url/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(connectionTimeout);
      
      if (response.statusCode == 200) {
        print('✅ Success: $url');
        return true;
      } else {
        print('❌ HTTP ${response.statusCode}: $url');
        return false;
      }
    } catch (e) {
      print('❌ Failed: $url - $e');
      return false;
    }
  }
  
  /// Find working server URL with smart caching
  static Future<String?> findWorkingServerUrl({bool forceRefresh = false}) async {
    // Check cache validity
    if (!forceRefresh && 
        _cachedWorkingUrl != null && 
        _lastCheck != null && 
        DateTime.now().difference(_lastCheck!).inMinutes < cacheValidDuration.inMinutes) {
      print('📦 Using cached server URL: $_cachedWorkingUrl');
      return _cachedWorkingUrl;
    }
    
    print('🔄 Searching for NeoQuest server...');
    
    // Test cached URL first (if exists)
    if (_cachedWorkingUrl != null) {
      print('🎯 Testing cached URL first: $_cachedWorkingUrl');
      if (await _testUrl(_cachedWorkingUrl!)) {
        _lastCheck = DateTime.now();
        return _cachedWorkingUrl;
      } else {
        print('💥 Cached URL no longer working, searching...');
        _cachedWorkingUrl = null;
      }
    }
    
    // Test all potential URLs
    final urls = _generateServerUrls();
    
    for (String url in urls) {
      if (await _testUrl(url)) {
        _cachedWorkingUrl = url;
        _lastCheck = DateTime.now();
        print('🎉 Found working server: $url');
        return url;
      }
    }
    
    print('💥 No working server found! Check if NeoQuest server is running.');
    return null;
  }
  
  /// Get server URL with automatic discovery
  static Future<String> getServerUrl() async {
    final url = await findWorkingServerUrl();
    
    if (url == null) {
      throw Exception(
        'NeoQuest server not found. Please ensure the server is running and accessible.'
      );
    }
    
    return url;
  }
  
  /// Force refresh server discovery
  static Future<String?> refreshServerUrl() async {
    return await findWorkingServerUrl(forceRefresh: true);
  }
  
  /// Get server info for debugging
  static Map<String, dynamic> getDebugInfo() {
    return {
      'cached_url': _cachedWorkingUrl,
      'last_check': _lastCheck?.toIso8601String(),
      'cache_valid': _lastCheck != null && 
                     DateTime.now().difference(_lastCheck!).inMinutes < cacheValidDuration.inMinutes,
      'potential_urls': _generateServerUrls(),
    };
  }
  
  /// Network diagnostics
  static Future<Map<String, dynamic>> runDiagnostics() async {
    print('🔬 Running network diagnostics...');
    
    final results = <String, bool>{};
    final urls = _generateServerUrls();
    
    for (String url in urls) {
      results[url] = await _testUrl(url);
    }
    
    final workingUrls = results.entries.where((e) => e.value).map((e) => e.key).toList();
    
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'results': results,
      'working_urls': workingUrls,
      'working_count': workingUrls.length,
      'cached_url': _cachedWorkingUrl,
    };
  }
}

// Helper class for endpoints
class ServerEndpoints {
  static const String health = '/health';
  static const String register = '/api/auth/register';
  static const String gameData = '/api/game/data';
  static const String gameMedia = '/api/game/media';
  static const String adminPlayers = '/api/admin/players';
  static const String adminStats = '/api/admin/stats';
}