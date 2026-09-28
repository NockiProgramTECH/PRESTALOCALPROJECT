document.addEventListener('DOMContentLoaded', function() {
    const otpInput = document.getElementById('otp');
    if (otpInput) {
        otpInput.addEventListener('input', function(e) {
            // Garder uniquement les chiffres
            this.value = this.value.replace(/[^0-9]/g, '');
        });
    }
});
