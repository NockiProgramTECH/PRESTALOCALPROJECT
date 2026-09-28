document.addEventListener('DOMContentLoaded', function() {
    // Gestion du bouton Appel
    const phoneButton = document.querySelector('.btn-action.btn-call');
    if (phoneButton) {
        const recordUrl = phoneButton.dataset.recordUrl;
        const phoneNumber = phoneButton.dataset.phone;

        phoneButton.addEventListener('click', function(event) {
            event.preventDefault();
            if (recordUrl) {
                fetch(recordUrl, {
                    method: 'POST',
                    headers: {
                        'X-CSRFToken': getCookie('csrftoken'),
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                }).finally(() => {
                    window.location.href = `tel:${phoneNumber}`;
                });
            } else {
                window.location.href = `tel:${phoneNumber}`;
            }
        });
    }

    // Gestion des boutons WhatsApp et Email (Contact)
    const contactButtons = document.querySelectorAll('.btn-whatsapp, .btn-email');
    contactButtons.forEach(button => {
        button.addEventListener('click', function(event) {
            const recordUrl = this.dataset.recordUrl;
            if (recordUrl) {
                // On envoie la requête sans bloquer l'ouverture du lien (target="_blank" ou mailto)
                fetch(recordUrl, {
                    method: 'POST',
                    headers: {
                        'X-CSRFToken': getCookie('csrftoken'),
                        'X-Requested-With': 'XMLHttpRequest'
                    }
                });
            }
        });
    });

    function getCookie(name) {
        let cookieValue = null;
        if (document.cookie && document.cookie !== '') {
            const cookies = document.cookie.split(';');
            for (let i = 0; i < cookies.length; i++) {
                const cookie = cookies[i].trim();
                if (cookie.substring(0, name.length + 1) === (name + '=')) {
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                    break;
                }
            }
        }
        return cookieValue;
    }
});
