import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../services/api_service.dart';
import 'qr_token_link_screen.dart';

class PlayerRegistrationScreen extends StatefulWidget {

  const PlayerRegistrationScreen({super.key});

  @override
  State<PlayerRegistrationScreen> createState() => _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState extends State<PlayerRegistrationScreen>
    with TickerProviderStateMixin {
  
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  late AnimationController _pulseController;
  
  bool _isRegistering = false;
  
  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    
    // Listen to text changes
    _nameController.addListener(() => setState(() {}));
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
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
              Icons.person_add,
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
    bool hasValidName = _nameController.text.trim().length >= 2;
    bool hasValidEmail = _emailController.text.trim().isEmpty || 
                        _emailController.text.contains('@');
    bool canRegister = hasValidName && hasValidEmail && !_isRegistering;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 40),
                _buildTopIcon(),
                const SizedBox(height: 24),
                
                Text(
                  'Spielerin Anmeldung',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                Text(
                  'Erstelle deinen Account',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.emeraldPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 60),

                Expanded(
                  child: Column(
                    children: [
                      // Name Input (Required)
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
                        child: TextFormField(
                          controller: _nameController,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Spielerin Name *',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            hintText: 'Dein Name für das Spiel',
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
                              Icons.person,
                              color: AppColors.emeraldPrimary,
                            ),
                          ),
                          enabled: !_isRegistering,
                          textInputAction: TextInputAction.next,
                          validator: (value) {
                            if (value == null || value.trim().length < 2) {
                              return 'Name muss mindestens 2 Zeichen haben';
                            }
                            return null;
                          },
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Email Input (Optional)
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
                        child: TextFormField(
                          controller: _emailController,
                          style: TextStyle(color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            labelText: 'Email (optional)',
                            labelStyle: TextStyle(color: AppColors.textSecondary),
                            hintText: 'deine@email.com',
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
                              Icons.email,
                              color: AppColors.emeraldPrimary,
                            ),
                          ),
                          enabled: !_isRegistering,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          validator: (value) {
                            if (value != null && value.trim().isNotEmpty && !value.contains('@')) {
                              return 'Ungültige Email-Adresse';
                            }
                            return null;
                          },
                          onFieldSubmitted: (_) => _registerPlayer(),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Register Button
                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: canRegister ? AppColors.emeraldGlowShadow : [],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: canRegister ? _registerPlayer : null,
                            icon: _isRegistering 
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryDark),
                                    ),
                                  )
                                : const Icon(Icons.login),
                            label: Text(_isRegistering ? 'Melde an...' : 'Beim Spiel anmelden'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: canRegister ? AppColors.emeraldPrimary : AppColors.disabled,
                              foregroundColor: canRegister ? AppColors.primaryDark : AppColors.textTertiary,
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
      ),
    );
  }

Future<void> _registerPlayer() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isRegistering = true;
    });

    try {
      final result = await ApiService.createPlayer(
        playerName: _nameController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      );

      if (result['success'] == true) {
        final player = result['data']['player'];

        // Navigate to QRScannerScreen für Token-Verknüpfung
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRTokenLinkScreen(
              playerId: player['id'],
              playerName: player['name'],
            ),
          ),
        );
      } else {
        _showSnackBar('Anmeldung fehlgeschlagen: ${result['error']}');
      }
    } catch (e) {
      _showSnackBar('Verbindungsfehler: $e');
    }

    setState(() {
      _isRegistering = false;
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