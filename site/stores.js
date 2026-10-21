// Liens des stores, partagés par l'accueil (landing.js) et la page de
// secours (app.js). Laisser à null tant que l'app n'est pas publiée sur le
// store : l'accueil affiche « bientôt », la page de secours un bouton vers
// l'accueil, et Android sans l'app retombe sur l'accueil au lieu du Play Store.
"use strict";

window.WISHY_STORES = Object.freeze({
  // App Store Connect → Informations sur l'app → Identifiant Apple.
  appStore: "https://apps.apple.com/app/id6755930972",
  // "https://play.google.com/store/apps/details?id=com.raphtang.wishy"
  playStore: null,
});
