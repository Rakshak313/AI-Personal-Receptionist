#!/bin/bash
# ============================================================================
#  test_repair_pjsip.sh — validates repair_pjsip.sh WITHOUT touching the real
#  Asterisk config.  It:
#    1. syntax-checks repair_pjsip.sh (bash -n, CRLF-safe)
#    2. extracts the embedded python (auth/aor recovery/creation logic)
#    3. Scenario R1: current file has ONLY the [1001] endpoint; a backup file
#       contains the original [1001] auth (password=original-secret) and aor
#       -> auth/aor must be recovered VERBATIM from the backup
#    4. Scenario R2: no backup file exists
#       -> auth/aor must be created from the expected configuration
#          (username=1001 / password=AIReceptionist@2026 / max_contacts=1)
#    In both scenarios the transport and endpoint must be untouched.
# ============================================================================
set -u
SRC=/mnt/d/AI-Personal-Receptionist/repair_pjsip.sh
TMP=/tmp

fail() { echo "FAIL: $1"; exit 1; }

# 1) Syntax check (strip any CR first for safety)
sed 's/\r$//' "$SRC" > "$TMP/repair.sh"
bash -n "$TMP/repair.sh" && echo "PASS: bash -n on repair_pjsip.sh" || fail "repair_pjsip.sh has a syntax error"

# 2) Extract the embedded python block from the heredoc
awk '/<<.PYEOF/{f=1; next} f && /^PYEOF/{f=0} f' "$TMP/repair.sh" > "$TMP/repair_pj.py"
[ -s "$TMP/repair_pj.py" ] || fail "could not extract python block"

echo
echo "================ SCENARIO R1: recover auth/aor from backup ================"
cat > "$TMP/r1_current.conf" <<'EOF'
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[1001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=1001
aors=1001
EOF
cat > "$TMP/r1_backup.conf" <<'EOF'
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[1001]
type=endpoint
context=from-internal
auth=1001
aors=1001

[1001]
type=auth
auth_type=userpass
username=1001
password=original-secret

[1001]
type=aor
max_contacts=1
EOF

python3 "$TMP/repair_pj.py" "$TMP/r1_current.conf" "$TMP/r1_backup.conf"
echo "--- resulting file:"
cat "$TMP/r1_current.conf"

[ "$(grep -c '^\[1001\]' "$TMP/r1_current.conf")" = "3" ] || fail "R1: expected 3 [1001] sections"
grep -q 'password=original-secret' "$TMP/r1_current.conf" || fail "R1: auth NOT recovered verbatim from backup"
grep -q 'max_contacts=1' "$TMP/r1_current.conf" || fail "R1: aor not present"
grep -q 'disallow=all' "$TMP/r1_current.conf" || fail "R1: endpoint body was modified"
[ "$(grep -c '^\[transport-udp\]' "$TMP/r1_current.conf")" = "1" ] || fail "R1: transport section was touched"
grep -q 'password=AIReceptionist@2026' "$TMP/r1_current.conf" && fail "R1: fallback password leaked in despite backup recovery"
echo "PASS: scenario R1 (auth/aor recovered verbatim; transport+endpoint untouched)"

echo
echo "================ SCENARIO R2: no backup -> create from expected config ================"
cat > "$TMP/r2_current.conf" <<'EOF'
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[1001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=1001
aors=1001
EOF

python3 "$TMP/repair_pj.py" "$TMP/r2_current.conf" "$TMP/does-not-exist.conf"
echo "--- resulting file:"
cat "$TMP/r2_current.conf"

[ "$(grep -c '^\[1001\]' "$TMP/r2_current.conf")" = "3" ] || fail "R2: expected 3 [1001] sections"
grep -q 'password=AIReceptionist@2026' "$TMP/r2_current.conf" || fail "R2: auth not created from expected config"
grep -q 'username=1001' "$TMP/r2_current.conf" || fail "R2: auth username missing"
grep -q 'auth_type=userpass' "$TMP/r2_current.conf" || fail "R2: auth_type missing"
grep -q 'type=aor' "$TMP/r2_current.conf" || fail "R2: aor not created"
grep -q 'max_contacts=1' "$TMP/r2_current.conf" || fail "R2: aor max_contacts missing"
[ "$(grep -c '^\[transport-udp\]' "$TMP/r2_current.conf")" = "1" ] || fail "R2: transport was touched"
grep -q 'disallow=all' "$TMP/r2_current.conf" || fail "R2: endpoint body was modified"
echo "PASS: scenario R2 (auth/aor created from expected config; transport+endpoint untouched)"

echo
echo "ALL TESTS PASSED"
