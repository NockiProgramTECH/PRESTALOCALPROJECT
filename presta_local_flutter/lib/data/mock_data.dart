// ignore_for_file: prefer_const_literals_to_create_immutables

import '../models/category_model.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';
import '../models/provider_model.dart';
import '../models/realisation_model.dart';
import '../models/review_model.dart';

/// ---------------------------------------------------------------------------
/// Données mock pour le développement et les tests de PrestA Local
///
/// Ces données simulent le comportement de l'API tant que le backend
/// n'est pas disponible. Toutes les méthodes sont statiques et peuvent
/// être remplacées une par une par des appels API réels.
/// ---------------------------------------------------------------------------
class MockData {
  MockData._();

  /// Utilisateur connecté (simulé)
  static const Map<String, String> currentUser = {
    'id': 'user_001',
    'name': 'Alexandre Zongo',
    'email': 'alexandre.zongo@email.bf',
    'phone': '+226 70 12 34 56',
    'avatar': 'https://i.pravatar.cc/150?img=68',
  };

  // ---------------------------------------------------------------------------
  // CATÉGORIES
  // ---------------------------------------------------------------------------

  /// Liste complète des catégories de services disponibles
  static const List<CategoryModel> categories = [
    CategoryModel(
      id: 'cat_01',
      name: 'Plomberie',
      icon: 'plumbing',
      description: 'Installation et réparation de canalisations, robinetterie, chauffe-eau',
      providerCount: 12,
    ),
    CategoryModel(
      id: 'cat_02',
      name: 'Électricité',
      icon: 'electrical_services',
      description: 'Installation électrique, dépannage, tableau électrique',
      providerCount: 8,
    ),
    CategoryModel(
      id: 'cat_03',
      name: 'Coiffure & Beauté',
      icon: 'content_cut',
      description: 'Coiffure homme, femme, tresses, soins esthétiques',
      providerCount: 15,
    ),
    CategoryModel(
      id: 'cat_04',
      name: 'Développement',
      icon: 'code',
      description: 'Création de sites web, applications, logiciels sur mesure',
      providerCount: 6,
    ),
    CategoryModel(
      id: 'cat_05',
      name: 'Réparation',
      icon: 'handyman',
      description: "Réparation d'appareils électroménagers, smartphones, ordinateurs",
      providerCount: 10,
    ),
    CategoryModel(
      id: 'cat_06',
      name: 'Maçonnerie',
      icon: 'construction',
      description: 'Construction, rénovation, carrelage, peinture',
      providerCount: 7,
    ),
    CategoryModel(
      id: 'cat_07',
      name: 'Nettoyage',
      icon: 'cleaning_services',
      description: 'Nettoyage domestique, bureau, nettoyage industriel',
      providerCount: 9,
    ),
    CategoryModel(
      id: 'cat_08',
      name: 'Transport',
      icon: 'local_shipping',
      description: 'Transport de personnes et de marchandises, déménagement',
      providerCount: 11,
    ),
  ];

  // ---------------------------------------------------------------------------
  // PRESTATAIRES
  // ---------------------------------------------------------------------------

  /// Retourne la liste complète des prestataires
  static List<ProviderModel> get providers => _allProviders;

  /// Retourne les prestataires en vedette (pour la page d'accueil)
  static List<ProviderModel> get featuredProviders =>
      _allProviders.where((p) => p.isFeatured).toList();

  /// Recherche de prestataires par texte et/ou zone
  static List<ProviderModel> searchProviders({
    String? query,
    String? categoryId,
    String? zone,
  }) {
    var results = _allProviders;

    if (query != null && query.isNotEmpty) {
      final q = query.toLowerCase();
      results = results.where((p) {
        return p.name.toLowerCase().contains(q) ||
            p.title.toLowerCase().contains(q) ||
            p.services.any((s) => s.toLowerCase().contains(q));
      }).toList();
    }

    if (categoryId != null && categoryId != 'all') {
      results = results.where((p) => p.category.id == categoryId).toList();
    }

    if (zone != null && zone.isNotEmpty && zone != 'Toutes les zones') {
      results = results.where((p) {
        return p.locationZone.toLowerCase().contains(zone.toLowerCase());
      }).toList();
    }

    return results;
  }

