(function () {
  "use strict";

  document.querySelectorAll("[data-contact-form]").forEach(function (form) {
    form.addEventListener("submit", function () {
      var submit = form.querySelector("button[type='submit'], input[type='submit']");
      if (!submit) return;
      submit.disabled = true;
      submit.setAttribute("aria-busy", "true");
      submit.value = "Sending…";
      submit.textContent = "Sending…";
    });
  });

  var message = document.querySelector("#contact-message");
  if (message && (message.querySelector("[role='status']") || message.querySelector("[role='alert']"))) {
    message.focus({ preventScroll: true });
  }
})();
