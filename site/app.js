// Page de secours des liens partagés : https://wishy-app.fr/w/<id>.
//
// Quand l'app est installée et le domaine vérifié (App Links / Universal
// Links), le téléphone ouvre l'app directement et cette page n'est jamais
// affichée. Sinon, elle propose d'ouvrir l'app ou de la télécharger (sur iOS,
// l'App Store d'abord, car wishy:// n'a pas de repli sans l'app).
"use strict";

// Doivent correspondre à DeeplinkConfig (lib/app/config/deeplink_config.dart).
const APP_SCHEME = "wishy";
const APP_HOST = "com.raphtang.wishy";
const ANDROID_PACKAGE = "com.raphtang.wishy";

// Liens des boutons, réglés dans stores.js : un bouton reste masqué tant que
// son lien est vide.
const STORES = window.WISHY_STORES || {};
const APP_STORE_URL = STORES.appStore || null;
const PLAY_STORE_URL = STORES.playStore || null;

const TEXTS = {
  fr: {
    homeTitle: "Wishy",
    homeSubtitle: "Crée tes listes d'envies et partage-les avec tes proches.",
    wishlistTitle: "Une wishlist t'attend",
    openApp: "Ouvrir dans Wishy",
    getAppIos: "Télécharger sur l'App Store",
    alreadyInstalled: "Déjà installée ?",
    desktopHint: "Ouvre ce lien sur ton téléphone.",
    discover: "Découvrir Wishy",
    storesSoon: "L'app arrive bientôt sur les stores",
  },
  en: {
    homeTitle: "Wishy",
    homeSubtitle: "Create your wishlists and share them with your loved ones.",
    wishlistTitle: "A wishlist is waiting for you",
    openApp: "Open in Wishy",
    getAppIos: "Download on the App Store",
    alreadyInstalled: "Already installed?",
    desktopHint: "Open this link on your phone.",
    discover: "Discover Wishy",
    storesSoon: "The app is coming soon to the stores",
  },
};

// Langue choisie : ?lang=, puis l'accueil, puis le navigateur (lang.js).
function pickLang() {
  return window.WISHY_LANG.initial();
}

function detectPlatform() {
  const userAgent = navigator.userAgent || "";
  if (/android/i.test(userAgent)) {
    return "android";
  }
  // iPadOS se présente comme un Mac : on le repère à l'écran tactile.
  const isIPadOS = /Macintosh/.test(userAgent) && navigator.maxTouchPoints > 1;
  if (/iPhone|iPad|iPod/.test(userAgent) || isIPadOS) {
    return "ios";
  }
  return "desktop";
}

// Seuls des identifiants numériques sont acceptés : ils sont insérés dans
// l'URL de l'app. 18 chiffres au plus, comme DeeplinkConfig (entier 64 bits).
function sharedWishlistId() {
  const match = window.location.pathname.match(/^\/w\/([1-9][0-9]{0,17})\/?$/);
  return match ? match[1] : null;
}

// Route existante de l'app, comprise aussi par les anciennes versions.
function appLink(wishlistId, platform) {
  const path = APP_HOST + "/wishlist/" + wishlistId;
  if (platform === "android") {
    // Ouvre l'app si elle est installée, sinon le Play Store (ou l'accueil
    // tant que PLAY_STORE_URL vaut null).
    return (
      "intent://" +
      path +
      "#Intent;scheme=" +
      APP_SCHEME +
      ";package=" +
      ANDROID_PACKAGE +
      ";S.browser_fallback_url=" +
      // Sans l'app : le Play Store une fois publié, l'accueil avant.
      encodeURIComponent(PLAY_STORE_URL || window.location.origin + "/") +
      ";end"
    );
  }
  return APP_SCHEME + "://" + path;
}

function show(element, isVisible) {
  element.hidden = !isVisible;
}

function render() {
  const lang = pickLang();
  const texts = TEXTS[lang];
  const platform = detectPlatform();
  const wishlistId = sharedWishlistId();

  document.documentElement.lang = lang;
  window.WISHY_LANG.applyImages(lang);

  const title = document.getElementById("title");
  const subtitle = document.getElementById("subtitle");
  const openApp = document.getElementById("open-app");
  const getApp = document.getElementById("get-app");
  const alreadyInstalled = document.getElementById("already-installed");
  const alreadyInstalledLabel = document.getElementById(
    "already-installed-label",
  );
  const openAppLink = document.getElementById("open-app-link");
  const stores = document.querySelector(".stores");
  const appStore = document.getElementById("app-store");
  const playStore = document.getElementById("play-store");
  const storesSoon = document.getElementById("stores-soon");

  // Les boutons des stores apparaissent dès que leur lien est renseigné
  // (stores.js). « Découvrir Wishy » (lien vers l'accueil) apparaît dès qu'un
  // store utile au visiteur manque : Play sur Android, App Store sur iOS,
  // l'un ou l'autre sur ordinateur.
  const showAppStore = APP_STORE_URL !== null && platform !== "android";
  const showPlayStore = PLAY_STORE_URL !== null && platform !== "ios";
  const missingStore =
    (platform !== "ios" && PLAY_STORE_URL === null) ||
    (platform !== "android" && APP_STORE_URL === null);

  if (APP_STORE_URL !== null) {
    appStore.href = APP_STORE_URL;
  }
  if (PLAY_STORE_URL !== null) {
    playStore.href = PLAY_STORE_URL;
  }
  show(appStore, showAppStore);
  show(playStore, showPlayStore);
  show(stores, showAppStore || showPlayStore);
  document.getElementById("soon-label").textContent = texts.discover;
  document.getElementById("soon-note").textContent = texts.storesSoon;
  show(storesSoon, missingStore);

  // Le sous-titre est visible dans le HTML (utile sans JavaScript) : il ne
  // reste que là où il a un texte à porter.
  show(subtitle, false);

  if (wishlistId === null) {
    title.textContent = texts.homeTitle;
    subtitle.textContent = texts.homeSubtitle;
    show(subtitle, true);
    return;
  }

  document.title = texts.wishlistTitle + " · Wishy";
  title.textContent = texts.wishlistTitle;

  if (platform === "desktop") {
    subtitle.textContent = texts.desktopHint;
    show(subtitle, true);
    return;
  }

  // Sans l'app, wishy:// n'a pas de repli sur iOS : l'action principale est
  // l'App Store, ou l'accueil tant que l'app n'y est pas, et l'ouverture de
  // l'app passe en lien secondaire. Avec l'app (et les Universal Links), on
  // n'arrive normalement pas sur cette page.
  if (platform === "ios") {
    if (APP_STORE_URL !== null) {
      getApp.textContent = texts.getAppIos;
      getApp.href = APP_STORE_URL;
      show(getApp, true);
      show(stores, false);
    } else {
      storesSoon.classList.add("share-soon-primary");
    }
    alreadyInstalledLabel.textContent = texts.alreadyInstalled;
    openAppLink.textContent = texts.openApp;
    openAppLink.href = appLink(wishlistId, platform);
    show(alreadyInstalled, true);
    return;
  }

  openApp.textContent = texts.openApp;
  openApp.href = appLink(wishlistId, platform);
  show(openApp, true);
}

render();
