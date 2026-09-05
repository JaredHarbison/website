(function () {
  "use strict";
  document.querySelectorAll("[data-access-links-search]").forEach(function (form) {
    var query = form.querySelector("[data-access-links-query]");
    if (!query) return;
    query.addEventListener("input", function () {
      if (query.value === "") form.requestSubmit();
    });
  });
}());
