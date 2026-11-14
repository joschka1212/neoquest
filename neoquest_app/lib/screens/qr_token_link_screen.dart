// lib/screens/qr_token_link_screen.dart
// QR Token Link Screen for connecting registered player with game token
// 20250821 V1.0 Initial implementation for reversed registration flow

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'game_download_screen.dart';

// Global constant for test mode
const bool TEST_MODE = true; // Set to false for production

class QRTokenLinkScreen extends StatefulWidget {
 final int playerId;
 final String playerName;

 const QRTokenLinkScreen({
   super.key,
   required this.playerId,
   required this.playerName,
 });

 @override
 State<QRTokenLinkScreen> createState() => _QRTokenLinkScreenState();
}

class _QRTokenLinkScreenState extends State<QRTokenLinkScreen>
   with TickerProviderStateMixin {
 MobileScannerController cameraController = MobileScannerController();
 bool _isProcessing = false;
 String _statusMessage = '';
 bool _torchEnabled = false;
 late AnimationController _pulseController;

 @override
 void initState() {
   super.initState();
   
   _pulseController = AnimationController(
     duration: const Duration(seconds: 1),
     vsync: this,
   )..repeat(reverse: true);
   
   print('📱 [QRTokenLink] Player: ${widget.playerName} (ID: ${widget.playerId})');
   print('🔧 [QRTokenLink] Using server URL: ${ApiService.baseUrl}');
 }

 @override
 void dispose() {
   cameraController.dispose();
   _pulseController.dispose();
   super.dispose();
 }

 Widget _buildTopIcon() {
   return AnimatedBuilder(
     animation: _pulseController,
     builder: (context, child) {
       final scale = _pulseController.value * 0.2 + 0.8;
       
       return Transform.scale(
         scale: scale,
         child: SizedBox(
           width: 80,
           height: 80,
           child: Icon(
             Icons.qr_code_scanner,
             size: 80,
             color: AppColors.emeraldPrimary,
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
         padding: const EdgeInsets.all(24.0),
         child: Column(
           children: [
             // Header section
             const SizedBox(height: 40),
             _buildTopIcon(),
             const SizedBox(height: 24),
             
             Text(
               'Scanne QR Code',
               style: TextStyle(
                 fontSize: 28,
                 fontWeight: FontWeight.bold,
                 color: AppColors.textPrimary,
               ),
               textAlign: TextAlign.center,
             ),
             
             const SizedBox(height: 8),
             Text(
               'Hallo ${widget.playerName}!',
               style: TextStyle(
                 fontSize: 18,
                 color: AppColors.emeraldPrimary,
               ),
               textAlign: TextAlign.center,
             ),

             const SizedBox(height: 60),

             // Main content area
             Expanded(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.start,
                 children: [
                   // Camera section
                   Container(
                     width: 250,
                     height: 250,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(12),
                       boxShadow: [
                         BoxShadow(
                           color: AppColors.emeraldPrimary.withOpacity(0.2),
                           blurRadius: 10,
                           offset: const Offset(0, 2),
                         ),
                       ],
                     ),
                     child: ClipRRect(
                       borderRadius: BorderRadius.circular(12),
                       child: Stack(
                         children: [
                           MobileScanner(
                             controller: cameraController,
                             onDetect: _onDetect,
                           ),
                           if (_isProcessing)
                             Container(
                               color: AppColors.overlayDark,
                               child: Center(
                                 child: CircularProgressIndicator(
                                   valueColor: AlwaysStoppedAnimation<Color>(AppColors.emeraldPrimary),
                                 ),
                               ),
                             ),
                           // Camera controls overlay
                           Positioned(
                             top: 8,
                             right: 8,
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Container(
                                   decoration: BoxDecoration(
                                     color: AppColors.overlayDark,
                                     borderRadius: BorderRadius.circular(20),
                                   ),
                                   child: IconButton(
                                     color: AppColors.textPrimary,
                                     icon: Icon(_torchEnabled ? Icons.flash_on : Icons.flash_off),
                                     onPressed: () {
                                       cameraController.toggleTorch();
                                       setState(() {
                                         _torchEnabled = !_torchEnabled;
                                       });
                                     },
                                   ),
                                 ),
                                 const SizedBox(width: 8),
                                 Container(
                                   decoration: BoxDecoration(
                                     color: AppColors.overlayDark,
                                     borderRadius: BorderRadius.circular(20),
                                   ),
                                   child: IconButton(
                                     color: AppColors.textPrimary,
                                     icon: const Icon(Icons.flip_camera_ios),
                                     onPressed: () => cameraController.switchCamera(),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                   
                   const SizedBox(height: 30),
                   
                   // Status and manual input section
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(24),
                     decoration: BoxDecoration(
                       color: AppColors.inputBackground,
                       borderRadius: BorderRadius.circular(12),
                       border: Border.all(
                         color: AppColors.borderInactive,
                         width: 1,
                       ),
                       boxShadow: [
                         BoxShadow(
                           color: AppColors.emeraldPrimary.withOpacity(0.1),
                           blurRadius: 10,
                           offset: const Offset(0, 2),
                         ),
                       ],
                     ),
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           _isProcessing 
                               ? _statusMessage 
                               : 'Scanne den QR-Code auf deinem Spieltoken',
                           style: TextStyle(
                             fontSize: 18,
                             fontWeight: FontWeight.w500,
                             color: AppColors.textPrimary,
                           ),
                           textAlign: TextAlign.center,
                         ),
                         const SizedBox(height: 20),
                         if (!_isProcessing)
                           SizedBox(
                             width: double.infinity,
                             child: ElevatedButton.icon(
                               onPressed: () {
                                 Navigator.push(
                                   context,
                                   MaterialPageRoute(
                                     builder: (context) => ManualTokenInputScreen(
                                       playerId: widget.playerId,
                                       playerName: widget.playerName,
                                     ),
                                   ),
                                 );
                               },
                               icon: const Icon(Icons.keyboard),
                               label: const Text('Manuelle Eingabe'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: AppColors.emeraldPrimary,
                                 foregroundColor: AppColors.primaryDark,
                                 padding: const EdgeInsets.symmetric(
                                   horizontal: 20, 
                                   vertical: 16
                                 ),
                                 shape: RoundedRectangleBorder(
                                   borderRadius: BorderRadius.circular(12),
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

             const SizedBox(height: 24),
           ],
         ),
       ),
     ),
   );
 }

 void _onDetect(BarcodeCapture capture) {
   if (_isProcessing) return;

   final List<Barcode> barcodes = capture.barcodes;
   
   for (final barcode in barcodes) {
     if (barcode.rawValue != null) {
       _handleQRCode(barcode.rawValue!);
       break;
     }
   }
 }

 void _handleQRCode(String qrCode) async {
   if (_isProcessing) return;
   
   print('🔍 QR Code detected: $qrCode');
   
   if (!qrCode.startsWith('NEOQUEST:')) {
     _showSnackBar('Ungültiger QR Code - Kein NeoQuest Token');
     return;
   }

   setState(() {
     _isProcessing = true;
     _statusMessage = 'Verknüpfe Token...';
   });

   try {
     await _linkToken(qrCode);
   } catch (e) {
     print('❌ Error: $e');
     setState(() {
       _isProcessing = false;
       _statusMessage = '';
     });
     _showSnackBar('Fehler beim Verknüpfen des Tokens');
   }
 }

 Future<void> _linkToken(String qrToken) async {
   setState(() {
     _statusMessage = 'Verbinde mit Server...';
   });

   try {
     print('🌐 [QRTokenLink] Linking token for player ${widget.playerId}');
     
     final result = await ApiService.linkTokenToPlayer(
       playerId: widget.playerId,
       qrToken: qrToken,
     );

     if (result['success'] == true) {
       setState(() {
         _statusMessage = 'Token erfolgreich verknüpft!';
       });

       await Future.delayed(const Duration(milliseconds: 800));

       final responseData = result['data'];
       final player = responseData['player'];
       final game = responseData['game'];

       if (mounted) {
         // Navigate to GameDownloadScreen
         Navigator.pushReplacement(
           context,
           MaterialPageRoute(
             builder: (context) => GameDownloadScreen(
               token: player['token'],
               gameTitle: game['title'],
               playerName: player['name'],
             ),
           ),
         );
       }
     } else {
       _showSnackBar('Token-Verknüpfung fehlgeschlagen: ${result['error']}');
     }
   } catch (e) {
     print('❌ [QRTokenLink] Connection error: $e');
     _showSnackBar('Verbindungsfehler - Prüfe Serververbindung');
   }

   setState(() {
     _isProcessing = false;
     _statusMessage = '';
   });
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

// Manual Token Input Screen
class ManualTokenInputScreen extends StatefulWidget {
 final int playerId;
 final String playerName;

 const ManualTokenInputScreen({
   super.key,
   required this.playerId,
   required this.playerName,
 });

 @override
 State<ManualTokenInputScreen> createState() => _ManualTokenInputScreenState();
}

class _ManualTokenInputScreenState extends State<ManualTokenInputScreen>
   with TickerProviderStateMixin {
 final TextEditingController _controller = TextEditingController();
 bool _isProcessing = false;
 late AnimationController _pulseController;

 @override
 void initState() {
   super.initState();
   
   _pulseController = AnimationController(
     duration: const Duration(seconds: 1),
     vsync: this,
   )..repeat(reverse: true);
   
   _controller.addListener(() {
     setState(() {});
   });
 }

 @override
 void dispose() {
   _controller.dispose();
   _pulseController.dispose();
   super.dispose();
 }

 Widget _buildTopIcon() {
   return AnimatedBuilder(
     animation: _pulseController,
     builder: (context, child) {
       final scale = _pulseController.value * 0.2 + 0.8;
       
       return Transform.scale(
         scale: scale,
         child: SizedBox(
           width: 80,
           height: 80,
           child: Icon(
             Icons.qr_code_scanner,
             size: 80,
             color: AppColors.emeraldPrimary,
           ),
         ),
       );
     },
   );
 }

 @override
 Widget build(BuildContext context) {
   bool hasValidQR = _controller.text.trim().isNotEmpty && 
                     _controller.text.trim().startsWith('NEOQUEST:');
   
   return Scaffold(
     appBar: AppBar(
       backgroundColor: AppColors.primaryDark,
       iconTheme: IconThemeData(color: AppColors.textPrimary),
     ),
     backgroundColor: AppColors.primaryDark,
     body: SafeArea(
       child: Padding(
         padding: const EdgeInsets.all(24.0),
         child: Column(
           children: [
             const SizedBox(height: 40),
             _buildTopIcon(),
             const SizedBox(height: 24),
             
             Text(
               'Token eingeben',
               style: TextStyle(
                 fontSize: 28,
                 fontWeight: FontWeight.bold,
                 color: AppColors.textPrimary,
               ),
               textAlign: TextAlign.center,
             ),
             
             const SizedBox(height: 8),
             Text(
               'Hallo ${widget.playerName}!',
               style: TextStyle(
                 fontSize: 18,
                 color: AppColors.emeraldPrimary,
               ),
               textAlign: TextAlign.center,
             ),

             const SizedBox(height: 60),

             Expanded(
               child: Column(
                 mainAxisAlignment: MainAxisAlignment.start,
                 children: [
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
                       controller: _controller,
                       style: TextStyle(color: AppColors.textPrimary),
                       textAlignVertical: TextAlignVertical.center,
                       decoration: InputDecoration(
                         labelText: _controller.text.trim().isEmpty ? 'QR Code Inhalt' : null,
                         labelStyle: TextStyle(color: AppColors.textSecondary),
                         hintText: 'NEOQUEST:DEF456:testgame1',
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
                           Icons.qr_code_scanner,
                           color: AppColors.emeraldPrimary,
                         ),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                         floatingLabelBehavior: FloatingLabelBehavior.never,
                       ),
                       enabled: !_isProcessing,
                       maxLines: 2,
                       textInputAction: TextInputAction.done,
                     ),
                   ),
                   
                   if (TEST_MODE) ...[
                     const SizedBox(height: 20),
                     ElevatedButton.icon(
                       onPressed: _fillTestData,
                       icon: const Icon(Icons.auto_fix_high),
                       label: const Text('Test Token füllen'),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: AppColors.warning,
                         foregroundColor: AppColors.primaryDark,
                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                         shape: RoundedRectangleBorder(
                           borderRadius: BorderRadius.circular(12),
                         ),
                       ),
                     ),
                   ],
                   
                   const SizedBox(height: 30),
                   
                   SizedBox(
                     width: double.infinity,
                     child: Container(
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: hasValidQR ? AppColors.emeraldGlowShadow : [],
                       ),
                       child: ElevatedButton.icon(
                         onPressed: (hasValidQR && !_isProcessing) ? _processInput : null,
                         icon: _isProcessing 
                             ? SizedBox(
                                 width: 20,
                                 height: 20,
                                 child: CircularProgressIndicator(
                                   strokeWidth: 2,
                                   valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                                 ),
                               )
                             : const Icon(Icons.play_arrow),
                         label: Text(_isProcessing ? 'Verknüpfe...' : 'Spiel starten'),
                         style: ElevatedButton.styleFrom(
                           backgroundColor: hasValidQR ? AppColors.emeraldPrimary : AppColors.disabled,
                           foregroundColor: hasValidQR ? AppColors.primaryDark : AppColors.textTertiary,
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
             ),

             const SizedBox(height: 24),
           ],
         ),
       ),
     ),
   );
 }

 void _fillTestData() {
   _controller.text = 'NEOQUEST:DEF456:testgame1';
 }

 void _processInput() async {
   if (_controller.text.trim().isEmpty) {
     _showSnackBar('Bitte QR Code Inhalt eingeben');
     return;
   }

   String qrContent = _controller.text.trim();
   
   if (!qrContent.startsWith('NEOQUEST:')) {
     _showSnackBar('Ungültiges QR Code Format');
     return;
   }

   setState(() {
     _isProcessing = true;
   });

   try {
     final result = await ApiService.linkTokenToPlayer(
       playerId: widget.playerId,
       qrToken: qrContent,
     );

     if (result['success'] == true) {
       final responseData = result['data'];
       final player = responseData['player'];
       final game = responseData['game'];

       Navigator.pushReplacement(
         context,
         MaterialPageRoute(
           builder: (context) => GameDownloadScreen(
             token: player['token'],
             gameTitle: game['title'],
             playerName: player['name'],
           ),
         ),
       );
     } else {
       _showSnackBar('Token-Verknüpfung fehlgeschlagen: ${result['error']}');
     }
   } catch (e) {
     _showSnackBar('Verbindungsfehler: $e');
   }

   setState(() {
     _isProcessing = false;
   });
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