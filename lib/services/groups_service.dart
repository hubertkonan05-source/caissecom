import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Id fixe du rôle "Administrateur" créé une fois pour toutes dans la table roles.
const String adminRoleId = '2b6d9277-108c-41f8-abf3-6c4b56585fd8';

// Nom du bucket Supabase Storage (privé) qui contient les preuves de paiement.
const String proofsBucket = 'preuves';

class GroupsService {
  final SupabaseClient _client = Supabase.instance.client;

  String get _currentUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw Exception('Aucun utilisateur connecté');
    return id;
  }

  /// Récupère tous les groupes de l'utilisateur connecté :
  /// ceux qu'il administre, et ceux dont il est simple membre.
  Future<List<Map<String, dynamic>>> fetchMyGroups() async {
    final adminResponse = await _client
        .from('groups')
        .select()
        .eq('admin_id', _currentUserId);

    final byId = <String, Map<String, dynamic>>{
      for (final g in List<Map<String, dynamic>>.from(adminResponse))
        g['id'].toString(): g,
    };

    // Groupes où l'utilisateur est membre (sans être admin).
    // En cas d'échec (relation ou droits d'accès), on garde au moins ses groupes d'admin.
    try {
      final memberResponse = await _client
          .from('members')
          .select('groups(*)')
          .eq('user_id', _currentUserId)
          .or('statut.eq.actif,statut.is.null');

      for (final row in List<Map<String, dynamic>>.from(memberResponse)) {
        final g = row['groups'];
        if (g is Map<String, dynamic>) {
          byId.putIfAbsent(g['id'].toString(), () => g);
        }
      }
    } catch (e) {
      debugPrint('fetchMyGroups (membres) : $e');
    }

    final groups = byId.values.toList();
    groups.sort((a, b) => (b['created_at'] ?? '')
        .toString()
        .compareTo((a['created_at'] ?? '').toString()));
    return groups;
  }

  /// Récupère les membres d'un groupe, avec leur nom et leur rôle.
  Future<List<Map<String, dynamic>>> fetchGroupMembers(String groupId) async {
    final response = await _client
        .from('members')
        .select('id, user_id, role_id, statut, users(nom, telephone), roles(nom)')
        .eq('group_id', groupId);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Retrouve l'id de la ligne "members" de l'utilisateur connecté dans un groupe donné.
  Future<String?> fetchMyMemberId(String groupId) async {
    final response = await _client
        .from('members')
        .select('id')
        .eq('group_id', groupId)
        .eq('user_id', _currentUserId)
        .maybeSingle();
    return response?['id'] as String?;
  }

  /// Envoie la capture du reçu dans le stockage privé et retourne son chemin.
  Future<String> uploadProof({
    required String groupId,
    required String memberId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final ext = extension.toLowerCase() == 'png' ? 'png' : 'jpg';
    final path = '$groupId/${memberId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _client.storage.from(proofsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
    return path;
  }

  /// Génère un lien temporaire (1 heure) pour afficher une preuve de paiement.
  Future<String> getProofSignedUrl(String path) async {
    return _client.storage.from(proofsBucket).createSignedUrl(path, 3600);
  }

  /// Enregistre une cotisation, en attente de validation par le trésorier.
  Future<String> createContribution({
    required String groupId,
    required String memberId,
    required double montant,
    required String moyenPaiement,
    String? preuveUrl,
    String? numeroExpediteur,
  }) async {
    final response = await _client
        .from('contributions')
        .insert({
          'group_id': groupId,
          'member_id': memberId,
          'montant': montant,
          'moyen_paiement': moyenPaiement,
          'preuve_url': preuveUrl,
          'numero_expediteur': numeroExpediteur,
          'statut': 'en_attente',
        })
        .select('id')
        .single();
    return response['id'].toString();
  }

  /// Récupère les cotisations en attente de validation pour un groupe.
  Future<List<Map<String, dynamic>>> fetchPendingContributions(String groupId) async {
    final response = await _client
        .from('contributions')
        .select('id, montant, moyen_paiement, preuve_url, date, members(users(nom))')
        .eq('group_id', groupId)
        .eq('statut', 'en_attente')
        .order('date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Valide ou rejette une cotisation (tracé dans le journal d'audit du groupe).
  Future<void> updateContributionStatus(String contributionId, String statut) async {
    await _client.rpc('valider_contribution', params: {
      'p_contribution_id': contributionId,
      'p_statut': statut,
    });
  }

  /// Crée un nouveau groupe et ajoute l'utilisateur connecté comme membre admin.
  Future<Map<String, dynamic>> createGroup({
    required String nom,
    required String type, // 'tontine' ou 'association'
    String? frequence,
    double? montantCotisation,
  }) async {
    final groupResponse = await _client
        .from('groups')
        .insert({
          'nom': nom,
          'type': type,
          'frequence': frequence,
          'montant_cotisation': montantCotisation,
          'admin_id': _currentUserId,
        })
        .select()
        .single();

    await _client.from('members').insert({
      'group_id': groupResponse['id'],
      'user_id': _currentUserId,
      'role_id': adminRoleId,
    });

    return groupResponse;
  }

  // ---------------------------------------------------------------------
  // Invitation de membres
  // ---------------------------------------------------------------------

  /// Récupère le nom du groupe et son code d'invitation.
  Future<Map<String, dynamic>> fetchGroupInvite(String groupId) async {
    final response = await _client
        .from('groups')
        .select('id, nom, code_invitation')
        .eq('id', groupId)
        .single();
    return Map<String, dynamic>.from(response);
  }

  /// Cherche un utilisateur déjà inscrit par son numéro de téléphone
  /// (au format international, ex. +2250777045928).
  Future<Map<String, dynamic>?> findUserByPhone(String phone) async {
    final response = await _client.rpc('trouver_utilisateur_par_telephone', params: {
      'p_phone': phone,
    });
    final rows = List<Map<String, dynamic>>.from(response as List);
    if (rows.isEmpty) return null;
    return {'id': rows.first['found_id'], 'nom': rows.first['found_nom']};
  }

  /// Vérifie si un utilisateur est déjà membre d'un groupe.
  Future<bool> isAlreadyMember(String groupId, String userId) async {
    final response = await _client
        .from('members')
        .select('id')
        .eq('group_id', groupId)
        .eq('user_id', userId)
        .maybeSingle();
    return response != null;
  }

  /// Id du rôle "Membre" par défaut (celui donné aux personnes ajoutées ou
  /// qui rejoignent via un code d'invitation).
  Future<String> _defaultMemberRoleId() async {
    final response = await _client
        .from('roles')
        .select('id')
        .ilike('nom', 'membre')
        .maybeSingle();
    if (response == null) {
      throw Exception(
        'Aucun rôle "Membre" configuré dans la table roles',
      );
    }
    return response['id'] as String;
  }

  /// Ajoute directement un utilisateur (déjà inscrit) à un groupe
  /// (tracé dans le journal d'audit du groupe).
  Future<void> addMemberByUserId({
    required String groupId,
    required String userId,
  }) async {
    await _client.rpc('ajouter_membre', params: {
      'p_group_id': groupId,
      'p_user_id': userId,
    });
  }

  /// Rejoint un groupe grâce à son code d'invitation (utilisateur connecté).
  Future<Map<String, dynamic>> joinGroupByCode(String code) async {
    final response = await _client.rpc(
      'rejoindre_groupe_par_code',
      params: {'p_code': code},
    );
    return Map<String, dynamic>.from(response as Map);
  }

  // ---------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------

  /// Récupère les notifications de l'utilisateur connecté, les plus récentes en premier.
  Future<List<Map<String, dynamic>>> fetchMyNotifications() async {
    final response = await _client
        .from('notifications')
        .select('id, contenu, type, lu, date, groups(nom)')
        .eq('user_id', _currentUserId)
        .order('date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// Marque une notification comme lue.
  Future<void> markNotificationRead(String notificationId) async {
    await _client.from('notifications').update({'lu': true}).eq('id', notificationId);
  }

  /// Marque toutes les notifications de l'utilisateur connecté comme lues.
  Future<void> markAllNotificationsRead() async {
    await _client
        .from('notifications')
        .update({'lu': true})
        .eq('user_id', _currentUserId)
        .eq('lu', false);
  }


  // ---------------------------------------------------------------------
  // Moyens de paiement (Wave / Orange Money / MTN MoMo)
  // ---------------------------------------------------------------------

  /// Récupère mes propres numéros enregistrés, sous la forme {méthode: numéro}.
  Future<Map<String, String>> fetchMyPaymentMethods() async {
    final response = await _client
        .from('payment_methods')
        .select('methode, numero')
        .eq('user_id', _currentUserId);
    return {
      for (final row in List<Map<String, dynamic>>.from(response))
        row['methode'].toString(): row['numero'].toString(),
    };
  }

  /// Enregistre (ou met à jour) mon numéro pour une méthode donnée.
  Future<void> savePaymentMethod({required String methode, required String numero}) async {
    await _client.from('payment_methods').upsert(
      {
        'user_id': _currentUserId,
        'methode': methode,
        'numero': numero,
      },
      onConflict: 'user_id,methode',
    );
  }

  /// Récupère le numéro de l'administrateur d'un groupe pour une méthode donnée
  /// (le numéro sur lequel envoyer sa cotisation). Retourne null s'il n'est pas configuré.
  Future<Map<String, dynamic>?> fetchGroupReceivingNumber({
    required String groupId,
    required String methode,
  }) async {
    final group = await _client
        .from('groups')
        .select('admin_id')
        .eq('id', groupId)
        .single();

    final adminId = group['admin_id'];

    // On cherche d'abord chez le(s) trésorier(s) du groupe (ceux qui ont le
    // droit de valider les paiements), puis chez l'admin en repli si aucun
    // trésorier n'a renseigné ce moyen.
    final tresoriers = await _client
        .from('members')
        .select('user_id, roles!inner(peut_valider_paiements)')
        .eq('group_id', groupId)
        .eq('roles.peut_valider_paiements', true);

    final candidats = <String>[
      ...List<Map<String, dynamic>>.from(tresoriers)
          .map((m) => m['user_id'].toString()),
      if (adminId != null) adminId.toString(),
    ];

    String? userIdTrouve;
    Map<String, dynamic>? method;
    for (final candidat in candidats.toSet()) {
      final result = await _client
          .from('payment_methods')
          .select('numero')
          .eq('user_id', candidat)
          .eq('methode', methode)
          .maybeSingle();
      if (result != null) {
        method = result;
        userIdTrouve = candidat;
        break;
      }
    }

    if (method == null || userIdTrouve == null) return null;

    final utilisateur = await _client
        .from('users')
        .select('nom')
        .eq('id', userIdTrouve)
        .maybeSingle();

    return {
      'numero': method['numero'],
      'nom_admin': utilisateur?['nom'] ?? 'le trésorier',
    };
  }


  /// Récupère le nom de l'utilisateur connecté.
  Future<String> fetchMyName() async {
    final response = await _client
        .from('users')
        .select('nom')
        .eq('id', _currentUserId)
        .maybeSingle();
    final nom = response?['nom']?.toString().trim();
    return (nom == null || nom.isEmpty) ? 'Utilisateur' : nom;
  }


  // ---------------------------------------------------------------------
  // Rôles
  // ---------------------------------------------------------------------

  /// Récupère l'admin_id d'un groupe (pour identifier l'administrateur parmi les membres).
  Future<String?> fetchGroupAdminId(String groupId) async {
    final response = await _client
        .from('groups')
        .select('admin_id')
        .eq('id', groupId)
        .single();
    return response['admin_id'] as String?;
  }

  /// Liste tous les rôles disponibles (id + nom), pour peupler un menu déroulant.
  Future<List<Map<String, dynamic>>> fetchAllRoles() async {
    final response = await _client.from('roles').select('id, nom').order('nom');
    return List<Map<String, dynamic>>.from(response);
  }

  /// Change le rôle d'un membre (réservé à l'administrateur du groupe).
  Future<void> updateMemberRole({required String memberId, required String roleId}) async {
    await _client.rpc('changer_role_membre', params: {
      'p_member_id': memberId,
      'p_role_id': roleId,
    });
  }


  /// Récupère le nom et le téléphone de l'utilisateur connecté.
  Future<Map<String, String>> fetchMyProfile() async {
    final response = await _client
        .from('users')
        .select('nom, telephone')
        .eq('id', _currentUserId)
        .maybeSingle();
    return {
      'nom': (response?['nom'] ?? 'Utilisateur').toString(),
      'telephone': (response?['telephone'] ?? '').toString(),
    };
  }


  /// Récupère l'historique de l'utilisateur (cotisations, dépenses, cagnottes reçues),
  /// tous groupes confondus, le plus récent en premier.
  Future<List<Map<String, dynamic>>> fetchMyHistory() async {
    final response = await _client.rpc('mon_historique');
    return List<Map<String, dynamic>>.from(response as List);
  }


  // ---------------------------------------------------------------------
  // Frais CaisseCom (100 FCFA par preuve de paiement)
  // ---------------------------------------------------------------------

  /// Récupère les numéros CaisseCom (Wave/Orange Money/MTN MoMo), sous la forme {méthode: numéro}.
  Future<Map<String, String>> fetchCaissecomPaymentMethods() async {
    final response = await _client.from('caissecom_payment_methods').select('methode, numero');
    return {
      for (final row in List<Map<String, dynamic>>.from(response))
        row['methode'].toString(): row['numero'].toString(),
    };
  }

  /// Crée le frais de 100 FCFA lié à une preuve de paiement qui vient d'être envoyée.
  Future<String> creerFraisPreuve({required String groupId, String? contributionId}) async {
    final response = await _client.rpc('creer_frais_preuve', params: {
      'p_group_id': groupId,
      'p_contribution_id': contributionId,
    });
    return response.toString();
  }

  /// Rattache une cotisation (créée après coup) au frais déjà payé.
  Future<void> attacherFraisAContribution({
    required String feeId,
    required String contributionId,
  }) async {
    await _client.rpc('attacher_frais_contribution', params: {
      'p_fee_id': feeId,
      'p_contribution_id': contributionId,
    });
  }

  /// Déclare que les 100 FCFA de frais ont été payés.
  Future<void> declarerPaiementFrais({
    required String feeId,
    required String methode,
    String? reference,
  }) async {
    await _client.rpc('declarer_paiement_frais', params: {
      'p_fee_id': feeId,
      'p_methode': methode,
      'p_reference': reference,
    });
  }

  /// Indique si l'utilisateur connecté est un administrateur CaisseCom.
  Future<bool> isCaissecomAdmin() async {
    final response = await _client
        .from('caissecom_admins')
        .select('user_id')
        .eq('user_id', _currentUserId)
        .maybeSingle();
    return response != null;
  }

  /// (Admin CaisseCom) Enregistre ou met à jour un numéro CaisseCom.
  Future<void> saveCaissecomPaymentMethod({required String methode, required String numero}) async {
    await _client.from('caissecom_payment_methods').upsert(
      {'methode': methode, 'numero': numero, 'updated_at': DateTime.now().toIso8601String()},
      onConflict: 'methode',
    );
  }

  /// (Admin CaisseCom) Récupère les frais déclarés comme payés, en attente de confirmation.
  Future<List<Map<String, dynamic>>> fetchFraisAConfirmer() async {
    final response = await _client
        .from('app_fees')
        .select('id, amount, payment_method, payment_reference, paid_at, user_id')
        .eq('payment_status', 'paye')
        .order('paid_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  /// (Admin CaisseCom) Confirme ou annule un frais déclaré comme payé.
  Future<void> verifierFraisPreuve({required String feeId, required String statut}) async {
    await _client.rpc('verifier_frais_preuve', params: {
      'p_fee_id': feeId,
      'p_statut': statut,
    });
  }

  /// (Admin CaisseCom) Récupère les revenus totaux de CaisseCom.
  Future<Map<String, dynamic>> fetchRevenusCaissecom() async {
    final response = await _client.rpc('revenus_caissecom');
    return Map<String, dynamic>.from(response as Map);
  }


  // ---------------------------------------------------------------------
  // Journal d'audit du groupe
  // ---------------------------------------------------------------------

  /// Enregistre une dépense (tracée dans le journal d'audit du groupe).
  Future<String> enregistrerDepense({
    required String groupId,
    required double montant,
    required String motif,
  }) async {
    final response = await _client.rpc('enregistrer_depense', params: {
      'p_group_id': groupId,
      'p_montant': montant,
      'p_motif': motif,
    });
    return response.toString();
  }

  /// Récupère le journal d'un groupe (filtré automatiquement selon le rôle
  /// de l'utilisateur connecté). [categorie] : 'financier' / 'membres' /
  /// 'administratif', ou null pour tout ce qui lui est accessible.
  Future<List<Map<String, dynamic>>> fetchHistoriqueGroupe({
    required String groupId,
    String? categorie,
    int limit = 30,
    int offset = 0,
    String? recherche,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final response = await _client.rpc('fetch_historique_groupe', params: {
      'p_group_id': groupId,
      'p_categorie': categorie,
      'p_limit': limit,
      'p_offset': offset,
      'p_recherche': recherche,
      'p_date_debut': dateDebut?.toIso8601String(),
      'p_date_fin': dateFin?.toIso8601String(),
    });
    return List<Map<String, dynamic>>.from(response as List);
  }


  /// Indique quels filtres proposer dans l'écran Historique d'un groupe,
  /// selon le rôle de l'utilisateur connecté (admin / trésorier / secrétaire).
  Future<Map<String, dynamic>> fetchMonAccesHistorique(String groupId) async {
    final response = await _client.rpc('mon_acces_historique', params: {
      'p_group_id': groupId,
    });
    return Map<String, dynamic>.from(response as Map);
  }


  // ---------------------------------------------------------------------
  // Exercice comptable
  // ---------------------------------------------------------------------

  /// Résumé de l'exercice en cours (solde, recettes, dépenses, en attente).
  Future<Map<String, dynamic>> fetchResumeExercice(String groupId) async {
    final response = await _client.rpc('resume_exercice', params: {
      'p_group_id': groupId,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// Clôture l'exercice en cours (admin uniquement) et en ouvre un nouveau.
  Future<Map<String, dynamic>> cloturerExercice(String groupId) async {
    final response = await _client.rpc('cloturer_exercice', params: {
      'p_group_id': groupId,
    });
    return Map<String, dynamic>.from(response as Map);
  }

  /// Corrige le montant d'une cotisation déjà enregistrée (régularisation,
  /// tracée avec motif dans le journal d'audit).
  Future<void> regulariserCotisation({
    required String contributionId,
    required double nouveauMontant,
    required String motif,
  }) async {
    await _client.rpc('regulariser_montant_cotisation', params: {
      'p_contribution_id': contributionId,
      'p_nouveau_montant': nouveauMontant,
      'p_motif': motif,
    });
  }


  /// Pour une liste de cotisations en attente, indique si les frais de
  /// traitement de chacune sont déjà confirmés par un admin CaisseCom.
  Future<Map<String, String>> fetchStatutsFrais(List<String> contributionIds) async {
    if (contributionIds.isEmpty) return {};
    final response = await _client.rpc('statut_frais_cotisations', params: {
      'p_contribution_ids': contributionIds,
    });
    final map = <String, String>{};
    for (final row in List<Map<String, dynamic>>.from(response as List)) {
      map[row['contribution_id'].toString()] = row['statut_frais'].toString();
    }
    return map;
  }


  // ---------------------------------------------------------------------
  // Quitter / réintégrer un groupe
  // ---------------------------------------------------------------------

  /// Groupes que l'utilisateur a quittés volontairement (pour pouvoir les réintégrer).
  Future<List<Map<String, dynamic>>> fetchMyLeftGroups() async {
    final response = await _client
        .from('members')
        .select('groups(*)')
        .eq('user_id', _currentUserId)
        .eq('statut', 'quitte');

    final groups = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(response)) {
      final g = row['groups'];
      if (g is Map<String, dynamic>) groups.add(g);
    }
    return groups;
  }

  /// Quitte un groupe (l'historique et les cotisations sont conservés).
  Future<void> quitterGroupe(String groupId) async {
    await _client.rpc('quitter_groupe', params: {'p_group_id': groupId});
  }

  /// Réintègre un groupe quitté volontairement.
  Future<void> reintegrerGroupe(String groupId) async {
    await _client.rpc('reintegrer_groupe', params: {'p_group_id': groupId});
  }

}