# Tests de la base

Tests SQL lancés par `scripts/check_supabase_migrations.sh` (et donc par la CI des migrations), après l'application de toutes les migrations sur une base vide.

Conventions :
- un fichier par sujet (`write_policies.sql`, ...), exécuté en `postgres` avec `ON_ERROR_STOP` ;
- tout se passe dans une transaction annulée à la fin (`BEGIN` ... `ROLLBACK`) : chaque fichier crée ses propres données ;
- pour agir en utilisateur connecté : `SET LOCAL ROLE authenticated` puis `request.jwt.claim.sub` et `request.jwt.claims` via `set_config` ;
- un résultat inattendu lève une erreur (`RAISE EXCEPTION`), ce qui fait échouer le script.

En local (Docker requis) : `scripts/check_supabase_migrations.sh origin/main`.
