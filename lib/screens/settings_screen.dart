import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/auth_service.dart';
import '../services/groups_service.dart';
import 'subscription_screen.dart';
import 'onboarding_screen.dart';
import 'security_screen.dart';
import 'payment_methods_screen.dart';
import 'caissecom_admin_screen.dart';
import 'help_screen.dart';
import 'my_groups_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GroupsService _groupsService = GroupsService();
  String _nom = '';
  String _telephone = '';
  bool _isCaissecomAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _groupsService.fetchMyProfile();
      final isAdmin = await _groupsService.isCaissecomAdmin();
      if (!mounted) return;
      setState(() {
        _nom = profile['nom'] ?? '';
        _telephone = profile['telephone'] ?? '';
        _isCaissecomAdmin = isAdmin;
      });
    } catch (_) {
      // Le profil reste vide si la requête échoue ; le reste de l'écran fonctionne quand même.
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Vous devrez vous reconnecter pour accéder à vos groupes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Se déconnecter', style: TextStyle(color: AppColors.brick)),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await AuthService().signOut();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
      return;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paramètres',
              style: TextStyle(fontSize: 21, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.gold,
                  child: Text(
                    _nom.isEmpty ? '?' : _nom[0].toUpperCase(),
                    style: const TextStyle(fontFamily: 'serif', fontSize: 19, color: Color(0xFF23200E)),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nom.isEmpty ? '…' : _nom,
                      style: const TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
                    ),
                    Text(
                      _telephone,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            _settingsRow(
              context,
              'Mes moyens de paiement',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
                );
              },
            ),
            _settingsRow(
              context,
              'Mes groupes',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const MyGroupsScreen()),
                );
              },
            ),
            _settingsRow(context, 'Notifications'),
            _settingsRow(
              context,
              'Sécurité',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SecurityScreen()),
                );
              },
            ),
            _settingsRow(
              context,
              'Abonnement',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
                );
              },
            ),
            _settingsRow(
              context,
              'Aide',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
            if (_isCaissecomAdmin)
              _settingsRow(
                context,
                'CaisseCom — Administration',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CaissecomAdminScreen()),
                  );
                },
              ),
            InkWell(
              onTap: () => _confirmSignOut(context),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: const Text(
                  'Se déconnecter',
                  style: TextStyle(fontSize: 14, color: AppColors.brick),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingsRow(BuildContext context, String label, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
            const Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
          ],
        ),
      ),
    );
  }
}