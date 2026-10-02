import uuid
from django.db import models
from django.conf import settings
from django.contrib.auth.models import AbstractUser, BaseUserManager
from django.core.validators import MinValueValidator, MaxValueValidator
from django.utils.translation import gettext_lazy as _

class CustomUserManager(BaseUserManager):
    """
    Manager personnalisé pour le modèle Prestataire où l'email est l'identifiant unique
    pour l'authentification au lieu du nom d'utilisateur.
    """
    def create_user(self, email, password=None, **extra_fields):
        if not email:
            raise ValueError(_('L\'adresse email doit être fournie'))
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)

        if extra_fields.get('is_staff') is not True:
            raise ValueError(_('Le superutilisateur doit avoir is_staff=True.'))
        if extra_fields.get('is_superuser') is not True:
            raise ValueError(_('Le superutilisateur doit avoir is_superuser=True.'))

        return self.create_user(email, password, **extra_fields)

class Ville(models.Model):
    """
    Représente une ville de résidence ou d'intervention.
    """
    nom = models.CharField(max_length=100, verbose_name=_("Nom de la ville"))

    class Meta:
        verbose_name = _("Ville")
        verbose_name_plural = _("Villes")

    def __str__(self):
        return self.nom

class CategoriePrestation(models.Model):
    """
    Regroupe les prestations par catégories (ex: Bâtiment, Informatique).
    """
    nom = models.CharField(max_length=100, verbose_name=_("Nom de la catégorie"))
    iconeImage = models.ImageField(upload_to='categories/icones/', null=True, blank=True, verbose_name=_("Icône de la catégorie"))
    descriptionText = models.TextField(null=True, blank=True, verbose_name=_("Description de la catégorie"))

    class Meta:
        verbose_name = _("Catégorie de Prestation")
        verbose_name_plural = _("Catégories de Prestation")

    def __str__(self):
        return self.nom

class Prestation(models.Model):
    """
    Définit un métier ou un service spécifique lié à une catégorie.
    """
    nom = models.CharField(max_length=100, verbose_name=_("Nom de la prestation"))
    slug = models.SlugField(max_length=100, unique=True, verbose_name=_("Slug"))
    categorie = models.ForeignKey(CategoriePrestation, on_delete=models.CASCADE, related_name='prestations', verbose_name=_("Catégorie"))
    description = models.TextField(verbose_name=_("Description"))
    image_couverture = models.ImageField(upload_to='prestations/couvertures/', null=True, blank=True, verbose_name=_("Image de couverture"))
    icone = models.ImageField(upload_to='prestations/icones/', null=True, blank=True, verbose_name=_("Icône"))
    est_actif = models.BooleanField(default=True, verbose_name=_("Est actif"))

    class Meta:
        verbose_name = _("Prestation")
        verbose_name_plural = _("Prestations")

    def __str__(self):
        return self.nom

