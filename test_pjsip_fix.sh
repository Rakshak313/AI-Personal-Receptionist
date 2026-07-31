#!/bin/bash
# ============================================================================
#  test_pjsip_fix.sh — validates fix_asterisk.sh WITHOUT touching the real
#  Asterisk config.  It:
#    1. syntax-checks fix_asterisk.sh (bash -n, CRLF-safe)
#    2. extracts the embedded python (type-aware duplicate-removal logic)
#    3. runs it against a synthetic pjsip.conf that contains:
#       a) a TRUE duplicate ([transport-udp] x2, same name + same type)
#       b) [1001] endpoint/auth/aor — same name, DIFFERENT types, all legal
#          and all must be PRESERVED (this is the regression test for the
#          bug that deleted valid auth/aor objects)
#       c) a second file with NO transport section (creation path)
#    4. asserts correct results for every scenario
# ============================================================================
set -u
SRC=/mnt/d/AI-Personal-Receptionist/fix_asterisk.sh
TMP=/tmp

fail() { echo "FAIL: $1"; exit 1; }

# 1) Syntax check the main script (strip any CR first for safety)
sed 's/\r$//' "$SRC" > "$TMP/fix.sh"
bash -n "$TMP/fix.sh" && echo "PASS: bash -n on fix_asterisk.sh" || fail "fix_asterisk.sh has a syntax error"

# 2) Extract the embedded python block from the heredoc
awk '/<<.PYEOF/{f=1; next} f && /^PYEOF/{f=0} f' "$TMP/fix.sh" > "$TMP/fix_pj.py"
[ -s "$TMP/fix_pj.py" ] || fail "could not extract python block"

echo
echo "================ SCENARIO A: duplicate transport + shared-name [1001] objects ================"
cat > "$TMP/sample_a.conf" <<'EOF'
[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5060

[transport-udp]
type=transport
protocol=udp
bind=0.0.0.0:5061

[1001]
type=endpoint
context=from-internal
disallow=all
allow=ulaw
auth=1001
aors=1001

[1001]
type=auth
auth_type=userpass
username=1001
password=AIReceptionist@2026

[1001]
type=aor
max_contacts=1
EOF

python3 "$TMP/fix_pj.py" "$TMP/sample_a.conf"
echo "--- resulting file:"
cat "$TMP/sample_a.conf"

NT=$(grep -c '^\[transport-udp\]' "$TMP/sample_a.conf")
N1=$(grep -c '^\[1001\]' "$TMP/sample_a.conf")
[ "$NT" = "1" ] || fail "scenario A: $NT transport sections remain (expected 1)"
[ "$N1" = "3" ] || fail "scenario A: $N1 [1001] sections remain (expected 3: endpoint+auth+aor)"
grep -q 'type=endpoint' "$TMP/sample_a.conf" || fail "scenario A: endpoint lost"
grep -q 'type=auth' "$TMP/sample_a.conf" || fail "scenario A: auth lost"
grep -q 'type=aor' "$TMP/sample_a.conf" || fail "scenario A: aor lost"
grep -q 'password=AIReceptionist@2026' "$TMP/sample_a.conf" || fail "scenario A: auth password lost"
grep -q 'context=from-internal' "$TMP/sample_a.conf" || fail "scenario A: endpoint body lost"
grep -q 'bind=0.0.0.0:5060' "$TMP/sample_a.conf" || fail "scenario A: kept transport bind lost"
echo "PASS: scenario A (true duplicate removed; endpoint/auth/aor all preserved)"

echo
echo "================ SCENARIO B: no transport section at all ================"
cat > "$TMP/sample_b.conf" <<'EOF'
[1001]
type=endpoint
transport=transport-udp
auth=1001
context=from-internal
EOF

python3 "$TMP/fix_pj.py" "$TMP/sample_b.conf"
echo "--- resulting file:"
cat "$TMP/sample_b.conf"

grep -q '^\[transport-udp\]' "$TMP/sample_b.conf" || fail "scenario B: no [transport-udp] was created"
grep -q 'bind=0.0.0.0:5060' "$TMP/sample_b.conf" || fail "scenario B: created transport lacks bind"
grep -q 'type=transport' "$TMP/sample_b.conf" || fail "scenario B: created transport lacks type"
grep -q 'protocol=udp' "$TMP/sample_b.conf" || fail "scenario B: created transport lacks protocol"
echo "PASS: scenario B (default UDP transport created)"

echo
echo "ALL TESTS PASSED"
