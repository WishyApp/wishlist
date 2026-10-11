#!/usr/bin/env bash
# Validate Supabase migrations on a throwaway Postgres container:
#   1. migrations merged before BASE_REF are not modified, renamed or deleted
#   2. every migration applies, in order, on an empty database
#   3. migrations added since BASE_REF can be applied a second time, after
#      all the others, without changing the public and storage schemas (data
#      and the auth schema are not compared). This is the
#      order 'db push --include-all' uses for a migration merged late.
#   4. the SQL tests in supabase-tests/ pass. Each file runs as postgres,
#      raises an error on an unexpected result and leaves the public, auth and
#      storage schemas, data included, as it found them
#      (see supabase-tests/README.md).
#
# Usage: scripts/check_supabase_migrations.sh [BASE_REF]
# Requires Docker. See docs/supabase-migrations.md.
set -euo pipefail

BASE_REF="${1:-}"
IMAGE="${SUPABASE_POSTGRES_IMAGE:-public.ecr.aws/supabase/postgres:17.6.1.043}"
CONTAINER="check-supabase-migrations-$$"
MIGRATIONS_DIR="supabase/migrations"
# Where migrations lived before supabase-dev/ and supabase-prod/ were merged
# into supabase/, for a BASE_REF older than that.
LEGACY_DIR="supabase-prod/supabase/migrations"
TESTS_DIR="supabase-tests"

cd "$(git rev-parse --show-toplevel)"

