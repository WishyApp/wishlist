---
name: Wishy (wishy-app.fr)
description: Le site de Wishy, l'app de wishlists entre proches, qui prolonge la palette et la police de l'app Flutter.
colors:
  background: "#f7f6f0"
  surface: "#ffffff"
  sand: "#e8e4da"
  border: "#e0dbd0"
  primary: "#f28c57"
  primary-dark: "#df733d"
  primary-text: "#c8612b"
  ink: "#2c2c2c"
  ink-deep: "#1e1e1e"
  ink-raised: "#3a3632"
  text-muted: "#6b5e50"
  on-ink-muted: "#d6cfc4"
  dash-soon: "#b9ad9e"
typography:
  display:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(2.9rem, 5.3vw, 4.9rem)"
    fontWeight: 800
    lineHeight: 0.93
    letterSpacing: "-0.04em"
  display-closing:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(3rem, 8vw, 6rem)"
    fontWeight: 800
    lineHeight: 0.95
    letterSpacing: "-0.04em"
  headline:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(2.2rem, 4.4vw, 3.75rem)"
    fontWeight: 800
    lineHeight: 0.98
    letterSpacing: "-0.04em"
  title:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(1.9rem, 3.4vw, 2.75rem)"
    fontWeight: 800
    lineHeight: 1
    letterSpacing: "-0.04em"
  lede:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "clamp(1.1rem, 1.45vw, 1.3rem)"
    fontWeight: 500
    lineHeight: 1.5
  body:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1.125rem"
    fontWeight: 500
    lineHeight: 1.5
  label:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "1rem"
    fontWeight: 700
    lineHeight: 1.5
  tag:
    fontFamily: "PlusJakartaSans, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "0.85rem"
    fontWeight: 800
    lineHeight: 1.25
    letterSpacing: "-0.02em"
rounded:
  tail: "6px"
  control: "14px"
  tag: "18px"
  bubble: "20px"
  panel: "28px"
  pill: "999px"
  phone: "15% / 7%"
spacing:
  gap-sm: "12px"
  gap-md: "24px"
  gutter: "clamp(16px, 4.5vw, 64px)"
  section-y: "clamp(56px, 7vw, 104px)"
  max-width: "1280px"
components:
  button-primary:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.surface}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "14px 22px"
    height: "52px"
  button-primary-hover:
    backgroundColor: "#000000"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "14px 22px"
    height: "52px"
  store-soon:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "14px 22px"
    height: "52px"
  button-open-app:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.ink}"
    typography: "{typography.label}"
    rounded: "{rounded.control}"
    padding: "14px 22px"
    height: "58px"
  nav-cta:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.surface}"
    rounded: "{rounded.pill}"
    padding: "10px 16px"
  lang-toggle:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    padding: "6px 10px"
  loop-tag:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.tag}"
    padding: "0.55em 0.95em 0.6em 0.6em"
  step-node:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.ink}"
    rounded: "{rounded.pill}"
    size: "48px"
  booking-tag:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.ink}"
    typography: "{typography.tag}"
    rounded: "{rounded.pill}"
    padding: "5px 11px"
  chat-panel:
    backgroundColor: "{colors.sand}"
    rounded: "{rounded.panel}"
    padding: "22px"
  bubble-in:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.bubble}"
    padding: "12px 16px"
  bubble-out:
    backgroundColor: "{colors.ink}"
    textColor: "{colors.surface}"
    rounded: "{rounded.bubble}"
    padding: "12px 16px"
---

# Design System: Wishy (wishy-app.fr)

## Overview

**Creative North Star: "La boucle à l'encre"**

Le site prolonge l'app au lieu de la présenter. Même crème chaud, même encre presque noire, même Plus Jakarta Sans, mêmes illustrations à l'encre épaisse et à l'humour absurde. Ce qui appartient au site, c'est la boucle : Wishy est un cycle (tes envies, tes proches, le secret, le jour J), et un tracé orange en pointillés fléchés relie les étapes, d'abord autour de quatre téléphones dans le premier écran, puis entre les sections jusqu'à leur numéro.

La page est aérée mais pas vide : de grands titres très gras et serrés, peu de texte, et les écrans de l'app toujours montrés dans des téléphones noirs légèrement inclinés, jamais à plat. La profondeur vient d'ombres douces posées sous les objets (téléphones, légendes, tableau du secret), pas de cartes empilées. Une seule bande sombre, celle du secret, inverse la page pour marquer le moment pivot.

Le registre rejeté est connu : l'illustration « flat » douce et générique, et le gabarit titre à gauche, téléphone à droite, puis sections alternées texte et capture.

