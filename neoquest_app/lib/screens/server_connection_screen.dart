// lib/screens/server_connection_screen.dart
// Server connection screen with automatic discovery and manual input
// 20250803 V1.0 Initial implementation
// lib/screens/server_connection_screen.dart
// Server connection screen with automatic discovery and manual input
// Matches the UI style of qr_scanner_screen.dart
// 20250803 V1.0 Initial implementation

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'player_registration_screen.dart';

class ServerConnectionScreen extends StatefulWidget {
  const ServerConnectionScreen({super.key});

  @override
  State<ServerConnectionScreen> createState() => _ServerConnectionScreenState();
}

class _ServerConnectionScreenState extends State<ServerConnectionScreen>
    with TickerProviderStateMixin {
  
  final TextEditingController _ipController = TextEditingController();
  late AnimationController _pulseController;
  late AnimationController _scanController;
  
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  String _statusMessage = 'Ready to scan for servers';
  String? _foundServerUrl;
  List<String> _foundServers = [];
  
  // Server candidates for auto-discovery
  static const List<String> _serverCandidates = [
    '10.0.2.2:3000',        // Android Emulator
    '192.168.1.100:3000',   // Common LAN range
    '192.168.0.100:3000',   // Alternative LAN range
    '192.168.1.101:3000',   // Next IP
    '192.168.1.102:3000',   // Next IP
    '192.168.178.100:3000', // German Fritzbox default range
    'localhost:3000',       // Localhost fallback
  ];

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    _scanController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    // Listen to text changes
    _ipController.addListener(() {
      setState(() {});
    });
    
    // Auto-start scanning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAutoScan();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _pulseController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  // Build the top icon matching the QR scanner style
  Widget _buildTopIcon() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _pulseController.value * 0.2 + 0.8;
        
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 80,
            height: 80,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.wifi_find,
                  size: 80,
                  color: _isConnected 
                      ? AppColors.emeraldPrimary
                      : _isScanning 
                          ? AppColors.emeraldPrimary  // <- Grün auch beim Scannen
                          : AppColors.emeraldPrimary, // <- Grün als Standard
                ),
                if (_isScanning)
                  AnimatedBuilder(
                    animation: _scanController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _scanController.value * 6.28, // 2π for full rotation
                        child: Icon(
                          Icons.radar,
                          size: 40,
                          color: AppColors.warning.withOpacity(0.7),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Auto-scan for servers
  Future<void> _startAutoScan() async {
    if (_isScanning) return;
    
    setState(() {
      _isScanning = true;
      _statusMessage = 'Scanning for NeoQuest servers...';
      _foundServers.clear();
    });
    
    _scanController.repeat();
    
    // Test each candidate
    for (String candidate in _serverCandidates) {
      if (!_isScanning) break; // User might have stopped
      
      setState(() {
        _statusMessage = 'Testing: $candidate';
      });
      
      final isReachable = await _testServerConnection(candidate);
      if (isReachable) {
        setState(() {
          _foundServers.add(candidate);
          if (_foundServerUrl == null) {
            _foundServerUrl = candidate;
          }
        });
      }
      
      // Small delay for UI smoothness
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    _scanController.stop();
    
    setState(() {
      _isScanning = false;
      if (_foundServers.isNotEmpty) {
        _statusMessage = 'Found ${_foundServers.length} server(s)';
        _foundServerUrl = _foundServers.first;
      } else {
        _statusMessage = 'No servers found. Enter IP manually.';
      }
    });
  }

  // Test a single server connection
  Future<bool> _testServerConnection(String serverAddress) async {
    try {
      final url = 'http://$serverAddress/health';
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['status'] == 'healthy';
      }
    } catch (e) {
      // Connection failed, that's expected for most IPs
    }
    
    return false;
  }

  // Connect to selected/entered server
  Future<void> _connectToServer() async {
    String serverToConnect = _foundServerUrl ?? _ipController.text.trim();
    
    if (serverToConnect.isEmpty) {
      _showSnackBar('Please enter a server IP address');
      return;
    }
    
    // Add default port if not specified
    if (!serverToConnect.contains(':')) {
      serverToConnect = '$serverToConnect:3000';
    }
    
    setState(() {
      _isConnecting = true;
      _statusMessage = 'Connecting to $serverToConnect...';
    });
    
    try {
      final isReachable = await _testServerConnection(serverToConnect);
      
      if (isReachable) {
        // Set the server URL in ApiService
        ApiService.setServerUrl('http://$serverToConnect');
        
        setState(() {
          _isConnected = true;
          _statusMessage = 'Connected successfully!';
        });
        
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Navigate to PlayerRegistrationScreen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const PlayerRegistrationScreen(),
            ),
          );
        }
      } else {
        setState(() {
          _statusMessage = 'Connection failed. Check IP and try again.';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Connection error: $e';
      });
    }
    
    setState(() {
      _isConnecting = false;
    });
  }

  // Stop scanning
  void _stopScan() {
    setState(() {
      _isScanning = false;
      _statusMessage = 'Scan stopped';
    });
    _scanController.stop();
  }

  @override
  Widget build(BuildContext context) {
    bool hasValidInput = _foundServerUrl != null || _ipController.text.trim().isNotEmpty;
    
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header section with consistent spacing (matching QR scanner)
              const SizedBox(height: 40),
              _buildTopIcon(),
              const SizedBox(height: 24),
              
              // Title text (matching QR scanner positioning and style)
              Text(
                'Connecting to Server',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 60),

              // Main content area
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    // Status display
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.inputBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.emeraldPrimary, // <- Immer grün
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldPrimary.withOpacity(0.2), // <- Immer grüner Glow
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            _statusMessage,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_foundServers.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Text(
                              'Found servers:',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._foundServers.map((server) => Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: server == _foundServerUrl 
                                    ? AppColors.emeraldPrimary.withOpacity(0.2)
                                    : AppColors.cardBackground,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: server == _foundServerUrl 
                                      ? AppColors.emeraldPrimary 
                                      : AppColors.borderInactive,
                                ),
                              ),
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _foundServerUrl = server;
                                  });
                                },
                                child: Row(
                                  children: [
                                    Icon(
                                      server == _foundServerUrl 
                                          ? Icons.radio_button_checked 
                                          : Icons.radio_button_unchecked,
                                      color: AppColors.emeraldPrimary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      server,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )).toList(),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Manual IP input
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emeraldPrimary.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _ipController,
                        style: TextStyle(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          labelText: _ipController.text.trim().isEmpty ? 'Manual Server IP' : null,
                          labelStyle: TextStyle(color: AppColors.textSecondary),
                          hintText: '192.168.1.100:3000',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          filled: true,
                          fillColor: AppColors.inputBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderInactive),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.borderInactive),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.emeraldPrimary, width: 2),
                          ),
                          prefixIcon: Icon(
                            Icons.computer,
                            color: AppColors.emeraldPrimary,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          floatingLabelBehavior: FloatingLabelBehavior.never,
                        ),
                        enabled: !_isConnecting,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _connectToServer(),
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Action buttons
                    Row(
                      children: [
                        // Scan button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isScanning ? _stopScan : _startAutoScan,
                            icon: Icon(_isScanning ? Icons.stop : Icons.search),
                            label: Text(_isScanning ? 'Stop Scan' : 'Scan Again'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isScanning ? AppColors.redAlert : AppColors.warning,
                              foregroundColor: AppColors.primaryDark,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 16),
                        
                        // Connect button
                        Expanded(
                          flex: 2,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: hasValidInput ? AppColors.emeraldGlowShadow : [],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: (hasValidInput && !_isConnecting) ? _connectToServer : null,
                              icon: _isConnecting 
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                                      ),
                                    )
                                  : const Icon(Icons.connect_without_contact),
                              label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasValidInput ? AppColors.emeraldPrimary : AppColors.disabled,
                                foregroundColor: hasValidInput ? AppColors.primaryDark : AppColors.textTertiary,
                                disabledBackgroundColor: AppColors.disabled,
                                disabledForegroundColor: AppColors.textTertiary,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.bold
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: AppColors.redAlert,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}