#!/bin/sh
# Runs the migration and rules_test.sql on a throwaway database.
# Usage: supabase/tests/run.sh "<psql connection options>"   e.g.  "-h /tmp/pg -p 54329 -U postgres"
set -e
here=$(dirname "$0")
psql $1 -q -c "drop database if exists mnpr_test" -c "create database mnpr_test"
psql $1 -d mnpr_test -q -v ON_ERROR_STOP=1 -f "$here/supabase_stub.sql" -f "$here/../migrations/20261119000000_init.sql"
psql $1 -d mnpr_test -q -v ON_ERROR_STOP=1 -f "$here/rules_test.sql"
