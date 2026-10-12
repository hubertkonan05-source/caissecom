import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

/// Affiché juste après l'envoi d'une preuve de paiement (cotisation).
/// Le membre (ou l'administrateur) doit régler 100 FCFA à CaisseCom pour
/// le traitement de cette preuve. C'est indépendant du statut de la cotisation
/// elle-même, qui suit son propre circuit de validation par le trésorier.
class FeePaymentScreen extends StatefulWidget {
  final String feeId;

  const FeePaymentScreen({super.key, required this.feeId});

  @override
  State<FeePaymentScreen> createState() => _FeePaymentScreenState();
}

class _FeePaymentScreenState extends State<FeePaymentScreen> {
  final GroupsService _groupsService = GroupsService();
  final TextEditingController _referenceController = TextEditingController();

  final List<String> _methods = ['Wave', 'Orange Money', 'MTN MoMo', 'Moov Money'];
  String _selectedMethod = 'Wave';
  Map<String, String> _numbers = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _done = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final numbers = await _groupsService.fetchCaissecomPaymentMethods();
      if (!mounted) return;
      setState(() {
        _numbers = numbers;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmPaid() async {
    final reference = _referenceController.text.trim();
    if (reference.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Entrez l'identifiant de la transaction (reçu par SMS après le paiement).",
          ),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _groupsService.declarerPaiementFrais(
        feeId: widget.feeId,
        methode: _selectedMethod,
        reference: reference,
      );
      if (!mounted) return;
      setState(() => _done = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _done,
      onPopInvoked: (didPop) async {
        if (didPop || _done) return;
        final leave = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Abandonner ?'),
            content: const Text(
              "Sans le paiement des 100 FCFA, votre cotisation ne sera pas enregistrée.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continuer le paiement'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Abandonner', style: TextStyle(color: AppColors.brick)),
              ),
            ],
          ),
        );
        if (leave == true && context.mounted) {
          Navigator.of(context).pop(false);
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Frais de traitement',
          style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : _error != null
              ? Padding(
                  padding: const EdgeInsets.all(22),
                  child: Text('Erreur : $_error', style: const TextStyle(color: AppColors.brick)),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: _done ? _buildDone() : _buildForm(),
                ),
      ),
    );
  }

  Widget _methodCard(String method) {
    final selected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedMethod = method),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? AppColors.forest.withOpacity(0.07) : AppColors.paperCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.forest : AppColors.muted.withOpacity(0.25),
              width: selected ? 1.5 : 1,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            method,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.forestDark : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMethodGrid() {
    final rows = <Widget>[];
    for (int i = 0; i < _methods.length; i += 2) {
      final paire = _methods.skip(i).take(2).toList();
      rows.add(
        Padding(
          padding: EdgeInsets.only(bottom: i + 2 < _methods.length ? 8 : 0),
          child: Row(
            children: [
              _methodCard(paire[0]),
              if (paire.length > 1) ...[
                const SizedBox(width: 8),
                _methodCard(paire[1]),
              ] else
                const Expanded(child: SizedBox()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  Widget _buildDone() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.check_circle, color: AppColors.success, size: 56),
        const SizedBox(height: 16),
        const Text(
          'Merci !',
          style: TextStyle(fontSize: 20, fontFamily: 'serif', color: AppColors.forestDark),
        ),
        const SizedBox(height: 8),
        const Text(
          'Votre paiement des frais a été enregistré.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Terminer'),
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Frais de traitement de la preuve',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                SizedBox(height: 4),
                Text(
                  '100 FCFA',
                  style: TextStyle(fontSize: 28, fontFamily: 'serif', color: AppColors.forestDark),
                ),
                SizedBox(height: 6),
                Text(
                  "Ce montant ne fait pas partie de votre cotisation : il rémunère "
                  "le traitement de votre preuve par CaisseCom.",
                  style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text('Payez 100 FCFA sur l\'un de ces numéros',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.paperCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.muted.withOpacity(0.25)),
            ),
            child: Column(
              children: _methods.map((m) {
                final numero = _numbers[m];
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppColors.muted.withOpacity(0.15)),
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                      Expanded(
                        child: Text(
                          numero ?? 'Non configuré',
                          style: TextStyle(
                            fontSize: 13,
                            color: numero == null ? AppColors.muted : AppColors.forestDark,
                            fontStyle: numero == null ? FontStyle.italic : FontStyle.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          const Text("J'ai payé via", style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 8),
          _buildMethodGrid(),
          const SizedBox(height: 18),

          const Text(
            "ID de la transaction (obligatoire)",
            style: TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _referenceController,
            decoration: InputDecoration(
              hintText: 'Ex : Wave Wv-12345, Orange MP240...',
              filled: true,
              fillColor: AppColors.paperCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.muted.withOpacity(0.3)),
              ),
            ),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _confirmPaid,
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text("J'ai payé les 100 FCFA"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}