# Migrations are compared by file name, not by path, so that moving the
# folder does not count as deleting and re-adding every migration.
added=""
if [[ -n "$BASE_REF" ]]; then
  echo "==> Checking that merged migrations are unchanged since $BASE_REF"
  merge_base="$(git merge-base "$BASE_REF" HEAD)"
  base_dir="$MIGRATIONS_DIR"
  if ! git cat-file -e "$merge_base:$MIGRATIONS_DIR" 2>/dev/null; then
    base_dir="$LEGACY_DIR"
  fi
  base_names=""
  changed=""
  while IFS= read -r path; do
    name="$(basename "$path")"
    base_names+="$name"$'\n'
    if [[ ! -f "$MIGRATIONS_DIR/$name" ]]; then
      changed+="deleted or renamed: $name"$'\n'
    elif [[ "$(git rev-parse "$merge_base:$path")" != "$(git hash-object "$MIGRATIONS_DIR/$name")" ]]; then
      changed+="modified: $name"$'\n'
    fi
  done < <(git ls-tree --name-only "$merge_base" -- "$base_dir/" | grep '\.sql$')
  if [[ -n "$changed" ]]; then
    printf '%s' "$changed"
    echo "::error::Merged migrations must not be modified, add a new migration instead"
    exit 1
  fi
  for file in "$MIGRATIONS_DIR"/*.sql; do
    if ! grep -qxF "$(basename "$file")" <<<"$base_names"; then
      added+="$file"$'\n'
    fi
  done
fi

ERR_FILE="$(mktemp)"
SCHEMA_BEFORE="$(mktemp)"
SCHEMA_AFTER="$(mktemp)"
STATE_BEFORE="$(mktemp)"
STATE_AFTER="$(mktemp)"
cleanup() {
  docker rm -f "$CONTAINER" >/dev/null 2>&1 || true
  rm -f "$ERR_FILE" "$SCHEMA_BEFORE" "$SCHEMA_AFTER" "$STATE_BEFORE" "$STATE_AFTER"
}
trap cleanup EXIT

# The default registry, ECR Public, limits anonymous pulls ("toomanyrequests:
# Rate exceeded", or "Data limit exceeded" once the quota of the runner IPs is
# used up). Each attempt tries ECR Public, then the same image on Docker Hub,
# tagged back to $IMAGE; attempts are retried with a growing delay.
pull_candidates=("$IMAGE")
if [[ "$IMAGE" == public.ecr.aws/* ]]; then
  pull_candidates+=("docker.io/${IMAGE#public.ecr.aws/}")
fi
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> Pulling $IMAGE"
  pulled=false
  for attempt in 1 2 3 4 5; do
    for candidate in "${pull_candidates[@]}"; do
      if docker pull -q "$candidate" >/dev/null; then
        [[ "$candidate" == "$IMAGE" ]] || docker tag "$candidate" "$IMAGE"
        echo "    pulled from $candidate"
        pulled=true
        break 2
      fi
    done
    if [[ "$attempt" -lt 5 ]]; then
      echo "    pull failed (attempt $attempt/5), retrying in $((attempt * 15))s"
      sleep $((attempt * 15))
    fi
  done
  if [[ "$pulled" != true ]]; then
    echo "::error::Unable to pull $IMAGE"
    exit 1
  fi
fi

echo "==> Starting $IMAGE"
docker run -d --name "$CONTAINER" -e POSTGRES_PASSWORD=postgres "$IMAGE" >/dev/null

psql_exec() {
  docker exec -i -e PGPASSWORD=postgres "$CONTAINER" \
    psql -h 127.0.0.1 -U postgres -d postgres -v ON_ERROR_STOP=1 -q "$@"
}

# The init scripts run on a socket-only server; wait for the TCP listener.
for _ in $(seq 1 60); do
  if psql_exec -tAc 'select 1' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done
psql_exec -tAc 'select 1' >/dev/null

# Recent pg_dump versions wrap the output in \restrict / \unrestrict lines
# holding a random key: drop them so that two dumps of a schema compare equal.
dump_schema() {
  docker exec -e PGPASSWORD=postgres "$CONTAINER" \
    pg_dump -h 127.0.0.1 -U postgres -d postgres --schema-only --schema=public --schema=storage |
    grep -vE '^\\(un)?restrict '
}

# Schema and data touched by the tests. Sequences are left out: nextval() is
# not undone by a rollback.
dump_state() {
  docker exec -e PGPASSWORD=postgres "$CONTAINER" \
    pg_dump -h 127.0.0.1 -U postgres -d postgres --schema=public --schema=auth --schema=storage |
    grep -vE '^\\(un)?restrict |^SELECT pg_catalog\.setval\('
}

apply() {
  local file="$1"
  echo "    $(basename "$file")"
  if ! psql_exec -f - <"$file" >/dev/null 2>"$ERR_FILE"; then
    cat "$ERR_FILE"
    echo "::error file=$file::Migration failed"
    exit 1
  fi
}

echo "==> Applying all migrations"
for file in "$MIGRATIONS_DIR"/*.sql; do
  apply "$file"
done

if [[ -n "$added" ]]; then
  echo "==> Re-applying migrations added since $BASE_REF"
  dump_schema >"$SCHEMA_BEFORE"
  while IFS= read -r file; do
    [[ -n "$file" ]] && apply "$file"
  done <<<"$added"
  dump_schema >"$SCHEMA_AFTER"
  # The schema is rebuilt from the repository only, printing it is safe.
  if ! diff -u "$SCHEMA_BEFORE" "$SCHEMA_AFTER"; then
    echo "::error::Re-applying migrations added since $BASE_REF changes the schema"
    exit 1
  fi
fi

if compgen -G "$TESTS_DIR/*.sql" >/dev/null; then
  echo "==> Running database tests"
  dump_state >"$STATE_BEFORE"
  for file in "$TESTS_DIR"/*.sql; do
    echo "    $(basename "$file")"
    if ! psql_exec -f - <"$file" >"$ERR_FILE" 2>&1; then
      cat "$ERR_FILE"
      echo "::error file=$file::Database test failed"
      exit 1
    fi
    # A test must not leak into the next ones (missing ROLLBACK, COMMIT...).
    # Only test fixtures can show up in the diff.
    dump_state >"$STATE_AFTER"
    if ! diff -u "$STATE_BEFORE" "$STATE_AFTER"; then
      echo "::error file=$file::Database test left changes, run it in BEGIN ... ROLLBACK"
      exit 1
    fi
  done
fi

echo "==> OK"
