# Migrations Supabase

On développe les features directement sur la base Supabase de dev. Ce document fixe les règles pour que ce qui tourne sur dev et prod reste décrit par les fichiers de `supabase/migrations/`, et que la mise en prod se fasse en rejouant ces fichiers, sans rien refaire à la main.

Un seul dossier `supabase/` sert aux deux projets. En local, on travaille sur le projet dev, lié une fois depuis la racine du repo (`supabase link --project-ref qedynftuclpdisocgzuv`, cf. README). La prod n'est migrée que par la CD.

## Les règles

1. **Toute modif de schéma passe par un fichier de migration**, même en cours de dev. Pas de table, colonne, policy ou fonction créée depuis le dashboard ou collée dans le SQL editor sans fichier correspondant dans le repo.
2. **Chaque migration est idempotente** : elle peut être rejouée sur une base où tout ou partie de ses objets existent déjà, sans erreur et sans effet de bord.
3. **On ne modifie jamais une migration déjà mergée.** Une correction est une nouvelle migration.
4. **Après un déploiement, le diff doit être vide** (voir [Vérifier la dérive](#vérifier-la-dérive)).

La règle 1 est la plus importante. L'idempotence n'est qu'un filet : sans la règle 1, elle masque les objets créés à la main au lieu de les révéler.

## Workflow d'une feature

```bash
supabase migration new add_something      # crée supabase/migrations/<timestamp>_add_something.sql
# écrire la migration (idempotente)
supabase db push                          # applique sur dev (projet lié) les migrations pas encore enregistrées
```

Si on a appliqué la migration autrement (SQL editor pendant qu'on itère dessus), on l'enregistre comme faite pour que `db push` ne la rejoue pas :

```bash
supabase migration repair --status applied <timestamp>
```

Grâce à la règle 2, l'oubli de cette étape n'est pas grave : le `db push` suivant rejouera la migration sans rien casser.

Au merge de la PR, la CI applique la migration sur dev ; la prod la reçoit au tag suivant, avant les builds (cf. README, section CI/CD).

`db push` refuse une migration dont le timestamp est plus ancien que la dernière déjà appliquée (cas d'une branche longue mergée après une autre). Dans ce cas, `supabase db push --include-all`, après avoir vérifié la liste avec `supabase migration list`. La CI utilise toujours `--include-all`.

## Écrire une migration idempotente

| Objet | Écriture |
|---|---|
| Table | `CREATE TABLE IF NOT EXISTS` |
| Colonne | `ALTER TABLE ... ADD COLUMN IF NOT EXISTS` |
| Index | `CREATE INDEX IF NOT EXISTS` |
| Fonction, vue | `CREATE OR REPLACE` |
| Trigger | `CREATE OR REPLACE TRIGGER`, ou `DROP TRIGGER IF EXISTS` puis `CREATE TRIGGER` |
| Policy | `DROP POLICY IF EXISTS` puis `CREATE POLICY` (pas de `IF NOT EXISTS` en Postgres) |
| Contrainte, type enum, ajout à une publication | bloc `DO` qui teste le catalogue |
| Suppression | `DROP ... IF EXISTS` |

Contrainte :

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'wishs_name_max_length'
      AND conrelid = 'public.wishs'::regclass
  ) THEN
    ALTER TABLE public.wishs
      ADD CONSTRAINT wishs_name_max_length CHECK (char_length(name) <= 50);
  END IF;
END $$;
```

Table ajoutée au realtime :

```sql
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'ma_table'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE ONLY public.ma_table;
  END IF;
END $$;
```

### La limite de `IF NOT EXISTS`

`IF NOT EXISTS` vérifie qu'un objet porte ce nom, pas qu'il a le bon contenu. Si une table existe déjà sur dev avec une colonne de moins, la migration la saute et l'écart reste. Les objets réécrits à chaque passage (`CREATE OR REPLACE`, `DROP` puis `CREATE`) n'ont pas ce problème. Les tables, colonnes et contraintes l'ont : c'est la vérification de dérive qui le rattrape.

### Fonctions `SECURITY DEFINER`

Toujours fixer le `search_path` et qualifier les objets :

```sql
CREATE OR REPLACE FUNCTION public.ma_fonction()
  RETURNS void
  LANGUAGE plpgsql
  SECURITY DEFINER
  SET search_path = ''
AS $$
BEGIN
  DELETE FROM public.ma_table WHERE user_id = auth.uid();
END;
$$;

REVOKE EXECUTE ON FUNCTION public.ma_fonction() FROM PUBLIC, anon;
```

## Versions minimale et recommandée de l'app

La table `app_versions` (une ligne par plateforme, `ios` et `android`) dit à l'app quelle version elle doit au moins avoir (`min_version` : écran bloquant) et laquelle est recommandée (`recommended_version` : popup à l'ouverture, une fois par session). Ses valeurs sont des **données**, pas du schéma : on les change à la main avec un `UPDATE` dans le SQL editor, jamais dans une migration, et `check_drift` (qui ne compare que le schéma) ne les signale pas.

Une migration ne doit pas les relever : `cd.yml` migre la prod avant que les builds soient publiés, donc tous les utilisateurs de la version précédente seraient bloqués sans rien à télécharger.

Procédure, par plateforme, sur dev d'abord puis sur prod, et sur prod **seulement une fois la version téléchargeable dans ce store** :

```sql
UPDATE public.app_versions SET min_version = '0.3.0', updated_at = now() WHERE platform = 'ios';
SELECT * FROM public.get_app_version_policy('ios');
```

Toujours vérifier avec le `SELECT` : une coquille (`3.0.0` pour `0.3.0`) bloque tout le monde. Les formats invalides (`^[0-9]+(\.[0-9]+){0,2}$`) sont refusés par la base. Les builds antérieurs à 0.3.0 n'ont pas ce garde-fou : le premier relèvement utile est vers une version ≥ 0.3.0.

## Cartes de l'accueil

La table `home_cards` pilote les cartes de l'écran d'accueil. L'app la lit à l'ouverture et au tirer-pour-rafraîchir (policy : lignes actives seulement, une carte éditoriale seulement dans sa fenêtre `starts_at` / `ends_at`). Comme `app_versions`, elle se modifie à la main dans le SQL editor : aucun privilège d'écriture pour les clients.

Les lignes `computed` règlent des cartes dont la logique reste dans l'app (`enabled`, `priority`, `params`). La ligne `home_stack` (`settings`) règle la pile, ce n'est pas une carte. Les seeds sont posés avec `ON CONFLICT DO NOTHING` : une migration ne réécrit jamais un réglage, une modification se fait à la main.

Une carte éditoriale ponctuelle (occasion, annonce) se crée avec un `INSERT`, sans publier l'app. La contrainte `home_cards_editorial_complete` refuse une carte sans dates, sans titre fr et en, ou dont `ends_at` précède `starts_at`.

```sql
INSERT INTO public.home_cards
  (key, kind, priority, event_at, starts_at, ends_at, title, body, cta_label, cta_route)
VALUES (
  'new_feature_2026_12', 'editorial', 45,
  '2026-12-10 00:00+01', '2026-12-03 00:00+01', '2026-12-10 23:59+01',
  '{"fr": "Du nouveau dans Wishy", "en": "What''s new in Wishy"}',
  '{"fr": "Découvre les cartes de l''accueil.", "en": "Discover the home cards."}',
  '{"fr": "Voir", "en": "Take a look"}',
  '/'
);
SELECT key, enabled, starts_at, ends_at FROM public.home_cards WHERE key = 'new_feature_2026_12';
```

Dev d'abord, puis prod, et toujours vérifier avec le `SELECT`. Pour retirer une carte avant la fin, `UPDATE public.home_cards SET enabled = false WHERE key = '...'`.

## Tester en local

Docker doit tourner.

```bash
supabase db reset     # recrée la base locale et rejoue toutes les migrations
```

Ou, sans démarrer la stack locale : `scripts/check_supabase_migrations.sh origin/main` (base vide, idempotence, tests SQL).

Pour tester l'idempotence, rejouer ensuite la nouvelle migration une deuxième fois sur la base locale :

```bash
psql "postgresql://postgres:postgres@localhost:54322/postgres" -f supabase/migrations/<fichier>.sql
```

## Vérifier la dérive

```bash
supabase db diff --linked --schema public    # sur le projet lié
```

La CI le fait après chaque déploiement et chaque lundi, sur dev et prod.

La commande rejoue les migrations du repo dans une base temporaire, la compare au projet distant et affiche le SQL qui manque au repo pour décrire le distant. Elle ne modifie rien sur le projet distant.

- Sortie vide : le repo décrit bien le projet.
- Sortie non vide : quelque chose a été fait sans migration. On l'ajoute au repo dans une nouvelle migration idempotente, qu'on applique (ou qu'on marque `applied`) partout.

Le diff ne compare pas les grants. Après une migration qui en change, vérifier à la main dans `information_schema.routine_privileges` ou `information_schema.role_table_grants`.
