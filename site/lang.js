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

  // Captures de l'app : le français est le src écrit dans le HTML (visible sans
  // JavaScript), l'anglais est cherché ici via data-i18n-src.
  const EN_IMAGES = {
    imgHome: "/img/app-home-en.webp",
    imgWl: "/img/app-wl-en.webp",
    imgBooked: "/img/app-booked-en.webp",
    imgFriendWish: "/img/app-friendwish-en.webp",
    imgFriendWl: "/img/app-friendwl-en.webp",
  };

  // Garde la valeur française d'origine d'un élément pour pouvoir y revenir.
  function remember(element, key, value) {
    if (!(key in element.dataset)) {
      element.dataset[key] = value;
    }
    return element.dataset[key];
  }

  window.WISHY_LANG = Object.freeze({
    remember,

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

    // Passe les <img data-i18n-src> dans la langue donnée (retour au français
    // possible : le src d'origine est gardé dans data-fr-src).
    applyImages(lang) {
      document.querySelectorAll("[data-i18n-src]").forEach((element) => {
        const fr = remember(element, "frSrc", element.getAttribute("src") || "");
        const en = EN_IMAGES[element.dataset.i18nSrc];
        element.setAttribute("src", lang === "en" && en ? en : fr);
      });
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
