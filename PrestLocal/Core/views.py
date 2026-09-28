import os

from django.conf import settings
from django.http import HttpResponse, JsonResponse
from django.views.decorators.cache import never_cache


def service_worker(request):
    """Sert le Service Worker avec les headers PWA nécessaires."""
    sw_path = os.path.join(settings.BASE_DIR, 'static', 'js', 'sw.js')
    with open(sw_path, 'r', encoding='utf-8') as f:
        content = f.read()
    response = HttpResponse(content, content_type='application/javascript')
    response['Service-Worker-Allowed'] = '/'
    response['Cache-Control'] = 'no-cache'
    return response


@never_cache
def healthcheck(request):
    """Sonde de disponibilité (Docker healthcheck, Render, monitoring…).

    Vérifie la connexion à la base de données : renvoie 200 si tout va bien,
    503 sinon. Aucune donnée sensible n'est exposée.
    """
    from django.db import connections
    from django.db.utils import OperationalError

    try:
        with connections['default'].cursor() as cursor:
            cursor.execute('SELECT 1')
            cursor.fetchone()
    except OperationalError:
        return JsonResponse(
            {'status': 'unavailable', 'database': 'down'}, status=503
        )
    return JsonResponse({'status': 'ok', 'database': 'up'})
