import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'screens/onboarding_screen.dart';
import 'screens/dashboard_screen.dart';

 Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://leskswzjtdkynnqvmero.supabase.co',
    publishableKey: 'sb_publishable_blO5-JvvKIQt83xlWf674Q_V_emfG-s',
  );

  runApp(const CaissecomApp());
}

// Accès pratique au client Supabase depuis n'importe quel écran
final supabase = Supabase.instance.client;

// TEST : mets à false pour toujours revenir à l'écran d'accueil au lancement,
// même si une session existe déjà sur le téléphone (pratique pour tester
// plusieurs comptes/numéros d'affilée sans avoir à se déconnecter à chaque fois).
// Remets à true une fois les tests terminés pour retrouver le comportement normal.
const bool kGarderSessionOuverte = false;

class CaissecomApp extends StatelessWidget {
  const CaissecomApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Si l'utilisateur s'est déjà connecté sur ce téléphone, Supabase a gardé
    // sa session : on ouvre directement le tableau de bord, sans SMS ni mot de passe.
    final bool isLoggedIn = kGarderSessionOuverte && supabase.auth.currentSession != null;

    return MaterialApp(
      title: 'CaisseCom',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      home: isLoggedIn ? const DashboardScreen() : const OnboardingScreen(),
    );
  }
}