  /// Retourne un prestataire par son ID
  static ProviderModel? getProviderById(String id) {
    try {
      return _allProviders.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // CONVERSATIONS & MESSAGES
  // ---------------------------------------------------------------------------

  /// Conversations pré-initialisées pour la démo
  static List<ConversationModel> get conversations => _allConversations;

  /// Ajoute un message à une conversation et retourne la conversation mise à jour
  static ConversationModel addMessageToConversation(
    String conversationId,
    MessageModel message,
  ) {
    final index = _allConversations.indexWhere((c) => c.id == conversationId);
    if (index == -1) {
      throw Exception('Conversation non trouvée : $conversationId');
    }

    final conversation = _allConversations[index];
    final updatedMessages = [...conversation.messages, message];

    final updatedConversation = ConversationModel(
      id: conversation.id,
      provider: conversation.provider,
      messages: updatedMessages,
      unreadCount: 0,
      isOnline: conversation.isOnline,
    );

    _allConversations[index] = updatedConversation;
    return updatedConversation;
  }

  /// Simule une réponse automatique du prestataire
  static Future<MessageModel> simulateAutoReply(String conversationId) async {
    // Délai simulé de 1.5 secondes
    await Future.delayed(const Duration(milliseconds: 1500));

    final conversation = _allConversations.firstWhere(
      (c) => c.id == conversationId,
    );

    // Réponses contextuelles selon le prestataire
    final autoReplies = {
      'prov_01': [
        'Merci pour votre message ! Je suis disponible cette semaine. Quand souhaitez-vous que je passe ?',
        'Très bien, je prends note. Je vous confirme le rendez-vous dans la journée.',
        "Je peux intervenir dès demain matin. Est-ce que cela vous convient ?",
        "N'hésitez pas à me donner plus de détails sur le travail à faire.",
        "Je vous enverrai un devis détaillé sous 24h.",
      ],
      'prov_02': [
        'Bonjour ! Je serais ravie de vous coiffer. Quand voulez-vous venir au salon ?',
        'Oui, j\'ai des disponibilités cette semaine. Quel jour vous arrange ?',
        "Merci ! Je prépare votre venue. À très bientôt au salon !",
        "Je vous attends ! Le salon est ouvert de 8h à 19h du lundi au samedi.",
      ],
      'prov_03': [
        'Bonjour ! Je suis disponible pour votre projet. Parlez-moi un peu plus de vos besoins.',
        'Super, je peux vous accompagner sur ce projet. On peut faire un appel pour discuter des détails.',
        "Je travaille à distance et je suis très réactif. N'hésitez pas à me solliciter !",
        "J'ai déjà réalisé plusieurs projets similaires. Je vous envoie quelques exemples.",
      ],
      'prov_04': [
        "Bonjour, je peux vous aider avec cette réparation. C'est pour quel appareil ?",
        "Je passe en fin de semaine si vous voulez. Je vous confirme le jour.",
        "J'ai les pièces nécessaires en stock. Je peux intervenir rapidement.",
        "Merci de votre confiance ! Je serai là à l'heure convenue.",
      ],
    };

    final replies = autoReplies[conversation.provider.id] ?? [
      "Merci pour votre message. Je vous réponds dans les plus brefs délais.",
      "Parfait, je prends note de votre demande.",
    ];

    final replyText = replies[conversation.messages.length % replies.length];

    return MessageModel(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: replyText,
      sender: MessageSender.provider,
      timestamp: DateTime.now(),
      isRead: false,
    );
  }

  // ---------------------------------------------------------------------------
  // DONNÉES PRIVÉES (non exportées directement)
  // ---------------------------------------------------------------------------

  static final List<ProviderModel> _allProviders = [
    // ---- Prestataire 1 : Mamadou Konate (Plombier) ----
    ProviderModel(
      id: 'prov_01',
      name: 'Mamadou Konaté',
      title: 'Plombier professionnel',
      category: categories[0], // Plomberie
      rating: 4.7,
      reviewCount: 128,
      location: 'Ouagadougou',
      locationZone: 'Zone 1',
      avatar: 'https://i.pravatar.cc/150?img=12',
      banner: 'https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800',
      about:
          'Plombier agréé avec plus de 10 ans d\'expérience. Je réalise tous types de travaux de plomberie : installation, dépannage, rénovation. Intervention rapide dans tout Ouagadougou. Devis gratuit et tarifs compétitifs. Satisfaction client garantie à 100% !',
      priceText: 'À partir de 5 000 CFA',
      priceValue: 5000,
      services: [
        'Dépannage urgence plomberie',
        'Installation robinetterie',
        'Réparation fuite d\'eau',
        'Pose de chauffe-eau',
        'Débouchage canalisations',
        'Rénovation salle de bain',
      ],
      realisations: [
        RealisationModel(
          id: 'real_01_01',
          imageUrl: 'https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=400',
          title: 'Rénovation complète SDB',
        ),
        RealisationModel(
          id: 'real_01_02',
          imageUrl: 'https://images.unsplash.com/photo-1545259741-2c3e3d4f8a9b?w=400',
          title: 'Installation chauffe-eau',
        ),
        RealisationModel(
          id: 'real_01_03',
          imageUrl: 'https://images.unsplash.com/photo-1585129819171-80b02d4c845b?w=400',
          title: 'Système irrigation jardin',
        ),
        RealisationModel(
          id: 'real_01_04',
          imageUrl: 'https://images.unsplash.com/photo-1600566753190-17f0baa2a6c3?w=400',
          title: 'Débouchage canalisation',
        ),
      ],
      reviews: [
        ReviewModel(
          id: 'rev_01_01',
          authorName: 'Fatoumata Ouédraogo',
          authorAvatar: 'https://i.pravatar.cc/150?img=25',
          rating: 5,
          date: DateTime(2026, 6, 15),
          comment:
              'Excellent travail ! Mamadou a réparé ma fuite d\'eau en un rien de temps. Professionnel et très sympathique. Je recommande vivement !',
        ),
        ReviewModel(
          id: 'rev_01_02',
          authorName: 'Paul Kaboré',
          authorAvatar: 'https://i.pravatar.cc/150?img=33',
          rating: 4,
          date: DateTime(2026, 5, 28),
          comment:
              'Travail correct, prix raisonnables. Le seul bémol est un petit retard le jour du rendez-vous.',
        ),
        ReviewModel(
          id: 'rev_01_03',
          authorName: 'Aminata Diallo',
          authorAvatar: 'https://i.pravatar.cc/150?img=44',
          rating: 5,
          date: DateTime(2026, 5, 10),
          comment:
              'Je recommande ! Il a installé ma nouvelle salle de bain et le résultat est magnifique.',
        ),
        ReviewModel(
          id: 'rev_01_04',
          authorName: 'Siaka Traoré',
          authorAvatar: 'https://i.pravatar.cc/150?img=55',
          rating: 5,
          date: DateTime(2026, 4, 22),
          comment:
              'Très professionnel, intervention rapide et propre. Je ferai appel à lui sans hésiter.',
        ),
      ],
      phone: '+226 70 12 34 56',
      whatsapp: '+226 70 12 34 56',
      email: 'mamadou.konate@email.bf',
      isVerified: true,
      isFeatured: true,
      isOnline: true,
      lastActive: DateTime.now().subtract(const Duration(minutes: 5)),
    ),

    // ---- Prestataire 2 : Awa Traoré (Coiffeuse/Visagiste) ----
    ProviderModel(
      id: 'prov_02',
      name: 'Awa Traoré',
      title: 'Coiffeuse & Visagiste',
      category: categories[2], // Coiffure & Beauté
      rating: 4.8,
      reviewCount: 96,
      location: 'Ouagadougou',
      locationZone: 'Ouaga 2000',
      avatar: 'https://i.pravatar.cc/150?img=47',
      banner: 'https://images.unsplash.com/photo-1560066984-138dadb4c035?w=800',
      about:
          'Coiffeuse professionnelle avec 8 ans d\'expérience. Spécialiste en tresses, coiffures africaines modernes, et soins capillaires. Diplômée en esthétique et visagisme. Mon salon vous accueille dans un cadre chic et relaxant à Ouaga 2000.',
      priceText: 'À partir de 3 000 CFA',
      priceValue: 3000,
      services: [
        'Tresses traditionnelles et modernes',
        'Coupe femme et homme',
        'Soins capillaires',
        'Pose de mèches',
        'Coiffures cérémonies (mariages, baptêmes)',
        'Conseils en image',
      ],
      realisations: [
        RealisationModel(
          id: 'real_02_01',
          imageUrl: 'https://images.unsplash.com/photo-1596728325488-58c87691e9af?w=400',
          title: 'Tresse moderne',
        ),
        RealisationModel(
          id: 'real_02_02',
          imageUrl: 'https://images.unsplash.com/photo-1582093236147-9a4c92a1f8e9?w=400',
          title: 'Coiffure mariage',
        ),
        RealisationModel(
          id: 'real_02_03',
          imageUrl: 'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400',
          title: 'Soin capillaire complet',
        ),
      ],
      reviews: [
        ReviewModel(
          id: 'rev_02_01',
          authorName: 'Mariam Sawadogo',
          authorAvatar: 'https://i.pravatar.cc/150?img=23',
          rating: 5,
          date: DateTime(2026, 7, 1),
          comment:
              'Awa est tout simplement la meilleure coiffeuse de Ouaga ! Mes tresses tiennent depuis 3 semaines, impeccable.',
        ),
        ReviewModel(
          id: 'rev_02_02',
          authorName: 'Clarisse Zoungrana',
          authorAvatar: 'https://i.pravatar.cc/150?img=45',
          rating: 5,
          date: DateTime(2026, 6, 18),
          comment:
              'Superbe prestation pour mon mariage. Awa a coiffé toute la famille, tout le monde était magnifique. Merci !',
        ),
        ReviewModel(
          id: 'rev_02_03',
          authorName: 'Rosine Tapsoba',
          authorAvatar: 'https://i.pravatar.cc/150?img=31',
          rating: 4,
          date: DateTime(2026, 5, 30),
          comment: 'Très bon travail, cadre agréable. Les prix sont un peu élevés mais la qualité est là.',
        ),
      ],
      phone: '+226 71 98 76 54',
      whatsapp: '+226 71 98 76 54',
      email: 'awa.traore@email.bf',
      isVerified: true,
      isFeatured: true,
      isOnline: true,
      lastActive: DateTime.now().subtract(const Duration(minutes: 15)),
    ),

    // ---- Prestataire 3 : Issa Ouédraogo (Développeur Fullstack) ----
    ProviderModel(
      id: 'prov_03',
      name: 'Issa Ouédraogo',
      title: 'Développeur Fullstack',
      category: categories[3], // Développement
      rating: 4.9,
      reviewCount: 74,
      location: 'Ouagadougou',
      locationZone: 'Centre',
      avatar: 'https://i.pravatar.cc/150?img=53',
      banner: 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?w=800',
      about:
          'Développeur fullstack passionné avec 6 ans d\'expérience. Je crée des sites web modernes, des applications mobiles et des solutions logicielles sur mesure pour les entreprises et particuliers. Maîtrise des technologies récentes : React, Flutter, Node.js, Python. Travail en remote ou sur site.',
      priceText: 'À partir de 50 000 CFA',
      priceValue: 50000,
      services: [
        'Création de sites web',
        'Applications mobiles',
        'Logiciels de gestion',
        'E-commerce',
        'Maintenance et support',
        'Conseil en transformation digitale',
      ],
      realisations: [
        RealisationModel(
          id: 'real_03_01',
          imageUrl: 'https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=400',
          title: 'Site e-commerce',
        ),
        RealisationModel(
          id: 'real_03_02',
          imageUrl: 'https://images.unsplash.com/photo-1551650975-87deedd944c3?w=400',
          title: 'App mobile livraison',
        ),
        RealisationModel(
          id: 'real_03_03',
          imageUrl: 'https://images.unsplash.com/photo-1504639725590-34d0984388bd?w=400',
          title: 'Dashboard analytics',
        ),
        RealisationModel(
          id: 'real_03_04',
          imageUrl: 'https://images.unsplash.com/photo-1555066931-4365d14bab8c?w=400',
          title: 'Application gestion stock',
        ),
        RealisationModel(
          id: 'real_03_05',
          imageUrl: 'https://images.unsplash.com/photo-1517433670267-08bbd4be890f?w=400',
          title: 'Site vitrine restaurant',
        ),
      ],
      reviews: [
        ReviewModel(
          id: 'rev_03_01',
          authorName: 'Thomas Ilboudo',
          authorAvatar: 'https://i.pravatar.cc/150?img=60',
          rating: 5,
          date: DateTime(2026, 7, 5),
          comment:
              'Issa a réalisé le site e-commerce de ma boutique. Travail de grande qualité, livré dans les délais. Je suis très satisfait !',
        ),
        ReviewModel(
          id: 'rev_03_02',
          authorName: 'Nadia Yaméogo',
          authorAvatar: 'https://i.pravatar.cc/150?img=26',
          rating: 5,
          date: DateTime(2026, 6, 20),
          comment:
              'Application mobile superbe ! Issa a su comprendre mes besoins et proposer des solutions innovantes. Je recommande à 100%',
        ),
        ReviewModel(
          id: 'rev_03_03',
          authorName: 'Adama Compaoré',
          authorAvatar: 'https://i.pravatar.cc/150?img=37',
          rating: 5,
          date: DateTime(2026, 5, 15),
          comment:
              'Professionnel, compétent et réactif. Un développeur rare sur le marché burkinabè.',
        ),
        ReviewModel(
          id: 'rev_03_04',
          authorName: 'Sarah Bélem',
          authorAvatar: 'https://i.pravatar.cc/150?img=42',
          rating: 4,
          date: DateTime(2026, 4, 28),
          comment: 'Très bon travail sur notre logiciel de gestion. Support après-vente appréciable.',
        ),
      ],
      phone: '+226 72 34 56 78',
      whatsapp: '+226 72 34 56 78',
      email: 'issa.ouedraogo@email.bf',
      isVerified: true,
      isFeatured: true,
      isOnline: false,
      lastActive: DateTime.now().subtract(const Duration(hours: 2)),
    ),

    // ---- Prestataire 4 : Boureima S. (Réparateur / Électricien) ----
    ProviderModel(
      id: 'prov_04',
      name: 'Boureima S.',
      title: 'Réparateur & Électricien',
      category: categories[1], // Électricité
      rating: 4.6,
      reviewCount: 88,
      location: 'Ouagadougou',
      locationZone: 'Secteur 15',
      avatar: 'https://i.pravatar.cc/150?img=22',
      banner: 'https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=800',
      about:
          'Artisan polyvalent spécialisé en réparation d\'appareils électroménagers et électricité générale. Plus de 12 ans d\'expérience dans le dépannage à domicile. Je répare toutes marques : thermiques, froid, climatisation. Intervention rapide dans tout Ouagadougou.',
      priceText: 'À partir de 4 000 CFA',
      priceValue: 4000,
      services: [
        'Réparation électroménager',
        'Installation électrique',
        'Dépannage climatisation',
        'Réparation smartphone/tablette',
        'Installation antenne TV',
        'Câblage réseau',
      ],
      realisations: [
        RealisationModel(
          id: 'real_04_01',
          imageUrl: 'https://images.unsplash.com/photo-1578176601913-8f5706c5b31a?w=400',
          title: 'Réparation climatisation',
        ),
        RealisationModel(
          id: 'real_04_02',
          imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400',
          title: 'Tableau électrique neuf',
        ),
        RealisationModel(
          id: 'real_04_03',
          imageUrl: 'https://images.unsplash.com/photo-1557318041-1ce374d55ebf?w=400',
          title: 'Installation cuisine',
        ),
      ],
      reviews: [
        ReviewModel(
          id: 'rev_04_01',
          authorName: 'Jean-Baptiste K.',
          authorAvatar: 'https://i.pravatar.cc/150?img=51',
          rating: 5,
          date: DateTime(2026, 7, 2),
          comment:
              'Intervention rapide pour mon frigo en panne. Boureima a diagnostiqué le problème en 5 minutes et réparé sur place. Merci !',
        ),
        ReviewModel(
          id: 'rev_04_02',
          authorName: 'Habibou Nikiéma',
          authorAvatar: 'https://i.pravatar.cc/150?img=66',
          rating: 4,
          date: DateTime(2026, 6, 12),
          comment:
              'A refait toute l\'installation électrique de ma maison. Travail soigné et aux normes. Je recommande.',
        ),
        ReviewModel(
          id: 'rev_04_03',
          authorName: 'Moussa Zongo',
          authorAvatar: 'https://i.pravatar.cc/150?img=34',
          rating: 4,
          date: DateTime(2026, 5, 8),
          comment:
              'Bon travail sur ma climatisation, prix correct. Seul petit bémol : un peu de retard.',
        ),
        ReviewModel(
          id: 'rev_04_04',
          authorName: 'Rokia Sanon',
          authorAvatar: 'https://i.pravatar.cc/150?img=48',
          rating: 5,
          date: DateTime(2026, 4, 15),
          comment:
              'Je l\'appelle à chaque panne. Toujours disponible et compétent. Un vrai professionnel !',
        ),
      ],
      phone: '+226 73 45 67 89',
      whatsapp: '+226 73 45 67 89',
      isVerified: true,
      isFeatured: true,
      isOnline: true,
      lastActive: DateTime.now().subtract(const Duration(minutes: 45)),
    ),

    // ---- Prestataire 5 : Fatimata Diallo (Nettoyage) ----
    ProviderModel(
      id: 'prov_05',
      name: 'Fatimata Diallo',
      title: 'Agente de nettoyage professionnelle',
      category: categories[6], // Nettoyage
      rating: 4.7,
      reviewCount: 52,
      location: 'Ouagadougou',
      locationZone: 'Zone 2',
      avatar: 'https://i.pravatar.cc/150?img=40',
      banner: 'https://images.unsplash.com/photo-1565630919981-5a2c4a3b07d2?w=800',
      about:
          'Agente de nettoyage avec 5 ans d\'expérience. Je propose des services de nettoyage complets pour particuliers et entreprises. Utilisation de produits écologiques et matériel professionnel. Discrétion et efficacité garanties.',
      priceText: 'À partir de 2 500 CFA',
      priceValue: 2500,
      services: [
        'Nettoyage domestique',
        'Nettoyage de bureau',
        'Nettoyage après travaux',
        'Lavage de vitres',
        'Désinfection',
        'Nettoyage canapé/moquette',
      ],
      realisations: [],
      reviews: [
        ReviewModel(
          id: 'rev_05_01',
          authorName: 'Alassane Ouédraogo',
          authorAvatar: 'https://i.pravatar.cc/150?img=32',
          rating: 5,
          date: DateTime(2026, 6, 25),
          comment: 'Maison impeccable après son passage. Très minutieuse et ponctuelle.',
        ),
        ReviewModel(
          id: 'rev_05_02',
          authorName: 'Bénédicte Yaméogo',
          authorAvatar: 'https://i.pravatar.cc/150?img=29',
          rating: 4,
          date: DateTime(2026, 5, 20),
          comment: 'Bon service de nettoyage pour mon bureau. Personnel professionnel.',
        ),
      ],
      phone: '+226 74 56 78 90',
      whatsapp: '+226 74 56 78 90',
      isVerified: true,
      isFeatured: false,
      isOnline: false,
      lastActive: DateTime.now().subtract(const Duration(hours: 5)),
    ),

    // ---- Prestataire 6 : Dramane Coulibaly (Maçon) ----
    ProviderModel(
      id: 'prov_06',
      name: 'Dramane Coulibaly',
      title: 'Maître maçon',
      category: categories[5], // Maçonnerie
      rating: 4.5,
      reviewCount: 63,
      location: 'Ouagadougou',
      locationZone: 'Pissy',
      avatar: 'https://i.pravatar.cc/150?img=62',
      banner: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800',
      about:
          'Maçon expérimenté avec plus de 15 ans dans le métier. Je réalise tous types de constructions : fondations, murs, carrelage, enduits. Mon équipe et moi travaillons avec rigueur et dans les délais impartis.',
      priceText: 'À partir de 10 000 CFA',
      priceValue: 10000,
      services: [
        'Construction de murs',
        'Carrelage intérieur/extérieur',
        'Enduits et crépis',
        'Fondations',
        'Rénovation maison',
        'Terrasse et dallage',
      ],
      realisations: [
        RealisationModel(
          id: 'real_06_01',
          imageUrl: 'https://images.unsplash.com/photo-1487958449943-2429e8be8625?w=400',
          title: 'Villa moderne',
        ),
        RealisationModel(
          id: 'real_06_02',
          imageUrl: 'https://images.unsplash.com/photo-1581092160562-40aa08e78837?w=400',
          title: 'Rénovation façade',
        ),
      ],
      reviews: [
        ReviewModel(
          id: 'rev_06_01',
          authorName: 'Seydou Kaboré',
          authorAvatar: 'https://i.pravatar.cc/150?img=41',
          rating: 5,
          date: DateTime(2026, 6, 5),
          comment: 'Excellent maçon ! Ma villa est magnifique grâce à lui. Travail soigné et finitions parfaites.',
        ),
        ReviewModel(
          id: 'rev_06_02',
          authorName: 'Martine Zoromé',
          authorAvatar: 'https://i.pravatar.cc/150?img=36',
          rating: 4,
          date: DateTime(2026, 4, 30),
          comment: 'Bon travail dans l\'ensemble. Respecte les délais. Je recommande.',
        ),
      ],
      phone: '+226 75 67 89 01',
      isVerified: false,
      isFeatured: false,
      isOnline: false,
      lastActive: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  /// Conversations pré-initialisées
  static final List<ConversationModel> _allConversations = [
    ConversationModel(
      id: 'conv_01',
      provider: _allProviders[0], // Mamadou
      messages: [
        MessageModel(
          id: 'msg_01_01',
          text: 'Bonjour Mamadou, êtes-vous disponible pour une réparation de fuite d\'eau cette semaine ?',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 15, 9, 30),
        ),
        MessageModel(
          id: 'msg_01_02',
          text: 'Bonjour ! Oui, je suis disponible. Je peux passer jeudi ou vendredi. Quel jour vous arrange ?',
          sender: MessageSender.provider,
          timestamp: DateTime(2026, 7, 15, 9, 35),
        ),
        MessageModel(
          id: 'msg_01_03',
          text: 'Vendredi après-midi serait parfait. Vers 15h ?',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 15, 10, 0),
        ),
        MessageModel(
          id: 'msg_01_04',
          text: 'C\'est noté ! Je serai chez vous vendredi à 15h. N\'oubliez pas de fermer l\'arrivée d\'eau en attendant. À bientôt !',
          sender: MessageSender.provider,
          timestamp: DateTime(2026, 7, 15, 10, 5),
        ),
      ],
      unreadCount: 0,
      isOnline: true,
    ),
    ConversationModel(
      id: 'conv_02',
      provider: _allProviders[1], // Awa
      messages: [
        MessageModel(
          id: 'msg_02_01',
          text: 'Salut Awa, est-ce que je peux prendre rendez-vous pour des tresses ce week-end ?',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 14, 14, 0),
        ),
        MessageModel(
          id: 'msg_02_02',
          text: 'Salut ! Oui bien sûr. Samedi ou dimanche ? J\'ai des créneaux à 10h et 14h.',
          sender: MessageSender.provider,
          timestamp: DateTime(2026, 7, 14, 14, 15),
        ),
        MessageModel(
          id: 'msg_02_03',
          text: 'Samedi à 10h, parfait ! Je viendrai au salon. Merci !',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 14, 14, 30),
        ),
      ],
      unreadCount: 0,
      isOnline: true,
    ),
    ConversationModel(
      id: 'conv_03',
      provider: _allProviders[2], // Issa
      messages: [
        MessageModel(
          id: 'msg_03_01',
          text: 'Bonjour Issa, j\'ai un projet de site web pour mon restaurant. Est-ce que vous prenez ce genre de projets ?',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 13, 11, 0),
        ),
        MessageModel(
          id: 'msg_03_02',
          text: 'Bonjour ! Oui, j\'ai déjà réalisé plusieurs sites pour des restaurants. Je peux vous faire un site vitrine avec menu en ligne et réservation. On peut discuter de vos besoins ?',
          sender: MessageSender.provider,
          timestamp: DateTime(2026, 7, 13, 11, 20),
        ),
        MessageModel(
          id: 'msg_03_03',
          text: 'Super ! On peut s\'appeler cette semaine ?',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 13, 11, 45),
        ),
      ],
      unreadCount: 1,
      isOnline: false,
    ),
    ConversationModel(
      id: 'conv_04',
      provider: _allProviders[3], // Boureima
      messages: [
        MessageModel(
          id: 'msg_04_01',
          text: 'Bonjour Boureima, ma climatisation ne fonctionne plus. Pouvez-vous passer ?',
          sender: MessageSender.user,
          timestamp: DateTime(2026, 7, 12, 16, 0),
        ),
        MessageModel(
          id: 'msg_04_02',
          text: 'Bonsoir, oui je peux passer demain dans la matinée. Vers 10h ?',
          sender: MessageSender.provider,
          timestamp: DateTime(2026, 7, 12, 16, 30),
        ),
      ],
      unreadCount: 0,
      isOnline: true,
    ),
  ];
}