**Key Characteristics:**
- Crème chaud en fond, blanc pour les surfaces posées dessus, encre pour le texte et les actions.
- Orange réservé au parcours : tracé, numéros d'étape, réservations, mot-clé des grands titres.
- Titres en Plus Jakarta Sans 800, interlignage sous 1, approche négative.
- Écrans de l'app dans des cadres de téléphone noirs, inclinés de quelques degrés.
- Illustrations à l'encre noire aux respirations, jamais de pictogrammes décoratifs.
- Mouvement unique : le tracé qui se dessine, désactivé sans `prefers-reduced-motion: no-preference`.

## Colors

Une palette chaude et retenue, crème et encre, où l'orange de l'app n'apparaît que là où le visiteur avance.

### Primary
- **Orange Wishy** (`primary`): la couleur de l'app. Tracé pointillé de la boucle et des transitions, pastilles numérotées des étapes, étiquette « réservé » dans le tableau du secret, état actif du sélecteur mobile du secret, sélection de texte. Toujours en aplat avec du texte encre dessus, jamais en texte sur fond clair. Sur la bande sombre, il colore aussi le mot-clé du titre.
- **Orange titre** (`primary-text`): l'orange assombri pour atteindre 3:1 en grand texte sur crème (3,73:1). Sert uniquement au mot-clé (`em`) des titres display sur fond clair, comme sur les visuels des stores.
- **Orange profond** (`primary-dark`): n'apparaît que teinté dans l'ombre portée du bouton « Ouvrir dans Wishy ».

### Neutral
- **Crème** (`background`): le fond de toutes les pages, repris de l'app. Sert aussi d'anneau de découpe autour des pastilles d'étape posées sur le tracé.
- **Blanc** (`surface`): ce qui est posé sur le crème : légendes de la boucle, bulle reçue, colonne « toi » du tableau du secret. Aussi le texte sur encre.
- **Sable** (`sand`): le fond de la conversation de famille (étape 2), une surface plus chaude que le blanc pour signaler « ailleurs que dans l'app ».
- **Filet** (`border`): bordures des boutons secondaires et du sélecteur de langue, séparateurs du pied de page et de la section « Qui on est ».
- **Encre** (`ink`): texte, boutons d'action, bulle envoyée, bande du secret. Le noir pur (#000000) n'existe qu'au survol des boutons encre.
- **Encre profonde** (`ink-deep`): le cadre des téléphones.
- **Encre relevée** (`ink-raised`): la colonne « eux » du tableau du secret, une surface un cran plus claire posée sur la bande encre.
- **Texte atténué** (`text-muted`): sous-titres, paragraphes de section, pied de page. Le #887a6b de l'app, assombri pour 5,8:1 sur crème.
- **Atténué sur encre** (`on-ink-muted`): texte secondaire sur la bande sombre et dans la bulle envoyée (9:1 sur encre).
- **Pointillé « bientôt »** (`dash-soon`): la bordure en tirets d'un store pas encore publié, et l'emplacement vide d'un wish non réservé. Bordure décorative uniquement, jamais du texte (2:1 sur crème).

### Named Rules
**The Trail Rule.** L'orange marque le parcours et rien d'autre : le tracé, les numéros d'étape, les réservations, l'état actif, et le mot-clé d'un grand titre. Seule exception d'action : « Ouvrir dans Wishy » sur la page de partage, qui prolonge le tracé jusque dans l'app. Un bouton de store, un lien de navigation ou un fond de section ne sont jamais orange.

**The Split Orange Rule.** `primary` sert d'aplat sous du texte encre (5,76:1) ou de texte sur encre. Sur crème, un texte orange utilise `primary-text`, et seulement en taille display.

## Typography

**Display Font:** PlusJakartaSans (avec system-ui, -apple-system, Segoe UI, Roboto, sans-serif)
**Body Font:** PlusJakartaSans (même pile)

**Character:** une seule famille, servie en local (CSP stricte, aucune police externe), en quatre graisses (400, 500, 700, 800). Le contraste vient de l'écart entre 800 très serré pour les titres et 500 détendu pour le texte.

