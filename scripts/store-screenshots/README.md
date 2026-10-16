# Visuels des stores (App Store / Google Play)

Outillage pour produire les visuels de fiche store de Wishy : seed de comptes de démo sur Supabase **dev**, captures de l'app sur simulateur iOS, puis composition (titre + sous-titre + cadre de téléphone) en HTML rendu par Chrome headless.

## Ce que ça produit

4 visuels × FR/EN, la bannière Google Play et les ressources créatives App Store, dans `out/` (ignoré par git) :

| Fichier | Taille |
| --- | --- |
| `out/apple-6.9in/<lang>/0N.png` | 1320×2868 (App Store 6,9") |
| `out/apple-6.3in/<lang>/0N.png` | 1206×2622 (App Store 6,3", l’emplacement demandé en premier) |
| `out/apple-ipad-13in/<lang>/0N.png` | 2064×2752 (App Store iPad 13", seulement si les captures iPad existent) |
| `out/google-play/<lang>/0N.png` | 1080×1920 (Google Play) |
| `out/google-play/<lang>/feature-graphic.png` | 1024×500 (bannière Google Play) |
| `out/apple-creative/<lang>/header.png` | 3840×1646 (ressource créative App Store : en-tête de la page produit) |
| `out/apple-creative/<lang>/search-results.png` | 3840×2560 (ressource créative : résultats de recherche) |
| `out/apple-creative/<lang>/universal.png` | 5244×2950 (ressource créative universelle 16:9 : évènements, mise en avant) |

## Prérequis

- Xcode avec un runtime iOS (simulateur iPhone 17 Pro Max)
- Google Chrome (ou `CHROME=/chemin/vers/chrome`)
- `cwebp` (`brew install webp`), `node` >= 18, Flutter
- `wishlist/env/.env.dev` déchiffré (transcrypt)

## Mise en place (une fois)

```sh
cd scripts/store-screenshots
npm install
./simulator.sh setup   # crée/démarre "Wishy Shots 17PM", barre de statut 9:41
```

Le simulateur est retrouvé par son nom, pas par son UDID.

## Étapes

```sh
export STORE_SHOTS_EMAIL_TEMPLATE='moi+wishy-demo-{key}@example.com'   # {key} = fr-main, fr-lea, ...

node seed.mjs fr && node seed.mjs en   # comptes, amis, wishlists, images, réservations
./run.sh fr-main                        # lance l'app (debug, dev) connectée au compte démo
./capture.sh fr                         # 5 captures dans raw/fr-*.png
./simulator.sh lang en                  # bascule le simulateur en anglais (reboot)
./run.sh en-main
./capture.sh en
./render.sh                             # compose tout dans out/
```

Pour l'iPad (l'app est compatible iPad, Apple veut donc de vraies captures iPad), on refait les mêmes étapes avec `SHOTS_DEVICE=ipad` devant `simulator.sh`, `run.sh` et `capture.sh`. Ça utilise le simulateur « Wishy Shots iPad 13 » et écrit dans `raw/ipad-<lang>-*.png`. `render.sh` produit ensuite les visuels iPad tout seul.

`seed.mjs` est idempotent : il supprime puis recrée les wishlists des comptes démo. Les identifiants sont dans `.accounts.json` (mode 600) et les ids/routes de capture dans `.ids.json`, tous deux ignorés par git. L'adresse e-mail réelle des comptes vient uniquement de la variable d'environnement, jamais du dépôt.

## Comment ça marche côté app

`wishlist/lib/app/dev/store_screenshot_mode.dart` n'est actif qu'en debug et avec `--dart-define=SHOTS_EMAIL=...` (passé par `run.sh`). Il connecte le compte démo, masque le bandeau debug, et lit une route dans un fichier (`.route.txt`) toutes les 500 ms pour naviguer. On n'utilise pas `simctl openurl` car iOS affiche une confirmation à chaque lien de scheme custom. `/?tab=2` ouvre l'onglet des réservations.

## Modifier les textes

Les titres et sous-titres sont dans l'objet `COPY` de `compose/shot.html` (visuels), de `compose/creative.html` (ressources créatives App Store) et dans `compose/feature.html` (bannière). Les polices et l'icône sont lues depuis `wishlist/fonts/` et `wishlist/assets/icon/`. Relancer `./render.sh` suffit, sans recapturer.

## Points d'attention

- Ressources créatives App Store (`compose/creative.html`) : les tailles et les zones de sécurité viennent des modèles Photoshop d'Apple ([bonnes pratiques](https://developer.apple.com/app-store/asset-best-practices/)). Le titre (et, pour l'en-tête et les résultats de recherche, les deux téléphones principaux) reste dans la zone de sécurité, les téléphones décoratifs peuvent être rognés selon l'appareil. `?debug=1` affiche la zone. Vérifier le rendu avec l'outil d'aperçu d'App Store Connect avant publication. Pas de prix promotionnel, d'URL ni de logo d'une autre plateforme dans ces visuels (règles Apple).

- Dev uniquement : `seed.mjs` refuse tout projet Supabase autre que le projet dev (`qedynftuclpdisocgzuv`).
- `raw/`, `out/`, `.image-cache/`, `.accounts.json`, `.ids.json` sont ignorés par git ; ne jamais committer d'identifiants.
- Les images des wishes sont téléchargées depuis Unsplash puis converties en webp dans `.image-cache/`.
- Sur le détail d'un wish, la barre de statut est claire sur fond clair (bug connu de l’app) : `compose/shot.html` la repeint à partir de la capture `home`.