class Prestataire(AbstractUser):
    """
    Modèle utilisateur personnalisé pour les prestataires de services.
    L'authentification se fait via l'email.
    """
    ROLE_PRESTATAIRE = 'prestataire'
    ROLE_CLIENT = 'client'
    ROLE_CHOICES = [
        (ROLE_PRESTATAIRE, _('Prestataire')),
        (ROLE_CLIENT, _('Client'))
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    username = models.CharField(max_length=150, unique=True, null=True, blank=True)
    email = models.EmailField(_('adresse email'), unique=True)
    telephone = models.CharField(max_length=20, null=True, blank=True, verbose_name=_("Téléphone"))
    photo_profil = models.ImageField(upload_to='prestataires/profils/', null=True, blank=True, verbose_name=_("Photo de profil"))
    metier = models.ForeignKey(Prestation, on_delete=models.SET_NULL, null=True, blank=True, related_name='prestataires', verbose_name=_("Métier"))
    bio = models.TextField(null=True, blank=True, verbose_name=_("Biographie"))
    role = models.CharField(
        max_length=20,
        choices=ROLE_CHOICES,
        default=ROLE_PRESTATAIRE,
        verbose_name=_("Rôle")
    )
    is_available = models.BooleanField(default=True, verbose_name=_("Disponible"))
    profile_views = models.PositiveIntegerField(default=0, verbose_name=_("Vues du profil"))
    call_clicks = models.PositiveIntegerField(default=0, verbose_name=_("Clics appel"))
    contact_clicks = models.PositiveIntegerField(default=0, verbose_name=_("Clics contact"))
    ville = models.ForeignKey(Ville, on_delete=models.SET_NULL, null=True, blank=True, verbose_name=_("Ville"))
    quartier = models.CharField(max_length=50, null=True, blank=True, verbose_name=_("Quartier/Zone d'intervention"))
    annee_experience = models.PositiveIntegerField(default=0, verbose_name=_("Années d'expérience"))
    est_verifie = models.BooleanField(default=False, verbose_name=_("Statut vérifié"))
    code_verification = models.CharField(max_length=6, null=True, blank=True, verbose_name=_("Code de vérification"))
    date_inscription = models.DateTimeField(auto_now_add=True, verbose_name=_("Date d'inscription"))

    objects = CustomUserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = []

    class Meta:
        verbose_name = _("Prestataire")
        verbose_name_plural = _("Prestataires")

    def save(self, *args, **kwargs):
        # Si le username n'est pas défini, on utilise l'email
        if not self.username and self.email:
            self.username = self.email
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.first_name} {self.last_name} ({self.email})"

    @property
    def is_prestataire(self):
        return self.role == 'prestataire'

    @property
    def is_client(self):
        return self.role == 'client'

    @property
    def has_active_subscription(self):
        """
        Vérifie si le prestataire a un abonnement valide.
        Les clients n'ont pas besoin d'abonnement.
        """
        if self.role == 'client':
            return True
        try:
            return self.abonnement.est_valide
        except Exception:
            return False

    @property
    def profile_completed(self):
        """Indique si le profil est suffisamment renseigné.

        - Prestataire : métier + ville + quartier (la bio et la photo restent
          optionnelles, mais sans ces trois champs il n'apparaît pas dans les
          recherches).
        - Client : prénom et nom.
        """
        if self.is_client:
            return bool((self.first_name or '').strip() and (self.last_name or '').strip())
        return bool(
            self.metier_id
            and self.ville_id
            and (self.quartier or '').strip()
        )

    @property
    def average_rating(self):
        evaluations = self.evaluations.all()
        if not evaluations:
            return 0
        return sum(e.note for e in evaluations) / len(evaluations)

    @property
    def review_count(self):
        return self.evaluations.count()

    @property
    def rating_breakdown(self):
        counts = {i: 0 for i in range(1, 6)}
        evals = self.evaluations.all()
        total = evals.count()
        for e in evals:
            counts[e.note] += 1
        
        breakdown = []
        for i in range(5, 0, -1):
            percentage = (counts[i] / total * 100) if total > 0 else 0
            breakdown.append({
                'note': i,
                'count': counts[i],
                'percentage': percentage
            })
        return breakdown

