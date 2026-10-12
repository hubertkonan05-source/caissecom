import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

class RolesScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const RolesScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final GroupsService _groupsService = GroupsService();

  bool _isLoading = true;
  String? _error;
  String? _adminId;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _roles = [];
  final Set<String> _savingMemberIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _groupsService.fetchGroupAdminId(widget.groupId),
        _groupsService.fetchGroupMembers(widget.groupId),
        _groupsService.fetchAllRoles(),
      ]);
      if (!mounted) return;
      setState(() {
        _adminId = results[0] as String?;
        _members = results[1] as List<Map<String, dynamic>>;
        _roles = results[2] as List<Map<String, dynamic>>;
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

  Future<void> _changeRole(Map<String, dynamic> member, String newRoleId) async {
    final memberId = member['id'].toString();
    setState(() => _savingMemberIds.add(memberId));
    try {
      await _groupsService.updateMemberRole(memberId: memberId, roleId: newRoleId);
      if (!mounted) return;
      setState(() {
        member['role_id'] = newRoleId;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _savingMemberIds.remove(memberId));
    }
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
              'Gérer les rôles',
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

            Expanded(child: _buildBody()),

            const Text(
              "Chaque poste donne des droits différents : validation des paiements, gestion de la caisse, invitations, consultation seule.",
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Terminé'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.forest));
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Erreur : $_error',
          style: const TextStyle(color: AppColors.brick, fontSize: 12),
        ),
      );
    }
    if (_members.isEmpty) {
      return const Center(
        child: Text('Aucun membre pour le moment', style: TextStyle(color: AppColors.muted)),
      );
    }

    return ListView(
      children: _members.map((m) {
        final bool isAdmin = m['user_id'] != null && m['user_id'] == _adminId;
        final nom = (m['users']?['nom'] ?? 'Membre').toString();
        return _roleRow(m, nom, isAdmin: isAdmin);
      }).toList(),
    );
  }

  Widget _roleRow(Map<String, dynamic> member, String name, {required bool isAdmin}) {
    final String memberId = member['id'].toString();
    final bool saving = _savingMemberIds.contains(memberId);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(name, style: const TextStyle(fontSize: 14, color: AppColors.ink))),
          if (isAdmin)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Administrateur',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF8A6A17)),
              ),
            )
          else if (saving)
            const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
            )
          else
            DropdownButton<String>(
              value: member['role_id']?.toString(),
              underline: const SizedBox(),
              style: const TextStyle(fontSize: 12.5, color: AppColors.forestDark),
              items: _roles
                  .map((r) => DropdownMenuItem(
                        value: r['id'].toString(),
                        child: Text(r['nom'].toString()),
                      ))
                  .toList(),
              onChanged: (newRoleId) {
                if (newRoleId != null) _changeRole(member, newRoleId);
              },
            ),
        ],
      ),
    );
  }
}