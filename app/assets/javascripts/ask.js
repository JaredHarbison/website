(function () {
  "use strict";

  function initializeAsk(container) {
    var body = container.querySelector("[data-ask-target='body']");
    var form = container.querySelector("[data-ask-form]");
    if (!body || !form) return;

    var question = form.querySelector("[data-ask-question]");
    var submit = form.querySelector("[data-ask-submit]");
    var endpoint = container.dataset.askEndpoint || form.action;

    function button(label, className, handler) {
      var element = document.createElement("button");
      element.type = "button";
      element.className = className;
      element.textContent = label;
      element.addEventListener("click", handler);
      return element;
    }

    function restoreForm() {
      body.replaceChildren(form);
      form.hidden = false;
      question.disabled = false;
      submit.disabled = false;
      submit.textContent = "Ask About Jared";
      question.value = "";
      question.focus();
    }

    function renderError(message) {
      body.replaceChildren();
      var state = document.createElement("div");
      state.className = "ask-state ask-state--error";
      var label = document.createElement("p");
      label.className = "ask-state__label";
      label.textContent = "Unable to answer";
      var text = document.createElement("p");
      text.className = "ask-state__text";
      text.textContent = message;
      state.append(label, text, button("Ask another question", "button-link", restoreForm));
      body.append(state);
    }

    function renderAnswer(submittedQuestion, answer) {
      body.replaceChildren();
      var state = document.createElement("div");
      state.className = "ask-state ask-state--answer";
      var asked = document.createElement("p");
      asked.className = "ask-state__question";
      asked.textContent = submittedQuestion;
      var label = document.createElement("p");
      label.className = "ask-state__label";
      label.textContent = "Answer";
      var text = document.createElement("p");
      text.className = "ask-state__text";
      text.textContent = answer;
      state.append(asked, label, text, button("Ask another question", "button-link", restoreForm));
      body.append(state);
    }

    form.addEventListener("submit", function (event) {
      event.preventDefault();
      if (submit.disabled) return;

      var submittedQuestion = question.value.trim();
      var formData = new FormData(form);
      submit.disabled = true;
      question.disabled = true;
      submit.textContent = "Finding evidence…";

      fetch(endpoint, {
        method: "POST",
        body: formData,
        credentials: "same-origin",
        headers: { Accept: "application/json" }
      }).then(function (response) {
        return response.json().then(function (payload) {
          if (!response.ok || !payload || typeof payload.answer !== "string") {
            throw new Error(payload && typeof payload.answer === "string" ? payload.answer : "The answer could not be loaded.");
          }
          if (["blocked"].indexOf(payload.status) !== -1) throw new Error(payload.answer);
          renderAnswer(submittedQuestion, payload.answer);
        });
      }).catch(function (error) {
        renderError(error.message || "The answer could not be loaded. Please try again.");
      });
    });
  }

  document.querySelectorAll("[data-ask-controller]").forEach(initializeAsk);
}());