### Hierarchy
- **Display** (`display`): le titre du premier écran, en quatre lignes. Variante plus grande `display-closing` pour l'appel final, et le titre de la bande du secret entre les deux (clamp(2.6rem, 6.4vw, 5.5rem), interlignage 0.95). Le titre de la page de partage suit la même logique en plus compact (clamp(2.3rem, 10vw, 3.4rem), approche -0.045em).
- **Headline** (`headline`): le titre de chaque étape.
- **Title** (`title`): les titres secondaires, comme « Qui on est ».
- **Lede** (`lede`): la phrase sous le titre du premier écran, limitée à 30ch, en texte atténué.
- **Body** (`body`): paragraphes d'étape, limités à 44ch (52ch dans « Qui on est »), en texte atténué. Le corps de page par défaut reste à 1rem, graisse 500.
- **Label** (`label`): boutons, liens de navigation (0.95rem), noms de wish.
- **Tag** (`tag`): étiquettes de réservation, noms d'étape dans les légendes de la boucle.

### Named Rules
**The Tight Display Rule.** Tout titre est en 800, approche négative (-0.04em), interlignage sous 1 pour les tailles display, et `text-wrap: balance`. Le point et la virgule, très larges dans cette police, sont resserrés de -0.1em dans les grands titres.

**The Key Word Rule.** Un grand titre porte au plus un mot-clé coloré, balisé `em` sans italique : `primary-text` sur crème, `primary` sur encre.

## Layout

