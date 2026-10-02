# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

LesProduFao is a Django platform that connects local service providers (**prestataires**) with **clients** looking for services in their city. It features a SASS-style profile dashboard, PWA support, a light/dark theme, subscriptions that gate provider visibility, a social feed, a messaging system, and a DRF API.

Django 5.2 · DRF · django-filter · Pillow · Gunicorn · WhiteNoise. Python runs from `venv/` (Windows environment, Git Bash shell).

## Common commands

```bash
source venv/Scripts/activate        # activate the virtual env (Windows / Git Bash)

python manage.py runserver          # run dev server
python manage.py check              # system check (fast sanity check)
python manage.py makemigrations     # create migrations after model changes
python manage.py migrate            # apply migrations
python manage.py collectstatic      # sync static/ -> staticfiles/ (committed; run after editing static/)
python manage.py createsuperuser    # admin superuser (login by email)
python populate_db.py               # seed dev data (Villes, Prestations, Prestataires, etc.)
```

There is **no automated test suite** in this repo. For ad-hoc verification of views/templates/forms, use Django's test `Client` from the shell, e.g.:

```bash
python manage.py shell -c "
from django.test import Client
from main.models import Prestataire
u = Prestataire.objects.filter(role='prestataire').first()
c = Client(); c.force_login(u)
r = c.get('/profile/'); print(r.status_code, r.content.decode()[:200])
"
```

`populate_db.py` must be re-run to get fresh prestataire/realisation data after destructive schema changes.

## Architecture

Custom user model: `Prestataire(AbstractUser)` in `main/models.py`. **Authentication is by email** (`USERNAME_FIELD = 'email'`), primary key is a UUID, and the user's kind is the `role` field (`'prestataire'` / `'client'`).

**Critical gotcha:** `Prestataire.is_prestataire` / `.is_client` and `.has_active_subscription` are **Python properties, not model fields** — you cannot use them in `.filter()`. Filter on the `role` field instead. Django also ships its own `is_active`, `is_staff`, etc.; the custom `is_available` field (Boolean) controls provider search visibility.

Django apps (mounted in `Core/urls.py`):

- `main` (`app_name='main'`) — the core app: `Prestataire`, `Ville`, `CategoriePrestation`, `Prestation`, `Realisation` (portfolio), `Evaluation`, `Notification`, favorites. Home, prestataire list/detail, profile dashboard, auth (email + verification code), password reset. Routes mount at `/` (mostly no prefix, e.g. `/profile/`, `/prestataires/`).
- `Abonnement` (`app_name='Abonnement'`) — `PlanAbonnement` + `Abonnement`. Subscription plans; an active subscription controls whether a prestataire is visible in searches (see `has_active_subscription`).
- `Feed` — `Like`, `Commentaire`; social feed (`/feed/`).
- `Messagerie` — `Conversation`, `Message`; messaging (`/messages/`).
- `api` — DRF serializers/viewsets exposed under `/api/`.

Other notable parts:

- `templates/` — Django templates, all extending `templates/base.html`. `base.html` exposes `{% block extrastyle %}` (page-scoped CSS in a `<style>` tag) and `{% block extrajs %}`. Many pages keep their page-specific CSS inline in `extrastyle` rather than in the global stylesheet.
- `static/css/main.css` — the design system: CSS custom properties in `:root` (colors, shadows, radii, font `Plus Jakarta Sans`). It mirrors the Flutter app's « Warm Kinetic Modern » tokens: citrus `--primary-green: #FF8A3D`, pressed `--primary-pressed: #E07228`, brown accent for text on soft orange `--primary-strong: #9A4600`, navy `--text-dark: #1E293B`, emerald `--success: #10B981` (statuses), sand canvas `--bg-light: #FBF9F7`, warm borders `--card-border: #EAE3DB`. Historical variable names (`--primary-green`, `--primary-red`, `--bg-soft-green`, `--green-text`…) are kept as aliases so existing rules keep working — always style with `var(--...)` tokens so the palette stays consistent with the app. Font Awesome 6 is loaded globally for icons.
- `static/js/` — vanilla JS per page (e.g. `profile.js`, `messagerie.js`), plain DOM, no framework. AJAX posts send `X-Requested-With: XMLHttpRequest` and read CSRF via a `getCookie('csrftoken')` helper.
- `media/` — user-uploaded files (served at `/media/` only when `DEBUG=True`). `static/` is the source dir; `staticfiles/` is the collectstatic output and is committed, so **after editing anything in `static/`, run `collectstatic`** so the deployed copy stays in sync.
- PWA: web app manifest, service worker served from `/sw.js` (see `Core/views.py`), offline page.

## Design conventions

- Providers without a photo use an **initials avatar** fallback (gradient green circle with `{{ prestataire.first_name|slice:":1" }}{{ prestataire.last_name|slice:":1" }}`), NOT a `default-profile.png` file (that file does not exist).
- Interactive elements on mobile need a **min 44px touch target** (this is enforced in the responsive CSS).
- Views that mutate data are typically `@require_POST` and return JSON; toggle/click endpoints update counters with `F()` expressions.
