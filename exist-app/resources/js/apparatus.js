/*
 * Progressive enhancement for the apparatus.
 *
 * The variants are already in the DOM as data- attributes, put there by the
 * XSLT, so this script adds no network traffic and the page is fully usable
 * with JavaScript disabled. That matters for a scholarly edition: the citable
 * artefact should not depend on a script executing.
 */
(function () {
  "use strict";

  function initTooltips() {
    document.querySelectorAll(".lemma[data-variants]").forEach(function (el) {
      var variants = el.getAttribute("data-variants");
      if (!variants) return;
      el.setAttribute("title", "Variants: " + variants);
      el.setAttribute("tabindex", "0");
      el.setAttribute("role", "button");
      el.setAttribute("aria-label", "Lemma with variants: " + variants);
    });
  }

  /* Clicking an apparatus marker highlights the corresponding note, and vice
     versa, so the reader does not lose their place in a dense apparatus. */
  function initLinking() {
    document.querySelectorAll(".app-marker a, .align-link").forEach(function (a) {
      a.addEventListener("click", function (ev) {
        var id = a.getAttribute("href");
        if (!id || id.charAt(0) !== "#") return;
        var target = document.querySelector(id);
        if (!target) return;
        ev.preventDefault();
        document.querySelectorAll(".is-highlighted").forEach(function (n) {
          n.classList.remove("is-highlighted");
        });
        target.classList.add("is-highlighted");
        target.scrollIntoView({ behavior: "smooth", block: "center" });
      });
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", function () {
      initTooltips(); initLinking();
    });
  } else {
    initTooltips(); initLinking();
  }
})();
