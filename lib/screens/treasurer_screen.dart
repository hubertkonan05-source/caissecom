import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'roles_screen.dart';
import 'expense_form_screen.dart';
import 'rapport_exercice_screen.dart';

class TreasurerScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final String type;

  const TreasurerScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.type,
  });

  @override
  State<TreasurerScreen> createState() => _TreasurerScreenState();
}

class _TreasurerScreenState extends State<TreasurerScreen> {
  final GroupsService _groupsService = GroupsService();
  final SupabaseClient _db = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _pendingFuture;

  bool get _isTontine => widget.type == 'Tontine';

  // Association : solde et dépenses réels
  num? _solde;
  List<Map<String, dynamic>> _expenses = [];
  String? _caisseError;

  // Association "par occasion" : collecte active
  Map<String, dynamic>? _collecte;

  // Tontine : tour en cours
  Map<String, dynamic>? _tour;
  bool _tourLoaded = false;
  String? _tourError;

  @override
  void initState() {
    super.initState();
    _pendingFuture = _fetchPendingAvecStatutFrais();
    _loadData();
  }

  /// Récupère les cotisations en attente et ajoute, sur chacune, le statut
  /// de ses frais de traitement (champ "_statut_frais"), pour pouvoir
  /// afficher un badge clair plutôt qu'un échec silencieux au clic.
  Future<List<Map<String, dynamic>>> _fetchPendingAvecStatutFrais() async {
    final pending = await _groupsService.fetchPendingContributions(widget.groupId);
    final ids = pending.map((c) => c['id'].toString()).toList();
    Map<String, String> statuts = {};
    try {
      statuts = await _groupsService.fetchStatutsFrais(ids);
    } catch (_) {
      // Si cette vérification échoue, la liste reste utilisable ; seul le
      // badge n'apparaîtra pas, et le serveur bloquera quand même la
      // validation au moment voulu.
    }
    for (final c in pending) {
      c['_statut_frais'] = statuts[c['id'].toString()];
    }
    return pending;
  }

  void _loadData() {
    if (_isTontine) {
      _loadTour();
    } else {
      _loadCaisse();
    }
  }

  void _refreshAll() {
    setState(() {
      _pendingFuture = _fetchPendingAvecStatutFrais();
    });
    _loadData();
  }

  // ---------------------------------------------------------------------
  // Association : caisse
  // ---------------------------------------------------------------------

