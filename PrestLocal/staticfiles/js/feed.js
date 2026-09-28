/**
 * feed.js — Interactions sociales (Likes et Commentaires)
 * Les styles visuels sont définis dans main.css (.feed-card__*, .like-btn, .feed-comment)
 */
document.addEventListener('DOMContentLoaded', function() {

    // -----------------------------------------------
    // Likes : toggle via AJAX
    // -----------------------------------------------
    document.addEventListener('click', function(e) {
        const likeBtn = e.target.closest('.like-btn');
        if (!likeBtn) return;

        const id  = likeBtn.dataset.id;
        const url = `/feed/like/${id}/`;

        fetch(url, {
            method: 'POST',
            headers: {
                'X-CSRFToken': getCookie('csrftoken'),
                'X-Requested-With': 'XMLHttpRequest'
            }
        })
        .then(r => r.json())
        .then(data => {
            if (data.status !== 'success') return;

            const icon  = likeBtn.querySelector('i');
            const count = likeBtn.querySelector('.like-count');

            if (data.liked) {
                // Passe en "aimé" : icône pleine + classe .liked
                icon.classList.replace('far', 'fas');
                likeBtn.classList.add('liked');
                likeBtn.setAttribute('aria-label', 'Retirer le like');
            } else {
                // Passe en "pas aimé" : icône vide
                icon.classList.replace('fas', 'far');
                likeBtn.classList.remove('liked');
                likeBtn.setAttribute('aria-label', 'Aimer cette réalisation');
            }

            count.textContent = data.like_count;
        })
        .catch(err => console.error('Erreur like :', err));
    });

    // -----------------------------------------------
    // Commentaires : ajout via AJAX
    // -----------------------------------------------
    document.addEventListener('submit', function(e) {
        const commentForm = e.target.closest('.comment-form');
        if (!commentForm) return;

        e.preventDefault();

        const id        = commentForm.dataset.id;
        const url       = `/feed/comment/${id}/`;
        const formData  = new FormData(commentForm);
        // Le conteneur est identifié par les deux classes (fixée + dynamique)
        const container = document.querySelector(`.comments-container-${id}`);

        fetch(url, {
            method: 'POST',
            body: formData,
            headers: { 'X-Requested-With': 'XMLHttpRequest' }
        })
        .then(r => r.json())
        .then(data => {
            if (data.status !== 'success') return;

            // Commentaire injecte avec les classes CSS (pas de style inline)
            const div = document.createElement('div');
            div.className = 'feed-comment';
            div.innerHTML = `<span class="feed-comment__author">${data.comment.user}</span>${data.comment.contenu}`;

            // Insère en premier pour que le plus récent soit en haut
            container.insertAdjacentElement('afterbegin', div);

            // Mise à jour du compteur
            const card = commentForm.closest('.feed-card');
            const countSpan = card ? card.querySelector('.comment-count') : null;
            if (countSpan) countSpan.textContent = data.comment_count;

            // Vide l'input
            commentForm.reset();
        })
        .catch(err => console.error('Erreur commentaire :', err));
    });

    // -----------------------------------------------
    // Partage : Web Share API + fallback clipboard
    // -----------------------------------------------
    document.addEventListener('click', function (e) {
        const shareBtn = e.target.closest('.share-btn');
        if (!shareBtn) return;

        const shareUrl   = shareBtn.dataset.url;
        const shareTitle = shareBtn.dataset.title;
        const shareText  = shareBtn.dataset.text;

        // CAS 1 : Web Share API disponible (mobile natif Android/iOS)
        if (navigator.share) {
            navigator.share({ title: shareTitle, text: shareText, url: shareUrl })
                .then(() => animateShareBtn(shareBtn))
                .catch(err => {
                    // AbortError = l'utilisateur a annulé : pas une vraie erreur
                    if (err.name !== 'AbortError') {
                        console.warn('Web Share API :', err);
                    }
                });

        // CAS 2 : Clipboard API (desktop Chrome/Edge/Safari modernes)
        } else if (navigator.clipboard && navigator.clipboard.writeText) {
            navigator.clipboard.writeText(shareUrl)
                .then(() => {
                    animateShareBtn(shareBtn);
                    showShareToast('Lien copié dans le presse-papiers !');
                })
                .catch(() => fallbackCopy(shareUrl, shareBtn));

        // CAS 3 : execCommand (navigateurs anciens)
        } else {
            fallbackCopy(shareUrl, shareBtn);
        }
    });

    // Anime brièvement le bouton (classe .shared pendant 600ms)
    function animateShareBtn(btn) {
        btn.classList.add('shared');
        setTimeout(() => btn.classList.remove('shared'), 600);
    }

    // Affiche le toast de confirmation
    var toastTimer = null;
    function showShareToast(message, duration) {
        duration = duration || 2500;
        var toast   = document.getElementById('shareToast');
        var msgSpan = document.getElementById('shareToastMsg');
        if (!toast || !msgSpan) return;
        msgSpan.textContent = message;
        toast.classList.add('visible');
        clearTimeout(toastTimer);
        toastTimer = setTimeout(function () {
            toast.classList.remove('visible');
        }, duration);
    }

    // Fallback execCommand pour les très anciens navigateurs
    function fallbackCopy(text, btn) {
        var ta = document.createElement('textarea');
        ta.value = text;
        ta.style.cssText = 'position:fixed;top:-9999px;left:-9999px;opacity:0;';
        document.body.appendChild(ta);
        ta.select();
        try {
            var ok = document.execCommand('copy');
            if (ok) {
                animateShareBtn(btn);
                showShareToast('Lien copié dans le presse-papiers !');
            } else {
                showShareToast('Copiez ce lien : ' + text, 5000);
            }
        } catch (err) {
            showShareToast('Copiez ce lien : ' + text, 5000);
        } finally {
            document.body.removeChild(ta);
        }
    }

    // -----------------------------------------------
    // Utilitaire : lire un cookie par son nom
    // -----------------------------------------------
    function getCookie(name) {
        if (!document.cookie) return null;
        const cookie = document.cookie
            .split(';')
            .map(c => c.trim())
            .find(c => c.startsWith(name + '='));
        return cookie ? decodeURIComponent(cookie.split('=')[1]) : null;
    }
});

