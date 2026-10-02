document.addEventListener('DOMContentLoaded', function() {
    const modal = document.getElementById('modal-real');
    const btnAdd = document.getElementById('btn-add-real');
    const btnClose = document.getElementById('btn-close-modal');
    const formReal = document.getElementById('form-add-real');
    const modalMsg = document.getElementById('modal-message');
    const portfolioGrid = document.getElementById('portfolio-grid');
    const noRealMsg = document.getElementById('no-real-msg');
    const profileForm = document.getElementById('profile-update-form');
    const profileMessage = document.getElementById('profile-update-message');
    const availabilityButton = document.getElementById('btn-toggle-availability');
    const availabilitySwitch = document.getElementById('availability-switch');

    /* ---------- Onglets du profil ---------- */
    const tabs = document.querySelectorAll('.profile-tab');
    const panels = document.querySelectorAll('.profile-tabpanel');

    tabs.forEach(function(tab) {
        tab.addEventListener('click', function() {
            const target = this.dataset.tab;
            tabs.forEach(function(t) { t.classList.remove('active'); });
            panels.forEach(function(p) { p.classList.remove('active'); });
            this.classList.add('active');
            const panel = document.getElementById('tab-' + target);
            if (panel) panel.classList.add('active');
        });
    });

    if (btnAdd) {
        btnAdd.addEventListener('click', function() {
            if (modal) modal.style.display = 'flex';
        });
    }

    if (btnClose) {
        btnClose.addEventListener('click', closeModal);
    }

    if (formReal) {
        formReal.addEventListener('submit', function(event) {
            event.preventDefault();
            const submitBtn = this.querySelector('button[type="submit"]');
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i>...';

            fetch(this.action || window.location.href, {
                method: 'POST',
                body: new FormData(this),
                headers: {
                    'X-Requested-With': 'XMLHttpRequest'
                }
            })
            .then(parseJSON)
            .then(data => {
                if (data.status === 'success') {
                    showMessage(modalMsg, data.message, 'success');
                    if (noRealMsg) noRealMsg.remove();
                    const newItem = document.createElement('div');
                    newItem.className = 'portfolio-item';
                    newItem.id = `real-${data.realisation.id}`;
                    const visuel = data.realisation.image_url
                        ? `<img src="${data.realisation.image_url}" alt="${escapeHtml(data.realisation.titre)}">`
                        : `<div class="portfolio-item__text">${escapeHtml(data.realisation.titre || 'Publication')}</div>`;
                    newItem.innerHTML = `
                        ${visuel}
                        <div class="portfolio-overlay">
                            <button class="btn-delete-real" data-real-id="${data.realisation.id}">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    `;
                    if (portfolioGrid) portfolioGrid.insertAdjacentElement('afterbegin', newItem);
                    setTimeout(() => {
                        closeModal();
                        submitBtn.disabled = false;
                        submitBtn.textContent = 'Enregistrer';
                    }, 1500);
                } else {
                    showMessage(modalMsg, 'Erreur lors de l\'ajout.', 'error');
                    submitBtn.disabled = false;
                    submitBtn.textContent = 'Enregistrer';
                }
            })
            .catch((error) => {
                showMessage(modalMsg, error && error.message ? error.message : 'Erreur réseau. Veuillez réessayer.', 'error');
                submitBtn.disabled = false;
                submitBtn.textContent = 'Enregistrer';
            });
        });
    }

    if (portfolioGrid) {
        portfolioGrid.addEventListener('click', function(event) {
            const deleteBtn = event.target.closest('.btn-delete-real');
            if (!deleteBtn) return;
            const realId = deleteBtn.dataset.realId;
            if (!realId) return;
            deleteRealisation(realId);
        });
    }

    if (profileForm) {
        profileForm.addEventListener('submit', function(event) {
            event.preventDefault();
            const submitBtn = this.querySelector('button[type="submit"]');
            submitBtn.disabled = true;
            submitBtn.textContent = 'Enregistrement...';

            fetch(this.action, {
                method: 'POST',
                body: new FormData(this),
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-CSRFToken': getCookie('csrftoken')
                }
            })
            .then(parseJSON)
            .then(data => {
                if (data.status === 'success') {
                    showMessage(profileMessage, data.message, 'success');
                } else {
                    showMessage(profileMessage, firstFieldError(data) || data.error || 'Erreur lors de la mise à jour du profil.', 'error');
                }
            })
            .catch((error) => {
                showMessage(profileMessage, error && error.message ? error.message : 'Erreur réseau. Veuillez réessayer.', 'error');
            })
            .finally(() => {
                submitBtn.disabled = false;
                submitBtn.textContent = 'Enregistrer les modifications';
            });
        });
    }

    function updateAvailabilityUI(isAvailable) {
        if (availabilitySwitch) availabilitySwitch.checked = isAvailable;
        // Synchronise aussi la case du formulaire de réglages pour éviter
        // qu'un enregistrement du profil n'annule silencieusement le toggle.
        const formCheckbox = document.getElementById('id_is_available');
        if (formCheckbox) formCheckbox.checked = isAvailable;
        if (availabilityButton) {
            availabilityButton.innerHTML = isAvailable
                ? '<i class="fas fa-eye-slash"></i> Me masquer'
                : '<i class="fas fa-eye"></i> Me rendre visible';
        }
        // Badge de statut dans le hero
        const dot = document.querySelector('.profile-hero__status-dot');
        if (dot) {
            dot.classList.toggle('available', isAvailable);
            dot.classList.toggle('hidden', !isAvailable);
        }
        // Badge de texte dans le hero
        const badge = document.querySelector('.profile-hero__badges .profile-badge--available, .profile-hero__badges .profile-badge--hidden');
        if (badge) {
            badge.outerHTML = isAvailable
                ? '<span class="profile-badge profile-badge--available"><i class="fas fa-check-circle"></i> Disponible aux recherches</span>'
                : '<span class="profile-badge profile-badge--hidden"><i class="fas fa-eye-slash"></i> Masqué des recherches</span>';
        }
    }

    /**
     * Envoie l'état cible choisi par l'utilisateur.
     * @param {boolean} newState - état de visibilité désiré
     */
    function toggleAvailability(newState) {
        if (!availabilityButton) return;
        const formData = new FormData();
        formData.append('is_available', newState.toString());

        fetch(availabilityButton.dataset.toggleUrl, {
            method: 'POST',
            body: formData,
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-CSRFToken': getCookie('csrftoken')
            }
        })
        .then(parseJSON)
        .then(data => {
            if (data.status === 'success') {
                updateAvailabilityUI(data.is_available);
            } else {
                updateAvailabilityUI(!newState);
            }
        })
        .catch(() => updateAvailabilityUI(!newState));
    }

    if (availabilityButton) {
        // Bouton : n'agit pas sur la checkbox, donc on inverse l'état courant.
        availabilityButton.addEventListener('click', () => {
            toggleAvailability(availabilitySwitch ? !availabilitySwitch.checked : true);
        });
    }
    if (availabilitySwitch) {
        // Sur un événement 'change' le navigateur a déjà basculé la checkbox,
        // donc sa valeur lue est déjà l'état désiré.
        availabilitySwitch.addEventListener('change', () => toggleAvailability(availabilitySwitch.checked));
    }

    function closeModal() {
        if (!modal) return;
        modal.style.display = 'none';
        if (formReal) {
            formReal.reset();
        }
        if (modalMsg) {
            modalMsg.style.display = 'none';
            modalMsg.className = '';
        }
    }

    function deleteRealisation(realId) {
        if (!confirm('Voulez-vous supprimer cette réalisation ?')) return;
        fetch(`/profile/realisation/delete/${realId}/`, {
            method: 'POST',
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-CSRFToken': getCookie('csrftoken')
            }
        })
        .then(parseJSON)
        .then(data => {
            if (data.status === 'success') {
                const item = document.getElementById(`real-${realId}`);
                if (item) {
                    item.style.opacity = '0';
                    setTimeout(() => {
                        item.remove();
                        // Restaure le message vide si le portfolio est vide
                        if (portfolioGrid && portfolioGrid.childElementCount === 0 && !noRealMsg) {
                            const empty = document.createElement('p');
                            empty.id = 'no-real-msg';
                            empty.className = 'profile-empty-msg';
                            empty.innerHTML = '<i class="fas fa-images"></i> Vous n\'avez pas encore de réalisations dans votre portfolio.';
                            portfolioGrid.appendChild(empty);
                        }
                    }, 300);
                }
            }
        });
    }

    function showMessage(element, message, type) {
        if (!element) return;
        element.className = 'alert ' + (type === 'success' ? 'alert-success' : 'alert-error');
        element.textContent = message;
        element.style.display = 'block';
    }

    /** Parse une réponse JSON, en vérifiant que le serveur a bien renvoyé du JSON. */
    function parseJSON(response) {
        const contentType = response.headers.get('content-type') || '';
        if (!contentType.includes('application/json')) {
            // Pas de JSON (page HTML, redirection, 500...) → renvoyer une erreur lisible
            const err = new Error(response.ok ? 'Réponse inattendue du serveur.' : `Erreur serveur (${response.status}).`);
            return Promise.reject(err);
        }
        return response.json().catch(() => Promise.reject(new Error('Réponse JSON invalide.')));
    }

    /** Échappe le HTML pour éviter toute injection XSS dans le innerHTML. */
    function escapeHtml(value) {
        const div = document.createElement('div');
        div.textContent = String(value);
        return div.innerHTML;
    }

    /** Extrait le premier message d'erreur de champ renvoyé par Django (form.errors.as_json). */
    function firstFieldError(data) {
        if (!data || !data.errors) return null;
        try {
            const errors = JSON.parse(data.errors);
            for (const key in errors) {
                if (errors[key] && errors[key][0] && errors[key][0].message) {
                    return errors[key][0].message;
                }
            }
        } catch (e) { /* ignore */ }
        return null;
    }

    function getCookie(name) {
        const value = `; ${document.cookie}`;
        const parts = value.split(`; ${name}=`);
        if (parts.length === 2) return parts.pop().split(';').shift();
        return '';
    }
});
