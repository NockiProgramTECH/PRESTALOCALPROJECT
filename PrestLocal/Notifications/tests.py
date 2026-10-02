"""Tests de la couche de notifications et des relances d'abonnement.

Ces tests vérifient :

- le service d'envoi (journalisation, idempotence, canaux injectables) ;
- les règles métier de relance (abonnement bientôt expiré, expiré, jamais
  souscrit ; les clients ne sont jamais relancés) ;
- le lien signé vers l'espace d'abonnement et la vue qui le reçoit ;
- le worker planifié (`executer_relances_abonnement`) et sa commande.
"""

from datetime import timedelta

from django.core import mail
from django.test import TestCase, override_settings
from django.urls import reverse
from django.utils import timezone

from Abonnement.models import Abonnement, PlanAbonnement
from main.models import Prestataire
from Notifications.abonnement import (
    TYPE_EXPIRE,
    TYPE_EXPIRATION_PROCHE,
    TYPE_JAMAIS_SOUSCRIT,
    cibles_relance,
    prestataire_depuis_reference,
    reference_relance,
    url_abonnement,
)
from Notifications.channels.base import (
    STATUT_ENVOYE,
    CanalNotification,
    MessageNotification,
    ResultatEnvoi,
)
from Notifications.models import JournalNotification
from Notifications.service import ServiceNotification, envoyer_email
from Notifications.tasks import executer_relances_abonnement

EMAIL_LOCMEM = 'django.core.mail.backends.locmem.EmailBackend'


class CanalEnregistreur(CanalNotification):
    """Canal de test : capture les messages au lieu de les transporter."""

    nom = "test"

    def __init__(self, disponible=True):
        self._disponible = disponible
        self.messages = []

    def disponible(self):
        return self._disponible

    def envoyer(self, message, destinataire):
        self.messages.append((destinataire, message))
        return ResultatEnvoi(self.nom, STATUT_ENVOYE)


def creer_prestataire(email="artisan@lesprodufao.bf", **extra):
    return Prestataire.objects.create_user(
        email=email,
        password="MotDePasse123",
        first_name="Awa",
        last_name="Ouédraogo",
        role=Prestataire.ROLE_PRESTATAIRE,
        **extra,
    )


class ServiceNotificationTests(TestCase):
    """Le service d'envoi : journalisation, idempotence, canaux injectés."""

    def setUp(self):
        self.prestataire = creer_prestataire()
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )

    def test_envoi_email_journalise_le_resultat(self):
        with override_settings(EMAIL_BACKEND=EMAIL_LOCMEM):
            rapport = envoyer_email(
                self.prestataire,
                sujet="Bonjour",
                texte="Contenu",
                type_notification="test_email",
            )
        self.assertTrue(rapport.envoye)
        self.assertEqual(len(mail.outbox), 1)
        self.assertEqual(mail.outbox[0].to, [self.prestataire.email])

        journal = JournalNotification.objects.get()
        self.assertEqual(journal.canal, "email")
        self.assertEqual(journal.statut, "envoye")
        self.assertEqual(journal.type_notification, "test_email")

    def test_cle_unique_evite_les_doublons(self):
        with override_settings(EMAIL_BACKEND=EMAIL_LOCMEM):
            premier = envoyer_email(
                self.prestataire,
                sujet="Relance",
                texte="Contenu",
                type_notification="relance",
                cle_unique="relance:1",
            )
            second = envoyer_email(
                self.prestataire,
                sujet="Relance",
                texte="Contenu",
                type_notification="relance",
                cle_unique="relance:1",
            )
        self.assertTrue(premier.envoye)
        self.assertFalse(second.envoye)
        self.assertEqual(len(mail.outbox), 1, "un seul email doit partir")
        self.assertEqual(
            JournalNotification.objects.filter(statut="envoye").count(), 1
        )

    def test_canal_injecte_sans_smtp_ni_reseau(self):
        canal = CanalEnregistreur()
        message = MessageNotification(
            type="test", sujet="Sujet", texte="Texte", url_action="https://x.bf"
        )
        rapport = ServiceNotification(canaux=[canal]).envoyer(
            self.prestataire, message
        )
        self.assertTrue(rapport.envoye)
        self.assertEqual(len(canal.messages), 1)
        destinataire, envoye = canal.messages[0]
        self.assertEqual(destinataire, self.prestataire)
        self.assertEqual(envoye.url_action, "https://x.bf")

    def test_canal_indisponible_est_journalise_sans_erreur(self):
        canal = CanalEnregistreur(disponible=False)
        rapport = ServiceNotification(canaux=[canal]).envoyer(
            self.prestataire,
            MessageNotification(type="test", sujet="S", texte="T"),
        )
        self.assertFalse(rapport.envoye)
        self.assertFalse(canal.messages)
        journal = JournalNotification.objects.get()
        self.assertEqual(journal.statut, "ignore")

    def test_destinataire_sans_email_est_ignore(self):
        sans_email = Prestataire.objects.create_user(
            email="sans-adresse@lesprodufao.bf",
            password="MotDePasse123",
            role=Prestataire.ROLE_CLIENT,
        )
        sans_email.email = ""
        rapport = ServiceNotification().envoyer(
            sans_email, MessageNotification(type="test", sujet="S", texte="T")
        )
        self.assertFalse(rapport.envoye)
        self.assertEqual(rapport.resultats[0].statut, "ignore")


