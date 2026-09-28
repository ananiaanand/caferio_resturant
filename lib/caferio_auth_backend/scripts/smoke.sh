#!/usr/bin/env bash
# Live smoke test against your DEPLOYED project. Creates ONE throw-away user.
#   SUPABASE_URL=https://xxxx.supabase.co SUPABASE_ANON_KEY=eyJ... ./scripts/smoke.sh
set -euo pipefail
: "${SUPABASE_URL:?}"; : "${SUPABASE_ANON_KEY:?}"
U="smoke$(date +%s)"; P="Sunflower-Kettle-42"
call() { curl -sS -o /tmp/smoke.out -w "%{http_code}" -X POST "$SUPABASE_URL/functions/v1/$1" \
  -H "apikey: $SUPABASE_ANON_KEY" -H "Authorization: Bearer $SUPABASE_ANON_KEY" -H "Content-Type: application/json" -d "$2"; }
expect() { [ "$1" = "$2" ] && echo "PASS  $3" || { echo "FAIL  $3 (got $1, want $2): $(cat /tmp/smoke.out)"; exit 1; }; }

expect "$(call auth-register "{\"username\":\"$U\",\"password\":\"$P\",\"confirm_password\":\"$P\"}")" 201 "register"
grep -q refresh_token /tmp/smoke.out || { echo "FAIL  no session returned"; exit 1; }
expect "$(call auth-register "{\"username\":\"$(echo $U | tr a-z A-Z)\",\"password\":\"$P\",\"confirm_password\":\"$P\"}")" 409 "duplicate (other case) rejected"
expect "$(call auth-login "{\"username\":\"$U\",\"password\":\"$P\"}")" 200 "login"
TOKEN=$(python3 -c "import json;print(json.load(open('/tmp/smoke.out'))['session']['access_token'])")
expect "$(call auth-login "{\"username\":\"$U\",\"password\":\"wrong-Pass-1\"}")" 401 "wrong password"
expect "$(call auth-login "{\"username\":\"nobody$U\",\"password\":\"wrong-Pass-1\"}")" 401 "unknown user (same answer)"
# GoTrue's own signup endpoint must be closed:
code=$(curl -sS -o /tmp/smoke.out -w "%{http_code}" -X POST "$SUPABASE_URL/auth/v1/signup" -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" -d '{"email":"attacker@example.com","password":"Attacker-Pass-123"}')
[ "$code" != "200" ] && echo "PASS  direct GoTrue signup blocked ($code)" || { echo "FAIL  direct signup OPEN"; exit 1; }
# a normal user must not read someone else's profile nor set own role
code=$(curl -sS -o /tmp/smoke.out -w "%{http_code}" -X PATCH "$SUPABASE_URL/rest/v1/profiles?select=role" -H "apikey: $SUPABASE_ANON_KEY" \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"role":"admin"}')
[ "$code" != "200" ] && [ "$code" != "204" ] && echo "PASS  role self-update denied ($code)" || { echo "FAIL  role self-update allowed"; exit 1; }
echo "Done. Delete user '$U' in Dashboard -> Authentication -> Users."
