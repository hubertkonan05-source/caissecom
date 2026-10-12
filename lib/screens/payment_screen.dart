import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'confirmation_screen.dart';
import 'fee_payment_screen.dart';

class PaymentScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String amount;
  final String cycleInfo;

  const PaymentScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.amount = '10 000 FCFA',
    this.cycleInfo = 'Cycle 3',
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final GroupsService _groupsService = GroupsService();
  final ImagePicker _picker = ImagePicker();
  String _selectedMethod = 'Wave';

  @override
  void initState() {
    super.initState();
    _loadPaymentInfo();
  }
  bool _isSaving = false;
  final List<String> _methods = ['Wave', 'Orange Money', 'MTN MoMo', 'Moov Money'];

  Future<void> _loadPaymentInfo() async {
    try {
      final mine = await _groupsService.fetchMyPaymentMethods();
      final receiving = await _groupsService.fetchGroupReceivingNumber(
        groupId: widget.groupId,
        methode: _selectedMethod,
      );
      if (!mounted) return;
      setState(() {
        _senderNumberController.text = mine[_selectedMethod] ?? '';
        _receivingInfo = receiving;
        _receivingLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _receivingLoaded = true);
    }
  }

  Future<void> _onMethodChanged(String method) async {
    setState(() {
      _selectedMethod = method;
      _receivingLoaded = false;
      _receivingInfo = null;
    });
    await _loadPaymentInfo();
  }

  Uint8List? _proofBytes;
  String _proofExt = 'jpg';

  final TextEditingController _senderNumberController = TextEditingController();
  Map<String, dynamic>? _receivingInfo;
  bool _receivingLoaded = false;

  Future<void> _pickProof() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.paper,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppColors.forestDark),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined, color: AppColors.forestDark),
              title: const Text('Prendre une photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1600,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final name = file.name.toLowerCase();
      if (!mounted) return;
      setState(() {
        _proofBytes = bytes;
        _proofExt = name.endsWith('.png') ? 'png' : 'jpg';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Impossible d'ajouter l'image : $e")),
      );
    }
  }

  Future<void> _submitPayment() async {
    if (_proofBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ajoutez la capture du reçu de paiement')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final memberId = await _groupsService.fetchMyMemberId(widget.groupId);
      if (memberId == null) {
        throw Exception("Impossible de retrouver ton adhésion à ce groupe");
      }

      final montant = double.tryParse(
            widget.amount.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;

      final proofPath = await _groupsService.uploadProof(
        groupId: widget.groupId,
        memberId: memberId,
        bytes: _proofBytes!,
        extension: _proofExt,
      );

      // 100 FCFA de frais de traitement, à payer AVANT que la cotisation soit enregistrée.
      final feeId = await _groupsService.creerFraisPreuve(groupId: widget.groupId);

      if (!mounted) return;
      final feePaid = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => FeePaymentScreen(feeId: feeId)),
      );

      if (feePaid != true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Cotisation non envoyée : le paiement des frais de traitement n'a pas été confirmé.",
            ),
          ),
        );
        return;
      }

      final contributionId = await _groupsService.createContribution(
        groupId: widget.groupId,
        memberId: memberId,
        montant: montant,
        moyenPaiement: _selectedMethod,
        preuveUrl: proofPath,
        numeroExpediteur: _senderNumberController.text.trim().isEmpty
            ? null
            : _senderNumberController.text.trim(),
      );

      try {
        await _groupsService.attacherFraisAContribution(
          feeId: feeId,
          contributionId: contributionId,
        );
      } catch (_) {
        // Le rattachement est secondaire : la cotisation et le frais existent déjà
        // même si cette étape échoue, donc on n'interrompt pas l'utilisateur pour ça.
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ConfirmationScreen(
            groupName: widget.groupName,
            amount: widget.amount,
            method: _selectedMethod,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _methodCard(String method) {
    final selected = _selectedMethod == method;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onMethodChanged(method),
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

  Widget _buildProofPicker() {
    if (_proofBytes == null) {
      return GestureDetector(
        onTap: _pickProof,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.muted.withOpacity(0.3)),
          ),
          alignment: Alignment.center,
          child: const Text(
            '📷  Ajouter une capture du reçu',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Image.memory(
            _proofBytes!,
            height: 170,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: 6),
        TextButton.icon(
          onPressed: _isSaving ? null : _pickProof,
          icon: const Icon(Icons.swap_horiz, size: 16, color: AppColors.forest),
          label: const Text(
            "Changer l'image",
            style: TextStyle(fontSize: 12.5, color: AppColors.forest),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _senderNumberController.dispose();
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ma cotisation',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            Text(
              '${widget.groupName} · ${widget.cycleInfo}',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 26),

            Center(
              child: Column(
                children: [
                  const Text('Montant à payer', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  Text(
                    widget.amount,
                    style: const TextStyle(fontSize: 32, fontFamily: 'serif', color: AppColors.forestDark),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            const Text('Moyen de paiement', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 8),
            _buildMethodGrid(),
            const SizedBox(height: 16),

            if (_receivingLoaded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _receivingInfo == null
                      ? "Le trésorier n'a pas encore renseigné son numéro $_selectedMethod. "
                          "Demandez-lui-en un directement."
                      : "Envoyez à ${_receivingInfo!['numero']} (${_receivingInfo!['nom_admin']}) via $_selectedMethod",
                  style: const TextStyle(fontSize: 12.5, color: AppColors.forestDark),
                ),
              ),
            const SizedBox(height: 16),

            const Text('Votre numéro (utilisé pour ce paiement)', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            TextField(
              controller: _senderNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                hintText: '07 00 00 00 00',
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

            const Text('Preuve de paiement', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 8),
            _buildProofPicker(),
            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitPayment,
                child: _isSaving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Envoyer ma cotisation'),
              ),
            ),
            const SizedBox(height: 10),
            const Center(
              child: Text(
                'En attente de validation par le trésorier',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}