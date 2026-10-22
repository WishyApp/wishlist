# 🎁 Wishy App

Welcome to the Wishy App! This Flutter application is designed to help you effortlessly create, manage, and share your wishlists with friends and family, making gift-giving occasions more organized and enjoyable.

## ✨ Features

* **📝 Create a Wishlist**: Create a wishlist, enter a title and details, and start adding your desired items.
* **📤 Share Your Wishlist**: Use the share functionality to send your wishlist via email, messaging apps, or directly within the app.
* **🔧 Manage Wishlists**: View and edit your existing wishlists, track reserved items, and update details as needed.
* **🤝 Collaborate**: Invite others to view or contribute to your wishlists. See what gifts have been reserved and what’s still available.

---

## 🚀 Getting Started

### ✅ Prerequisites

* **🛠 Flutter**: Ensure you have Flutter installed on your machine. You can follow the installation guide [here](https://flutter.dev/docs/get-started/install). The project uses the exact version set in `wishlist/pubspec.yaml` (`environment: flutter:`, currently 3.41.4), the one CI and CD install; `flutter pub get` fails with an older one.
* **🎯 Dart**: Flutter requires Dart, which is included with the Flutter SDK.

### 📦 Installation

1. **🔗 Clone the Repository**

   ```bash
   git clone git@github.com:Raphael-Mssn/wishlist.git
   cd wishlist
   ```

2. **🔐 Decrypt the Secrets**

   `wishlist/env/.env.dev`, `wishlist/env/.env.prod` and `wishlist/android/key.properties` are encrypted in git with [transcrypt](https://github.com/elasticdog/transcrypt) (see `.gitattributes`). Ask a maintainer for the password, then:

   ```bash
   transcrypt -p '<password>'
   ```

   Without it these files stay encrypted and the app fails to load its config at startup.

3. **📥 Install Dependencies**

   The Flutter project lives in the `wishlist/` subfolder of the repository: run the commands below from there.

   ```bash
   cd wishlist
   flutter pub get   # also generates the localization files (`generate: true`)
   ```

4. **⚙️ Generate the Code**

   Generated files (Freezed, Riverpod, routes, assets) are committed and CI fails if they are out of date: regenerate them after `pub get` and after any change to an annotated class.

   ```bash
   dart run build_runner build --delete-conflicting-outputs
   dart format lib   # CI compares the generated files after formatting them
   ```

5. **▶️ Run the App**

   ```bash
   flutter run   # dev environment by default
   ```

   The environment comes from `--dart-define=APP_ENV=<env>`; accepted values are `dev` (default) and `prod` (`lib/app/config/environment.dart`, `environment_service.dart`).

6. **📱 Build for Production**

   ```bash
   flutter build appbundle --dart-define=APP_ENV=prod   # For Android
   flutter build ios --dart-define=APP_ENV=prod         # For iOS
   ```

---

## 🧱 Supabase Setup (for developers)

The app uses **Supabase** as its backend for authentication, database, and storage.
Each environment (`dev` and `prod`) is managed separately to keep development safe and clean.

### ⚙️ Requirements

* **Supabase CLI**
  Install via Homebrew or npm:

  ```bash
  brew install supabase/tap/supabase
  # or
  npm install -g supabase
  ```

* **Docker Desktop** (required for migrations)

  ```bash
  brew install --cask docker
  open -a "Docker"
  ```

---

### 🔐 Login to Supabase

Each developer must use their own Supabase account and Personal Access Token (PAT).

1. Generate a new token at [https://supabase.com/account/tokens](https://supabase.com/account/tokens)
2. Log in to the CLI:

   ```bash
   supabase login --token "<YOUR_PERSONAL_TOKEN>"
   ```

---

### 🗂 Project Linking

A single `supabase/` folder (migrations, config) describes both Supabase environments:

| Environment | Supabase Project | Project Ref            | Postgres |
| ----------- | ---------------- | ---------------------- | -------- |
| Development | wishlist-dev     | `qedynftuclpdisocgzuv` | 17       |
| Production  | wishy-prod       | `cbcrtjggsmtwvqljzbnl` | 17       |

Locally, link the dev project, from the repository root:

From the repository root:

```bash
supabase link --project-ref qedynftuclpdisocgzuv
```

The CLI works on the linked project. Prod is migrated by the CD only (see below): do not link it to run `db push` from your machine.

Verify with:

```bash
supabase projects list
```

---

### 🔄 Schema changes

Every schema change goes through an idempotent migration file, applied to dev with `supabase db push` (the linked project) and to prod by the CD at the next tag. Never run `db push` on prod from your machine, and never edit the schema from the dashboard.

See [docs/supabase-migrations.md](docs/supabase-migrations.md) for the workflow, how to write idempotent migrations and how to check for drift.

---

## 🔗 Liens de partage (wishy-app.fr)

Une wishlist se partage avec un lien `https://wishy-app.fr/w/<id>`, cliquable dans toutes les messageries.

- **App installée** : le lien ouvre directement l'app (App Links sur Android, Universal Links sur iOS).
- **Sinon** : le navigateur affiche la page de secours [`site/share.html`](site/share.html), avec un bouton qui ouvre l'app (sur iOS, l'App Store en premier et « Ouvrir dans Wishy » en lien secondaire) et les liens vers les stores (ou vers l'accueil tant qu'ils ne sont pas renseignés). Elle n'affiche aucune donnée de la liste.

Dans l'app, `DeepLinkNavigator` (`lib/shared/infra/deep_link_navigator.dart`) écoute les liens via `app_links` et ouvre l'écran correspondant (`DeeplinkConfig.locationFromUri`). Le deep linking intégré de Flutter est désactivé (`flutter_deeplinking_enabled` / `FlutterDeepLinkingEnabled` à `false`), comme le demande `app_links`, déjà utilisé par Supabase pour les liens d'auth.

### Site (Cloudflare Pages)

Le dossier `site/` est servi tel quel par Cloudflare Pages, sans étape de build, et redéployé à chaque push sur `main` :

| Réglage Cloudflare Pages | Valeur |
| ------------------------ | ------ |
| Commande de build | *(vide)* |
| Répertoire de sortie | `site` |
| Domaine personnalisé | `wishy-app.fr` |

- `site/index.html` est la page d'accueil de `wishy-app.fr`. `site/_redirects` sert `share.html` pour `/w/<id>` (cible `/share` sans extension, Cloudflare Pages redirigeant `/share.html` vers `/share`) ; `site/` n'a pas de `404.html`, donc les autres chemins inconnus retombent sur l'accueil. Garder des chemins absolus (`/style.css`) dans les pages.
- `site/confidentialite.html` et `site/conditions.html` (servies en `/confidentialite` et `/conditions`) reprennent la politique de confidentialité et les conditions d'utilisation, jusqu'ici sur Notion. Les modifier ici, puis mettre à jour la date « Dernière mise à jour ». Tant que l'app (`settings_screen.dart`) et les fiches des stores pointent encore vers Notion, garder les deux copies synchronisées.
- Les liens des stores se règlent dans `site/stores.js`, partagé par les deux pages : tant qu'un lien vaut `null`, l'accueil affiche « bientôt » à sa place et la page de secours affiche « Découvrir Wishy » (lien vers l'accueil) dès qu'un store utile au visiteur manque (Google Play sur Android, App Store sur iOS, l'un ou l'autre sur ordinateur, même si l'autre bouton est affiché) ; sur Android, le lien `intent://` retombe alors sur l'accueil au lieu du Play Store. Sur iOS, la page de secours propose l'App Store en bouton principal et « Ouvrir dans Wishy » en lien secondaire, `wishy://` n'ayant pas de repli sans l'app.
- Le design du site vit dans `site-design/`, hors du dossier publié : contexte produit (`PRODUCT.md`), contrat de direction (`DESIGN.md`) et état d'[Impeccable](https://github.com/pbakaus/impeccable) (`.impeccable/`). Le skill lui-même n'est pas versionné : pour retravailler le site, installer Impeccable 4.7.0 (skill et agents) dans `site-design/.claude/`, ignoré par git, puis lancer Claude Code depuis `site-design/`.
- `site/.well-known/assetlinks.json` (Android) et `site/.well-known/apple-app-site-association` (iOS) autorisent l'app à ouvrir les liens du domaine. Le type `application/json` est forcé par `site/_headers`.
- Le domaine est repris à l'identique dans `DeeplinkConfig.webHost`, l'`intent-filter` https de `AndroidManifest.xml` et `Runner.entitlements` (`applinks:wishy-app.fr`).

Les empreintes SHA-256 d'`assetlinks.json` sont celles de la clé de signature Google Play et de la clé d'importation (Play Console → Intégrité de l'application). Pour tester App Links avec une build de debug, ajouter l'empreinte de la clé de debug (`keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`).

Vérifier l'état des liens sur un téléphone :

```bash
# Android : "verified" attendu pour wishy-app.fr
adb shell pm get-app-links com.raphtang.wishy
# Android : relancer la vérification après une mise à jour d'assetlinks.json
adb shell pm verify-app-links --re-verify com.raphtang.wishy
```

Sur iOS, Apple lit le fichier via son CDN, avec parfois plusieurs heures de retard après une modification. Pour tester, toucher le lien depuis Notes ou Messages : le coller dans la barre d'adresse de Safari n'ouvre jamais l'app.

---

## 🚀 CI/CD

Le projet utilise **GitHub Actions** pour l'intégration et le déploiement continus.

### ✅ Intégration Continue (CI)

La CI se déclenche automatiquement sur :
- Push sur `main`
- Ouverture/mise à jour d'une Pull Request

Elle exécute :
- `dart format` - vérification du formatage
- `flutter analyze` - analyse statique du code
- `build_runner` - génération de code (Freezed, Riverpod, etc.)
- `flutter test` - tests unitaires et golden tests

### 📦 Déploiement Continu (CD)

La CD se déclenche lors du push d'un **tag de version** (`v*`).

#### Déclencher un déploiement

```bash
git tag vX.Y.Z
git push origin vX.Y.Z
```

#### Destinations

| Plateforme | Track            |
| ---------- | ---------------- |
| Android    | Internal Testing |
| iOS        | TestFlight       |

Avant les builds, le job `migrate-database` applique les migrations Supabase et déploie les Edge Functions en prod (cf. ci-dessous).

### 🗄️ Migrations Supabase

Le workflow `supabase.yml` :

| Déclencheur | Ce qu'il fait |
| ----------- | ------------- |
| PR qui touche une migration | Vérifie qu'aucune migration déjà mergée n'est modifiée, renommée ou supprimée, les rejoue sur une base vide en Postgres 17 (la version de dev et de prod), puis rejoue une 2e fois celles ajoutées par la PR et vérifie que les schémas `public` et `storage` ne changent pas (idempotence, ordre de `--include-all`). Il les rejoue aussi avec la CLI sur la version exacte de Postgres de dev et de prod, et échoue si `supabase-dev/` ou `supabase-prod/` contient encore des fichiers. Ces vérifications tournent aussi à chaque push sur `main`, et le déploiement sur dev attend le rejeu en 17.11 |
| PR ou push qui touche `supabase/functions/**` | Job `functions` : `deno check` de chaque `index.ts` et `deno test --allow-net supabase/functions/` avec Deno 2.1.4 (celui de l'Edge Runtime). Le déploiement sur dev l'attend |
| Merge sur `main` | Contrôle de dérive, `db push` sur dev, nouveau contrôle de dérive, puis déploiement des Edge Functions sur dev |
| Chaque lundi | Contrôle de dérive sur dev et prod, migrations mergées mais pas encore déployées mises de côté |
| Tag `v*` (workflow CD) | Mêmes étapes (migrations puis Edge Functions) sur prod, avant les builds, uniquement si le commit tagué est sur `main` |

Les jobs qui touchent aux projets Supabase sont inactifs tant que la variable de repo `SUPABASE_DEPLOY_ENABLED` ne vaut pas `true`. Avant chaque push, le job liste dans ses logs les migrations qu'il va appliquer, puis vérifie que le projet n'a pas dérivé (migrations en attente mises de côté) : un état de départ inconnu fait échouer le job sans rien appliquer.

Rattrapage d'un projet modifié hors migrations (objets créés à la main que de nouvelles migrations viennent capturer) : le contrôle d'avant push échoue forcément, puisque le projet contient déjà ce que les migrations en attente vont créer. Passer la variable de repo `SUPABASE_SKIP_PRE_PUSH_DRIFT_DEV` (dev) ou `SUPABASE_SKIP_PRE_PUSH_DRIFT_PROD` (prod) à `true` le temps du déploiement de rattrapage de cet environnement (le contrôle d'après push reste actif), puis la supprimer dès que le contrôle d'après push est vert.

Le contrôle de dérive n'affiche ni le diff ni le détail des erreurs de la CLI : en cas d'échec, lancer `supabase db diff --linked --schema public` en local. Workflow complet : [docs/supabase-migrations.md](docs/supabase-migrations.md).

Pour tester les migrations en local (Docker requis) :

```bash
scripts/check_supabase_migrations.sh origin/main
```

Limites du contrôle d'idempotence : il compare les schémas `public` et `storage`, pas les données ni le schéma `auth`. Une migration rejouée qui insère des lignes (un `INSERT` sans `ON CONFLICT`, par exemple) passe ce contrôle : c'est à la relecture de s'en assurer.

### ⚡ Edge Functions Supabase

Les Edge Functions vivent dans `supabase/functions/<nom>/index.ts` et sont déployées par la CI, jamais à la main : dev à chaque merge sur `main` (job `deploy-dev`), prod à chaque tag `v*` (job `migrate-database`, avant les builds), mais seulement si ce tag est le dernier tag `v*` de `main` ; un lancement manuel du workflow CD ne déploie les fonctions que depuis la pointe de `main`. Dans les autres cas (relance d'une ancienne release, tag sur un ancien commit de `main`, run manuel sur un commit en retard), les fonctions sont ignorées avec un `::warning::` pour ne pas redéployer un ancien code en prod, alors que les migrations et les builds tournent normalement. L'action `supabase-deploy` lance `supabase functions deploy --use-api --project-ref <ref>` (toutes les fonctions du dossier, bundle côté serveur, sans Docker) après les migrations et le contrôle de dérive, y compris quand aucune migration n'est en attente. Le contrôle de dérive du lundi ne déploie rien. Le token `SUPABASE_ACCESS_TOKEN` doit donc aussi avoir la permission Edge Functions en read & write (déploiement et mise à jour des fonctions, cf. secrets ci-dessous) ; Edge Function Secrets n'est pas nécessaire.

* `verify_jwt` se règle fonction par fonction dans `supabase/config.toml` (`[functions.<nom>]`), le déploiement ne passe jamais `--no-verify-jwt`. Toute nouvelle fonction y déclare sa section.
* Une fonction supprimée du dépôt n'est pas supprimée des projets : la retirer à la main avec `supabase functions delete <nom> --project-ref <ref>` (dev et prod).

#### Secrets GitHub requis

| Secret | Description |
| ------ | ----------- |
| `ANDROID_KEYSTORE_BASE64` | Keystore Android encodé en base64 |
| `ANDROID_KEYSTORE_PASSWORD` | Mot de passe du keystore |
| `ANDROID_KEY_ALIAS` | Alias de la clé |
| `ANDROID_KEY_PASSWORD` | Mot de passe de la clé |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | JSON du service account Google Play |
| `IOS_P12_BASE64` | Certificat Apple Distribution encodé en base64 |
| `IOS_P12_PASSWORD` | Mot de passe du certificat |
| `IOS_PROVISIONING_PROFILE_BASE64` | Provisioning profile de l'app (Runner) encodé en base64 |
| `IOS_SHARE_EXTENSION_PROFILE_BASE64` | Provisioning profile de la Share Extension encodé en base64 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID App Store Connect |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID App Store Connect |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | Contenu du fichier .p8 |
| `SUPABASE_URL` | URL Supabase production |
| `SUPABASE_ANON_KEY` | Clé anonyme Supabase production |
| `SUPABASE_ACCESS_TOKEN` | Token Supabase limité aux projets dev et prod (Project Settings : read ; Database, Migrations, Edge Functions : read & write ; Connection Pooling : read) |
| `SUPABASE_DB_PASSWORD_DEV` | Optionnel : mot de passe de la base dev, si la CLI ne peut pas utiliser son rôle de connexion temporaire |
| `SUPABASE_DB_PASSWORD_PROD` | Optionnel : idem pour la prod |

---

## 📧 Contact

If you have any questions, feel free to reach out via [wishyapp.contact@gmail.com](mailto:wishyapp.contact@gmail.com).

## Happy gifting! 🎁✨