class RelanceAbonnementTests(TestCase):
    """Règles métier de relance : qui relancer, avec quel motif."""

    def setUp(self):
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )

    def _abonnement(self, prestataire, jours_restants):
        return Abonnement.objects.create(
            prestataire=prestataire,
            plan=self.plan,
            date_fin=timezone.now() + timedelta(days=jours_restants),
            est_actif=True,
            paye=True,
        )

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_abonnement_bientot_expire_envoye_avec_lien(self):
        prestataire = creer_prestataire()
        self._abonnement(prestataire, jours_restants=5)

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.cibles, 1)
        self.assertEqual(rapport.envoyes, 1)
        self.assertEqual(len(mail.outbox), 1)

        contenu = mail.outbox[0].alternatives[0][0]
        lien = url_abonnement(prestataire)
        self.assertIn(f"/abonnement/gestion/{prestataire.pk}/", lien)
        self.assertIn(lien, contenu)
        self.assertIn("restez en avant", contenu.lower())

        journal = JournalNotification.objects.get()
        self.assertEqual(journal.type_notification, TYPE_EXPIRATION_PROCHE)

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_abonnement_expire_est_relance(self):
        prestataire = creer_prestataire(email="expire@lesprodufao.bf")
        self._abonnement(prestataire, jours_restants=-3)

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.envoyes, 1)
        self.assertEqual(
            JournalNotification.objects.get().type_notification, TYPE_EXPIRE
        )
        self.assertIn("/abonnement/gestion/", mail.outbox[0].alternatives[0][0])

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_prestataire_jamais_abonne_est_relance(self):
        prestataire = creer_prestataire(email="nouveau@lesprodufao.bf")
        # Inscrit il y a 10 jours, sans aucun abonnement.
        Prestataire.objects.filter(pk=prestataire.pk).update(
            date_inscription=timezone.now() - timedelta(days=10)
        )

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.cibles, 1)
        self.assertEqual(
            JournalNotification.objects.get().type_notification,
            TYPE_JAMAIS_SOUSCRIT,
        )

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_prestataire_recent_et_client_non_relances(self):
        recent = creer_prestataire(email="recent@lesprodufao.bf")
        Prestataire.objects.filter(pk=recent.pk).update(
            date_inscription=timezone.now() - timedelta(days=1)
        )
        client = Prestataire.objects.create_user(
            email="client@lesprodufao.bf",
            password="MotDePasse123",
            role=Prestataire.ROLE_CLIENT,
        )
        Prestataire.objects.filter(pk=client.pk).update(
            date_inscription=timezone.now() - timedelta(days=30)
        )

        rapport = executer_relances_abonnement()
        self.assertEqual(rapport.cibles, 0)
        self.assertEqual(len(mail.outbox), 0)

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_relance_idempotente_sur_deux_executions(self):
        prestataire = creer_prestataire(email="double@lesprodufao.bf")
        self._abonnement(prestataire, jours_restants=4)

        premier = executer_relances_abonnement()
        second = executer_relances_abonnement()

        self.assertEqual(premier.envoyes, 1)
        self.assertEqual(second.envoyes, 0)
        self.assertEqual(second.ignores, 1)
        self.assertEqual(len(mail.outbox), 1, "pas de second email")

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_mode_simulation_n_envoie_rien(self):
        prestataire = creer_prestataire(email="simu@lesprodufao.bf")
        self._abonnement(prestataire, jours_restants=2)

        rapport = executer_relances_abonnement(simulation=True)
        self.assertEqual(rapport.cibles, 1)
        self.assertEqual(rapport.envoyes, 0)
        self.assertEqual(len(mail.outbox), 0)
        self.assertFalse(JournalNotification.objects.exists())

    def test_cibles_couvrent_les_trois_motifs(self):
        proche = creer_prestataire(email="proche@lesprodufao.bf")
        self._abonnement(proche, jours_restants=6)
        expire = creer_prestataire(email="fini@lesprodufao.bf")
        self._abonnement(expire, jours_restants=-1)
        jamais = creer_prestataire(email="jamais@lesprodufao.bf")
        Prestataire.objects.filter(pk=jamais.pk).update(
            date_inscription=timezone.now() - timedelta(days=5)
        )

        motifs = {cible.motif for cible in cibles_relance()}
        self.assertEqual(
            motifs, {TYPE_EXPIRATION_PROCHE, TYPE_EXPIRE, TYPE_JAMAIS_SOUSCRIT}
        )