  Future<void> _loadCaisse() async {
    try {
      final solde = await _db.rpc('solde_caisse', params: {'p_group_id': widget.groupId});
      final exp = await _db
          .from('expenses')
          .select('montant, motif, date')
          .eq('group_id', widget.groupId)
          .order('date', ascending: false)
          .limit(10);
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
        _solde = num.tryParse(solde.toString());
        _expenses = List<Map<String, dynamic>>.from(exp);
        _collecte = collecte;
        _caisseError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _caisseError = e.toString());
    }
  }

  Future<void> _openExpenseForm() async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) => ExpenseFormScreen(groupName: widget.groupName),
      ),
    );
    if (result == null) return;

    final montant = double.tryParse(
          (result['amount'] ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    if (montant <= 0) return;

    try {
      await _groupsService.enregistrerDepense(
        groupId: widget.groupId,
        montant: montant,
        motif: result['motif'] ?? '',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dépense de ${result['amount']} enregistrée')),
      );
      _loadCaisse();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Tontine : tour en cours
  // ---------------------------------------------------------------------

  Future<void> _loadTour() async {
    try {
      final tour = await _db
          .from('beneficiaries')
          .select()
          .eq('group_id', widget.groupId)
          .eq('statut', 'en_cours')
          .maybeSingle();

      if (tour == null) {
        if (!mounted) return;
        setState(() {
          _tour = null;
          _tourLoaded = true;
          _tourError = null;
        });
        return;
      }

      final membres = List<Map<String, dynamic>>.from(
        await _db
            .from('members')
            .select('id, statut, users(nom)')
            .eq('group_id', widget.groupId),
      );
      final actifs = membres.where((m) => (m['statut'] ?? 'actif') == 'actif').length;

      final valides = await _db
          .from('contributions')
          .select('member_id')
          .eq('group_id', widget.groupId)
          .eq('cycle', tour['cycle'])
          .eq('statut', 'valide');
      final nbValides = (valides as List).map((v) => v['member_id']).toSet().length;

      final ben = membres.firstWhere(
        (m) => m['id'] == tour['member_id'],
        orElse: () => <String, dynamic>{},
      );

      if (!mounted) return;
      setState(() {
        _tour = {
          'cycle': tour['cycle'],
          'date_limite': tour['date_limite'],
          'beneficiaire': (ben['users']?['nom'] ?? 'Membre').toString(),
          'attendues': actifs,
          'validees': nbValides,
        };
        _tourLoaded = true;
        _tourError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tourLoaded = true;
        _tourError = e.toString();
      });
    }
  }

  Future<void> _confirmCloseTour() async {
    final nom = _tour?['beneficiaire'] ?? 'le bénéficiaire';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer le tour ?'),
        content: Text(
          'Confirmez que la somme collectée a été versée à $nom. '
          'Le tour suivant s\'ouvrira et cette action est définitive.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (ok == true) await _closeTour();
  }

  Future<void> _closeTour({bool forcer = false}) async {
    try {
      final res = await _db.rpc('cloturer_tour', params: {
        'p_group_id': widget.groupId,
        'p_forcer': forcer,
      });
      final manquantes = int.tryParse(res.toString()) ?? 0;

      if (manquantes > 0 && !forcer) {
        if (!mounted) return;
        final force = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cotisations manquantes'),
            content: Text(
              '$manquantes cotisation(s) ne sont pas encore validées. '
              'Clôturer quand même ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Attendre'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clôturer quand même'),
              ),
            ],
          ),
        );
        if (force == true) await _closeTour(forcer: true);
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tour clôturé — membres notifiés')),
      );
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Paiements à valider
  // ---------------------------------------------------------------------

  Future<void> _showProof(String path) async {
    try {
      final url = await _groupsService.getProofSignedUrl(path);
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: AppColors.paper,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: InteractiveViewer(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(color: AppColors.forest),
                      );
                    },
                    errorBuilder: (context, error, stack) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Impossible d'afficher l'image",
                        style: TextStyle(color: AppColors.brick),
                      ),
                    ),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Fermer'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Future<void> _respond(String contributionId, String statut) async {
    try {
      await _groupsService.updateContributionStatus(contributionId, statut);
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  // ---------------------------------------------------------------------
  // Utilitaires d'affichage
  // ---------------------------------------------------------------------

  String _fmtMontant(num v) {
    final neg = v < 0;
    final s = v.abs().toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final fromEnd = s.length - i;
      buf.write(s[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return '${neg ? '-' : ''}${buf.toString()} FCFA';
  }

  String _fmtDate(dynamic value) {
    if (value == null) return '';
    final d = DateTime.tryParse(value.toString())?.toLocal();
    if (d == null) return '';
    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$j/$m/${d.year}';
  }

  Widget _buildTourCard() {
    if (!_tourLoaded) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AppColors.forest)),
      );
    }
    if (_tourError != null) {
      return Text(
        'Erreur : $_tourError',
        style: const TextStyle(color: AppColors.brick, fontSize: 12),
      );
    }
    if (_tour == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.paperCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.muted.withOpacity(0.2)),
        ),
        child: const Text(
          "Aucun tour en cours. Démarrez la tontine depuis l'écran du groupe.",
          style: TextStyle(fontSize: 13, color: AppColors.muted),
        ),
      );
    }

    final int attendues = (_tour!['attendues'] as int?) ?? 0;
    final int validees = (_tour!['validees'] as int?) ?? 0;
    final double progress = attendues == 0 ? 0 : (validees / attendues).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tour ${_tour!['cycle']} en cours',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            'Bénéficiaire : ${_tour!['beneficiaire']}',
            style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
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
            '$validees / $attendues cotisations validées · avant le ${_fmtDate(_tour!['date_limite'])}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmCloseTour,
              child: const Text('Clôturer le tour'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmCloseCollecte() async {
    final titre = (_collecte?['titre'] ?? 'cette collecte').toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clôturer la collecte ?'),
        content: Text(
          '« $titre » sera clôturée : plus aucune cotisation ne pourra y être '
          'rattachée et les membres seront informés du total collecté.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await _db.rpc('cloturer_collecte', params: {'p_collecte_id': _collecte!['id']});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collecte clôturée — membres notifiés')),
      );
      _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  Widget _buildCollecteCard() {
    final c = _collecte!;
    final int attendus = int.tryParse(c['attendus'].toString()) ?? 0;
    final int valides = int.tryParse(c['valides'].toString()) ?? 0;
    final double progress = attendus == 0 ? 0 : (valides / attendus).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Collecte en cours', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            (c['titre'] ?? '').toString(),
            style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
          ),
          Text(
            '${_fmtMontant(num.tryParse(c['montant'].toString()) ?? 0)} / membre',
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
            '$valides / $attendus validées · '
            '${_fmtMontant(num.tryParse(c['total_collecte'].toString()) ?? 0)} collectés',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _confirmCloseCollecte,
              child: const Text('Clôturer la collecte'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaisseCard() {
    final String soldeTexte = _caisseError != null
        ? 'Solde indisponible'
        : (_solde == null ? 'Calcul en cours…' : _fmtMontant(_solde!));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.paperCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.muted.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solde de la caisse', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(height: 2),
          Text(
            soldeTexte,
            style: const TextStyle(fontSize: 22, fontFamily: 'serif', color: AppColors.forestDark),
          ),
          if (_caisseError != null) ...[
            const SizedBox(height: 4),
            Text(
              _caisseError!,
              style: const TextStyle(color: AppColors.brick, fontSize: 11),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _openExpenseForm,
              child: const Text('Enregistrer une dépense'),
            ),
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
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RolesScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.groups_outlined, size: 18, color: AppColors.forest),
            label: const Text('Rôles', style: TextStyle(color: AppColors.forest, fontSize: 12.5)),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RapportExerciceScreen(
                    groupId: widget.groupId,
                    groupName: widget.groupName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.summarize_outlined, color: AppColors.forest),
            tooltip: 'Rapport financier',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Espace trésorier',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            Text(widget.groupName, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 18),

            if (_isTontine)
              _buildTourCard()
            else ...[
              _buildCaisseCard(),
              if (_collecte != null) ...[
                const SizedBox(height: 12),
                _buildCollecteCard(),
              ],
            ],
            const SizedBox(height: 18),

            const Text('Paiements à valider', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 4),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _pendingFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(color: AppColors.forest));
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Erreur : ${snapshot.error}',
                          style: const TextStyle(color: AppColors.brick, fontSize: 12)),
                    );
                  }
                  final pending = snapshot.data ?? [];
                  if (pending.isEmpty) {
                    return const Center(
                      child: Text('Tous les paiements sont à jour', style: TextStyle(color: AppColors.muted)),
                    );
                  }
                  return ListView.builder(
                    itemCount: pending.length,
                    itemBuilder: (context, index) {
                      final item = pending[index];
                      final nom = item['members']?['users']?['nom'] ?? 'Membre';
                      final montant = item['montant'];
                      final methode = item['moyen_paiement'] ?? '';
                      final statutFrais = item['_statut_frais'];
                      final fraisConfirmes = statutFrais == 'verifie';
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$nom — ${montant.toString()} FCFA',
                                    style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                                Text('Moyen · $methode',
                                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (fraisConfirmes ? AppColors.success : AppColors.brick)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    fraisConfirmes
                                        ? 'Frais CaisseCom confirmés'
                                        : 'Frais CaisseCom non confirmés',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: fraisConfirmes ? AppColors.success : AppColors.brick,
                                    ),
                                  ),
                                ),
                                if (item['preuve_url'] != null)
                                  InkWell(
                                    onTap: () => _showProof(item['preuve_url'].toString()),
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4),
                                      child: Text(
                                        'Voir la preuve',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: AppColors.forest,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: fraisConfirmes
                                        ? AppColors.success
                                        : AppColors.muted.withOpacity(0.25),
                                    foregroundColor: fraisConfirmes ? Colors.white : AppColors.muted,
                                  ),
                                  onPressed: fraisConfirmes
                                      ? () => _respond(item['id'], 'valide')
                                      : () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Validation impossible : les 100 FCFA de frais n'ont pas "
                                                "encore été confirmés par CaisseCom.",
                                              ),
                                            ),
                                          );
                                        },
                                  icon: const Icon(Icons.check, size: 16),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.brick.withOpacity(0.12),
                                    foregroundColor: AppColors.brick,
                                  ),
                                  onPressed: () => _respond(item['id'], 'rejete'),
                                  icon: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            if (!_isTontine && _expenses.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Dépenses récentes', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
              const SizedBox(height: 4),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  itemCount: _expenses.length,
                  itemBuilder: (context, index) {
                    final e = _expenses[index];
                    final num montant = num.tryParse(e['montant'].toString()) ?? 0;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              (e['motif'] ?? '').toString(),
                              style: const TextStyle(fontSize: 13, color: AppColors.ink),
                            ),
                          ),
                          Text(
                            '- ${_fmtMontant(montant)}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brick,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}