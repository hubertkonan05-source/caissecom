import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

/// Onglet "Historique" d'un groupe : journal des événements, filtré
/// automatiquement côté serveur selon le rôle de l'utilisateur connecté
/// (administrateur, trésorier, secrétaire ou membre simple).
class GroupHistoryTab extends StatefulWidget {
  final String groupId;

  const GroupHistoryTab({super.key, required this.groupId});

  @override
  State<GroupHistoryTab> createState() => _GroupHistoryTabState();
}

enum _Periode { tout, aujourdhui, semaine, mois, annee, personnalisee }

class _GroupHistoryTabState extends State<GroupHistoryTab> {
  final GroupsService _groupsService = GroupsService();
  final TextEditingController _searchController = TextEditingController();
  static const int _pageSize = 30;

  final List<Map<String, dynamic>> _entries = [];
  String? _categorie; // null = Tout
  _Periode _periode = _Periode.tout;
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String _recherche = '';

  bool _accesLoaded = false;
  List<Map<String, String?>> _filtresCategorie = const [
    {'label': 'Tout', 'value': null},
  ];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _error;

  static const Map<_Periode, String> _labelsPeriode = {
    _Periode.tout: 'Toujours',
    _Periode.aujourdhui: "Aujourd'hui",
    _Periode.semaine: 'Cette semaine',
    _Periode.mois: 'Ce mois',
    _Periode.annee: 'Cette année',
    _Periode.personnalisee: 'Période personnalisée',
  };

