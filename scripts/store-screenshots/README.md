# Visuels des stores (App Store / Google Play)

Outillage pour produire les visuels de fiche store de Wishy : seed de comptes de démo sur Supabase **dev**, captures de l'app sur simulateur iOS, puis composition (titre + sous-titre + cadre de téléphone) en HTML rendu par Chrome headless.

## Ce que ça produit

4 visuels × FR/EN, dans `out/` (ignoré par git) :

| Fichier | Taille |
| --- | --- |
| `out/apple-6.9in/<lang>/0N.png` | 1320×2868 (App Store 6,9") |
| `out/google-play/<lang>/0N.png` | 1080×1920 (Google Play) |
| `out/google-play/<lang>/feature-graphic.png` | 1024×500 (bannière Google Play) |

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

`seed.mjs` est idempotent : il supprime puis recrée les wishlists des comptes démo. Les identifiants sont dans `.accounts.json` (mode 600) et les ids/routes de capture dans `.ids.json`, tous deux ignorés par git. L'adresse e-mail réelle des comptes vient uniquement de la variable d'environnement, jamais du dépôt.

## Comment ça marche côté app

`wishlist/lib/app/dev/store_screenshot_mode.dart` n'est actif qu'en debug et avec `--dart-define=SHOTS_EMAIL=...` (passé par `run.sh`). Il connecte le compte démo, masque le bandeau debug, et lit une route dans un fichier (`.route.txt`) toutes les 500 ms pour naviguer. On n'utilise pas `simctl openurl` car iOS affiche une confirmation à chaque lien de scheme custom. `/?tab=2` ouvre l'onglet des réservations.

## Modifier les textes

Les titres et sous-titres sont dans l'objet `COPY` de `compose/shot.html` (visuels) et dans `compose/feature.html` (bannière). Les polices et l'icône sont lues depuis `wishlist/fonts/` et `wishlist/assets/icon/`. Relancer `./render.sh` suffit, sans recapturer.

## Points d'attention

- Dev uniquement : `seed.mjs` refuse tout projet Supabase autre que le projet dev (`qedynftuclpdisocgzuv`).
- `raw/`, `out/`, `.image-cache/`, `.accounts.json`, `.ids.json` sont ignorés par git ; ne jamais committer d'identifiants.
- Les images des wishes sont téléchargées depuis Unsplash puis converties en webp dans `.image-cache/`.
- Sur le détail d'un wish, la barre de statut est claire sur fond clair (bug connu de l'app, audit F091) : `compose/shot.html` la repeint à partir de la capture `home`.
