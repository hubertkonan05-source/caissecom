  import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Envoie le code OTP par SMS au numéro donné.
  /// À utiliser uniquement à l'inscription ou pour un mot de passe oublié (le SMS est payant).
  Future<void> sendOtp(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Vérifie le code reçu, puis crée la ligne "users" si elle n'existe pas encore.
  Future<void> verifyOtp({required String phone, required String token, String? nom}) async {
    final response = await _client.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.sms,
    );
    final authUser = response.user;
    if (authUser == null) throw Exception('Vérification échouée');

    final existing = await _client.from('users').select('id').eq('id', authUser.id).maybeSingle();
    if (existing == null) {
      await _client.from('users').insert({
        'id': authUser.id,
        'telephone': phone,
        'nom': nom ?? '',
      });
    }
  }

  /// Connexion avec numéro + mot de passe : aucun SMS envoyé.
  Future<void> signInWithPassword({required String phone, required String password}) async {
    final response = await _client.auth.signInWithPassword(
      phone: phone,
      password: password,
    );
    if (response.user == null) throw Exception('Connexion échouée');
  }

  /// Définit (ou remplace) le mot de passe de l'utilisateur connecté.
  /// Appelé juste après une vérification par code SMS.
  Future<void> setPassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  /// Supprime le compte : les données personnelles sont effacées côté serveur
  /// (l'historique des groupes est conservé, anonymisé), puis l'utilisateur
  /// est déconnecté de cet appareil.
  Future<void> deleteAccount() async {
    await _client.rpc('supprimer_mon_compte');
    try {
      await _client.auth.signOut();
    } catch (_) {
      // Le compte est déjà désactivé côté serveur : si la déconnexion échoue
      // (session déjà invalide), la session locale est de toute façon retirée.
    }
  }

  String? get currentUserId => _client.auth.currentUser?.id;
  String? get currentPhone => _client.auth.currentUser?.phone;
  bool get isLoggedIn => _client.auth.currentUser != null;

  Future<void> signOut() async => _client.auth.signOut();

  /// Transforme une erreur technique en message compréhensible.
  static String friendlyError(Object e) {
    final String message = e is AuthException ? e.message : e.toString();
    final lower = message.toLowerCase();

    if (lower.contains('invalid login credentials')) {
      return 'Numéro ou mot de passe incorrect';
    }
    if (lower.contains('expired or is invalid') || lower.contains('otp_expired')) {
      return 'Code invalide ou expiré';
    }
    if (lower.contains('rate limit') ||
        lower.contains('too many') ||
        lower.contains('security purposes')) {
      return 'Trop de tentatives. Patientez une minute avant de réessayer.';
    }
    if (lower.contains('different from the old password') ||
        lower.contains('same password')) {
      return "Choisissez un mot de passe différent de l'ancien";
    }
    if (lower.contains('password should be at least') ||
        lower.contains('weak_password')) {
      return 'Mot de passe trop court ou trop simple';
    }
    return 'Erreur : $message';
  }
}