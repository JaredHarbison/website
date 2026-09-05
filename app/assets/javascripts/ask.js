(function () {
  "use strict";

  function initializeAsk(container) {
    var body = container.querySelector("[data-ask-target='body']");
    var history = container.querySelector("[data-ask-history]");
    var form = container.querySelector("[data-ask-form]");
    var modal = container.querySelector("[data-ask-issue-modal]");
    if (!body || !history || !form) return;
    var question = form.querySelector("[data-ask-question]");
    var submit = form.querySelector("[data-ask-submit]");
    var endpoint = container.dataset.askEndpoint || form.action;
    var turns = [];

    function addButton(parent, label, className, handler) {
      var element = document.createElement("button");
      element.type = "button"; element.className = className; element.textContent = label;
      element.addEventListener("click", handler); parent.append(element); return element;
    }

    function restoreForm() {
      if (turns.length >= 4) return;
      form.hidden = false; question.disabled = false; submit.disabled = false;
      submit.textContent = turns.length ? "Ask another question" : "Ask About Jared"; question.value = ""; question.placeholder = turns.length ? "Ask a follow-up…" : "What kind of engineer is Jared?"; question.focus();
    }

    function showIssue(turn) {
      if (!modal) return;
      modal.dataset.question = turn.question; modal.dataset.answer = turn.answer; modal.dataset.status = turn.status;
      modal.showModal();
      modal.querySelector("[name='feedback']").focus();
    }

    function appendTurn(submittedQuestion, payload) {
      var turn = { question: submittedQuestion, answer: payload.answer, status: payload.status };
      turns.push(turn);
      var state = document.createElement("article"); state.className = "ask-state ask-state--answer";
      var asked = document.createElement("p"); asked.className = "ask-state__question"; asked.textContent = submittedQuestion;
      var label = document.createElement("p"); label.className = "ask-state__label"; label.textContent = payload.status === "answer" ? "Answer" : "No approved answer";
      var text = document.createElement("p"); text.className = "ask-state__text"; text.textContent = payload.answer;
      state.append(asked, label, text);
      if (payload.status === "answer") addButton(state, "Something seem off?", "ask-issue-link", function () { showIssue(turn); });
      history.append(state);
      if (turns.length >= 4) {
        var cta = document.createElement("p"); cta.className = "ask-contact-cta";
        cta.append("Got more questions? ");
        var link = document.createElement("a"); link.href = "/contact"; link.textContent = "Ask Jared."; cta.append(link);
        if (container.dataset.resumeAvailable === "true") { var resume = document.createElement("span"); resume.textContent = " You can also request Jared's résumé there."; cta.append(resume); } history.append(cta);
        var limit = document.createElement("p"); limit.className = "ask-limit-message"; limit.textContent = "This conversation has reached its four-question limit."; history.append(limit);
        form.hidden = true;
      } else restoreForm();
      state.scrollIntoView({ behavior: "smooth", block: "start" });
    }

    function renderError(message) {
      var state = document.createElement("div"); state.className = "ask-state ask-state--error";
      var label = document.createElement("p"); label.className = "ask-state__label"; label.textContent = "Unable to answer";
      var text = document.createElement("p"); text.className = "ask-state__text"; text.textContent = message;
      state.append(label, text); history.append(state); restoreForm();
    }

    form.addEventListener("submit", function (event) {
      event.preventDefault(); if (submit.disabled || turns.length >= 4) return;
      var submittedQuestion = question.value.trim(); var formData = new FormData(form);
      submit.disabled = true; question.disabled = true; submit.textContent = "Finding evidence…";
      fetch(endpoint, { method: "POST", body: formData, credentials: "same-origin", headers: { Accept: "application/json" } })
        .then(function (response) { return response.json().then(function (payload) {
          if (!response.ok || !payload || typeof payload.answer !== "string") throw new Error(payload && payload.answer || "The answer could not be loaded.");
          appendTurn(submittedQuestion, payload);
        }); }).catch(function (error) { renderError(error.message || "The answer could not be loaded. Please try again."); });
    });

    if (modal) {
      modal.querySelector("[data-ask-issue-cancel]").addEventListener("click", function () { modal.close(); });
      modal.querySelector("[data-ask-issue-form]").addEventListener("submit", function (event) {
        event.preventDefault(); var issueForm = event.currentTarget; var status = issueForm.querySelector("[data-ask-issue-status]");
        var data = new FormData(issueForm); data.append("t", form.querySelector("[name='t']")?.value || ""); data.append("question", modal.dataset.question); data.append("answer", modal.dataset.answer); data.append("answer_status", modal.dataset.status);
        var issueButton = issueForm.querySelector("[data-ask-issue-submit]"); issueButton.disabled = true; status.textContent = "Sending…";
        fetch("/api/ask/issues", { method: "POST", body: data, credentials: "same-origin", headers: { Accept: "application/json" } }).then(function (response) { return response.json().then(function (payload) { if (!response.ok || payload.status !== "ok") throw new Error(payload.message || "Feedback could not be sent."); status.textContent = "Thank you — feedback received."; issueButton.disabled = false; setTimeout(function () { modal.close(); }, 700); }); }).catch(function (error) { status.textContent = error.message; issueButton.disabled = false; });
      });
    }
  }
  document.querySelectorAll("[data-ask-controller]").forEach(initializeAsk);
}());
