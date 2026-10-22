# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

Ce dossier décrit le site `wishy-app.fr` (pages publiées dans `site/`, à la racine du repo). L'app elle-même est une app Flutter iOS / Android (`wishlist/`).

## Users

- **Familles et groupes d'amis** qui s'offrent des cadeaux à des occasions récurrentes : Noël, anniversaires, crémaillères. Ce sont les deux publics confirmés par les testeurs.
- Chacun joue deux rôles, souvent dans la même semaine : celui qui fait sa liste d'envies, et celui qui cherche quoi offrir à un proche.
- Sur le site, deux situations d'arrivée :
  1. **Quelqu'un reçoit un lien de liste** (`wishy-app.fr/w/<id>`) par WhatsApp, SMS ou mail, sans avoir l'app. Il a déjà une raison précise d'installer : voir la liste d'un proche et lui offrir quelque chose.
  2. **Quelqu'un découvre Wishy** (bouche-à-oreille, post, recherche) et arrive sur l'accueil. Il doit comprendre en quelques secondes ce que fait l'app et pourquoi elle vaut mieux que ce qu'il utilise déjà.

## Product Purpose

Wishy remplace les listes de cadeaux bricolées : documents envoyés par mail à la famille, notes de téléphone, messages perdus dans un groupe WhatsApp. Tu crées une wishlist par occasion, tu la partages, et tes proches se répartissent les cadeaux entre eux.

Le site a un seul objectif : que le visiteur reparte avec l'app installée. Il sert aussi de domaine pour les liens de partage (App Links / Universal Links) et pointe vers les pages légales exigées par les stores.

## Positioning

- **Le secret est gardé côté propriétaire.** Tes amis réservent un wish et voient entre eux qui offre quoi, pour éviter les doublons. Toi, tu ne vois pas les réservations de tes propres listes. La surprise reste intacte. Une note partagée ou une liste Amazon ne fait pas ça.
- **Les deux côtés du cadeau dans la même app** : tes listes, et les cadeaux que tu as réservés pour les autres (classés par ami, avec le budget total).

## Operating Context

- Les listes circulent par lien dans les messageries. Le lien de partage est la principale porte d'entrée des nouveaux utilisateurs.
- Une wishlist par occasion (anniversaire, Noël 2026, crémaillère, idées cadeaux).
- Ajout d'un wish : photo, prix, lien, et partage direct depuis n'importe quelle app (extension de partage).
- Ajout d'amis dans l'app pour retrouver toutes leurs listes au même endroit.

## Capabilities and Constraints

- **Statut** : app en bêta (TestFlight, test interne Play). Sortie publique sur l'App Store et Google Play prévue dans les semaines qui viennent. Le site doit pouvoir être en ligne avant : les liens des stores se règlent à un seul endroit, et un store sans lien affiche « Bientôt » au lieu d'un bouton mort.
- **Hébergement** : Cloudflare Pages, dossier `site/` servi tel quel, sans étape de build. CSP stricte (`default-src 'self'`) dans `site/_headers` : aucune ressource externe (polices, scripts, images) n'est chargée.
- **Page de secours `/w/<id>`** : n'affiche aucune donnée de la liste. Décision explicite des fondateurs pour ne rien faire fuiter. Elle propose « Ouvrir dans Wishy » et les stores. Introduite par la PR #253 (Raphaël).
- **Langues** : français et anglais.
- **Pages légales** : politique de confidentialité (`/confidentialite`) et conditions d'utilisation (`/conditions`) hébergées sur le site, en français uniquement, migrées depuis les pages Notion publiques d'origine. Contact : wishyapp.contact@gmail.com.
- **Vocabulaire produit** : « wishlist », « wish », « réserver », « Je veux l'offrir », « Réservations ».

## Brand Commitments

- Nom : **Wishy**. Domaine `wishy-app.fr`.
- Ton : tutoiement, direct, un peu de second degré, comme dans l'app.
- Illustrations : encre noire épaisse, humour absurde, une émotion franche (jambes qui dépassent d'un carton, type qui s'ennuie sur un banc). Une illustration « flat » douce et générique a été rejetée (« laid et sans âme »). Toute nouvelle illustration reste dans ce registre, avec au plus un accent orange.
- Engagements affichables : **gratuite, sans pub, données non revendues**.
- Équipe : deux frères, **Raphaël et Tanguy**. L'idée vient de trois occasions de cadeaux d'affilée avec des doublons, et de familles ou d'amis qui s'envoyaient par mail des documents de listes de cadeaux. C'est aussi un projet pour travailler et apprendre ensemble.

## Evidence on Hand

- Captures de l'app et visuels store (FR/EN) : `~/Downloads/wishy-store-assets/` (hors repo). Captures brutes dans `raw/`, visuels Play dans `google-play/`, App Store dans `apple-*`. Les comptes démo permettent d'en refaire, par exemple la même liste vue par son propriétaire et par un ami.
- Illustrations de l'app : `wishlist/assets/svg/` (`no_wishlist.svg`, `no_friend.svg`, `no_wish_box_hat.svg`, `no_wish_bag.svg`, `no_wish_flashlight.svg`, `no_booked_wish.svg`), dans leur version redessinée de la PR #241. Le site en garde une copie dans `site/img/` : la remettre à jour si elles changent encore.
- Icône : `site/icon-512.png`, `site/icon-180.png`. Police : Plus Jakarta Sans (`site/fonts/`).
- **Absents, à ne pas inventer** : avis ou témoignages, nombre d'utilisateurs, notes sur les stores, presse, partenaires.

## Product Principles

1. **Le lien partagé est la porte d'entrée.** Chaque page doit fonctionner pour quelqu'un qui n'a jamais entendu parler de Wishy et qui arrive depuis une conversation.
2. **La surprise d'abord.** Ce qui distingue Wishy, c'est que celui qui fait sa liste ne sait pas ce qu'on va lui offrir. Le reste en découle.
3. **Les deux rôles, pas seulement la liste.** Wishy n'est pas qu'une app de wishlist : c'est l'organisation des cadeaux entre proches.
4. **Rien de faux, rien qui fuite.** Aucune promesse ni preuve inventée, aucune donnée d'utilisateur exposée publiquement.
5. **Une personnalité, pas un modèle.** Le second degré et les illustrations à l'encre sont ce qui rend Wishy reconnaissable.
