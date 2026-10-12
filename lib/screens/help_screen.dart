import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

// TODO Konan : remplace par tes vrais contacts avant de publier l'app.
const String _kContactTelephone = '+2250777045928';
const String _kContactEmail = 'nejmadijital@gmail.com';

// TODO Konan : remplace par l'adresse réelle où tu héberges les pages juridiques
// (voir le dossier site_juridique), sans oublier le nom du fichier à la fin.
const String _kUrlConfidentialite = 'https://hubertkonan05-source.github.io/caissecom/confidentialite.html';
const String _kUrlConditions = 'https://hubertkonan05-source.github.io/caissecom/conditions.html';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const List<_FaqSection> _sections = [
    _FaqSection(
      titre: 'Démarrer',
      items: [
        _FaqItem(
          'Comment créer un groupe ?',
          "Depuis l'accueil, touchez le bouton + en bas à droite. Choisissez "
              "« Tontine » ou « Association », donnez un nom, une fréquence et "
              "un montant de cotisation. Une fois créé, vous pouvez inviter des membres.",
        ),
        _FaqItem(
          'Comment inviter des membres ?',
          "Dans l'écran d'un groupe, onglet Membres, utilisez soit le lien ou "
              "le code à partager, soit l'ajout direct par numéro de téléphone "
              "(la personne doit déjà avoir un compte CaisseCom).",
        ),
        _FaqItem(
          'Comment rejoindre un groupe avec un code ?',
          "Depuis l'écran « Rejoindre un groupe », entrez le code à 6 caractères "
              "que l'administrateur vous a transmis.",
        ),
      ],
    ),
    _FaqSection(
      titre: 'Cotiser et payer',
      items: [
        _FaqItem(
          'Comment envoyer ma cotisation ?',
          "Ouvrez le groupe, touchez « Cotiser ». Choisissez le moyen de "
              "paiement, envoyez l'argent directement au trésorier sur le numéro "
              "affiché, puis ajoutez une capture du reçu comme preuve.",
        ),
        _FaqItem(
          "Pourquoi dois-je payer 100 FCFA en plus de ma cotisation ?",
          "Ces 100 FCFA ne font pas partie de votre cotisation : ils rémunèrent "
              "le traitement de votre preuve par CaisseCom. Ils sont payés à part, "
              "sur les numéros CaisseCom affichés, jamais sur ceux de l'association.",
        ),
        _FaqItem(
          'Combien de temps avant que ma cotisation soit validée ?',
          "Le trésorier valide votre cotisation une fois qu'il a vérifié le "
              "paiement reçu, et que CaisseCom a confirmé le paiement des 100 FCFA. "
              "Vous recevez une notification une fois validée.",
        ),
      ],
    ),
    _FaqSection(
      titre: 'Tontines',
      items: [
        _FaqItem(
          "Qu'est-ce que l'ordre de passage ?",
          "C'est l'ordre dans lequel chaque membre reçoit la cagnotte. "
              "L'administrateur le fixe au démarrage, par tirage au sort ou "
              "manuellement.",
        ),
        _FaqItem(
          "Comment un tour se termine-t-il ?",
          "Une fois que les cotisations du tour sont validées, le trésorier "
              "clôture le tour : le bénéficiaire reçoit la cagnotte et le tour "
              "suivant s'ouvre automatiquement.",
        ),
      ],
    ),
    _FaqSection(
      titre: 'Associations',
      items: [
        _FaqItem(
          "Qu'est-ce qu'une collecte par occasion ?",
          "Une cotisation ponctuelle (assistance à un membre, événement...) "
              "lancée par l'administrateur ou le trésorier, en plus des "
              "cotisations régulières.",
        ),
        _FaqItem(
          "Comment voir le solde de la caisse ?",
          "Dans l'espace trésorier du groupe : il est calculé automatiquement "
              "à partir des cotisations validées et des dépenses enregistrées.",
        ),
      ],
    ),
    _FaqSection(
      titre: 'Rôles et sécurité',
      items: [
        _FaqItem(
          'Quels sont les différents rôles ?',
          "Administrateur (tous les droits), Trésorier (valide les paiements, "
              "gère la caisse), Secrétaire (gère les membres et les annonces), "
              "Commissaire aux comptes (consultation), et Membre.",
        ),
        _FaqItem(
          'Comment changer mon mot de passe ?',
          "Paramètres > Sécurité. Vous devrez indiquer votre mot de passe "
              "actuel avant d'en choisir un nouveau.",
        ),
        _FaqItem(
          "J'ai oublié mon mot de passe, que faire ?",
          "Sur l'écran de connexion, touchez « Mot de passe oublié ou "
              "première connexion ? ». Un code vous sera envoyé par SMS.",
        ),
      ],
    ),
    _FaqSection(
      titre: 'Historique',
      items: [
        _FaqItem(
          "À quoi sert l'onglet Historique d'un groupe ?",
          "C'est le journal de toutes les opérations importantes : "
              "cotisations, dépenses, changements de rôle, clôtures de tour... "
              "Ce que vous y voyez dépend de votre rôle dans le groupe.",
        ),
        _FaqItem(
          "Qu'est-ce qu'un exercice comptable ?",
          "Une période financière pour un groupe. Le trésorier ou "
              "l'administrateur peut consulter le résumé, l'exporter en PDF, "
              "et clôturer l'exercice pour en ouvrir un nouveau.",
        ),
      ],
    ),
  ];

  Future<void> _appelerSupport() async {
    final uri = Uri(scheme: 'tel', path: _kContactTelephone);
    await launchUrl(uri);
  }

  Future<void> _ouvrirLien(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> _ecrireSupport() async {
    final uri = Uri(scheme: 'mailto', path: _kContactEmail);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(
        backgroundColor: AppColors.paper,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.forestDark),
        title: const Text(
          'Aide',
          style: TextStyle(fontSize: 18, fontFamily: 'serif', color: AppColors.forestDark),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        children: [
          for (final section in _sections) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                section.titre,
                style: const TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
              ),
            ),
            ...section.items.map((item) => _FaqTile(item: item)),
          ],
          const SizedBox(height: 24),

          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Informations légales',
              style: TextStyle(fontSize: 15, fontFamily: 'serif', color: AppColors.forestDark),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Politique de confidentialité', style: TextStyle(fontSize: 13.5)),
            trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.muted),
            onTap: () => _ouvrirLien(_kUrlConfidentialite),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Conditions d'utilisation", style: TextStyle(fontSize: 13.5)),
            trailing: const Icon(Icons.open_in_new, size: 18, color: AppColors.muted),
            onTap: () => _ouvrirLien(_kUrlConditions),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.paperCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.muted.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Vous ne trouvez pas de réponse ?",
                  style: TextStyle(fontSize: 14, fontFamily: 'serif', color: AppColors.forestDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Contactez l'équipe CaisseCom directement.",
                  style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _appelerSupport,
                        icon: const Icon(Icons.call_outlined, size: 16),
                        label: const Text('Appeler', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _ecrireSupport,
                        icon: const Icon(Icons.mail_outline, size: 16),
                        label: const Text('Écrire', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _FaqSection {
  final String titre;
  final List<_FaqItem> items;
  const _FaqSection({required this.titre, required this.items});
}

class _FaqItem {
  final String question;
  final String reponse;
  const _FaqItem(this.question, this.reponse);
}

class _FaqTile extends StatelessWidget {
  final _FaqItem item;
  const _FaqTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 10),
        title: Text(
          item.question,
          style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.reponse,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}