class Realisation(models.Model):
    """Publication du fil d'actualité / portfolio d'un membre.

    Une publication peut contenir :
    - du **texte seul** (`contenu`), un titre facultatif (`titre`) ;
    - une ou plusieurs **images** (`image` = image principale, les suivantes
      dans `RealisationImage`) ;
    - une **vidéo** (`video`) ;
    - un **lien externe** (`lien`) ;
    - une **catégorie** de prestation (`categorie`).

    Les champs image/vidéo sont facultatifs depuis l'ouverture du fil aux
    publications textuelles.
    """
    prestataire = models.ForeignKey(Prestataire, on_delete=models.CASCADE, related_name='realisations', verbose_name=_("Prestataire"))
    image = models.ImageField(upload_to='prestataires/realisations/', null=True, blank=True, verbose_name=_("Image principale"))
    video = models.FileField(upload_to='prestataires/videos/', null=True, blank=True, verbose_name=_("Vidéo"))
    contenu = models.TextField(blank=True, default='', verbose_name=_("Texte de la publication"))
    titre = models.CharField(max_length=200, null=True, blank=True, verbose_name=_("Titre de la réalisation"))
    lien = models.URLField(max_length=500, blank=True, default='', verbose_name=_("Lien externe"))
    categorie = models.ForeignKey('CategoriePrestation', on_delete=models.SET_NULL, null=True, blank=True, related_name='realisations', verbose_name=_("Catégorie"))
    date_ajout = models.DateTimeField(auto_now_add=True)
    modifie_le = models.DateTimeField(auto_now=True, verbose_name=_("Modifiée le"))

    class Meta:
        verbose_name = _("Réalisation")
        verbose_name_plural = _("Réalisations")
        ordering = ['-date_ajout']

    def __str__(self):
        return f"Réalisation de {self.prestataire} - {self.titre or self.id}"


class RealisationImage(models.Model):
    """Image supplémentaire d'une publication (au-delà de l'image principale)."""
    realisation = models.ForeignKey(Realisation, on_delete=models.CASCADE, related_name='images', verbose_name=_("Réalisation"))
    image = models.ImageField(upload_to='prestataires/realisations/', verbose_name=_("Image"))
    ordre = models.PositiveIntegerField(default=0, verbose_name=_("Ordre"))

    class Meta:
        verbose_name = _("Image de réalisation")
        verbose_name_plural = _("Images de réalisation")
        ordering = ['ordre', 'id']

    def __str__(self):
        return f"Image {self.ordre} de la réalisation {self.realisation_id}"

class Evaluation(models.Model):
    """
    Évaluations laissées par les clients pour les prestataires.
    """
    prestataire = models.ForeignKey(Prestataire, on_delete=models.CASCADE, related_name='evaluations', verbose_name=_("Prestataire"))
    client = models.ForeignKey(Prestataire, on_delete=models.CASCADE, related_name='avis_donnes', verbose_name=_("Client"), null=True)
    client_nom = models.CharField(max_length=100, verbose_name=_("Nom du client"), blank=True)
    client_prenom = models.CharField(max_length=100, verbose_name=_("Prénom du client"), blank=True)
    client_email = models.EmailField(verbose_name=_("Email du client"), blank=True)
    note = models.IntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        verbose_name=_("Note (1-5)")
    )
    commentaire = models.TextField(verbose_name=_("Commentaire"))
    date_evaluation = models.DateTimeField(auto_now_add=True, verbose_name=_("Date de l'évaluation"))

    class Meta:
        verbose_name = _("Évaluation")
        verbose_name_plural = _("Évaluations")
        unique_together = ('prestataire', 'client')

    def __str__(self):
        return f"Évaluation de {self.client.first_name if self.client else 'Inconnu'} pour {self.prestataire}"


class Favorite(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='favorites')
    prestataire = models.ForeignKey('Prestataire', on_delete=models.CASCADE, related_name='favorited_by')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        verbose_name = "Favori"
        verbose_name_plural = "Favoris"
        unique_together = ('user', 'prestataire')

    def __str__(self):
        return f"{self.user.first_name} ♥ {self.prestataire.first_name}"


class Notification(models.Model):
    TYPE_CHOICES = [
        ('evaluation', 'Nouvel avis'),
        ('favori', 'Nouveau favori'),
        ('message', 'Nouveau message'),
        ('system', 'Information'),
    ]
    recipient = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    actor = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name='actions')
    notification_type = models.CharField(max_length=20, choices=TYPE_CHOICES)
    message = models.TextField()
    link = models.CharField(max_length=500, blank=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        verbose_name = "Notification"
        verbose_name_plural = "Notifications"

    def __str__(self):
        return f"[{'Lu' if self.is_read else 'Non lu'}] {self.message[:50]}"
