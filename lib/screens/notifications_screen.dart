import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';

class NotificationsScreen extends StatefulWidget {
  /// Change à chaque ouverture de l'onglet : déclenche un rechargement.
  final int refreshToken;

  const NotificationsScreen({super.key, this.refreshToken = 0});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final GroupsService _groupsService = GroupsService();
  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
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
    _notificationsFuture = _groupsService.fetchMyNotifications();
  }

  void _refresh() {
    setState(() {
      _notificationsFuture = _groupsService.fetchMyNotifications();
    });
  }

  Future<void> _onTapNotification(Map<String, dynamic> n) async {
    if (n['lu'] == true) return;
    try {
      await _groupsService.markNotificationRead(n['id'].toString());
      _refresh();
    } catch (_) {
      // Pas grave si ça échoue : la notification reste juste marquée non lue.
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _groupsService.markAllNotificationsRead();
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    }
  }

  String _timeAgo(dynamic value) {
    final d = DateTime.tryParse((value ?? '').toString())?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);

    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Il y a ${diff.inHours} h';
    if (diff.inDays == 1) return 'Hier';
    if (diff.inDays < 7) return 'Il y a ${diff.inDays} jours';

    final j = d.day.toString().padLeft(2, '0');
    final m = d.month.toString().padLeft(2, '0');
    return '$j/$m/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(fontSize: 21, fontFamily: 'serif', color: AppColors.forestDark),
                ),
                TextButton(
                  onPressed: _markAllRead,
                  child: const Text(
                    'Tout marquer comme lu',
                    style: TextStyle(fontSize: 12, color: AppColors.forest),
                  ),
                ),
              ],
            ),
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
                  future: _notificationsFuture,
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
                    final notifications = snapshot.data ?? [];
                    if (notifications.isEmpty) {
                      return ListView(
                        children: const [
                          SizedBox(height: 60),
                          Center(
                            child: Text(
                              'Aucune notification pour le moment',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                      );
                    }
                    return ListView.builder(
                      itemCount: notifications.length,
                      itemBuilder: (context, index) {
                        final n = notifications[index];
                        final bool unread = n['lu'] != true;
                        final String groupe = (n['groups']?['nom'] ?? '').toString();
                        final String texte = (n['contenu'] ?? '').toString();

                        return InkWell(
                          onTap: () => _onTapNotification(n),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: AppColors.muted.withOpacity(0.15))),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6, right: 12),
                                  decoration: BoxDecoration(
                                    color: unread ? AppColors.gold : Colors.transparent,
                                    shape: BoxShape.circle,
                                    border: unread
                                        ? null
                                        : Border.all(color: AppColors.muted.withOpacity(0.3)),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (groupe.isNotEmpty)
                                        Text(
                                          groupe,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.forestDark,
                                          ),
                                        ),
                                      Text(
                                        texte,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          height: 1.4,
                                          color: unread ? AppColors.ink : AppColors.muted,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _timeAgo(n['date']),
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