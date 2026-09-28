#!/usr/bin/env bash
# Rebuild database "caferio_test" in the state the ORIGINAL repo would produce.
# usage: LEGACY_DIR=/path/to/repo tests/build_legacy_db.sh
set -u
LEGACY_DIR="${LEGACY_DIR:?set LEGACY_DIR to the folder containing the old supabase_*.sql files}"
HERE="$(cd "$(dirname "$0")" && pwd)"
P="psql -X -q -v ON_ERROR_STOP=0"
su postgres -c "psql -X -q -c 'drop database if exists caferio_test' -c 'create database caferio_test'"
run() { echo ">> $1"; su postgres -c "$P -d caferio_test -f '$1'" 2>&1 | grep -E "ERROR|NOTICE: *ROLE|WARNING" ; }
run "$HERE/00_mock_supabase.sql"
# chronological order of the original files
for f in supabase_recommendations.sql supabase_schema.sql supabase_orders_fix.sql \
         supabase_recommendation_fix.sql supabase_phase1_setup.sql supabase_phase5_rls.sql \
         auth_migration.sql; do
  run "$LEGACY_DIR/$f"
done
run "$HERE/01_seed_legacy_users.sql"
