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

2. **📥 Install Dependencies**

   ```bash
   flutter pub get
   ```

3. **▶️ Run the App**

   ```bash
   flutter run   # dev environment by default
   ```

4. **📱 Build for Production**

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

Every schema change goes through an idempotent migration file, applied to dev then to prod with `supabase db push`. Never edit the schema from the dashboard.

See [docs/supabase-migrations.md](docs/supabase-migrations.md) for the workflow, how to write idempotent migrations and how to check for drift.

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
git tag v0.2.3
git push origin v0.2.3
```

#### Destinations

| Plateforme | Track            |
| ---------- | ---------------- |
| Android    | Internal Testing |
| iOS        | TestFlight       |

Avant les builds, le job `migrate-database` applique les migrations Supabase en prod (cf. ci-dessous).

### 🗄️ Migrations Supabase

Le workflow `supabase.yml` :

| Déclencheur | Ce qu'il fait |
| ----------- | ------------- |
| PR qui touche une migration | Vérifie qu'aucune migration déjà mergée n'est modifiée, renommée ou supprimée, les rejoue sur une base vide en Postgres 17 (la version de dev et de prod), puis rejoue une 2e fois celles ajoutées par la PR et vérifie que les schémas `public` et `storage` ne changent pas (idempotence, ordre de `--include-all`) |
| Merge sur `main` | Contrôle de dérive, `db push` sur dev, puis nouveau contrôle de dérive |
| Chaque lundi | Contrôle de dérive sur dev et prod, migrations mergées mais pas encore déployées mises de côté |
| Tag `v*` (workflow CD) | Mêmes étapes sur prod, avant les builds, uniquement si le commit tagué est sur `main` |

Les jobs qui touchent aux projets Supabase sont inactifs tant que la variable de repo `SUPABASE_DEPLOY_ENABLED` ne vaut pas `true`. Avant chaque push, le job liste dans ses logs les migrations qu'il va appliquer, puis vérifie que le projet n'a pas dérivé (migrations en attente mises de côté) : un état de départ inconnu fait échouer le job sans rien appliquer.

Rattrapage d'un projet modifié hors migrations (objets créés à la main que de nouvelles migrations viennent capturer) : le contrôle d'avant push échoue forcément, puisque le projet contient déjà ce que les migrations en attente vont créer. Passer la variable de repo `SUPABASE_SKIP_PRE_PUSH_DRIFT_DEV` (dev) ou `SUPABASE_SKIP_PRE_PUSH_DRIFT_PROD` (prod) à `true` le temps du déploiement de rattrapage de cet environnement (le contrôle d'après push reste actif), puis la supprimer dès que le contrôle d'après push est vert.

Le contrôle de dérive n'affiche ni le diff ni le détail des erreurs de la CLI : en cas d'échec, lancer `supabase db diff --linked --schema public` en local. Workflow complet : [docs/supabase-migrations.md](docs/supabase-migrations.md).

Pour tester les migrations en local (Docker requis) :

```bash
scripts/check_supabase_migrations.sh origin/main
```

Limites du contrôle d'idempotence : il compare les schémas `public` et `storage`, pas les données ni le schéma `auth`. Une migration rejouée qui insère des lignes (un `INSERT` sans `ON CONFLICT`, par exemple) passe ce contrôle : c'est à la relecture de s'en assurer.

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
| `IOS_PROVISIONING_PROFILE_BASE64` | Provisioning profile encodé en base64 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID App Store Connect |
| `APP_STORE_CONNECT_API_KEY_ID` | Key ID App Store Connect |
| `APP_STORE_CONNECT_API_PRIVATE_KEY` | Contenu du fichier .p8 |
| `SUPABASE_URL` | URL Supabase production |
| `SUPABASE_ANON_KEY` | Clé anonyme Supabase production |
| `SUPABASE_ACCESS_TOKEN` | Token Supabase limité aux projets dev et prod (Project Settings : read ; Database, Migrations : read & write ; Connection Pooling : read) |
| `SUPABASE_DB_PASSWORD_DEV` | Optionnel : mot de passe de la base dev, si la CLI ne peut pas utiliser son rôle de connexion temporaire |
| `SUPABASE_DB_PASSWORD_PROD` | Optionnel : idem pour la prod |

---

## 📧 Contact

If you have any questions, feel free to reach out via [wishyapp.contact@gmail.com](mailto:wishyapp.contact@gmail.com).

## Happy gifting! 🎁✨