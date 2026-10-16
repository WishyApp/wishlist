# Tests de la base

Tests SQL lancés par `scripts/check_supabase_migrations.sh` (et donc par la CI des migrations), après l'application de toutes les migrations sur une base vide.

Conventions :
- un fichier par sujet (`write_policies.sql`, ...), exécuté en `postgres` avec `ON_ERROR_STOP` ;
- tout se passe dans une transaction annulée à la fin (`BEGIN` ... `ROLLBACK`) : chaque fichier crée ses propres données. Le script compare les schémas `public`, `auth` et `storage` (données comprises) avant et après chaque fichier, et échoue si quelque chose est resté ;
- pour agir en utilisateur connecté : `SET LOCAL ROLE authenticated` puis `request.jwt.claim.sub` et `request.jwt.claims` via `set_config` ;
- les fonctions créées par `postgres` (dont les helpers `pg_temp`) n'ont pas `EXECUTE` pour `PUBLIC` : un helper appelé après un changement de rôle a besoin de `GRANT EXECUTE ... TO PUBLIC` (ou de `ALTER DEFAULT PRIVILEGES FOR ROLE postgres GRANT EXECUTE ON FUNCTIONS TO PUBLIC` en début de transaction, annulé avec le reste) ;
- un résultat inattendu lève une erreur (`RAISE EXCEPTION`), ce qui fait échouer le script.

En local (Docker requis) : `scripts/check_supabase_migrations.sh origin/main`.
