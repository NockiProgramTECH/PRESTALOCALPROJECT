import os
import django
import random
from datetime import timedelta

from django.utils import timezone

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'Core.settings')
django.setup()

from main.models import Ville, CategoriePrestation, Prestation, Prestataire, Evaluation, Realisation
from Abonnement.models import PlanAbonnement, Abonnement

def populate():
    print("Début du peuplement de la base de données...")

    # 1. Création des Villes
    ouaga, _ = Ville.objects.get_or_create(nom="Ouagadougou")
    bobo, _ = Ville.objects.get_or_create(nom="Bobo-Dioulasso")
    print(f"Villes créées/récupérées: {ouaga}, {bobo}")

    # 2. Création des Catégories de Prestation
    categories_data = {
        "Plomberie": "Dépannage, installation de tuyauterie et réparations sanitaires.",
        "Électricité": "Installations électriques, dépannages et mise en conformité.",
        "Coiffure & Beauté": "Coiffure africaine, tresses, soins capillaires et esthétiques.",
        "Développement": "Création de sites internet, applications web et mobiles.",
        "Réparation": "Réparation d'appareils électroménagers et électroniques.",
        "Maçonnerie": "Bâtiment, rénovation, travaux de gros œuvre et carrelage.",
        "Nettoyage": "Entretien ménager, nettoyage de bureaux et chantiers.",
        "Plus": "Découvrez d'autres services locaux adaptés à vos besoins."
    }

    cat_objs = {}
    for name, desc in categories_data.items():
        cat_obj, created = CategoriePrestation.objects.get_or_create(
            nom=name,
            defaults={"descriptionText": desc}
        )
        cat_objs[name] = cat_obj
        if created:
            print(f"Catégorie créée: {name}")

    # 3. Création des Métiers/Prestations
    prestations_data = [
        ("Plombier Professionnel", "plombier-professionnel", "Plomberie"),
        ("Électricien", "electricien", "Électricité"),
        ("Coiffeuse", "coiffeuse", "Coiffure & Beauté"),
        ("Développeur Web", "developpeur-web", "Développement"),
        ("Réparateur", "reparateur", "Réparation"),
        ("Maçon", "macon", "Maçonnerie"),
        ("Spécialiste Nettoyage", "specialiste-nettoyage", "Nettoyage"),
        ("Chauffagiste", "chauffagiste", "Réparation"),
    ]

    pres_objs = {}
    for name, slug, cat_name in prestations_data:
        pres_obj, created = Prestation.objects.get_or_create(
            nom=name,
            defaults={
                "slug": slug,
                "categorie": cat_objs[cat_name],
                "description": f"Prestations qualifiées de type {name.lower()}."
            }
        )
        pres_objs[name] = pres_obj
        if created:
            print(f"Prestation créée: {name}")

    # 4. Création des Prestataires
    prestataires_mock = [
        {
            "email": "mamadou@lesprodufao.bf",
            "first_name": "Mamadou",
            "last_name": "Konaté",
            "telephone": "+22670112233",
            "metier": "Plombier Professionnel",
            "bio": "Plombier expérimenté avec plus de 8 ans d'expérience. Intervention rapide et travail de qualité garanti.",
            "ville": ouaga,
            "quartier": "Patte d'Oie",
            "experience": 8,
            "verifie": True,
            "reviews_count": 128,
            "rating": 4.7
        },
        {
            "email": "awa@lesprodufao.bf",
            "first_name": "Awa",
            "last_name": "Traoré",
            "telephone": "+22676445566",
            "metier": "Coiffeuse",
            "bio": "Coiffeuse passionnée spécialisée dans les tresses africaines, chignons et tissages. Service de qualité en salon ou à domicile.",
            "ville": ouaga,
            "quartier": "Somgandé",
            "experience": 5,
            "verifie": True,
            "reviews_count": 96,
            "rating": 4.8
        },
        {
            "email": "issa@lesprodufao.bf",
            "first_name": "Issa",
            "last_name": "Ouédraogo",
            "telephone": "+22665889900",
            "metier": "Développeur Web",
            "bio": "Développeur web full-stack spécialisé dans la conception de sites vitrines, e-commerce et applications web sur mesure avec Django et React.",
            "ville": ouaga,
            "quartier": "Dassasgho",
            "experience": 4,
            "verifie": True,
            "reviews_count": 74,
            "rating": 4.9
        },
        {
            "email": "boureima@lesprodufao.bf",
            "first_name": "Boureima",
            "last_name": "S.",
            "telephone": "+22670123456",
            "metier": "Réparateur",
            "bio": "Spécialiste de la réparation et du dépannage d'appareils électroménagers (réfrigérateurs, climatiseurs, machines à laver) et appareils de plomberie.",
            "ville": ouaga,
            "quartier": "Pissy",
            "experience": 6,
            "verifie": True,
            "reviews_count": 88,
            "rating": 4.6
        },
        {
            "email": "adama@lesprodufao.bf",
            "first_name": "Adama",
            "last_name": "Zongo",
            "telephone": "+22671987654",
            "metier": "Électricien",
            "bio": "Électricien de bâtiment certifié. Réalisation d'installations neuves, rénovations, dépannage d'urgence et schémas électriques.",
            "ville": ouaga,
            "quartier": "Tampouy",
            "experience": 7,
            "verifie": False,
            "reviews_count": 53,
            "rating": 4.7
        },
        {
            "email": "fatoumata@lesprodufao.bf",
            "first_name": "Fatoumata",
            "last_name": "K.",
            "telephone": "+22678234567",
            "metier": "Spécialiste Nettoyage",
            "bio": "Prestation professionnelle de nettoyage pour particuliers et entreprises. Entretien de maisons, bureaux et fin de chantiers.",
            "ville": ouaga,
            "quartier": "Ouaga 2000",
            "experience": 3,
            "verifie": False,
            "reviews_count": 53,
            "rating": 4.7
        },
        {
            "email": "seydou@lesprodufao.bf",
            "first_name": "Seydou",
            "last_name": "Diallo",
            "telephone": "+22672345678",
            "metier": "Chauffagiste",
            "bio": "Chauffagiste professionnel spécialisé dans l'installation et la maintenance de climatisations, chauffe-eaux solaires et tuyauteries chaudes.",
            "ville": ouaga,
            "quartier": "Koulouba",
            "experience": 5,
            "verifie": False,
            "reviews_count": 67,
            "rating": 4.5
        },
        {
            "email": "moussa@lesprodufao.bf",
            "first_name": "Moussa",
            "last_name": "Barro",
            "telephone": "+22675987654",
            "metier": "Maçon",
            "bio": "Maçon professionnel avec 10 ans d'expérience. Gros œuvre, surélévations, pose de carrelage, briquetage et crépissage de haute qualité.",
            "ville": ouaga,
            "quartier": "Larlé",
            "experience": 10,
            "verifie": False,
            "reviews_count": 112,
            "rating": 4.8
        }
    ]

    # Utilisateur générique pour laisser des avis
    client_user, _ = Prestataire.objects.get_or_create(
        email="client@lesprodufao.bf",
        defaults={
            "first_name": "Abdoulaye",
            "last_name": "K.",
            "username": "client@lesprodufao.bf",
            "is_active": True
        }
    )
    client_user.set_password("password123")
    client_user.save()

    for p_info in prestataires_mock:
        p_obj, created = Prestataire.objects.get_or_create(
            email=p_info["email"],
            defaults={
                "username": p_info["email"],
                "first_name": p_info["first_name"],
                "last_name": p_info["last_name"],
                "telephone": p_info["telephone"],
                "metier": pres_objs[p_info["metier"]],
                "bio": p_info["bio"],
                "ville": p_info["ville"],
                "quartier": p_info["quartier"],
                "annee_experience": p_info["experience"],
                "est_verifie": p_info["verifie"],
                "is_active": True
            }
        )
        if created:
            p_obj.set_password("password123")
            p_obj.save()
            print(f"Prestataire créé: {p_obj.first_name} {p_obj.last_name}")

        # Pour correspondre aux avis, on ajoute des évaluations mockées
        # Django calcule average_rating et review_count dynamiquement
        p_obj.evaluations.all().delete() # On nettoie d'abord les avis pour ce script

        # Avis fixe comme dans la maquette
        if p_info["first_name"] == "Mamadou":
            Evaluation.objects.create(
                prestataire=p_obj,
                client=client_user,
                client_nom="K.",
                client_prenom="Abdoulaye",
                client_email="abdoulaye@gmail.com",
                note=5,
                commentaire="Service rapide et efficace. Très professionnel, je recommande !"
            )
            # Génération d'avis fictifs supplémentaires pour arriver au bon nombre/note
            create_mock_reviews(p_obj, p_info["reviews_count"] - 1, p_info["rating"])
        else:
            # Génération d'avis fictifs
            create_mock_reviews(p_obj, p_info["reviews_count"], p_info["rating"])

        print(f"-> {p_obj.first_name} possède maintenant {p_obj.review_count} avis (note moyenne: {p_obj.average_rating:.1f})")

    # 5. Plans d'abonnement + abonnements actifs
    # Sans abonnement payé/actif, les profils n'apparaissent pas dans les
    # vues filtrées sur l'abonnement et l'API `?abonnes_only=1` renvoie une
    # liste vide : on crée donc des données de test cohérentes.
    plans = [
        ("Basique", 5000, 30, "Visibilité standard pendant 30 jours."),
        ("Premium", 15000, 90, "Mise en avant, badge Premium et statistiques."),
    ]
    plan_objs = {}
    for nom, prix, duree, description in plans:
        plan_obj, created = PlanAbonnement.objects.get_or_create(
            nom=nom,
            defaults={"prix": prix, "duree_jours": duree, "description": description},
        )
        plan_objs[nom] = plan_obj
        if created:
            print(f"Plan créé: {nom}")

    for index, p_info in enumerate(prestataires_mock):
        prestataire = Prestataire.objects.filter(email=p_info["email"]).first()
        if prestataire is None:
            continue
        plan = plan_objs["Premium"] if index < 3 else plan_objs["Basique"]
        abonnement, created = Abonnement.objects.get_or_create(
            prestataire=prestataire,
            defaults={
                "plan": plan,
                "date_fin": timezone.now() + timedelta(days=plan.duree_jours),
                "est_actif": True,
                "paye": True,
                "transaction_id": f"SEED-{index + 1:04d}",
            },
        )
        if created:
            print(f"Abonnement {plan.nom} activé pour {prestataire.first_name}")

    print("Peuplement terminé avec succès !")

