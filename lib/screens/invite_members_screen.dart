import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import '../utils/phone_utils.dart';
import 'dashboard_screen.dart';

class InviteMembersScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const InviteMembersScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Groupe',
  });

  @override
  State<InviteMembersScreen> createState() => _InviteMembersScreenState();
}

class _InviteMembersScreenState extends State<InviteMembersScreen> {
  final GroupsService _groupsService = GroupsService();
  final TextEditingController _phoneController = TextEditingController();

  String? _code;
  bool _codeLoading = true;
  bool _isAdding = false;

  late Future<List<Map<String, dynamic>>> _membersFuture;

  @override
  void initState() {
    super.initState();
    _loadCode();
    _membersFuture = _groupsService.fetchGroupMembers(widget.groupId);
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = _groupsService.fetchGroupMembers(widget.groupId);
    });
  }

  Future<void> _loadCode() async {
    try {
      final data = await _groupsService.fetchGroupInvite(widget.groupId);
      if (!mounted) return;
      setState(() {
        _code = data['code_invitation']?.toString();
        _codeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _codeLoading = false);
      _showMessage('Erreur : $e');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyLink() async {
    if (_code == null) return;
    await Clipboard.setData(ClipboardData(text: 'caissecom.app/rejoindre/$_code'));
    _showMessage('Lien copié');
  }

  Future<void> _addByPhone() async {
    if (_phoneController.text.trim().isEmpty) return;
    final phone = formatPhone(_phoneController.text);
    if (phone == null) {
      _showMessage('Numéro invalide');
      return;
    }

    setState(() => _isAdding = true);
    try {
      final user = await _groupsService.findUserByPhone(phone);
      if (user == null) {
        _showMessage(
          "Aucun compte avec ce numéro. Partagez-lui le lien ou le code pour qu'il s'inscrive.",
        );
        return;
      }

      final userId = user['id'] as String;
      final alreadyMember = await _groupsService.isAlreadyMember(widget.groupId, userId);
      if (alreadyMember) {
        _showMessage('${user['nom'] ?? 'Cette personne'} est déjà membre du groupe');
        return;
      }

      await _groupsService.addMemberByUserId(groupId: widget.groupId, userId: userId);
      if (!mounted) return;
      _phoneController.clear();
      _refreshMembers();
      _showMessage('${user['nom'] ?? 'Membre'} ajouté au groupe');
    } catch (e) {
      _showMessage('Erreur : $e');
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Widget _buildLinkCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.paperCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.muted.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _codeLoading
                ? const Text(
                    'Chargement du code…',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  )
                : Text(
                    _code == null
                        ? 'Code indisponible'
                        : 'caissecom.app/rejoindre/$_code',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
            ),
            onPressed: _code == null ? null : _copyLink,
            child: const Text('Copier', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAddByPhone() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enabled: !_isAdding,
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
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: _isAdding ? null : _addByPhone,
          child: _isAdding
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Ajouter'),
        ),
      ],
    );
  }

  Widget _buildMembersList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _membersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Erreur : ${snapshot.error}',
            style: const TextStyle(color: AppColors.brick, fontSize: 12),
          );
        }
        final members = snapshot.data ?? [];
        if (members.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text('Aucun membre pour le moment', style: TextStyle(color: AppColors.muted)),
          );
        }
        return Column(
          children: members.map((m) {
            final nom = (m['users']?['nom'] ?? 'Membre').toString();
            final role = (m['roles']?['nom'] ?? 'Membre').toString();
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(nom, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                  Text(role, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            );
          }).toList(),
        );
      },
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
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inviter des membres',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            Text(widget.groupName, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 44,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),

            const Text('Lien ou code à partager', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            _buildLinkCard(),
            const SizedBox(height: 22),

            const Text('Ajouter par numéro de téléphone', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 6),
            _buildAddByPhone(),
            const SizedBox(height: 4),
            const Text(
              "La personne doit déjà avoir un compte CaisseCom. Sinon, partagez-lui le lien.",
              style: TextStyle(fontSize: 11.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),

            const Text('Membres du groupe', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(child: _buildMembersList()),
            ),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const DashboardScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Terminer'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}