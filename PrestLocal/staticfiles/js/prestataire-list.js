/**
 * Gestion AJAX de la liste des prestataires avec Skeleton Screens
 */
document.addEventListener('DOMContentLoaded', function() {
    const filtersForm = document.getElementById('filtersForm');
    const searchForm = document.querySelector('.search-main-container');
    const container = document.getElementById('prestataires-container');
    const skeletonTemplate = document.getElementById('skeleton-template');
    const resultsCounter = document.querySelector('.results-counter');

    if (!container || !skeletonTemplate) return;

    /**
     * Charge les données via AJAX
     */
    async function fetchPrestataires(url) {
        // Afficher les skeletons
        container.innerHTML = skeletonTemplate.innerHTML;
        
        // Scroll vers le haut de la liste
        window.scrollTo({
            top: document.querySelector('.filter-bar-section').offsetTop - 100,
            behavior: 'smooth'
        });

        try {
            const response = await fetch(url, {
                headers: {
                    'X-Requested-With': 'XMLHttpRequest'
                }
            });

            if (!response.ok) throw new Error('Erreur réseau');

            const html = await response.text();
            
            // Un petit délai artificiel pour apprécier le squelette (optionnel)
            // setTimeout(() => {
                container.innerHTML = html;
                updateResultsCounter();
                bindPaginationLinks();
            // }, 500);

        } catch (error) {
            console.error('Erreur:', error);
            container.innerHTML = '<div class="alert alert-error">Une erreur est survenue lors du chargement des prestataires.</div>';
        }
    }

    /**
     * Met à jour le compteur de résultats
     */
    function updateResultsCounter() {
        const newCount = document.getElementById('results-count-update');
        if (newCount && resultsCounter) {
            resultsCounter.textContent = newCount.textContent;
        }
    }

    /**
     * Réattache les événements sur les nouveaux liens de pagination
     */
    function bindPaginationLinks() {
        const links = document.querySelectorAll('.ajax-page-link');
        links.forEach(link => {
            link.addEventListener('click', function(e) {
                e.preventDefault();
                fetchPrestataires(this.href);
            });
        });
    }

    // Intercepter le changement de catégorie
    const categorySelect = document.getElementById('filter-categorie');
    if (categorySelect) {
        categorySelect.addEventListener('change', function() {
            const formData = new FormData(filtersForm);
            const params = new URLSearchParams(formData);
            const url = `${filtersForm.action}?${params.toString()}`;
            fetchPrestataires(url);
            
            // Mettre à jour l'URL sans recharger la page
            window.history.pushState({}, '', url);
        });
    }

    // Intercepter la recherche principale
    if (searchForm) {
        searchForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const formData = new FormData(searchForm);
            const params = new URLSearchParams(formData);
            const url = `${searchForm.action}?${params.toString()}`;
            fetchPrestataires(url);
            window.history.pushState({}, '', url);
        });
    }

    // Initialiser les liens de pagination existants
    bindPaginationLinks();
});
