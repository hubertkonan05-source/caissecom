import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CreateCollecteScreen extends StatefulWidget {
  final String groupName;

  const CreateCollecteScreen({super.key, required this.groupName});

  @override
  State<CreateCollecteScreen> createState() => _CreateCollecteScreenState();
}

class _CreateCollecteScreenState extends State<CreateCollecteScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _detailController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _detailController.dispose();
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
              'Lancer une collecte',
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

            const Text('Titre de l\'événement', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _titleController,
              decoration: _inputDecoration('Ex : Funérailles du père de Yao'),
            ),
            const SizedBox(height: 14),

            const Text('Montant par membre', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: _inputDecoration('Ex : 5 000 FCFA'),
            ),
            const SizedBox(height: 14),

            const Text('Détails (optionnel)', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _detailController,
              maxLines: 3,
              decoration: _inputDecoration('Précise le contexte pour les membres...'),
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final title = _titleController.text.isEmpty
                      ? 'Nouvelle collecte'
                      : _titleController.text;
                  final amount = _amountController.text.isEmpty
                      ? '5 000 FCFA'
                      : _amountController.text;
                  Navigator.pop(context, {'title': title, 'amount': amount});
                },
                child: const Text('Alerter les membres'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Tous les membres recevront une notification avec le montant fixé.',
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