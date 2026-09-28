/**
 * PrestaLocal - main.js
 * Script global de gestion du DOM, des interactions UX/UI et des animations.
 * 
 * Auteur: Senior UX/UI Developer
 */

document.addEventListener('DOMContentLoaded', () => {
    // Registration du Service Worker PWA
    registerServiceWorker();

    // Initialisation des modules UI
    initMobileNavbar();
    initCategoryScrolling();
    initScrollAnimations();
    initInteractiveRatings();
    initMobileNavActiveState();
});

/**
 * Enregistre le Service Worker PrestaLocal et gère les mises à jour.
 */
function registerServiceWorker() {
    if ('serviceWorker' in navigator) {
        // Enregistrer le SW avec un cache-buster basé sur la date du build
        const swUrl = '/static/js/sw.js?v=' + new Date().toISOString().split('T')[0];

        navigator.serviceWorker.register(swUrl, {
            scope: '/'
        }).then((registration) => {
            console.log('[PWA] Service Worker enregistré avec scope:', registration.scope);

            // Détection de mise à jour du SW
            registration.addEventListener('updatefound', () => {
                const newWorker = registration.installing;
                console.log('[PWA] Nouveau Service Worker en cours d\'installation...');

                newWorker.addEventListener('statechange', () => {
                    if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
                        // Nouveau SW installé — proposer le rechargement
                        showUpdateBanner();
                    }
                });
            });
        }).catch((error) => {
            console.warn('[PWA] Échec de l\'enregistrement du Service Worker:', error);
        });

        // Re-vérifier le SW toutes les heures (mise à jour silencieuse)
        setInterval(() => {
            navigator.serviceWorker.register('/static/js/sw.js', { scope: '/' });
        }, 60 * 60 * 1000);
    } else {
        console.info('[PWA] Les Service Workers ne sont pas supportés par ce navigateur.');
    }
}

/**
 * Affiche une bannière de mise à jour lorsque un nouveau SW est disponible.
 */
function showUpdateBanner() {
    const banner = document.createElement('div');
    banner.className = 'pwa-update-banner';
    banner.setAttribute('role', 'alert');
    banner.innerHTML = `
        <span>Une nouvelle version de PrestaLocal est disponible.</span>
        <button id="pwaUpdateBtn" class="pwa-update-btn">
            <i class="fas fa-sync-alt"></i> Mettre à jour
        </button>
        <button id="pwaDismissBtn" class="pwa-dismiss-btn" aria-label="Fermer">
            <i class="fas fa-times"></i>
        </button>
    `;
    document.body.appendChild(banner);

    // Animation d'entrée
    requestAnimationFrame(() => banner.classList.add('visible'));

    document.getElementById('pwaUpdateBtn').addEventListener('click', () => {
        // Envoyer un message au SW pour ignorer l'attente
        navigator.serviceWorker.ready.then((reg) => {
            reg.waiting?.postMessage({ type: 'SKIP_WAITING' });
        });
        window.location.reload();
    });

    document.getElementById('pwaDismissBtn').addEventListener('click', () => {
        banner.classList.remove('visible');
        setTimeout(() => banner.remove(), 300);
    });
}

/**
 * Gère le menu burger et le tiroir de navigation mobile
 */
function initMobileNavbar() {
    const burgerBtn = document.getElementById('burgerBtn');
    const mobileNav = document.getElementById('mobileNav');
    const navOverlay = document.getElementById('navOverlay');
    
    if (!burgerBtn || !mobileNav || !navOverlay) return;

    function toggleMenu(forceClose = false) {
        const isOpen = forceClose ? false : !mobileNav.classList.contains('open');
        
        mobileNav.classList.toggle('open', isOpen);
        navOverlay.classList.toggle('active', isOpen);
        burgerBtn.classList.toggle('active', isOpen);
        
        // Mise à jour de l'accessibilité
        burgerBtn.setAttribute('aria-expanded', isOpen);
        mobileNav.setAttribute('aria-hidden', !isOpen);
        
        // Empêcher le scroll du body quand le menu est ouvert
        document.body.style.overflow = isOpen ? 'hidden' : '';
    }

    burgerBtn.addEventListener('click', (e) => {
        e.stopPropagation();
        toggleMenu();
    });

    // Fermer le tiroir si on clique sur l'overlay
    navOverlay.addEventListener('click', () => toggleMenu(true));

    // Fermer le tiroir si on clique sur un lien (utile pour les ancres)
    mobileNav.querySelectorAll('a').forEach(link => {
        link.addEventListener('click', () => toggleMenu(true));
    });
}

/**
 * Rend le défilement horizontal des catégories plus fluide sur mobile (effet "drag-to-scroll" tactile)
 */
