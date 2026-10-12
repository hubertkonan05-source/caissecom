import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/groups_service.dart';
import 'group_detail_screen.dart';

/// Écran permettant de rejoindre un groupe existant avec un code d'invitation
/// (reçu par lien ou communiqué à l'oral).
class JoinGroupScreen extends StatefulWidget {
  const JoinGroupScreen({super.key});

  @override
  State<JoinGroupScreen> createState() => _JoinGroupScreenState();
}

class _JoinGroupScreenState extends State<JoinGroupScreen> {
  final GroupsService _groupsService = GroupsService();
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final group = await _groupsService.joinGroupByCode(code);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GroupDetailScreen(
            groupId: group['group_id'].toString(),
            groupName: (group['nom'] ?? 'Groupe').toString(),
            type: (group['type'] ?? 'Tontine').toString(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rejoindre un groupe',
              style: TextStyle(fontSize: 23, fontFamily: 'serif', color: AppColors.forestDark),
            ),
            const SizedBox(height: 6),
            const Text(
              "Entrez le code reçu par lien ou communiqué par l'administrateur du groupe.",
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontFamily: 'serif', letterSpacing: 4),
              decoration: InputDecoration(
                hintText: 'FK29X4',
                filled: true,
                fillColor: AppColors.paperCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.muted.withOpacity(0.3)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _join,
                child: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Rejoindre'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}