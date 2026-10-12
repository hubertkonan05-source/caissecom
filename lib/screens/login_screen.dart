import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../utils/phone_utils.dart';
import 'dashboard_screen.dart';

enum _LoginStep { password, requestCode, enterCode, newPassword }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  _LoginStep _step = _LoginStep.password;
  bool _isLoading = false;
  bool _obscure = true;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Retourne le numéro au format international, ou null (avec message) s'il est invalide.
  String? _phoneOrWarn() {
    final phone = formatPhone(_phoneController.text);
    if (phone == null) _showMessage('Numéro invalide');
    return phone;
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DashboardScreen()),
    );
  }

  // Connexion habituelle : numéro + mot de passe (aucun SMS)
  Future<void> _signInWithPassword() async {
    final phone = _phoneOrWarn();
    if (phone == null) return;
    if (_passwordController.text.isEmpty) {
      _showMessage('Entrez votre mot de passe');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithPassword(
        phone: phone,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _goToDashboard();
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Mot de passe oublié / première connexion : envoi d'un code SMS
  Future<void> _sendCode() async {
    final phone = _phoneOrWarn();
    if (phone == null) return;
    setState(() => _isLoading = true);
    try {
      await _authService.sendOtp(phone);
      if (!mounted) return;
      setState(() => _step = _LoginStep.enterCode);
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyCode() async {
    final phone = _phoneOrWarn();
    if (phone == null) return;
    if (_codeController.text.isEmpty) {
      _showMessage('Entrez le code reçu par SMS');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await _authService.verifyOtp(phone: phone, token: _codeController.text.trim());
      if (!mounted) return;
      setState(() => _step = _LoginStep.newPassword);
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNewPassword() async {
    final password = _newPasswordController.text;
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
      _goToDashboard();
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String get _title {
    switch (_step) {
      case _LoginStep.password:
        return 'Connexion';
      case _LoginStep.requestCode:
        return 'Recevoir un code';
      case _LoginStep.enterCode:
        return 'Vérification';
      case _LoginStep.newPassword:
        return 'Nouveau mot de passe';
    }
  }

  Widget _primaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        child: _isLoading
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label),
      ),
    );
  }

  Widget _linkButton(String label, VoidCallback onPressed) {
    return Center(
      child: TextButton(
        onPressed: _isLoading ? null : onPressed,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: AppColors.forest),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
  }

  Widget _phoneField({required bool enabled}) {
    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      enabled: enabled,
      decoration: _inputDecoration('07 00 00 00 00'),
    );
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

  List<Widget> _buildStepContent() {
    switch (_step) {
      case _LoginStep.password:
        return [
          _label('Numéro de téléphone'),
          const SizedBox(height: 6),
          _phoneField(enabled: true),
          const SizedBox(height: 14),
          _label('Mot de passe'),
          const SizedBox(height: 6),
          _passwordField(_passwordController, 'Votre mot de passe'),
          const SizedBox(height: 18),
          _primaryButton('Se connecter', _signInWithPassword),
          const SizedBox(height: 10),
          _linkButton(
            'Mot de passe oublié ou première connexion ?\nRecevoir un code par SMS',
            () => setState(() => _step = _LoginStep.requestCode),
          ),
        ];

      case _LoginStep.requestCode:
        return [
          _label('Numéro de téléphone'),
          const SizedBox(height: 6),
          _phoneField(enabled: true),
          const SizedBox(height: 8),
          const Text(
            'Un code vous sera envoyé par SMS, puis vous choisirez un nouveau mot de passe.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          _primaryButton('Recevoir le code', _sendCode),
          const SizedBox(height: 10),
          _linkButton(
            'Retour à la connexion par mot de passe',
            () => setState(() => _step = _LoginStep.password),
          ),
        ];

      case _LoginStep.enterCode:
        return [
          _label('Numéro de téléphone'),
          const SizedBox(height: 6),
          _phoneField(enabled: false),
          const SizedBox(height: 18),
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
          const SizedBox(height: 20),
          _primaryButton('Vérifier le code', _verifyCode),
          const SizedBox(height: 10),
          _linkButton(
            'Changer de numéro',
            () => setState(() {
              _codeController.clear();
              _step = _LoginStep.requestCode;
            }),
          ),
        ];

      case _LoginStep.newPassword:
        return [
          const Text(
            'Choisissez un mot de passe pour vous connecter sans SMS la prochaine fois.',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          _label('Nouveau mot de passe (6 caractères minimum)'),
          const SizedBox(height: 6),
          _passwordField(_newPasswordController, 'Nouveau mot de passe'),
          const SizedBox(height: 14),
          _label('Confirmer le mot de passe'),
          const SizedBox(height: 6),
          _passwordField(_confirmController, 'Confirmer'),
          const SizedBox(height: 20),
          _primaryButton('Enregistrer et continuer', _saveNewPassword),
        ];
    }
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
            Text(
              _title,
              style: const TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
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
            ..._buildStepContent(),
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