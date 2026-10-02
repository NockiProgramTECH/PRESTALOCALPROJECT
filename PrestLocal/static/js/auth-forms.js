document.addEventListener('DOMContentLoaded', function() {
    const rootStyles = getComputedStyle(document.documentElement);
    const errorBorder = rootStyles.getPropertyValue('--danger-red') || 'var(--primary-red)';
    const defaultBorder = rootStyles.getPropertyValue('--grey-200') || '#ddd';

    // Champs réservés aux prestataires : obligatoires seulement si le rôle
    // « prestataire » est sélectionné (un client n'a pas de métier ni de zone
    // d'intervention). La règle serveur reste identique (formulaire Django).
    const PRO_FIELDS = ['id_metier', 'id_ville', 'id_quartier'];

    function syncProFieldRequirements() {
        const roleField = document.getElementById('id_role');
        if (!roleField) return;
        const isProvider = roleField.value === 'prestataire';
        PRO_FIELDS.forEach((fieldId) => {
            const field = document.getElementById(fieldId);
            if (!field) return;
            if (isProvider) {
                field.setAttribute('required', 'required');
            } else {
                field.removeAttribute('required');
            }
        });
    }

    const forms = [
        { id: 'signupForm', validate: validateSignupForm },
        { id: 'loginForm', validate: validateSimpleForm },
        { id: 'verifyForm', validate: validateVerifyForm }
    ];

    forms.forEach(({ id, validate }) => {
        const form = document.getElementById(id);
        if (!form) return;
        form.addEventListener('submit', function(event) {
            if (!validate(this)) {
                event.preventDefault();
            }
        });
    });

    function validateRequiredFields(form, selector) {
        let isValid = true;
        const inputs = form.querySelectorAll(selector);
        inputs.forEach(input => {
            const hasValue = input.value.trim().length > 0;
            if (!hasValue) {
                isValid = false;
                input.style.borderColor = errorBorder;
            } else {
                input.style.borderColor = defaultBorder;
            }
        });
        return isValid;
    }

    function validateSignupForm(form) {
        const requiredValid = validateRequiredFields(form, 'input[required], select[required]');
        const terms = document.getElementById('terms');
        if (!terms || !terms.checked) {
            if (terms) terms.style.outline = `2px solid ${errorBorder}`;
            alert("Vous devez accepter les conditions d'utilisation.");
            return false;
        }
        if (!requiredValid) {
            alert('Veuillez remplir tous les champs obligatoires.');
            return false;
        }
        return true;
    }

    // Appliqué au chargement puis à chaque changement de rôle.
    const roleField = document.getElementById('id_role');
    if (roleField) {
        syncProFieldRequirements();
        roleField.addEventListener('change', syncProFieldRequirements);
    }

    function validateSimpleForm(form) {
        if (!validateRequiredFields(form, 'input[required]')) {
            alert('Veuillez remplir tous les champs obligatoires.');
            return false;
        }
        return true;
    }

    function validateVerifyForm(form) {
        const codeInput = form.querySelector('input[name="code"]');
        const codeValue = codeInput ? codeInput.value.trim() : '';
        if (codeValue.length !== 6) {
            if (codeInput) codeInput.style.borderColor = errorBorder;
            alert('Veuillez entrer un code de vérification valide (6 chiffres).');
            return false;
        }
        return true;
    }
});
