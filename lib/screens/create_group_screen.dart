import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'invite_members_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final GroupsService _groupsService = GroupsService();
  bool _isSaving = false;

  String _selectedType = 'Tontine';
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _frequency = 'Mensuelle';
  String _beneficiaryOrder = 'Tirage au sort';

  List<String> get _frequencyOptions {
    if (_selectedType == 'Association') {
      return ['Mensuelle', 'Hebdomadaire', 'Par occasion'];
    }
    return ['Mensuelle', 'Hebdomadaire'];
  }

  void _selectType(String type) {
    setState(() {
      _selectedType = type;
      if (!_frequencyOptions.contains(_frequency)) {
        _frequency = _frequencyOptions.first;
      }
    });
  }

  Future<void> _saveGroup() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donne un nom à ton groupe')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final bool isOccasional = _frequency == 'Par occasion';
      double? montant;
      if (!isOccasional && _amountController.text.isNotEmpty) {
        montant = double.tryParse(
          _amountController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        );
      }

      final group = await _groupsService.createGroup(
        nom: _nameController.text,
        type: _selectedType == 'Tontine' ? 'tontine' : 'association',
        frequence: _frequency,
        montantCotisation: montant,
      );

      if (!mounted) return;

      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InviteMembersScreen(
  groupId: group['id'],
  groupName: _nameController.text,
),
        ),
      );

      if (!mounted) return;
      // On renvoie "true" pour dire au dashboard de rafraîchir sa liste
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la création : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isTontine = _selectedType == 'Tontine';
    final bool isOccasional = _frequency == 'Par occasion';

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
              'Créer un groupe',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 44,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 22),

            const Text('Quel type de groupe ?', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _TypeCard(
                    title: 'Tontine',
                    subtitle: 'Un bénéficiaire par cycle',
                    selected: _selectedType == 'Tontine',
                    onTap: () => _selectType('Tontine'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _TypeCard(
                    title: 'Association',
                    subtitle: 'Caisse commune partagée',
                    selected: _selectedType == 'Association',
                    onTap: () => _selectType('Association'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            _FieldLabel('Nom du groupe'),
            _TextInput(controller: _nameController, hint: 'Ex : Tontine Famille Koffi'),
            const SizedBox(height: 14),

            if (!isOccasional) ...[
              _FieldLabel('Montant de la cotisation'),
              _TextInput(controller: _amountController, hint: 'Ex : 10 000 FCFA', keyboardType: TextInputType.number),
              const SizedBox(height: 14),
            ],

            _FieldLabel('Fréquence'),
            _Dropdown(
              value: _frequency,
              options: _frequencyOptions,
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 14),

            if (isOccasional)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  "Pas de cotisation fixe : tu lanceras une collecte avec un montant "
                  "à chaque événement (funérailles, mariage, entraide...).",
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                ),
              ),

            if (isTontine) ...[
              _FieldLabel('Ordre des bénéficiaires'),
              _Dropdown(
                value: _beneficiaryOrder,
                options: const ['Tirage au sort', 'Ordre manuel'],
                onChanged: (v) => setState(() => _beneficiaryOrder = v!),
              ),
              const SizedBox(height: 14),
            ],

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveGroup,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continuer'),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _TypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _TypeCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.forest.withOpacity(0.06) : AppColors.paperCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.forest : AppColors.muted.withOpacity(0.25),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  const _TextInput({required this.controller, required this.hint, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.paperCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.muted.withOpacity(0.3)),
        ),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const _Dropdown({required this.value, required this.options, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.paperCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.muted.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}