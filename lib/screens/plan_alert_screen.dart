import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PlanAlertScreen extends StatelessWidget {
  final String groupName;
  final int memberCount;
  final String requiredPlan;
  final int daysLeft;
  final int graceDays;

  const PlanAlertScreen({
    super.key,
    this.groupName = 'Association Solidarité Adjamé',
    this.memberCount = 11,
    this.requiredPlan = 'Premium — 2 500 FCFA/mois',
    this.daysLeft = 4,
    this.graceDays = 7,
  });

  @override
  Widget build(BuildContext context) {
    final double progress = (graceDays - daysLeft) / graceDays;

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.forestDark),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('!', style: TextStyle(fontSize: 26, color: Color(0xFF8A6A17), fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(
              'Ce groupe passe à $memberCount membres',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 8),
            Text(
              '$groupName nécessite désormais le plan $requiredPlan.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 22),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Période de grâce restante',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.brick.withOpacity(0.14),
                valueColor: const AlwaysStoppedAnimation(AppColors.brick),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$daysLeft jours sur $graceDays restants',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.paperCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.muted.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  _summaryRow('Membres actuels', '$memberCount'),
                  _summaryRow('Plan requis', requiredPlan),
                  _summaryRow('Après le délai', 'Ajout de membres bloqué'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Plus tard : activer l'abonnement via Supabase/paiement
                },
                child: const Text('Activer Premium maintenant'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continuer sans activer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}