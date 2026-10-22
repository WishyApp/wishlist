// Page de secours des liens partagés : https://wishy-app.fr/w/<id>.
//
// Quand l'app est installée et le domaine vérifié (App Links / Universal
// Links), le téléphone ouvre l'app directement et cette page n'est jamais
// affichée. Sinon, elle propose d'ouvrir l'app ou de la télécharger.
"use strict";

// Doivent correspondre à DeeplinkConfig (lib/app/config/deeplink_config.dart).
const APP_SCHEME = "wishy";
const APP_HOST = "com.raphtang.wishy";
const ANDROID_PACKAGE = "com.raphtang.wishy";

const PLAY_STORE_URL =
  "https://play.google.com/store/apps/details?id=" + ANDROID_PACKAGE;
// Identifiant Apple de l'app (App Store Connect → Informations sur l'app).
// Le bouton App Store est masqué si la valeur est null.
const APP_STORE_URL = "https://apps.apple.com/app/id6755930972";

const TEXTS = {
  fr: {
    homeTitle: "Wishy",
    homeSubtitle: "Crée tes listes d'envies et partage-les avec tes proches.",
    wishlistTitle: "Une wishlist t'attend",
    wishlistSubtitle:
      "Ouvre-la dans l'app Wishy pour découvrir les envies et réserver un cadeau.",
    openApp: "Ouvrir dans Wishy",
    getAppIos: "Télécharger sur l'App Store",
    alreadyInstalled: "Déjà installée ?",
    storesTitle: "Pas encore l'app ?",
    storesTitleHome: "Télécharger l'app",
    desktopHint: "Ouvre ce lien depuis ton téléphone pour voir la wishlist.",
  },
  en: {
    homeTitle: "Wishy",
    homeSubtitle: "Create your wishlists and share them with your loved ones.",
    wishlistTitle: "A wishlist is waiting for you",
    wishlistSubtitle:
      "Open it in the Wishy app to discover the wishes and book a gift.",
    openApp: "Open in Wishy",
    getAppIos: "Download on the App Store",
    alreadyInstalled: "Already installed?",
    storesTitle: "Don't have the app yet?",
    storesTitleHome: "Download the app",
    desktopHint: "Open this link on your phone to see the wishlist.",
  },
};

function pickTexts() {
  const language = (navigator.language || "fr").toLowerCase();
  return language.startsWith("fr") ? TEXTS.fr : TEXTS.en;
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
    // Ouvre l'app si elle est installée, sinon le Play Store.
    return (
      "intent://" +
      path +
      "#Intent;scheme=" +
      APP_SCHEME +
      ";package=" +
      ANDROID_PACKAGE +
      ";S.browser_fallback_url=" +
      encodeURIComponent(PLAY_STORE_URL) +
      ";end"
    );
  }
  return APP_SCHEME + "://" + path;
}

function show(element, isVisible) {
  element.hidden = !isVisible;
}

function render() {
  const texts = pickTexts();
  const platform = detectPlatform();
  const wishlistId = sharedWishlistId();

  document.documentElement.lang = texts === TEXTS.fr ? "fr" : "en";

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
  const storesTitle = document.getElementById("stores-title");
  const appStore = document.getElementById("app-store");
  const playStore = document.getElementById("play-store");
  const desktopHint = document.getElementById("desktop-hint");

  const showAppStore = APP_STORE_URL !== null && platform !== "android";
  const showPlayStore = platform !== "ios";

  if (APP_STORE_URL !== null) {
    appStore.href = APP_STORE_URL;
  }
  playStore.href = PLAY_STORE_URL;
  show(appStore, showAppStore);
  show(playStore, showPlayStore);
  show(stores, showAppStore || showPlayStore);

  if (wishlistId === null) {
    title.textContent = texts.homeTitle;
    subtitle.textContent = texts.homeSubtitle;
    storesTitle.textContent = texts.storesTitleHome;
    return;
  }

  document.title = texts.wishlistTitle + " · Wishy";
  title.textContent = texts.wishlistTitle;
  subtitle.textContent = texts.wishlistSubtitle;
  storesTitle.textContent = texts.storesTitle;

  if (platform === "desktop") {
    desktopHint.textContent = texts.desktopHint;
    show(desktopHint, true);
    return;
  }

  // Sans l'app, wishy:// n'a pas de repli sur iOS : on propose d'abord
  // l'App Store. Avec l'app (et les Universal Links), on n'arrive
  // normalement pas sur cette page.
  if (platform === "ios" && APP_STORE_URL !== null) {
    getApp.textContent = texts.getAppIos;
    getApp.href = APP_STORE_URL;
    show(getApp, true);
    alreadyInstalledLabel.textContent = texts.alreadyInstalled;
    openAppLink.textContent = texts.openApp;
    openAppLink.href = appLink(wishlistId, platform);
    show(alreadyInstalled, true);
    show(stores, false);
    return;
  }

  openApp.textContent = texts.openApp;
  openApp.href = appLink(wishlistId, platform);
  show(openApp, true);
}

render();
