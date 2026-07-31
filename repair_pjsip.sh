#!/bin/bash
# ============================================================================
#  repair_pjsip.sh — restores the [1001] auth and [1001] aor objects that were
#  incorrectly removed from pjsip.conf by an over-aggressive duplicate sweep.
#
#  PJSIP allows one section per OBJECT TYPE to share a name, so [1001] may
#  legally appear as type=endpoint, type=auth and type=aor.  This script:
#    - backs up pjsip.conf,
#    - recovers the original [1001] auth/aor sections from the pre-fix backup
#      (pjsip.conf.bak-20260731-155315) when they exist there,
#    - otherwise creates them from the expected configuration
#      (username=1001 / password=AIReceptionist@2026 / max_contacts=1),
#    - NEVER modifies the transport or the [1001] endpoint,
#    - reloads PJSIP and verifies transports/endpoints/auths/aors/contacts.
#  Run as root:  sudo bash repair_pjsip.sh
# ============================================================================
set -u
set -o pipefail

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo (e.g. 'sudo bash repair_pjsip.sh')."; exit 1; }

TS=$(date +%Y%m%d-%H%M%S)
PJSIP=/etc/asterisk/pjsip.conf
BACKUP=/etc/asterisk/pjsip.conf.bak-20260731-155315   # pre-fix backup (may not exist)

say() { echo; echo "### $1"; }

say "[1/6] Identity + current file state"
whoami
echo "--- pjsip.conf size:"
stat -c '%s bytes, modified %y' "$PJSIP"
echo "--- available backups:"
ls -la /etc/asterisk/pjsip.conf.bak-* /etc/asterisk/pjsip.conf.backup 2>/dev/null
echo "--- sections currently in pjsip.conf:"
grep -nE '^\s*\[[^]]*\]' "$PJSIP" || echo "  (no sections found!)"

say "[2/6] Inspecting the current [1001] sections"
grep -nA8 -E '^\s*\[1001\]' "$PJSIP" | head -40

say "[3/6] Backing up current pjsip.conf"
cp -a "$PJSIP" "${PJSIP}.repair-bak-${TS}" && echo "  Backup: ${PJSIP}.repair-bak-${TS}"

say "[4/6] Recreating missing [1001] auth / aor objects"
python3 - "$PJSIP" "$BACKUP" <<'PYEOF'
import os, re, sys

path, backup = sys.argv[1], sys.argv[2]

def parse_sections(text):
    """Return [(name, type_or_None, line_1based, body_lines)]."""
    lines = text.splitlines()
    secs = []
    i = 0
    while i < len(lines):
        m = re.match(r'\s*\[([^\]]+)\]\s*', lines[i])
        if not m:
            i += 1
            continue
        name = m.group(1).strip()
        body = []
        j = i + 1
        while j < len(lines) and not re.match(r'\s*\[[^\]]+\]', lines[j]):
            body.append(lines[j])
            j += 1
        tm = re.search(r'^\s*type\s*=\s*(\S+)', '\n'.join(body), re.M)
        secs.append((name, tm.group(1) if tm else None, i + 1, body))
        i = j
    return secs

with open(path) as f:
    cur = parse_sections(f.read())
print(f"  Current sections: {[(n, t) for n, t, _, _ in cur]}")

def ensure_object(name, wanted_type, fallback_lines, label):
    if any(n == name and t == wanted_type for n, t, _, _ in cur):
        print(f"  [OK] [{name}] type={wanted_type} already present - skipping.")
        return
    recovered = None
    if backup and os.path.exists(backup):
        with open(backup) as f:
            old = parse_sections(f.read())
        for n, t, ln, body in old:
            if n == name and t == wanted_type:
                keep = [b for b in body if not re.match(r'^\s*type\s*=\s*', b)]
                if keep:
                    recovered = '\n'.join(keep).strip()
                    break
    if recovered:
        with open(path, 'a') as f:
            f.write(f"\n[{name}]\ntype={wanted_type}\n{recovered}\n")
        print(f"  [RECOVERED] [{name}] type={wanted_type} restored from backup ({label}).")
    else:
        block = '\n'.join(fallback_lines)
        with open(path, 'a') as f:
            f.write(f"\n[{name}]\ntype={wanted_type}\n{block}\n")
        print(f"  [CREATED] [{name}] type={wanted_type} from expected configuration (not found in backup).")

ensure_object('1001', 'auth',
    ["auth_type=userpass", "username=1001", "password=AIReceptionist@2026"],
    "pjsip.conf.bak-20260731-155315")
ensure_object('1001', 'aor',
    ["max_contacts=1"],
    "pjsip.conf.bak-20260731-155315")

# Warn (do NOT modify) if the endpoint does not reference the auth/aor,
# since a dangling endpoint would be the next registration blocker.
for n, t, _, body in cur:
    if n == '1001' and t == 'endpoint':
        endp = '\n'.join(body)
        refs = []
        if not re.search(r'^\s*auth\s*=\s*1001\s*$', endp, re.M):
            refs.append('auth=1001')
        if not re.search(r'^\s*aors\s*=\s*1001\s*$', endp, re.M):
            refs.append('aors=1001')
        if refs:
            print(f"  WARNING: [1001] endpoint is missing reference(s): {', '.join(refs)}")
            print("           Registration will not work until the endpoint points at the auth/aor.")
        else:
            print("  [OK] [1001] endpoint references auth=1001 and aors=1001.")
        break

print("\n  --- Final [1001] sections: ---")
final = parse_sections(open(path).read())
for n, t, ln, body in final:
    if n == '1001':
        print(f"  line {ln}: [{n}] type={t}")
        for b in body:
            print(f"      {b}")
PYEOF

say "[5/6] Validating + reloading PJSIP"
asterisk -rx 'pjsip reload' 2>&1 | head -12
echo "  (pjsip reload applies pjsip.conf changes without a full restart;"
echo "   a service restart is only needed if the reload reports an error.)"

say "[6/6] Verification"
echo "--- pjsip show transports:"
asterisk -rx 'pjsip show transports' 2>&1
echo "--- pjsip show endpoints:"
asterisk -rx 'pjsip show endpoints' 2>&1
echo "--- pjsip show auths:"
asterisk -rx 'pjsip show auths' 2>&1
echo "--- pjsip show aors:"
asterisk -rx 'pjsip show aors' 2>&1
echo "--- pjsip show contacts:"
asterisk -rx 'pjsip show contacts' 2>&1

echo
echo "=== SCRIPT COMPLETE ==="
