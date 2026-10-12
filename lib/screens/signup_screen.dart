import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/phone_utils.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _codeSent = false;
  bool _verified = false;
  bool _isLoading = false;
  bool _obscure = true;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _sendCode() async {
    if (_nameController.text.trim().isEmpty) {
      _showMessage('Entrez votre nom complet');
      return;
    }
    if (_phoneController.text.isEmpty) return;
    final phone = formatPhone(_phoneController.text);
    if (phone == null) {
      _showMessage('Numéro invalide');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.sendOtp(phone);
      if (!mounted) return;
      setState(() => _codeSent = true);
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.isEmpty) return;
    final phone = formatPhone(_phoneController.text);
    if (phone == null) return;
    setState(() => _isLoading = true);
    try {
      await _authService.verifyOtp(
        phone: phone,
        token: _codeController.text.trim(),
        nom: _nameController.text.trim(),
      );
      if (!mounted) return;
      // Compte vérifié : on demande maintenant un mot de passe
      setState(() => _verified = true);
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePassword() async {
    final password = _passwordController.text;
    if (password.length < 6) {
      _showMessage('Le mot de passe doit contenir au moins 6 caractères');
      return;
    }
    if (password != _confirmController.text) {
      _showMessage('Les deux mots de passe ne correspondent pas');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.setPassword(password);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Widget _loadingChild(String label) {
    return _isLoading
        ? const SizedBox(
            height: 18,
            width: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          )
        : Text(label);
  }

  Widget _passwordField(TextEditingController controller, String hint) {
    return TextField(
      controller: controller,
      obscureText: _obscure,
      decoration: _inputDecoration(hint).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: AppColors.muted,
            size: 20,
          ),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.forestDark),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Créer mon compte',
              style: TextStyle(
                fontSize: 23,
                fontFamily: 'serif',
                color: AppColors.forestDark,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 44,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Étape 3 : choix du mot de passe (après vérification du code)
            if (_verified) ...[
              const Text(
                'Numéro vérifié. Choisissez un mot de passe : vous l\'utiliserez pour vous connecter sans SMS.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              const Text(
                'Mot de passe (6 caractères minimum)',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              _passwordField(_passwordController, 'Mot de passe'),
              const SizedBox(height: 14),
              const Text(
                'Confirmer le mot de passe',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              _passwordField(_confirmController, 'Confirmer'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePassword,
                  child: _loadingChild('Terminer mon inscription'),
                ),
              ),
            ],

            // Étapes 1 et 2 : nom + téléphone, puis code SMS
            if (!_verified) ...[
              if (!_codeSent) ...[
                const Text(
                  'Nom complet',
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration('Ex : Konan Koffi'),
                ),
                const SizedBox(height: 14),
              ],

              const Text(
                'Numéro de téléphone',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_codeSent,
                decoration: _inputDecoration('07 00 00 00 00'),
              ),
              const SizedBox(height: 18),

              if (!_codeSent)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    child: _loadingChild('Recevoir le code'),
                  ),
                ),

              if (_codeSent) ...[
                const SizedBox(height: 10),
                const Text(
                  'Code reçu par SMS',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontFamily: 'serif'),
                  decoration: _inputDecoration('••••••'),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _verifyCode,
                    child: _loadingChild('Continuer'),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() {
                              _codeController.clear();
                              _codeSent = false;
                            }),
                    child: const Text(
                      'Changer de numéro',
                      style: TextStyle(fontSize: 12.5, color: AppColors.forest),
                    ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.paperCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.muted.withOpacity(0.3)),
      ),
    );
  }
}