def create_mock_reviews(prestataire, count, target_rating):
    """
    Crée des évaluations fictives pour arriver à la note moyenne ciblée.
    """
    first_names = ["Daouda", "Mariam", "Ousmane", "Fatou", "Amadou", "Salif", "Alizèta", "Adama", "Pascal", "Fatim"]
    last_names = ["Ouédraogo", "Sangaré", "Kabré", "Sawadogo", "Ilboudo", "Traoré", "Zoungrana", "Compaoré", "Barro"]
    comments = [
        "Excellent travail, très poli et professionnel.",
        "Prestation correcte, est venu à l'heure convenue.",
        "Bon rapport qualité prix, je recommande vivement.",
        "Très compétent dans son domaine. Rien à redire.",
        "Travail soigné et rapide. Très satisfait de l'intervention.",
        "Professionnel de confiance, très réactif.",
        "Disponible rapidement et bon travail.",
        "Intervention impeccable, merci pour le service.",
        "Sympathique et efficace, résout le problème rapidement.",
        "Rien à redire, travail parfait."
    ]

    total_sum = int(target_rating * (count + 1))
    notes = []
    
    # Remplir grossièrement les notes
    for i in range(count):
        # notes aléatoires autour de la cible
        n = int(target_rating)
        if random.random() > 0.5 and n < 5:
            n += 1
        elif random.random() > 0.5 and n > 1:
            n -= 1
        notes.append(n)

    # Ajustement pour coller au score moyen
    current_sum = sum(notes)
    diff = total_sum - current_sum - 5 # Le premier avis est déjà créé ou simulé
    
    # Corriger petit à petit
    if diff > 0:
        for i in range(min(diff, count)):
            if notes[i] < 5:
                notes[i] += 1
    elif diff < 0:
        for i in range(min(abs(diff), count)):
            if notes[i] > 1:
                notes[i] -= 1

    # Insertion
    for note in notes:
        fn = random.choice(first_names)
        ln = random.choice(last_names)
        comment = random.choice(comments)
        # Note entre 1 et 5
        note = max(1, min(5, note))
        
        Evaluation.objects.create(
            prestataire=prestataire,
            client=None, # Client anonyme / non connecté
            client_nom=ln,
            client_prenom=fn,
            client_email=f"{fn.lower()}.{ln.lower()}@test.bf",
            note=note,
            commentaire=comment
        )

if __name__ == "__main__":
    populate()
