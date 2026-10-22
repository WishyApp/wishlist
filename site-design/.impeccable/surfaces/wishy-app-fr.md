---
version: 1
slug: "wishy-app-fr"
primary_target: "https://wishy-app.fr"
related_targets: ["https://wishy-app.fr/w"]
---

# Surface : page d'accueil wishy-app.fr

Mode : Persuade. Fichiers : `site/index.html` (accueil), la page de secours `/w/<id>` passe dans `site/share.html` (réécriture `/w/* /share 200` dans `site/_redirects`) et reprend le même système.

Visiteur : famille ou ami qui découvre Wishy. Action : installer l'app (boutons stores, « Bientôt » tant que le lien est vide). Preuve : vraies captures de l'app, mécanique du secret, illustrations à l'encre. Aucun avis ni chiffre inventé. FR/EN, aucune ressource externe (CSP).

Choix : « La boucle » (esquisse `.impeccable/mocks/decision/boucle.html`). Moment mémorable : la boucle orange qui relie les quatre écrans et revient au départ.

Décisions ouvertes : captures « même liste vue par toi / par tes amis » à refaire avec les comptes démo ; liens App Store / Play à renseigner au lancement.

## Direction contract

THESIS: Wishy est un cycle, pas une liste : tes envies, tes proches, le secret, le jour J, puis ça recommence. La page refuse le titre-à-gauche-téléphone-à-droite suivi de sections alternées texte/capture.

OWN-WORLD: fond crème #f7f6f0, encre #2c2c2c, blanc pour les surfaces, orange #f28c57 réservé au parcours (la boucle, l'étape active, rien d'autre). Plus Jakarta Sans 800 serrée en titres, 500 en texte. Écrans de l'app dans des téléphones noirs inclinés. Illustrations à l'encre noire aux respirations.

STORY: le visiteur comprend en un écran que Wishy sert des deux côtés du cadeau, voit que ses proches réservent sans que lui ne sache rien, puis installe l'app.

FIRST VIEWPORT: titre en 4 lignes à gauche (« Les cadeaux, entre amis. La surprise, pour toi. »), une phrase, boutons stores. À droite sur ~55 % de la largeur, quatre téléphones posés en boucle reliés par un tracé orange pointillé fléché, chaque étape numérotée et cliquable.

FORM: boucle, position 6 de ma liste, seed:24c757e015a37ea3. Interaction signature : au scroll, la boucle se dessine étape par étape ; chaque étape cliquée ouvre sa section, qui reprend son téléphone en grand.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
