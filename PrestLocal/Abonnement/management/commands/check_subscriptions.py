from django.core.management.base import BaseCommand
from django.utils import timezone
from django.core.mail import EmailMultiAlternatives
from django.template.loader import render_to_string
from Abonnement.models import Abonnement
from django.conf import settings

class Command(BaseCommand):
    help = 'Vérifie les abonnements arrivant à expiration dans 7 jours et envoie des emails.'

    def handle(self, *args, **options):
        # On cherche les abonnements qui expirent exactement dans 7 jours
        cible = timezone.now() + timezone.timedelta(days=7)
        debut_jour = cible.replace(hour=0, minute=0, second=0, microsecond=0)
        fin_jour = cible.replace(hour=23, minute=59, second=59, microsecond=999999)
        
        abonnements = Abonnement.objects.filter(
            date_fin__range=(debut_jour, fin_jour),
            est_actif=True
        )
        
        count = 0
        for abo in abonnements:
            try:
                subject = "Votre abonnement expire bientôt - PrestLocal"
                html_content = render_to_string('emails/subscription_expiry.html', {
                    'user': abo.prestataire,
                    'expiry_date': abo.date_fin,
                    'domain': 'prestlocal.com' # Idéalement utiliser un réglage
                })
                text_content = f"Bonjour {abo.prestataire.first_name}, votre abonnement expire dans 7 jours."
                
                msg = EmailMultiAlternatives(
                    subject, 
                    text_content, 
                    settings.EMAIL_HOST_USER, 
                    [abo.prestataire.email]
                )
                msg.attach_alternative(html_content, "text/html")
                msg.send()
                count += 1
            except Exception as e:
                self.stdout.write(self.style.ERROR(f"Erreur pour {abo.prestataire.email}: {e}"))
        
        self.stdout.write(self.style.SUCCESS(f"Traitement terminé. {count} emails envoyés."))
