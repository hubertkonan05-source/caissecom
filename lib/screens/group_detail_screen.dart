import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'payment_screen.dart';
import 'treasurer_screen.dart';
import 'create_collecte_screen.dart';
import 'invite_members_screen.dart';
import 'group_history_tab.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String type;
  final String frequency;
  final double? montantCotisation;

  const GroupDetailScreen({
    super.key,
    required this.groupId,
    this.groupName = 'Groupe',
    this.type = 'Tontine',
    this.frequency = 'Mensuelle',
    this.montantCotisation,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  int _selectedTab = 0;
  final List<String> _tabs = ['Aperçu', 'Membres', 'Historique'];
  final GroupsService _groupsService = GroupsService();
  final SupabaseClient _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _membersFuture;
  late Future<Map<String, dynamic>> _tontineFuture;

  // Collecte active en mode "Par occasion"
  Map<String, dynamic>? _collecte;
  bool _collecteLoaded = false;
  String? _collecteError;
  num? _solde;

  @override
  void initState() {
    super.initState();
    _membersFuture = _groupsService.fetchGroupMembers(widget.groupId);
    _tontineFuture = _loadTontine();
    _loadCollecte();
  }

  void _refreshMembers() {
    setState(() {
      _membersFuture = _groupsService.fetchGroupMembers(widget.groupId);
      _tontineFuture = _loadTontine();
    });
    _loadCollecte();
  }

  // ---------------------------------------------------------------------
  // Tontine : chargement, démarrage, ordre de passage
  // ---------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadTontine() async {
    if (widget.type != 'Tontine') return {};

    final group = await _db
        .from('groups')
        .select('admin_id')
        .eq('id', widget.groupId)
        .single();

    final tours = await _db
        .from('beneficiaries')
        .select()
        .eq('group_id', widget.groupId)
        .order('cycle');

    final members = await _db
        .from('members')
        .select('id, statut, users(nom)')
        .eq('group_id', widget.groupId);

    return {
      'isAdmin': group['admin_id'] == _db.auth.currentUser?.id,
      'tours': List<Map<String, dynamic>>.from(tours),
      'members': List<Map<String, dynamic>>.from(members),
    };
  }

  Future<void> _startTontine(String mode, {List<String>? ordre}) async {
    try {
      final params = <String, dynamic>{
        'p_group_id': widget.groupId,
        'p_mode': mode,
      };
      if (ordre != null) params['p_ordre'] = ordre;

      await _db.rpc('demarrer_tontine', params: params);
      if (!mounted) return;
      _refreshMembers();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tontine démarrée — membres notifiés')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _chooseStartMode(List<Map<String, dynamic>> activeMembers) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.paper,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.casino_outlined, color: AppColors.forestDark),
              title: const Text('Tirage au sort'),
              subtitle: const Text("L'app tire l'ordre de passage au hasard"),
              onTap: () => Navigator.pop(ctx, 'tirage'),
            ),
            ListTile(
              leading: const Icon(Icons.reorder, color: AppColors.forestDark),
              title: const Text('Ordre manuel'),
              subtitle: const Text('Vous choisissez qui reçoit en premier'),
              onTap: () => Navigator.pop(ctx, 'manuel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'tirage') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Démarrer la tontine ?'),
          content: const Text(
            "L'ordre sera tiré au sort et ne pourra plus être modifié.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tirer au sort'),
            ),
          ],
        ),
      );
      if (ok == true) await _startTontine('tirage');
    } else {
      final items = activeMembers
          .map((m) => <String, String>{
                'id': m['id'].toString(),
                'nom': (m['users']?['nom'] ?? 'Membre').toString(),
              })
          .toList();

      final ordre = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.paper,
        builder: (ctx) => _OrdreManuelSheet(members: items),
      );
      if (ordre != null) await _startTontine('manuel', ordre: ordre);
    }
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '';
    final d = DateTime.tryParse(value.toString())?.toLocal();
    if (d == null) return '';
    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$j/$m/${d.year}';
  }

  Widget _buildTontineSection() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _tontineFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
          );
        }
        if (snapshot.hasError) {
          return Text(
            'Erreur : ${snapshot.error}',
            style: const TextStyle(color: AppColors.brick, fontSize: 12),
          );
        }

        final data = snapshot.data ?? {};
        final bool isAdmin = data['isAdmin'] == true;
        final tours = (data['tours'] as List<Map<String, dynamic>>?) ?? [];
        final allMembers = (data['members'] as List<Map<String, dynamic>>?) ?? [];
        final activeMembers =
            allMembers.where((m) => (m['statut'] ?? 'actif') == 'actif').toList();
        final names = <String, String>{
          for (final m in allMembers)
            m['id'].toString(): (m['users']?['nom'] ?? 'Membre').toString(),
        };

        // Tontine pas encore démarrée
        if (tours.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ordre de passage',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                const SizedBox(height: 4),
                const Text(
                  "La tontine n'a pas encore démarré",
                  style: TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
                ),
                const SizedBox(height: 6),
                Text(
                  '${activeMembers.length} membre(s) actif(s)',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 10),
                if (isAdmin && activeMembers.length >= 2)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _chooseStartMode(activeMembers),
                      child: const Text('Démarrer la tontine'),
                    ),
                  )
                else if (isAdmin)
                  const Text(
                    'Invitez au moins 2 membres pour démarrer.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  )
                else
                  const Text(
                    "En attente du démarrage par l'administrateur.",
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
              ],
            ),
          );
        }

        // Tontine démarrée
        final current = tours.firstWhere(
          (t) => t['statut'] == 'en_cours',
          orElse: () => <String, dynamic>{},
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.gold.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current.isEmpty
                        ? 'Tontine terminée'
                        : 'Tour ${current['cycle']} sur ${tours.length}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    current.isEmpty
                        ? 'Tous les tours ont été servis'
                        : 'Bénéficiaire : ${names[current['member_id'].toString()] ?? 'Membre'}',
                    style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
                  ),
                  if (current.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Cotisations à verser avant le ${_fmtDate(current['date_limite'])}',
                      style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ordre de passage',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            for (final t in tours) _tourRow(t, names),
          ],
        );
      },
    );
  }

  Widget _tourRow(Map<String, dynamic> t, Map<String, String> names) {
    final String statut = (t['statut'] ?? 'a_venir').toString();
    final String nom = names[t['member_id'].toString()] ?? 'Membre';
    final String label = statut == 'cloture'
        ? 'Reçu'
        : (statut == 'en_cours' ? 'En cours' : 'À venir');
    final Color color = statut == 'cloture'
        ? AppColors.success
        : (statut == 'en_cours' ? AppColors.gold : AppColors.muted);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: AppColors.forest.withOpacity(0.12),
            child: Text(
              '${t['cycle']}',
              style: const TextStyle(fontSize: 12, color: AppColors.forestDark),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                Text(
                  'Avant le ${_fmtDate(t['date_limite'])}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Collecte "Par occasion"
  // ---------------------------------------------------------------------

  Future<void> _loadCollecte() async {
    final bool occasional = widget.type != 'Tontine' && widget.frequency == 'Par occasion';
    if (!occasional) {
      if (widget.type != 'Tontine') {
        try {
          final r = await _db.rpc('solde_caisse', params: {'p_group_id': widget.groupId});
          if (mounted) setState(() => _solde = num.tryParse(r.toString()));
        } catch (_) {
          // Le solde reste affiché comme "en cours" si le calcul échoue.
        }
      }
      if (mounted) setState(() => _collecteLoaded = true);
      return;
    }

    try {
      final c = await _db
          .from('collectes')
          .select()
          .eq('group_id', widget.groupId)
          .eq('statut', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      Map<String, dynamic>? collecte;
      if (c != null) {
        final resume = Map<String, dynamic>.from(
          await _db.rpc('resume_collecte', params: {'p_collecte_id': c['id']}) as Map,
        );
        collecte = {
          ...c,
          'valides': resume['valides'],
          'attendus': resume['attendus'],
          'total_collecte': resume['total'],
        };
      }

      if (!mounted) return;
      setState(() {
        _collecte = collecte;
        _collecteLoaded = true;
        _collecteError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _collecteLoaded = true;
        _collecteError = e.toString();
      });
    }
  }

  Future<void> _launchCollecte() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateCollecteScreen(groupName: widget.groupName),
      ),
    );
    if (result == null) return;

    final titre = (result['title'] ?? '').trim();
    final montant = double.tryParse(
          (result['amount'] ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;

    if (titre.isEmpty || montant <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre ou montant invalide')),
      );
      return;
    }

    try {
      await _db.rpc('lancer_collecte', params: {
        'p_group_id': widget.groupId,
        'p_titre': titre,
        'p_montant': montant,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Collecte "$titre" lancée — membres notifiés')),
      );
      _loadCollecte();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  String _fmtMontant(dynamic value) {
    final num v = num.tryParse(value.toString()) ?? 0;
    final neg = v < 0;
    final digits = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return '${neg ? '-' : ''}${buf.toString()} FCFA';
  }

  Widget _buildCollecteSection() {
    if (!_collecteLoaded) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      );
    }
    if (_collecteError != null) {
      return Text(
        'Erreur : $_collecteError',
        style: const TextStyle(color: AppColors.brick, fontSize: 12),
      );
    }

    final c = _collecte;
    if (c == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.gold.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Collecte en cours', style: TextStyle(fontSize: 13, color: AppColors.muted)),
            SizedBox(height: 4),
            Text(
              'Aucune collecte active pour le moment',
              style: TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            SizedBox(height: 6),
            Text(
              "Le responsable peut en lancer une avec l'icône en haut à droite.",
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final int attendus = int.tryParse(c['attendus'].toString()) ?? 0;
    final int valides = int.tryParse(c['valides'].toString()) ?? 0;
    final double progress = attendus == 0 ? 0 : (valides / attendus).clamp(0.0, 1.0);
    final String limite = _fmtDate(c['date_limite']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Collecte en cours', style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            (c['titre'] ?? '').toString(),
            style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
          ),
          const SizedBox(height: 2),
          Text(
            '${_fmtMontant(c['montant'])} / membre',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.muted.withOpacity(0.15),
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$valides / $attendus cotisations validées · ${_fmtMontant(c['total_collecte'])} collectés',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (limite.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              "À verser avant le $limite",
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isTontine = widget.type == 'Tontine';
    final bool isOccasional = !isTontine && widget.frequency == 'Par occasion';
    final String montantAffiche = widget.montantCotisation != null
        ? '${widget.montantCotisation!.toStringAsFixed(0)} FCFA'
        : '';

    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.forestDark),
        actions: [
          if (isOccasional)
            IconButton(
              onPressed: _launchCollecte,
              icon: const Icon(Icons.campaign_outlined, color: AppColors.forestDark),
              tooltip: 'Lancer une collecte',
            ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TreasurerScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                    type: widget.type,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.forestDark),
            tooltip: 'Espace trésorier',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.groupName,
              style: const TextStyle(fontSize: 21, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 2),
            Text(
              isTontine
                  ? 'Tontine · $montantAffiche / ${widget.frequency.toLowerCase()}'
                  : (isOccasional ? 'Cotisation par occasion' : 'Caisse commune · $montantAffiche'),
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.paperCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.muted.withOpacity(0.2)),
              ),
              child: Row(
                children: List.generate(_tabs.length, (i) {
                  final selected = _selectedTab == i;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedTab = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.forest : Colors.transparent,
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _tabs[i],
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                            color: selected ? AppColors.paper : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(child: _buildTabContent(isTontine, isOccasional)),
          ],
        ),
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.paper,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => InviteMembersScreen(
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                    ),
                  ),
                ).then((_) => _refreshMembers());
              },
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Ajouter un membre'),
            )
          : FloatingActionButton.extended(
              backgroundColor: AppColors.forest,
              foregroundColor: AppColors.paper,
              onPressed: () {
                if (isOccasional && _collecte == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Aucune collecte en cours pour le moment')),
                  );
                  return;
                }
                final String amount = isTontine
                    ? montantAffiche
                    : (isOccasional ? _fmtMontant(_collecte!['montant']) : montantAffiche);
                final String cycleInfo = isTontine
                    ? 'Cycle en cours'
                    : (isOccasional ? (_collecte!['titre'] ?? 'Collecte').toString() : 'Cotisation du mois');

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaymentScreen(
                      groupId: widget.groupId,
                      groupName: widget.groupName,
                      amount: amount,
                      cycleInfo: cycleInfo,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.payments_outlined, size: 18),
              label: const Text('Cotiser'),
            ),
    );
  }

  Widget _buildMembersList() {
    return RefreshIndicator(
      onRefresh: () async => _refreshMembers(),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _membersFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.forest));
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur : ${snapshot.error}',
                style: const TextStyle(color: AppColors.brick, fontSize: 12),
              ),
            );
          }
          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 40),
                Center(child: Text('Aucun membre pour le moment', style: TextStyle(color: AppColors.muted))),
              ],
            );
          }
          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final m = members[index];
              final nom = m['users']?['nom'] ?? 'Membre';
              final role = m['roles']?['nom'] ?? 'Membre';
              final statut = m['statut'] ?? 'actif';
              return _memberRow(
                nom,
                role,
                statut == 'actif' ? AppColors.success : AppColors.muted,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTabContent(bool isTontine, bool isOccasional) {
    if (_selectedTab == 0) {
      return RefreshIndicator(
        onRefresh: () async => _refreshMembers(),
        child: ListView(
          children: [
            if (isTontine)
              _buildTontineSection()
            else if (isOccasional)
              _buildCollecteSection()
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.forest.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Solde de la caisse', style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    Text(
                      _solde == null ? 'Calcul en cours…' : _fmtMontant(_solde),
                      style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            const Text('Membres du groupe', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 4),
            SizedBox(height: 260, child: _buildMembersList()),
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      return _buildMembersList();
    } else {
      return GroupHistoryTab(groupId: widget.groupId);
    }
  }

  Widget _memberRow(String name, String status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Text(name, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
            ],
          ),
          Text(status, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Feuille pour choisir manuellement l'ordre de passage (glisser-déposer).
class _OrdreManuelSheet extends StatefulWidget {
  final List<Map<String, String>> members;

  const _OrdreManuelSheet({required this.members});

  @override
  State<_OrdreManuelSheet> createState() => _OrdreManuelSheetState();
}

class _OrdreManuelSheetState extends State<_OrdreManuelSheet> {
  late List<Map<String, String>> _items;

  @override
  void initState() {
    super.initState();
    _items = List<Map<String, String>>.from(widget.members);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ordre de passage',
              style: TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 4),
            const Text(
              'Maintenez un nom et glissez-le pour le déplacer. Le premier de la liste reçoit en premier.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ReorderableListView(
                shrinkWrap: true,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _items.removeAt(oldIndex);
                    _items.insert(newIndex, item);
                  });
                },
                children: [
                  for (int i = 0; i < _items.length; i++)
                    ListTile(
                      key: ValueKey(_items[i]['id']),
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.forest,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(fontSize: 12, color: AppColors.paper),
                        ),
                      ),
                      title: Text(_items[i]['nom'] ?? ''),
                      trailing: const Icon(Icons.drag_handle, color: AppColors.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _items.map((e) => e['id']!).toList(),
                ),
                child: const Text("Valider l'ordre et démarrer"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}