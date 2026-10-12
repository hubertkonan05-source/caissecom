import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

class CaissecomAdminScreen extends StatefulWidget {
  const CaissecomAdminScreen({super.key});

  @override
  State<CaissecomAdminScreen> createState() => _CaissecomAdminScreenState();
}

class _CaissecomAdminScreenState extends State<CaissecomAdminScreen> {
  final GroupsService _groupsService = GroupsService();
  final List<String> _methods = ['Wave', 'Orange Money', 'MTN MoMo', 'Moov Money'];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _saving = {};
  bool _isLoading = true;
  Map<String, dynamic>? _revenus;
  List<Map<String, dynamic>> _aConfirmer = [];

  @override
  void initState() {
    super.initState();
    for (final m in _methods) {
      _controllers[m] = TextEditingController();
      _saving[m] = false;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      final numbers = await _groupsService.fetchCaissecomPaymentMethods();
      final revenus = await _groupsService.fetchRevenusCaissecom();
      final aConfirmer = await _groupsService.fetchFraisAConfirmer();
      if (!mounted) return;
      setState(() {
        for (final m in _methods) {
          _controllers[m]!.text = numbers[m] ?? '';
        }
        _revenus = revenus;
        _aConfirmer = aConfirmer;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _saveNumber(String methode) async {
    final numero = _controllers[methode]!.text.trim();
    if (numero.isEmpty) return;
    setState(() => _saving[methode] = true);
    try {
      await _groupsService.saveCaissecomPaymentMethod(methode: methode, numero: numero);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$methode enregistré')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _saving[methode] = false);
    }
  }

  Future<void> _verifier(String feeId, String statut) async {
    try {
      await _groupsService.verifierFraisPreuve(feeId: feeId, statut: statut);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
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
        title: const Text(
          'CaisseCom — Administration',
          style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Revenus',
                    style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _statBlock('${_revenus?['revenu_total'] ?? 0} F', 'Revenu total'),
                        _statBlock('${_revenus?['nb_preuves_confirmees'] ?? 0}', 'Preuves confirmées'),
                        _statBlock('${_revenus?['nb_en_attente'] ?? 0}', 'En attente'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'Mes numéros CaisseCom',
                    style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Numéros sur lesquels les utilisateurs paient les 100 FCFA de traitement de preuve.",
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  ..._methods.map(_methodRow),
                  const SizedBox(height: 24),

                  const Text(
                    'Paiements à confirmer',
                    style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
                  ),
                  const SizedBox(height: 10),
                  if (_aConfirmer.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Rien à confirmer pour le moment', style: TextStyle(color: AppColors.muted)),
                    )
                  else
                    ..._aConfirmer.map(_feeRow),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _statBlock(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 17, fontFamily: 'serif', color: AppColors.forestDark)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _methodRow(String methode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.muted.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(methode, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: TextField(
              controller: _controllers[methode],
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '07 00 00 00 00',
                isDense: true,
                filled: true,
                fillColor: AppColors.paper,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppColors.muted.withOpacity(0.25)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _saving[methode]! ? null : () => _saveNumber(methode),
            child: _saving[methode]!
                ? const SizedBox(
                    height: 14, width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('OK', style: TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(Map<String, dynamic> fee) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${fee['amount']} F · ${fee['payment_method'] ?? ''}',
                  style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                ),
                if ((fee['payment_reference'] ?? '').toString().isNotEmpty)
                  Text(
                    'Réf. ${fee['payment_reference']}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                  ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _verifier(fee['id'].toString(), 'verifie'),
                icon: const Icon(Icons.check, size: 16),
              ),
              const SizedBox(width: 6),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.brick.withOpacity(0.12),
                  foregroundColor: AppColors.brick,
                ),
                onPressed: () => _verifier(fee['id'].toString(), 'annule'),
                icon: const Icon(Icons.close, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}