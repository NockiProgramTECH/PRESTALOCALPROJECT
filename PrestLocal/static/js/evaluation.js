/**
 * Gestion des évaluations par AJAX
 */
document.addEventListener('DOMContentLoaded', function() {
    const evaluationForm = document.getElementById('evaluation-form');
    const evaluationMessage = document.getElementById('evaluation-message');
    const starInputs = document.querySelectorAll('.star-rating-input input');
    
    // Feedback visuel pour la sélection des étoiles
    if (starInputs.length > 0) {
        starInputs.forEach(input => {
            input.addEventListener('change', function() {
                const note = this.value;
                const labels = document.querySelectorAll('.star-rating-input label');
                
                // On peut ajouter un petit texte de feedback si on veut
                console.log(`Note sélectionnée : ${note}/5`);
            });
        });
    }

    if (evaluationForm) {
        evaluationForm.addEventListener('submit', function(e) {
            e.preventDefault();

            // Récupération des données du formulaire
            const formData = new FormData(evaluationForm);
            const url = evaluationForm.getAttribute('data-url');
            const note = formData.get('note');

            // Vérification si une note est sélectionnée
            if (!note) {
                showMessage('Veuillez sélectionner une note en cliquant sur les étoiles.', 'error');
                return;
            }

            // Vérification si un commentaire est rempli
            if (!formData.get('commentaire').trim()) {
                showMessage('Veuillez entrer un commentaire pour partager votre expérience.', 'error');
                return;
            }

            // Désactiver le bouton pendant l'envoi
            const submitBtn = evaluationForm.querySelector('button[type="submit"]');
            const originalBtnText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Envoi en cours...';

            // Envoi de la requête AJAX
            fetch(url, {
                method: 'POST',
                body: formData,
                headers: {
                    'X-Requested-With': 'XMLHttpRequest',
                    'X-CSRFToken': formData.get('csrfmiddlewaretoken')
                }
            })
            .then(response => response.json())
            .then(data => {
                if (data.status === 'success') {
                    showMessage('Merci ! Votre avis a été enregistré et le prestataire a été notifié.', 'success');
                    evaluationForm.reset();
                    // Recharger la page après un court délai pour voir le nouvel avis
                    setTimeout(() => {
                        window.location.reload();
                    }, 2000);
                } else {
                    showMessage(data.message || 'Une erreur est survenue.', 'error');
                    submitBtn.disabled = false;
                    submitBtn.textContent = originalBtnText;
                }
            })
            .catch(error => {
                console.error('Erreur:', error);
                showMessage('Une erreur réseau est survenue. Veuillez réessayer.', 'error');
                submitBtn.disabled = false;
                submitBtn.textContent = originalBtnText;
            });
        });
    }

    /**
     * Affiche un message de succès ou d'erreur avec une animation
     */
    function showMessage(text, type) {
        evaluationMessage.textContent = text;
        evaluationMessage.style.display = 'block';
        evaluationMessage.style.opacity = '0';
        evaluationMessage.style.transform = 'translateY(-10px)';
        evaluationMessage.style.transition = 'all 0.3s ease';
        
        if (type === 'success') {
            evaluationMessage.style.backgroundColor = '#ecfdf5';
            evaluationMessage.style.color = '#065f46';
            evaluationMessage.style.border = '1px solid #a7f3d0';
        } else {
            evaluationMessage.style.backgroundColor = '#fef2f2';
            evaluationMessage.style.color = '#991b1b';
            evaluationMessage.style.border = '1px solid #fecaca';
        }

        // Animation d'entrée
        setTimeout(() => {
            evaluationMessage.style.opacity = '1';
            evaluationMessage.style.transform = 'translateY(0)';
        }, 10);
    }
});
