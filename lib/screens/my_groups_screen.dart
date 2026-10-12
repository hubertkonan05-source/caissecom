import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'group_detail_screen.dart';

/// Gestion de ses groupes depuis les Paramètres : ouvrir un groupe, le
/// quitter, ou réintégrer un groupe quitté. L'historique et les cotisations
/// sont toujours conservés quand on quitte un groupe.
class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  final GroupsService _groupsService = GroupsService();
  final String? _myId = Supabase.instance.client.auth.currentUser?.id;

  List<Map<String, dynamic>> _actifs = [];
  List<Map<String, dynamic>> _quittes = [];
  bool _isLoading = true;
  String? _error;
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final actifs = await _groupsService.fetchMyGroups();
      final quittes = await _groupsService.fetchMyLeftGroups();
      if (!mounted) return;
      setState(() {
        _actifs = actifs;
        _quittes = quittes;
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

  bool _estAdmin(Map<String, dynamic> g) => g['admin_id']?.toString() == _myId;

  String _typeAffiche(Map<String, dynamic> g) =>
      (g['type']?.toString().toLowerCase() == 'tontine') ? 'Tontine' : 'Association';

  void _ouvrirGroupe(Map<String, dynamic> g) {
    final montant = num.tryParse((g['montant_cotisation'] ?? '').toString());
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          groupId: g['id'].toString(),
          groupName: (g['nom'] ?? 'Groupe').toString(),
          type: _typeAffiche(g),
          frequency: (g['frequence'] ?? 'Mensuelle').toString(),
          montantCotisation: montant?.toDouble(),
        ),
      ),
    ).then((_) => _load());
  }

  Future<void> _quitter(Map<String, dynamic> g) async {
    final nom = (g['nom'] ?? 'ce groupe').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quitter « $nom » ?'),
        content: const Text(
          "Vous ne recevrez plus les notifications de ce groupe et ne pourrez plus "
          "y cotiser. Votre historique est conservé, et vous pourrez le réintégrer "
          "plus tard depuis cet écran.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitter', style: TextStyle(color: AppColors.brick)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _executer(g, () => _groupsService.quitterGroupe(g['id'].toString()), 'Vous avez quitté « $nom »');
  }

  Future<void> _reintegrer(Map<String, dynamic> g) async {
    final nom = (g['nom'] ?? 'ce groupe').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Réintégrer « $nom » ?'),
        content: const Text("Vous retrouverez l'accès au groupe et à ses notifications."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Réintégrer')),
        ],
      ),
    );
    if (ok != true) return;
    await _executer(g, () => _groupsService.reintegrerGroupe(g['id'].toString()), 'Vous avez réintégré « $nom »');
  }

  Future<void> _executer(
    Map<String, dynamic> g,
    Future<void> Function() action,
    String messageSucces,
  ) async {
    final id = g['id'].toString();
    setState(() => _busyIds.add(id));
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messageSucces)));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    } finally {
      if (mounted) setState(() => _busyIds.remove(id));
    }
  }

  Widget _carteGroupe(Map<String, dynamic> g, {required bool quitte}) {
    final id = g['id'].toString();
    final busy = _busyIds.contains(id);
    final admin = _estAdmin(g);
    final type = _typeAffiche(g);
    final frequence = (g['frequence'] ?? '').toString();

    return InkWell(
      onTap: quitte ? null : () => _ouvrirGroupe(g),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.paperCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.muted.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (g['nom'] ?? 'Groupe').toString(),
                    style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [type, if (frequence.isNotEmpty) frequence, if (admin) 'Administrateur'].join(' · '),
                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
              )
            else if (quitte)
              OutlinedButton(
                onPressed: () => _reintegrer(g),
                child: const Text('Réintégrer', style: TextStyle(fontSize: 12)),
              )
            else if (!admin)
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.brick),
                onPressed: () => _quitter(g),
                child: const Text('Quitter', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
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
          'Mes groupes',
          style: TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Text('Erreur : $_error', style: const TextStyle(color: AppColors.brick)),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      if (_actifs.isEmpty && _quittes.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 60),
                          child: Center(
                            child: Text("Vous n'avez encore aucun groupe", style: TextStyle(color: AppColors.muted)),
                          ),
                        ),
                      if (_actifs.isNotEmpty) ...[
                        const Text('Groupes actifs',
                            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        ..._actifs.map((g) => _carteGroupe(g, quitte: false)),
                      ],
                      if (_quittes.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Groupes quittés',
                            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                        const SizedBox(height: 8),
                        ..._quittes.map((g) => _carteGroupe(g, quitte: true)),
                      ],
                      const SizedBox(height: 20),
                      const Text(
                        "L'administrateur d'un groupe ne peut pas le quitter, et une "
                        "tontine déjà démarrée ne peut pas être quittée.",
                        style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4),
                      ),
                    ],
                  ),
                ),
    );
  }
}