  @override
  void initState() {
    super.initState();
    _initAccesEtCharger();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initAccesEtCharger() async {
    try {
      final acces = await _groupsService.fetchMonAccesHistorique(widget.groupId);
      final bool admin = acces['est_admin'] == true;
      final bool tresorier = acces['est_tresorier'] == true;
      final bool secretaire = acces['est_secretaire'] == true;

      final filtres = <Map<String, String?>>[
        {'label': 'Tout', 'value': null},
      ];
      if (admin || tresorier) filtres.add({'label': 'Finances', 'value': 'financier'});
      if (admin || secretaire) filtres.add({'label': 'Membres', 'value': 'membres'});
      if (admin || secretaire) filtres.add({'label': 'Administration', 'value': 'administratif'});

      if (!mounted) return;
      setState(() {
        _filtresCategorie = filtres;
        _accesLoaded = true;
      });
    } catch (_) {
      // Si la vérification échoue, on garde juste le filtre "Tout" par défaut.
      if (!mounted) return;
      setState(() => _accesLoaded = true);
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _entries.clear();
      _hasMore = true;
    });
    try {
      final data = await _groupsService.fetchHistoriqueGroupe(
        groupId: widget.groupId,
        categorie: _categorie,
        limit: _pageSize,
        offset: 0,
        recherche: _recherche.trim().isEmpty ? null : _recherche.trim(),
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(data);
        _hasMore = data.length == _pageSize;
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

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final data = await _groupsService.fetchHistoriqueGroupe(
        groupId: widget.groupId,
        categorie: _categorie,
        limit: _pageSize,
        offset: _entries.length,
        recherche: _recherche.trim().isEmpty ? null : _recherche.trim(),
        dateDebut: _dateDebut,
        dateFin: _dateFin,
      );
      if (!mounted) return;
      setState(() {
        _entries.addAll(data);
        _hasMore = data.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  void _selectCategorie(String? value) {
    if (value == _categorie) return;
    setState(() => _categorie = value);
    _load();
  }

  Future<void> _openPeriodeSheet() async {
    final choix = await showModalBottomSheet<_Periode>(
      context: context,
      backgroundColor: AppColors.paper,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Période',
                  style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
                ),
              ),
            ),
            const SizedBox(height: 4),
            ..._labelsPeriode.entries.map((entry) {
              final selected = entry.key == _periode;
              return ListTile(
                title: Text(entry.value),
                trailing: selected ? const Icon(Icons.check, color: AppColors.forest) : null,
                onTap: () => Navigator.pop(ctx, entry.key),
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choix == null) return;
    await _appliquerPeriode(choix);
  }

  Future<void> _appliquerPeriode(_Periode p) async {
    final now = DateTime.now();
    DateTime? debut;
    DateTime? fin;

    switch (p) {
      case _Periode.tout:
        break;
      case _Periode.aujourdhui:
        debut = DateTime(now.year, now.month, now.day);
        fin = debut.add(const Duration(days: 1));
        break;
      case _Periode.semaine:
        debut = now.subtract(Duration(days: now.weekday - 1));
        debut = DateTime(debut.year, debut.month, debut.day);
        fin = now;
        break;
      case _Periode.mois:
        debut = DateTime(now.year, now.month, 1);
        fin = now;
        break;
      case _Periode.annee:
        debut = DateTime(now.year, 1, 1);
        fin = now;
        break;
      case _Periode.personnalisee:
        final plage = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: now,
          initialDateRange: _dateDebut != null && _dateFin != null
              ? DateTimeRange(start: _dateDebut!, end: _dateFin!)
              : null,
        );
        if (plage == null) return; // annulé : on ne change rien
        debut = plage.start;
        fin = plage.end.add(const Duration(days: 1));
        break;
    }

    setState(() {
      _periode = p;
      _dateDebut = debut;
      _dateFin = fin;
    });
    _load();
  }

  String _fmtDateTime(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '';
    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    final h = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$j/$m/${d.year} à $h:$min';
  }

  IconData _iconeCategorie(String categorie) {
    switch (categorie) {
      case 'financier':
        return Icons.payments_outlined;
      case 'membres':
        return Icons.people_outline;
      default:
        return Icons.settings_outlined;
    }
  }

  Color _couleurCategorie(String categorie) {
    switch (categorie) {
      case 'financier':
        return AppColors.forest;
      case 'membres':
        return const Color(0xFF8A6A17);
      default:
        return AppColors.muted;
    }
  }

  String _fmtMontant(dynamic value) {
    final num? v = num.tryParse((value ?? '').toString());
    if (v == null) return (value ?? '').toString();
    final digits = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return '${buf.toString()} FCFA';
  }

  Widget _champDetail(String label, String valeur) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          Expanded(
            child: Text(valeur, style: const TextStyle(fontSize: 13, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> entry) {
    final Map<String, dynamic>? avant =
        entry['log_old_data'] is Map ? Map<String, dynamic>.from(entry['log_old_data']) : null;
    final Map<String, dynamic>? apres =
        entry['log_new_data'] is Map ? Map<String, dynamic>.from(entry['log_new_data']) : null;
    final String auteur = (entry['auteur_nom'] ?? '').toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          (entry['log_description'] ?? entry['log_action'] ?? '').toString(),
          style: const TextStyle(fontSize: 15, fontFamily: 'serif'),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _champDetail('Date', _fmtDateTime(entry['log_created_at'])),
              if (auteur.isNotEmpty) _champDetail('Effectué par', auteur),
              if (apres?['membre'] != null) _champDetail('Membre', apres!['membre'].toString()),
              if (apres?['montant'] != null) _champDetail('Montant', _fmtMontant(apres!['montant'])),
              if (apres?['moyen_paiement'] != null)
                _champDetail('Moyen', apres!['moyen_paiement'].toString()),
              if (apres?['numero_expediteur'] != null)
                _champDetail('Numéro utilisé', apres!['numero_expediteur'].toString()),
              if (apres?['motif'] != null) _champDetail('Motif', apres!['motif'].toString()),
              if (apres?['statut'] != null) _champDetail('Statut', apres!['statut'].toString()),

              if (avant?['statut'] != null && apres?['statut'] != null) ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 10),
                _champDetail('Avant', avant!['statut'].toString()),
                _champDetail('Après', apres!['statut'].toString()),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              isDense: true,
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.muted),
              filled: true,
              fillColor: AppColors.paperCard,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.muted.withOpacity(0.25)),
              ),
            ),
            onSubmitted: (value) {
              _recherche = value;
              _load();
            },
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: _periode == _Periode.tout ? AppColors.paperCard : AppColors.gold.withOpacity(0.25),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.muted.withOpacity(0.25)),
          ),
          child: IconButton(
            onPressed: _openPeriodeSheet,
            icon: const Icon(Icons.calendar_today_outlined, size: 19, color: AppColors.forestDark),
            tooltip: _labelsPeriode[_periode],
          ),
        ),
      ],
    );
  }

  Widget _buildChipsCategorie() {
    if (_filtresCategorie.length <= 1) return const SizedBox.shrink();
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filtresCategorie.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _filtresCategorie[i];
          final selected = f['value'] == _categorie;
          return ChoiceChip(
            label: Text(f['label']!, style: const TextStyle(fontSize: 12)),
            selected: selected,
            selectedColor: AppColors.forest,
            backgroundColor: AppColors.paperCard,
            labelStyle: TextStyle(color: selected ? AppColors.paper : AppColors.ink),
            onSelected: (_) => _selectCategorie(f['value']),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_accesLoaded) {
      return const Center(child: CircularProgressIndicator(color: AppColors.forest));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSearchRow(),
        const SizedBox(height: 10),
        _buildChipsCategorie(),
        if (_filtresCategorie.length > 1) const SizedBox(height: 10),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.forest));
    }
    if (_error != null) {
      return Center(
        child: Text('Erreur : $_error', style: const TextStyle(color: AppColors.brick, fontSize: 12)),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('Aucun événement pour le moment', style: TextStyle(color: AppColors.muted)),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _entries.length + 1,
        itemBuilder: (context, index) {
          if (index == _entries.length) {
            if (!_hasMore) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: _isLoadingMore
                    ? const CircularProgressIndicator(color: AppColors.forest)
                    : TextButton(
                        onPressed: _loadMore,
                        child: const Text('Charger plus'),
                      ),
              ),
            );
          }

          final e = _entries[index];
          final categorie = (e['log_categorie'] ?? '').toString();
          final auteur = (e['auteur_nom'] ?? '').toString();

          return InkWell(
            onTap: () => _showDetail(e),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(_iconeCategorie(categorie), size: 18, color: _couleurCategorie(categorie)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (e['log_description'] ?? e['log_action'] ?? '').toString(),
                          style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          auteur.isEmpty
                              ? _fmtDateTime(e['log_created_at'])
                              : '${_fmtDateTime(e['log_created_at'])} · $auteur',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}