Conteneur centré de 1280px (`max-width`) avec une gouttière fluide (`gutter`). Le premier écran est une grille à deux colonnes égales : le texte à gauche, la boucle à droite qui prend toute sa colonne (jusqu'à 760px, ratio 740/880, unités de conteneur `cqw` pour les légendes). Les étapes suivantes sont centrées sur une colonne, le texte au-dessus (720px au plus) et le visuel en dessous, et sont reliées par une bande de tracé (150 à 200px de haut) qui alterne de sens et se termine sur la pastille numérotée de l'étape suivante. Une illustration à l'encre peut occuper le côté libre de cette bande.

Rythme vertical : `section-y` pour les étapes, plus généreux pour la bande du secret (clamp(72px, 10vw, 136px)). Écarts internes autour de `gap-sm` et `gap-md`.

Points de rupture : sous 900px, le premier écran passe sur une colonne et la boucle se centre à 560px au plus ; sous 640px, la navigation ne garde que l'appel « Télécharger », les sous-titres des légendes disparaissent, les boutons de store prennent toute la largeur, les annotations fléchées et les illustrations des tracés disparaissent, et le tableau du secret devient un sélecteur à deux onglets. La page de partage pousse ses deux téléphones hors des bords, sous les boutons.

## Elevation & Depth

Hybride, à dominante plate. Les surfaces de page sont à plat ; seuls les objets « posés » (téléphones, légendes de la boucle, tableau du secret, bouton « Ouvrir dans Wishy ») portent une ombre douce, décalée vers le bas, à étalement négatif et teintée encre. Aucune ombre dure ni décalée.

### Shadow Vocabulary
- **Téléphone** (`box-shadow: 0 18px 40px -12px rgba(44, 44, 44, 0.35)`): sous chaque cadre de téléphone.
- **Légende** (`box-shadow: 0 8px 22px -8px rgba(44, 44, 44, 0.35)`): sous les légendes blanches de la boucle.
- **Tableau** (`box-shadow: 0 30px 60px -20px rgba(0, 0, 0, 0.5)`): sous le tableau du secret, sur la bande encre.
- **Halo orange** (`box-shadow: 0 10px 24px -10px rgba(223, 115, 61, 0.7)`): sous « Ouvrir dans Wishy » uniquement.
- **Découpe** (`box-shadow: 0 0 0 6px` couleur `background`): anneau crème qui détache une pastille d'étape du tracé. Ce n'est pas une élévation.

### Named Rules
**The Resting Object Rule.** Une ombre signifie « objet posé sur la page ». Les sections, les panneaux de texte et la conversation n'en ont pas.

## Shapes

Des angles franchement arrondis, jamais vifs. Les contrôles (boutons, vignettes de wish, carte de lien) sont à `control` ; les légendes à `tag` ; les bulles à `bubble`, avec un coin côté locuteur ramené à `tail` ; les grands panneaux (conversation, tableau du secret) à `panel`. Les éléments d'interface secondaires (appel de navigation, sélecteur de langue, étiquettes, onglets) sont des pilules. Les pastilles d'étape et les emplacements de wish vides sont des cercles. Le cadre de téléphone a un rayon elliptique (`phone`) et une bordure encre profonde proportionnelle à sa largeur.

Les tirets ont un sens : une bordure en tirets veut dire « pas encore là » (store à venir, wish pas encore réservé). Le tracé, lui, est en points ronds (`stroke-dasharray: 0.1 15`, trait de 5) terminés par une flèche ouverte.

## Components

### Buttons
Pleins, sobres, à l'encre.
- **Shape:** arrondi `control`, hauteur minimale 52px.
- **Primary:** fond encre, texte blanc, `label`. Sert aux boutons de store publiés.
- **Hover / Focus:** passage au noir pur au survol (transition 0.2s ease) ; focus par un contour encre de 3px décalé de 3px, commun à tout le site.
- **Secondary:** fond transparent, bordure 2px `border`, qui passe à l'encre au survol.
- **Store « bientôt »:** transparent, bordure en tirets 2px `dash-soon`, sans lien ni curseur, mention « · bientôt » en 500 à 75 % d'opacité.
- **Ouvrir dans Wishy (page de partage):** le seul bouton orange : aplat `primary`, texte encre, 58px de haut, halo orange ; plus clair au survol.

### Chips
- **Étiquette de réservation:** pilule `primary`, texte encre, `tag`. Son pendant « libre » est un simple texte atténué sans fond.
- **Sélecteur de langue:** pilule transparente, bordure 2px `border`, encre au survol.

### Cards / Containers
- **Corner Style:** `panel` pour la conversation et le tableau du secret.
- **Background:** `sand` pour la conversation ; `surface` et `ink-raised` côte à côte pour le tableau du secret.
- **Shadow Strategy:** seul le tableau du secret porte une ombre (voir Elevation & Depth).
- **Border:** aucune ; les lignes de wish sont séparées par un filet de 1.5px à 25 % du brun de l'app.
- **Internal Padding:** 22px pour la conversation, clamp(20px, 3vw, 32px) pour chaque colonne du tableau.

### Navigation
Barre du haut sans fond : logo et nom « Wishy » en 800 à gauche, liens en 700 (soulignés au survol), sélecteur de langue, puis l'appel « Télécharger » en pilule encre. Sous 640px, seuls le logo, la langue et l'appel restent.

### Phone frame (signature)
L'écran de l'app (capture WebP 600×1304) dans un cadre `ink-deep` à rayon `phone`, avec l'ombre téléphone. Il est toujours incliné, entre -9 et +8 degrés, et se redresse (rotation 0, montée de 6px) au survol ou au focus quand il est un lien d'étape.

### Loop (signature)
Quatre téléphones de tailles décroissantes en orbite, reliés par quatre segments de tracé orange fléchés. Chaque téléphone est un lien vers sa section et porte une légende blanche collée sous son écran : pastille numérotée `primary`, nom d'étape en 800, sous-titre atténué. Au chargement, chaque segment se dessine puis sa légende apparaît, en cascade de 0.5s. Entre les sections, le tracé continue et se dessine quand il entre à l'écran, puis la pastille d'étape apparaît en grandissant.

### Chat bubbles
Bulle reçue blanche à gauche, bulle envoyée encre à droite, coin du locuteur à `tail`. La bulle envoyée peut contenir une carte de lien (fond encre plus clair, icône arrondie, titre en 700, sous-titre `on-ink-muted`).

## Do's and Don'ts

### Do:
- **Do** réserver l'orange au parcours (The Trail Rule) : tracé, pastilles, réservations, état actif, mot-clé d'un titre.
- **Do** mettre `primary-text` (#c8612b) pour tout mot orange sur crème, et `primary` (#f28c57) uniquement en aplat ou sur encre.
- **Do** montrer chaque capture de l'app dans le cadre de téléphone encre, incliné de quelques degrés.
- **Do** composer les titres en 800, approche -0.04em, interlignage sous 1, un seul mot-clé coloré.
- **Do** placer les illustrations à l'encre noire de l'app aux respirations (bandes de tracé, « Qui on est », appel final), à plein contraste, ou à 22 % d'opacité quand elles ne font qu'habiller la page de partage.
- **Do** garder les ombres pour les objets posés, toujours douces et à étalement négatif.
- **Do** soumettre tout mouvement à `prefers-reduced-motion: no-preference`, avec la courbe `cubic-bezier(0.16, 1, 0.3, 1)`.

### Don't:
- **Don't** utiliser l'orange pour un bouton de store, un lien, un fond de section ou une décoration sans rapport avec le parcours.
- **Don't** écrire du texte en `primary` (#f28c57) sur crème ou sur blanc.
- **Don't** charger une police, une image ou un script externe : la CSP du site (`default-src 'self'`) l'interdit.
- **Don't** introduire d'illustration « flat » douce et générique : toute nouvelle illustration reste à l'encre noire épaisse, avec au plus un accent orange.
- **Don't** poser une capture de l'app à plat, sans le cadre de téléphone.
- **Don't** revenir au gabarit titre à gauche, téléphone à droite, suivi de sections alternées texte et capture.
