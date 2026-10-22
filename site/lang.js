// Langue du site, partagée par l'accueil (landing.js) et la page de secours
// (app.js) pour qu'elles affichent toujours la même : ?lang=, puis le choix
// enregistré par le sélecteur de l'accueil, puis la langue du navigateur.
"use strict";

(function () {
  const STORAGE_KEY = "wishy-lang";

  function isSupported(lang) {
    return lang === "fr" || lang === "en";
  }

  function readStored() {
    try {
      return window.localStorage.getItem(STORAGE_KEY);
    } catch (error) {
      return null;
    }
  }

  window.WISHY_LANG = Object.freeze({
    // "fr" ou "en".
    initial() {
      const fromUrl = new URLSearchParams(window.location.search).get("lang");
      if (isSupported(fromUrl)) {
        return fromUrl;
      }
      const stored = readStored();
      if (isSupported(stored)) {
        return stored;
      }
      const browser = (navigator.language || "fr").toLowerCase();
      return browser.startsWith("fr") ? "fr" : "en";
    },

    store(lang) {
      try {
        window.localStorage.setItem(STORAGE_KEY, lang);
      } catch (error) {
        // Stockage indisponible (navigation privée) : la langue ne sera pas retenue.
      }
    },
  });
})();
