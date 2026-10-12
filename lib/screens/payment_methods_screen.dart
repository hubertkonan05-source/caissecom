import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  final GroupsService _groupsService = GroupsService();
  final List<String> _methods = ['Wave', 'Orange Money', 'MTN MoMo', 'Moov Money'];

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, bool> _saving = {};
  bool _isLoading = true;

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
      final numbers = await _groupsService.fetchMyPaymentMethods();
      if (!mounted) return;
      setState(() {
        for (final m in _methods) {
          _controllers[m]!.text = numbers[m] ?? '';
        }
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

  Future<void> _save(String methode) async {
    final numero = _controllers[methode]!.text.trim();
    if (numero.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Entrez un numéro pour $methode')),
      );
      return;
    }

    setState(() => _saving[methode] = true);
    try {
      await _groupsService.savePaymentMethod(methode: methode, numero: numero);
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

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _methodRow(String methode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.muted.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(methode, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
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
                onPressed: _saving[methode]! ? null : () => _save(methode),
                child: _saving[methode]!
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
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
          'Mes moyens de paiement',
          style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    "Ces numéros servent à deux choses : indiquer sur quel numéro on vous envoie l'argent "
                    "quand vous êtes trésorier d'un groupe, et pré-remplir le numéro depuis lequel vous "
                    "envoyez vos propres cotisations.",
                    style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  ..._methods.map(_methodRow),
                ],
              ),
            ),
    );
  }
}