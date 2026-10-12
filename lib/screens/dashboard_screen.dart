import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'history_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  // Chaque fois qu'on ouvre un onglet de données (Accueil, Historique,
  // Notifications), son jeton augmente : l'onglet voit le changement et
  // recharge ses informations (sinon il resterait figé sur ce qu'il avait
  // chargé au démarrage de l'app).
  int _homeToken = 0;
  int _historyToken = 0;
  int _notificationsToken = 0;

  void _selectTab(int index) {
    setState(() {
      _currentIndex = index;
      if (index == 0) _homeToken++;
      if (index == 1) _historyToken++;
      if (index == 2) _notificationsToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _HomeTab(
        refreshToken: _homeToken,
        onCreateGroup: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateGroupScreen()),
          );
          // Si un groupe vient d'être créé, on force le rafraîchissement de la liste
          if (created == true) {
            setState(() => _homeToken++);
          }
        },
      ),
      HistoryScreen(refreshToken: _historyToken),
      NotificationsScreen(refreshToken: _notificationsToken),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.paper,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.paperCard,
          border: Border(top: BorderSide(color: AppColors.muted.withOpacity(0.15))),
        ),
        child: SafeArea(
          child: Row(
            children: [
              _navItem(Icons.home_outlined, Icons.home, 'Accueil', 0),
              _navItem(Icons.receipt_long_outlined, Icons.receipt_long, 'Historique', 1),
              _navItem(Icons.notifications_outlined, Icons.notifications, 'Notifications', 2),
              _navItem(Icons.settings_outlined, Icons.settings, 'Paramètres', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData outlineIcon, IconData filledIcon, String label, int index) {
    final bool selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _selectTab(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: selected ? AppColors.forest.withOpacity(0.14) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  selected ? filledIcon : outlineIcon,
                  color: selected ? AppColors.forest : AppColors.muted,
                  size: 22,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? AppColors.forest : AppColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTab extends StatefulWidget {
  final VoidCallback onCreateGroup;
  final int refreshToken;

  const _HomeTab({required this.onCreateGroup, this.refreshToken = 0});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final GroupsService _groupsService = GroupsService();
  late Future<List<Map<String, dynamic>>> _groupsFuture;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _groupsFuture = _groupsService.fetchMyGroups();
    _loadName();
  }

  @override
  void didUpdateWidget(covariant _HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _refresh();
          _loadName();
        }
      });
    }
  }

  Future<void> _loadName() async {
    try {
      final nom = await _groupsService.fetchMyName();
      if (!mounted) return;
      setState(() => _userName = nom);
    } catch (_) {
      // Le prénom reste vide si la requête échoue ; le reste de l'écran fonctionne quand même.
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _groupsFuture = _groupsService.fetchMyGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bonjour', style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      Text(
                        _userName.isEmpty ? '…' : _userName,
                        style: const TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.gold,
                    child: Text(
                      _userName.isEmpty ? '?' : _userName[0].toUpperCase(),
                      style: const TextStyle(color: Color(0xFF23200E), fontFamily: 'serif'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              const Text(
                'Mes groupes',
                style: TextStyle(fontSize: 16, fontFamily: 'serif', color: AppColors.forestDark),
              ),
              const SizedBox(height: 6),

              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _groupsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.forest));
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erreur de connexion à Supabase :\n${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.brick, fontSize: 12),
                          ),
                        );
                      }
                      final groups = snapshot.data ?? [];
                      if (groups.isEmpty) {
                        return ListView(
                          children: const [
                            SizedBox(height: 60),
                            Center(
                              child: Text(
                                "Aucun groupe pour l'instant.\nCrée-en un avec le bouton +",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.builder(
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final g = groups[index];
                          final bool isTontine = g['type'] == 'tontine';
                          return _GroupTile(
                            name: g['nom'] ?? '',
                            type: isTontine ? 'Tontine' : 'Association',
                            status: 'À jour',
                            statusColor: AppColors.success,
                            trailing: g['frequence'] ?? '',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => GroupDetailScreen(
                                    groupId: g['id'],
                                    groupName: g['nom'] ?? '',
                                    type: isTontine ? 'Tontine' : 'Association',
                                    frequency: g['frequence'] ?? 'Mensuelle',
                                    montantCotisation: (g['montant_cotisation'] as num?)?.toDouble(),
                                  ),
                                ),
                              ).then((_) => _refresh());
                            },
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
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.gold,
        foregroundColor: const Color(0xFF23200E),
        onPressed: () async {
          widget.onCreateGroup();
          _refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _GroupTile extends StatelessWidget {
  final String name;
  final String type;
  final String status;
  final Color statusColor;
  final String trailing;
  final VoidCallback onTap;

  const _GroupTile({
    required this.name,
    required this.type,
    required this.status,
    required this.statusColor,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isTontine = type == 'Tontine';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: isTontine
                          ? AppColors.gold.withOpacity(0.18)
                          : AppColors.forest.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isTontine ? const Color(0xFF8A6A17) : AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      Text(status, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              trailing,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}