function initCategoryScrolling() {
    const grid = document.querySelector('.categories-grid');
    if (!grid) return;

    let isDown = false;
    let startX;
    let scrollLeft;

    grid.addEventListener('mousedown', (e) => {
        isDown = true;
        grid.classList.add('active-drag');
        startX = e.pageX - grid.offsetLeft;
        scrollLeft = grid.scrollLeft;
    });

    grid.addEventListener('mouseleave', () => {
        isDown = false;
        grid.classList.remove('active-drag');
    });

    grid.addEventListener('mouseup', () => {
        isDown = false;
        grid.classList.remove('active-drag');
    });

    grid.addEventListener('mousemove', (e) => {
        if (!isDown) return;
        e.preventDefault();
        const x = e.pageX - grid.offsetLeft;
        const walk = (x - startX) * 1.5; // Vitesse de défilement
        grid.scrollLeft = scrollLeft - walk;
    });
}

/**
 * Anime les éléments lors du défilement (Scroll Animations)
 */
function initScrollAnimations() {
    const fadeElements = document.querySelectorAll('.category-card, .provider-card, .trust-item, .card-prestataire-new');
    
    if ('IntersectionObserver' in window) {
        const observerOptions = {
            threshold: 0.1,
            rootMargin: '0px 0px -50px 0px'
        };

        const observer = new IntersectionObserver((entries, observer) => {
            entries.forEach(entry => {
                if (entry.isIntersecting) {
                    entry.target.classList.add('visible');
                    // On cesse d'observer une fois l'élément affiché
                    observer.unobserve(entry.target);
                }
            });
        }, observerOptions);

        fadeElements.forEach(el => {
            el.classList.add('scroll-fade-in');
            observer.observe(el);
        });
    } else {
        // Fallback pour les anciens navigateurs
        fadeElements.forEach(el => el.style.opacity = '1');
    }
}

/**
 * Gère les interactions tactiles et animations pour les étoiles d'évaluation
 */
function initInteractiveRatings() {
    const starLabels = document.querySelectorAll('.star-rating-input label');
    if (!starLabels.length) return;

    starLabels.forEach(label => {
        // Animation au survol de la souris
        label.addEventListener('mouseenter', () => {
            label.querySelector('i').classList.add('fa-bounce');
        });
        label.addEventListener('mouseleave', () => {
            label.querySelector('i').classList.remove('fa-bounce');
        });
        
        // Amélioration de l'interaction tactile
        label.addEventListener('touchstart', () => {
            const inputId = label.getAttribute('for');
            const input = document.getElementById(inputId);
            if (input) {
                input.checked = true;
                // Déclencher l'événement change
                const event = new Event('change', { bubbles: true });
                input.dispatchEvent(event);
            }
        });
    });
}

/**
 * Met en surbrillance l'onglet actif de la barre de navigation inférieure mobile (Bottom Nav)
 */
function initMobileNavActiveState() {
    const currentPath = window.location.pathname;
    const navItems = document.querySelectorAll('.bottom-nav-item');
    if (!navItems.length) return;

    navItems.forEach(item => {
        const href = item.getAttribute('href');
        if (currentPath === href || (href !== '/' && currentPath.startsWith(href))) {
            item.classList.add('active');
        } else {
            item.classList.remove('active');
        }
    });
}

/**
 * Badge de notifications — push via WebSocket (remplace le polling 30s)
 */
function initNotificationBadge() {
    if (!document.querySelector('.notif-badge')) return;

    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
    const wsUrl = `${proto}://${window.location.host}/ws/notifications/`;
    let socket;
    try {
        socket = new WebSocket(wsUrl);
    } catch (e) {
        return;
    }

    socket.onmessage = (e) => {
        let data;
        try { data = JSON.parse(e.data); } catch (err) { return; }
        if (data.type !== 'notification.unread') return;
        const count = data.count || 0;
        document.querySelectorAll('.notif-badge').forEach(b => {
            b.textContent = count;
            b.style.display = count > 0 ? 'flex' : 'none';
        });
    };
    // Reconnexion simple si la connexion se ferme
    socket.onclose = () => setTimeout(initNotificationBadge, 5000);
    socket.onerror = () => socket.close();
}

/**
 * Initialise les boutons favoris (AJAX toggle)
 */
function initFavoriteButtons() {
    document.addEventListener('click', function(e) {
        const btn = e.target.closest('.favorite-btn');
        if (!btn) return;
        e.preventDefault();

        const url = btn.dataset.url;
        const icon = btn.querySelector('i');

        fetch(url, {
            method: 'POST',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-CSRFToken': (function() {
                    const value = '; ' + document.cookie;
                    const parts = value.split('; csrftoken=');
                    if (parts.length === 2) return parts.pop().split(';').shift();
                    return '';
                })()
            }
        })
        .then(r => r.json())
        .then(data => {
            if (data.status === 'favori') {
                icon.className = 'fas fa-heart';
                icon.style.color = 'var(--danger-red)';
                btn.classList.add('liked');
            } else {
                icon.className = 'far fa-heart';
                icon.style.color = '';
                btn.classList.remove('liked');
            }
        })
        .catch(() => {});
    });
}

// Initialiser au chargement
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        initNotificationBadge();
        initFavoriteButtons();
    });
} else {
    initNotificationBadge();
    initFavoriteButtons();
}
