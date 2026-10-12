import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'signup_screen.dart';
import 'login_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            height: 230,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: AppColors.forest,
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.all(24),
            child: const Text(
              'CaisseCom',
              style: TextStyle(
                color: AppColors.paper,
                fontSize: 26,
                fontFamily: 'serif',
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La caisse commune, sans le cahier',
                    style: TextStyle(
                      fontSize: 23,
                      fontFamily: 'serif',
                      color: AppColors.forestDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 3,
                    width: 44,
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Gère tes tontines et les cotisations de ton association "
                    "au même endroit, avec un suivi que tout le monde peut voir.",
                    style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.5),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SignupScreen()),
                        );
                      },
                      child: const Text('Créer mon compte'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const LoginScreen()),
                        );
                      },
                      child: const Text("J'ai déjà un compte"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}