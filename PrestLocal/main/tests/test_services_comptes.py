"""Tests des services de comptes (code, activation, réinitialisation, atomicité)."""

from django.core import mail
from django.test import (
    TestCase,
    override_settings,
)

from main.models import Prestataire
from main.services import (
    CodeInvalide,
    EnvoiCodeImpossible,
    activer_compte,
    demarrer_inscription,
    demander_reinitialisation,
    reinitialiser_mot_de_passe,
)


class ServicesComptesTests(TestCase):
    """Inscription, activation et réinitialisation d'un compte."""

    def _nouveau_compte(self, email='nouveau@lesprodufao.bf'):
        return Prestataire(email=email, first_name='Issa', last_name='Sawadogo')

    # ---- Inscription -----------------------------------------------------

    def test_inscription_cree_un_compte_inactif_et_envoie_le_code(self):
        compte = self._nouveau_compte()

        demarrer_inscription(utilisateur=compte, base_url='https://exemple.bf')

        self.assertFalse(compte.is_active)
        self.assertTrue(compte.pk)
        self.assertEqual(len(compte.code_verification), 6)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn(compte.code_verification, mail.outbox[0].body)

    @override_settings(NOTIFICATIONS_CHANNELS=['push'])
    def test_inscription_annulee_si_aucun_canal_ne_delivre_le_code(self):
        """Pas de code délivré = pas de compte conservé (transaction annulée)."""
        compte = self._nouveau_compte(email='echec@lesprodufao.bf')

        with self.assertRaises(EnvoiCodeImpossible):
            demarrer_inscription(utilisateur=compte)

        self.assertFalse(
            Prestataire.objects.filter(email='echec@lesprodufao.bf').exists()
        )

    # ---- Activation ------------------------------------------------------

    def test_activation_avec_le_bon_code(self):
        compte = self._nouveau_compte()
        demarrer_inscription(utilisateur=compte)

        activer_compte(compte, compte.code_verification)

        compte.refresh_from_db()
        self.assertTrue(compte.is_active)
        self.assertIsNone(compte.code_verification)

    def test_activation_refusee_avec_un_mauvais_code(self):
        compte = self._nouveau_compte()
        demarrer_inscription(utilisateur=compte)

        with self.assertRaises(CodeInvalide):
            activer_compte(compte, '000000')

        compte.refresh_from_db()
        self.assertFalse(compte.is_active)

    # ---- Réinitialisation ------------------------------------------------

    def test_reinitialisation_inconnue_ne_revele_rien_et_nenvoie_rien(self):
        self.assertIsNone(demander_reinitialisation('inconnu@lesprodufao.bf'))
        self.assertEqual(len(mail.outbox), 0)

    def test_reinitialisation_envoie_un_code_puis_change_le_mot_de_passe(self):
        compte = Prestataire.objects.create_user(
            email='oublie@lesprodufao.bf', password='AncienMotDePasse123'
        )

        retrouve = demander_reinitialisation('OUBLIE@lesprodufao.bf')

        self.assertEqual(retrouve, compte)
        self.assertEqual(len(mail.outbox), 1)
        code = retrouve.code_verification
        self.assertEqual(len(code), 6)

        # L'instance renvoyée par le service porte le code à jour.
        reinitialiser_mot_de_passe(retrouve, code, 'NouveauMotDePasse123')

        compte.refresh_from_db()
        self.assertTrue(compte.check_password('NouveauMotDePasse123'))
        self.assertIsNone(compte.code_verification)

    def test_reinitialisation_refusee_avec_un_mauvais_code(self):
        compte = Prestataire.objects.create_user(
            email='oublie2@lesprodufao.bf', password='AncienMotDePasse123'
        )
        demander_reinitialisation('oublie2@lesprodufao.bf')

        with self.assertRaises(CodeInvalide):
            reinitialiser_mot_de_passe(compte, '999999', 'NouveauMotDePasse123')

        compte.refresh_from_db()
        self.assertTrue(compte.check_password('AncienMotDePasse123'))
