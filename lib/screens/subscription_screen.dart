import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'plan_alert_screen.dart';

class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

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
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Passer en Premium',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const Text('Pour les groupes qui grandissent.', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 20),

            _planCard(
              title: 'Gratuit',
              price: '0 FCFA',
              features: const ['0 à 10 membres', 'Suivi des cotisations'],
            ),
            const SizedBox(height: 12),
            _planCard(
              title: 'Premium',
              price: '2 500 FCFA/mois',
              tag: '11 à 21 membres',
              highlight: true,
              features: const ['Export des rapports en PDF', 'Rappels avancés'],
            ),
            const SizedBox(height: 12),
            _planCard(
              title: 'Premium +',
              price: '5 000 FCFA/mois',
              tag: '22 membres et +',
              tagColor: AppColors.forest,
              features: const ['Tout Premium', 'Support prioritaire'],
            ),
            const SizedBox(height: 22),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Plus tard : activer le plan choisi via Supabase/paiement
                },
                child: const Text('Choisir mon plan'),
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PlanAlertScreen()),
                  );
                },
                child: const Text(
                  "Voir un exemple d'alerte de palier",
                  style: TextStyle(color: AppColors.forest, fontSize: 12.5),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _planCard({
    required String title,
    required String price,
    required List<String> features,
    String? tag,
    Color tagColor = AppColors.gold,
    bool highlight = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight ? AppColors.gold.withOpacity(0.08) : AppColors.paperCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: highlight ? AppColors.gold : AppColors.muted.withOpacity(0.2),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Stack(
        children: [
          if (tag != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: tagColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  tag,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: tagColor == AppColors.gold ? const Color(0xFF23200E) : AppColors.paper,
                  ),
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark)),
              const SizedBox(height: 4),
              Text(price, style: const TextStyle(fontSize: 20, fontFamily: 'serif', color: AppColors.forestDark)),
              const SizedBox(height: 8),
              ...features.map((f) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('• $f', style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  )),
            ],
          ),
        ],
      ),
    );
  }
}