#!/usr/bin/env bash
# Fail if the public schema of the linked project differs from the local
# migrations.
#
# Usage: check_drift.sh ENVIRONMENT [PENDING_LIST]
#   ENVIRONMENT: name of the linked project (dev or prod), used in messages.
#   PENDING_LIST: file holding the names of the migrations not applied on the
#   project yet, one per line. They are moved aside during the comparison, so
#   that the project is compared with the migrations it already has.
#
# The repository is public: never print the diff, only whether there is one.
set -euo pipefail

environment="$1"
pending_list="${2:-}"
migrations_dir="supabase/migrations"

aside="$(mktemp -d)"
drift="$(mktemp)"
log="$(mktemp)"
restore() {
  if compgen -G "$aside/*.sql" >/dev/null; then
    mv "$aside"/*.sql "$migrations_dir"/
  fi
  rm -rf "$aside" "$drift" "$log"
}
trap restore EXIT

if [[ -n "$pending_list" && -s "$pending_list" ]]; then
  while IFS= read -r name; do
    mv "$migrations_dir/$name" "$aside/"
  done <"$pending_list"
fi

# The CLI error may quote SQL or object names of the remote project: only
# print the exit code.
if supabase db diff --linked --schema public -o "$drift" >/dev/null 2>"$log"; then
  status=0
else
  status=$?
fi
if [[ $status -ne 0 ]]; then
  echo "::error::supabase db diff failed on $environment (exit code $status). Run 'supabase db diff --linked --schema public' locally for details."
  exit 1
fi

if [[ -s "$drift" ]]; then
  echo "::error::Schema drift on $environment: the remote schema differs from the migrations. Run 'supabase db diff --linked --schema public' locally (see docs/supabase-migrations.md)."
  exit 1
fi

echo "No drift on $environment"
