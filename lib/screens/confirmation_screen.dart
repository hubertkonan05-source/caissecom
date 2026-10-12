import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ConfirmationScreen extends StatelessWidget {
  final String groupName;
  final String amount;
  final String method;

  const ConfirmationScreen({
    super.key,
    required this.groupName,
    required this.amount,
    required this.method,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.check, color: AppColors.success, size: 30),
              ),
              const SizedBox(height: 18),
              const Text(
                'Cotisation envoyée',
                style: TextStyle(fontSize: 19, fontFamily: 'serif', color: AppColors.forestDark),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le trésorier a été notifié et validera ton paiement sous peu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 24),

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
                    _summaryRow('Groupe', groupName),
                    _summaryRow('Montant', amount),
                    _summaryRow('Moyen', method),
                    _summaryRow('Date', "aujourd'hui"),
                  ],
                ),
              ),
              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Retour au groupe'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink)),
        ],
      ),
    );
  }
}