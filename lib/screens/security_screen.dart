import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'onboarding_screen.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _updatePassword() async {
    final current = _currentController.text;
    final newPassword = _newController.text;
    final confirm = _confirmController.text;

    if (current.isEmpty) {
      _showMessage('Entrez votre mot de passe actuel');
      return;
    }
    if (newPassword.length < 6) {
      _showMessage('Le nouveau mot de passe doit contenir au moins 6 caractères');
      return;
    }
    if (newPassword != confirm) {
      _showMessage('Les deux mots de passe ne correspondent pas');
      return;
    }

    final phone = _authService.currentPhone;
    if (phone == null) {
      _showMessage('Impossible de retrouver votre numéro. Reconnectez-vous.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // On vérifie le mot de passe actuel en se reconnectant avec.
      await _authService.signInWithPassword(phone: phone, password: current);
      // Puis on enregistre le nouveau.
      await _authService.setPassword(newPassword);

      if (!mounted) return;
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
      _showMessage('Mot de passe mis à jour');
    } catch (e) {
      _showMessage(AuthService.friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isDeleting = false;

  /// Demande une vraie confirmation (taper SUPPRIMER) avant d'effacer le compte.
  Future<void> _confirmerSuppression() async {
    final saisie = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Supprimer mon compte ?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Votre nom, votre numéro et vos moyens de paiement seront effacés "
                "et vous ne pourrez plus vous connecter. L'historique financier des "
                "groupes est conservé sous « Utilisateur supprimé », pour ne pas "
                "fausser leur comptabilité.\n\nCette action est définitive.",
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 14),
              const Text('Tapez SUPPRIMER pour confirmer :', style: TextStyle(fontSize: 12.5)),
              const SizedBox(height: 6),
              TextField(
                controller: saisie,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setLocal(() {}),
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: saisie.text.trim().toUpperCase() == 'SUPPRIMER'
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Supprimer', style: TextStyle(color: AppColors.brick)),
            ),
          ],
        ),
      ),
    );
    saisie.dispose();
    if (ok != true) return;

    setState(() => _isDeleting = true);
    try {
      await _authService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is PostgrestException ? e.message : e.toString();
      _showMessage(message);
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppColors.paperCard,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.muted.withOpacity(0.3)),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _label(String text) {
    return Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.forestDark),
        title: const Text(
          'Sécurité',
          style: TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Changer mon mot de passe',
              style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 16),

            _label('Mot de passe actuel'),
            const SizedBox(height: 6),
            TextField(
              controller: _currentController,
              obscureText: _obscureCurrent,
              decoration: _inputDecoration(
                'Mot de passe actuel',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 14),

            _label('Nouveau mot de passe (6 caractères minimum)'),
            const SizedBox(height: 6),
            TextField(
              controller: _newController,
              obscureText: _obscureNew,
              decoration: _inputDecoration(
                'Nouveau mot de passe',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: AppColors.muted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 14),

            _label('Confirmer le nouveau mot de passe'),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmController,
              obscureText: _obscureNew,
              decoration: _inputDecoration('Confirmer'),
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Mettre à jour le mot de passe'),
              ),
            ),
            const SizedBox(height: 36),

            const Divider(height: 1),
            const SizedBox(height: 20),
            const Text(
              'Supprimer mon compte',
              style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.brick),
            ),
            const SizedBox(height: 6),
            const Text(
              "Efface vos données personnelles et bloque l'accès à ce compte. "
              "Action définitive.",
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick),
                onPressed: _isDeleting ? null : _confirmerSuppression,
                child: _isDeleting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brick),
                      )
                    : const Text('Supprimer mon compte'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}