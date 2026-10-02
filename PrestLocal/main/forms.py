from django import forms
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm
from django.utils.translation import gettext_lazy as _
from .models import Evaluation, Prestataire, Ville, Prestation, Realisation

class RealisationForm(forms.ModelForm):
    """
    Formulaire pour ajouter une réalisation (portfolio).
    """
    class Meta:
        model = Realisation
        fields = ['titre', 'image']
        widgets = {
            'titre': forms.TextInput(attrs={'class': 'form-input', 'placeholder': 'Ex: Rénovation villa à Ouaga'}),
            'image': forms.FileInput(attrs={'class': 'form-input'}),
        }

class PrestataireSignupForm(UserCreationForm):
    """
    Formulaire d'inscription COMPLET incluant TOUS les champs du modèle Prestataire.
    Layout par lignes (col-full pour 1 par ligne, col-half pour 2 par ligne).
    """
    email = forms.EmailField(
        label=_("Adresse Email"),
        widget=forms.EmailInput(attrs={'class': 'form-input col-full', 'placeholder': 'exemple@mail.com'})
    )
    role = forms.ChoiceField(
        choices=Prestataire._meta.get_field('role').choices,
        label=_("Je suis"),
        initial='prestataire',
        widget=forms.Select(attrs={'class': 'form-input col-full'})
    )
    last_name = forms.CharField(
        label=_("Nom"),
        widget=forms.TextInput(attrs={'class': 'form-input col-half', 'placeholder': 'Ex: Konaté'})
    )
    first_name = forms.CharField(
        label=_("Prénom"),
        widget=forms.TextInput(attrs={'class': 'form-input col-half', 'placeholder': 'Ex: Mamadou'})
    )
    telephone = forms.CharField(
        label=_("Téléphone"),
        widget=forms.TextInput(attrs={'class': 'form-input col-half', 'placeholder': '+226 .. .. .. ..'})
    )
    photo_profil = forms.ImageField(
        label=_("Photo de profil"),
        required=False,
        widget=forms.FileInput(attrs={'class': 'form-input col-half'})
    )
    metier = forms.ModelChoiceField(
        queryset=Prestation.objects.filter(est_actif=True),
        label=_("Métier / Service"),
        empty_label=_("Sélectionnez votre métier"),
        widget=forms.Select(attrs={'class': 'form-input col-half'})
    )
    annee_experience = forms.IntegerField(
        label=_("Années d'expérience"),
        initial=0,
        widget=forms.NumberInput(attrs={'class': 'form-input col-half', 'min': '0'})
    )
    ville = forms.ModelChoiceField(
        queryset=Ville.objects.all(),
        label=_("Ville"),
        empty_label=_("Sélectionnez votre ville"),
        widget=forms.Select(attrs={'class': 'form-input col-half'})
    )
    quartier = forms.CharField(
        label=_("Quartier"),
        widget=forms.TextInput(attrs={'class': 'form-input col-half', 'placeholder': 'Ex: Zone du bois'})
    )
    bio = forms.CharField(
        label=_("Biographie / Compétences"),
        required=False,
        widget=forms.Textarea(attrs={'class': 'form-input col-full', 'placeholder': 'Décrivez vos compétences...', 'rows': 3})
    )

    class Meta(UserCreationForm.Meta):
        model = Prestataire
        fields = (
            "email", "role", "last_name", "first_name", "telephone", "photo_profil", 
            "metier", "annee_experience", "ville", "quartier", "bio"
        )

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        
        # Ordre strict des champs pour le layout
        field_order = [
            "email", 
            "role",
            "last_name", "first_name", 
            "telephone", "photo_profil", 
            "metier", "annee_experience", 
            "ville", "quartier", 
            "bio",
            "password1", "password2"
        ]
        
        new_fields = {}
        for field_name in field_order:
            if field_name in self.fields:
                new_fields[field_name] = self.fields.pop(field_name)
        new_fields.update(self.fields)
        self.fields = new_fields
        
        # Champs spécifiques au métier : obligatoires uniquement pour un
        # compte prestataire (un client n'a rien à faire d'un métier ni d'un
        # quartier d'intervention). La règle est réappliquée dans clean().
        for name in ('metier', 'annee_experience', 'ville', 'quartier'):
            if name in self.fields:
                self.fields[name].required = False

        # Application des classes CSS aux champs hérités (mots de passe)
        if 'password1' in self.fields:
            self.fields['password1'].widget.attrs.update({'class': 'form-input col-half', 'placeholder': 'Mot de passe'})
        if 'password2' in self.fields:
            self.fields['password2'].widget.attrs.update({'class': 'form-input col-half', 'placeholder': 'Confirmation'})

    def clean_email(self):
        email = self.cleaned_data.get('email')
        if Prestataire.objects.filter(email=email).exists():
            raise forms.ValidationError(_("Cette adresse email est déjà utilisée."))
        return email

    def clean(self):
        """Un prestataire doit renseigner son métier et sa zone d'intervention."""
        cleaned = super().clean()
        if cleaned.get('role') != Prestataire.ROLE_PRESTATAIRE:
            return cleaned

        for name in ('metier', 'ville', 'quartier'):
            if not cleaned.get(name):
                self.add_error(
                    name,
                    _("Ce champ est obligatoire pour un compte prestataire."),
                )
        if cleaned.get('annee_experience') is None:
            cleaned['annee_experience'] = 0
        return cleaned

