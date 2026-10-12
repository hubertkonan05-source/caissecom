import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

class HistoryScreen extends StatefulWidget {
  /// Change à chaque ouverture de l'onglet : déclenche un rechargement.
  final int refreshToken;

  const HistoryScreen({super.key, this.refreshToken = 0});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final GroupsService _groupsService = GroupsService();
  late Future<List<Map<String, dynamic>>> _historyFuture;

  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _historyFuture = _groupsService.fetchMyHistory();
  }

  void _refresh() {
    setState(() {
      _historyFuture = _groupsService.fetchMyHistory();
    });
  }

  String _fmtDate(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '';
    const mois = [
      'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
      'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
    ];
    return '${d.day} ${mois[d.month - 1]}';
  }

  String _fmtMontant(dynamic value) {
    final num v = num.tryParse((value ?? '0').toString()) ?? 0;
    final digits = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final fromEnd = digits.length - i;
      buf.write(digits[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(' ');
    }
    return '${buf.toString()} F';
  }

  String _title(Map<String, dynamic> e) {
    final groupe = (e['groupe'] ?? '').toString();
    switch (e['type']) {
      case 'cotisation':
        return 'Cotisation — $groupe';
      case 'depense':
        return 'Dépense — $groupe';
      case 'cagnotte':
        return 'Cagnotte reçue — $groupe';
      default:
        return groupe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Historique',
              style: TextStyle(fontSize: 21, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const Text('Tous les groupes', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 10),
            Container(
              height: 3,
              width: 44,
              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.forest));
                    }
                    if (snapshot.hasError) {
                      return ListView(
                        children: [
                          const SizedBox(height: 60),
                          Center(
                            child: Text(
                              'Erreur : ${snapshot.error}',
                              style: const TextStyle(color: AppColors.brick, fontSize: 12),
                            ),
                          ),
                        ],
                      );
                    }
                    final entries = snapshot.data ?? [];
                    if (entries.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 60),
                          Center(
                            child: Text(
                              'Aucune opération pour le moment',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (context, index) {
                        final e = entries[index];
                        final bool positif = e['positif'] == true;
                        final String detail = (e['detail'] ?? '').toString();

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
                                    Text(_title(e), style: const TextStyle(fontSize: 14, color: AppColors.ink)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_fmtDate(e['date'])}${detail.isNotEmpty ? ' · $detail' : ''}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${positif ? '+' : '−'}${_fmtMontant(e['montant'])}',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: positif ? AppColors.success : AppColors.brick,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}