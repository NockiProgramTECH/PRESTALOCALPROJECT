/**
 * Messagerie LesProduFao — temps réel via WebSocket
 * Envoi/réception instantanés + présence en ligne.
 * Repli HTTP POST si le WebSocket est indisponible.
 */
document.addEventListener('DOMContentLoaded', function () {
    const convMessages = document.getElementById('convMessages');
    const convForm = document.getElementById('convForm');
    const msgInput = document.getElementById('msgInput');
    const msgSendBtn = document.getElementById('msgSendBtn');

    if (!convForm || !convMessages) return;

    const conversationId = convMessages.dataset.conversationId;
    const myId = convMessages.dataset.userId;

    // URL du WebSocket (wss:// si page en https, sinon ws://)
    const proto = window.location.protocol === 'https:' ? 'wss' : 'ws';
    const wsUrl = `${proto}://${window.location.host}/ws/chat/${conversationId}/`;

    let socket = null;
    let pendingQueue = []; // messages à envoyer une fois le socket ouvert

    function appendBubble(senderId, content, time) {
        const empty = convMessages.querySelector('.conv-empty');
        if (empty) empty.remove();

        const div = document.createElement('div');
        div.className = 'message-bubble ' + (String(senderId) === String(myId) ? 'sent' : 'received');
        const text = document.createElement('span');
        text.className = 'msg-text';
        text.textContent = content; // XSS-safe
        const timeEl = document.createElement('div');
        timeEl.className = 'msg-time';
        timeEl.textContent = time || "À l'instant";
        div.appendChild(text);
        div.appendChild(timeEl);
        convMessages.appendChild(div);
        scrollToBottom();
    }

    function scrollToBottom() {
        convMessages.scrollTop = convMessages.scrollHeight;
    }

    function formatTime(iso) {
        const d = new Date(iso);
        return d.toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
    }

    function updatePresence(userId, online) {
        const dot = document.querySelector(`.conv-presence[data-presence-user="${userId}"]`);
        if (!dot) return;
        dot.classList.toggle('online', online);
        const label = dot.querySelector('.presence-text');
        if (label) label.textContent = online ? 'en ligne' : 'hors ligne';
    }

    function openSocket() {
        try {
            socket = new WebSocket(wsUrl);
        } catch (e) {
            socket = null;
            return;
        }

        socket.onopen = function () {
            // Envoie les messages mis en file pendant l'ouverture
            pendingQueue.forEach(function (c) {
                socket.send(JSON.stringify({ type: 'chat.message', content: c }));
            });
            pendingQueue = [];
        };

        socket.onmessage = function (e) {
            let data;
            try { data = JSON.parse(e.data); } catch (err) { return; }

            if (data.type === 'chat.message') {
                const m = data.message;
                // Ignore l'écho de son propre message (affichage optimiste déjà fait)
                if (String(m.sender_id) === String(myId)) return;
                appendBubble(m.sender_id, m.content, formatTime(m.created_at));
            } else if (data.type === 'chat.presence') {
                updatePresence(data.user_id, data.online);
            }
        };

        socket.onclose = function () {
            socket = null;
        };
        socket.onerror = function () {
            if (socket) socket.close();
        };
    }

    // ---- Envoi par WebSocket (avec repli HTTP) ----
    function httpFallback(content) {
        fetch(window.location.pathname, {
            method: 'POST',
            body: new FormData(convForm),
            headers: {
                'X-Requested-With': 'XMLHttpRequest',
                'X-CSRFToken': getCookie('csrftoken')
            }
        })
        .then(r => r.json())
        .then(data => {
            if (data.status === 'ok') {
                appendBubble(myId, data.content, "À l'instant");
                msgInput.value = '';
            }
        })
        .catch(() => {});
    }

    convForm.addEventListener('submit', function (e) {
        e.preventDefault();

        const content = msgInput.value.trim();
        if (!content) return;

        if (socket && socket.readyState === WebSocket.OPEN) {
            // Affichage optimiste local + envoi temps réel
            appendBubble(myId, content, "À l'instant");
            socket.send(JSON.stringify({ type: 'chat.message', content }));
            msgInput.value = '';
        } else if (socket && socket.readyState === WebSocket.CONNECTING) {
            // Le socket s'ouvre encore : on affiche en optimiste et on met en file
            appendBubble(myId, content, "À l'instant");
            pendingQueue.push(content);
            msgInput.value = '';
        } else {
            // Repli HTTP POST classique (le service diffuse aussi au groupe WS)
            httpFallback(content);
        }
    });

    function getCookie(name) {
        const value = `; ${document.cookie}`;
        const parts = value.split(`; ${name}=`);
        if (parts.length === 2) return parts.pop().split(';').shift();
        return '';
    }

    openSocket();
    scrollToBottom();
});