class LienAbonnementTests(TestCase):
    """Lien signé + vue qui le reçoit (aucun droit supplémentaire accordé)."""

    def setUp(self):
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )
        self.prestataire = creer_prestataire(email="ligue@lesprodufao.bf")
        self.autre = creer_prestataire(email="autre@lesprodufao.bf")

    def test_reference_signee_identifie_le_prestataire(self):
        reference = reference_relance(self.prestataire)
        self.assertEqual(
            prestataire_depuis_reference(reference).pk, self.prestataire.pk
        )
        self.assertIsNone(prestataire_depuis_reference("faux-jeton"))
        self.assertIsNone(prestataire_depuis_reference(""))

    def test_vue_gestion_redirige_le_bon_compte(self):
        self.client.force_login(self.prestataire)
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url)
        self.assertRedirects(response, reverse("Abonnement:plan_list"))

    def test_vue_gestion_refuse_un_autre_compte(self):
        self.client.force_login(self.autre)
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url)
        self.assertRedirects(response, reverse("main:index"))
        # Aucune information sur l'autre compte n'a fuité.
        messages_rendus = [str(m) for m in response.wsgi_request._messages]
        self.assertTrue(
            any("ne correspond pas à votre compte" in m for m in messages_rendus)
        )

    def test_vue_gestion_exige_une_connexion(self):
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url)
        self.assertEqual(response.status_code, 302)
        self.assertIn("/login/", response["Location"])

    def test_plan_list_affiche_le_bandeau_pour_le_bon_compte(self):
        self.client.force_login(self.prestataire)
        reference = reference_relance(self.prestataire)
        url = reverse("Abonnement:plan_list")
        response = self.client.get(url, {"ref": reference})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.context["relance_abonnement"])
        self.assertContains(response, "Votre abonnement conditionne votre visibilité")

    def test_plan_list_ignore_une_reference_etrangere(self):
        self.client.force_login(self.autre)
        reference = reference_relance(self.prestataire)
        url = reverse("Abonnement:plan_list")
        response = self.client.get(url, {"ref": reference})
        self.assertEqual(response.status_code, 200)
        self.assertFalse(response.context["relance_abonnement"])
        self.assertNotContains(
            response, "Votre abonnement conditionne votre visibilité"
        )

    def test_gestion_conserve_le_jeton_jusqu_aux_offres(self):
        self.client.force_login(self.prestataire)
        reference = reference_relance(self.prestataire)
        url = reverse("Abonnement:gestion", args=[self.prestataire.pk])
        response = self.client.get(url, {"ref": reference})
        self.assertEqual(response.status_code, 302)
        self.assertIn("ref=", response["Location"])
        # En suivant la redirection, le bandeau apparaît bien.
        final = self.client.get(response["Location"])
        self.assertTrue(final.context["relance_abonnement"])


class CommandeRelanceTests(TestCase):
    """La commande planifiée relaie le worker et imprime un rapport."""

    def setUp(self):
        self.plan = PlanAbonnement.objects.create(
            nom="Basique", prix=5000, duree_jours=30
        )
        self.prestataire = creer_prestataire(email="commande@lesprodufao.bf")
        Abonnement.objects.create(
            prestataire=self.prestataire,
            plan=self.plan,
            date_fin=timezone.now() + timedelta(days=3),
            est_actif=True,
            paye=True,
        )

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_commande_relancer_abonnements(self):
        from io import StringIO

        from django.core.management import call_command

        sortie = StringIO()
        call_command("relancer_abonnements", stdout=sortie)
        self.assertIn("1 envoyée(s)", sortie.getvalue())

    @override_settings(EMAIL_BACKEND=EMAIL_LOCMEM)
    def test_ancienne_commande_deleguee(self):
        from io import StringIO

        from django.core.management import call_command

        sortie = StringIO()
        call_command("check_subscriptions", stdout=sortie)
        contenu = sortie.getvalue()
        self.assertIn("dépréciée", contenu)
        self.assertEqual(len(mail.outbox), 1)
