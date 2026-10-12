 import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ExpenseFormScreen extends StatefulWidget {
  final String groupName;

  const ExpenseFormScreen({super.key, required this.groupName});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _motifController = TextEditingController();
  bool _hasJustificatif = false;

  @override
  void dispose() {
    _amountController.dispose();
    _motifController.dispose();
    super.dispose();
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enregistrer une dépense',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            Text(widget.groupName, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 44,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 22),

            const Text('Montant', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ex : 30 000 FCFA'),
            ),
            const SizedBox(height: 14),

            const Text('Motif de la dépense', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _motifController,
              maxLines: 3,
              decoration: _inputDecoration('Ex : Assistance à un membre malade'),
            ),
            const SizedBox(height: 14),

            const Text('Justificatif', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () {
                setState(() => _hasJustificatif = !_hasJustificatif);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasJustificatif ? AppColors.forest : AppColors.muted.withOpacity(0.3),
                    width: _hasJustificatif ? 1.5 : 1,
                  ),
                  color: _hasJustificatif ? AppColors.forest.withOpacity(0.06) : Colors.transparent,
                ),
                alignment: Alignment.center,
                child: Text(
                  _hasJustificatif ? '✓ Justificatif ajouté' : '📎 Ajouter un justificatif (reçu, facture)',
                  style: TextStyle(
                    fontSize: 13,
                    color: _hasJustificatif ? AppColors.forestDark : AppColors.muted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final amount = _amountController.text.isEmpty ? '0 FCFA' : _amountController.text;
                  final motif = _motifController.text.isEmpty ? 'Dépense' : _motifController.text;
                  Navigator.pop(context, {'amount': amount, 'motif': motif});
                },
                child: const Text('Enregistrer la dépense'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Cette dépense sera visible par tous les membres du groupe.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.muted.withOpacity(0.3)),
      ),
    );
  }
}