class PrestataireLoginForm(AuthenticationForm):
    """
    Formulaire de connexion personnalisé.
    """
    username = forms.EmailField(
        label=_("Email"),
        widget=forms.EmailInput(attrs={'class': 'form-input', 'placeholder': 'exemple@mail.com'})
    )
    password = forms.CharField(
        label=_("Mot de passe"),
        widget=forms.PasswordInput(attrs={'class': 'form-input', 'placeholder': '••••••••'})
    )

class PrestataireProfileForm(forms.ModelForm):
    """
    Formulaire de mise à jour du profil pour les prestataires.
    """
    class Meta:
        model = Prestataire
        fields = ['telephone', 'bio', 'metier', 'ville', 'quartier', 'photo_profil', 'is_available']
        widgets = {
            'telephone': forms.TextInput(attrs={'class': 'form-input', 'placeholder': '+226 .. .. .. ..'}),
            'bio': forms.Textarea(attrs={'class': 'form-input', 'rows': 4, 'placeholder': 'Décrivez vos compétences...'}),
            'metier': forms.Select(attrs={'class': 'form-input'}),
            'ville': forms.Select(attrs={'class': 'form-input'}),
            'quartier': forms.TextInput(attrs={'class': 'form-input', 'placeholder': 'Ex: Zone du bois'}),
            'photo_profil': forms.FileInput(attrs={'class': 'form-input'}),
            'is_available': forms.CheckboxInput(attrs={'class': 'form-checkbox'})
        }

class VerifyEmailForm(forms.Form):
    """
    Formulaire pour entrer le code de vérification reçu par email.
    """
    code = forms.CharField(
        label=_("Code de vérification"),
        max_length=6,
        widget=forms.TextInput(attrs={'class': 'form-input', 'placeholder': '123456', 'autocomplete': 'off'})
    )

class PasswordResetRequestForm(forms.Form):
    """
    Formulaire pour demander la réinitialisation du mot de passe.
    """
    email = forms.EmailField(
        label=_("Adresse Email"),
        widget=forms.EmailInput(attrs={'class': 'form-input', 'placeholder': 'exemple@mail.com'})
    )

class PasswordResetConfirmForm(forms.Form):
    """
    Formulaire pour confirmer le code et changer le mot de passe.
    """
    code = forms.CharField(
        label=_("Code de vérification"),
        max_length=6,
        widget=forms.TextInput(attrs={'class': 'form-input', 'placeholder': '123456', 'autocomplete': 'off'})
    )
    new_password = forms.CharField(
        label=_("Nouveau mot de passe"),
        widget=forms.PasswordInput(attrs={'class': 'form-input', 'placeholder': '••••••••'})
    )
    confirm_password = forms.CharField(
        label=_("Confirmer le mot de passe"),
        widget=forms.PasswordInput(attrs={'class': 'form-input', 'placeholder': '••••••••'})
    )

    def clean(self):
        cleaned_data = super().clean()
        password = cleaned_data.get("new_password")
        confirm = cleaned_data.get("confirm_password")
        if password and confirm and password != confirm:
            raise forms.ValidationError(_("Les mots de passe ne correspondent pas."))
        return cleaned_data


