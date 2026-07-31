#!/bin/bash
# ============================================================================
#  fix_asterisk.sh — AI Personal Receptionist: Asterisk PJSIP repair script
#
#  Fixes two problems that prevent Linphone from registering:
#    1. pjsip.conf contains a duplicate '[transport-udp]' section, which makes
#       Asterisk reject the ENTIRE pjsip.conf (no transports / endpoints /
#       aors / auths are loaded at all).
#    2. chan_sip (deprecated channel driver) is loaded and competes for
#       UDP 0.0.0.0:5060, so the PJSIP UDP transport cannot bind
#       ("Address already in use").  We disable chan_sip so res_pjsip is the
#       only SIP driver and owns port 5060.
#
#  Safe by design: backs up every file it edits, prints everything it does.
#  Run as root:  sudo bash fix_asterisk.sh
# ============================================================================
set -u
set -o pipefail

# Refuse to run without root: this script edits /etc/asterisk and restarts a
# systemd service, so it must be run with sudo.
[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo (e.g. 'sudo bash fix_asterisk.sh')."; exit 1; }

TS=$(date +%Y%m%d-%H%M%S)
PJSIP="${PJSIP_CONF:-/etc/asterisk/pjsip.conf}"
MODS="${MODULES_CONF:-/etc/asterisk/modules.conf}"
LOG="${ASTERISK_LOG:-/var/log/asterisk/messages}"

say() { echo; echo "### $1"; }

say "[1/8] Identity check (must be root)"
whoami
asterisk -rx 'core show version' 2>&1 | head -2
echo "  Reminder: close any editor that has pjsip.conf open (e.g. the 'sudo nano' session)"
echo "  BEFORE this script runs, so a later save cannot overwrite the fixed file."

say "[2/8] Current PJSIP state (before fix)"
asterisk -rx 'pjsip show transports' 2>&1 | head -8
echo "--- chan_sip module state:"
asterisk -rx 'module show like chan_sip' 2>&1 | head -8

say "[3/8] Transport-related sections currently in pjsip.conf"
grep -nE '^[[:space:]]*\[[^]]*\]' "$PJSIP" | grep -i transport || echo "  (none found)"

say "[4/8] Backing up files before editing"
cp -a "$PJSIP" "${PJSIP}.bak-${TS}" && echo "  Backup created: ${PJSIP}.bak-${TS}"
cp -a "$MODS"  "${MODS}.bak-${TS}"  && echo "  Backup created: ${MODS}.bak-${TS}"
ls -la "${PJSIP}.bak-${TS}" "${MODS}.bak-${TS}"

say "[5/8] Fixing pjsip.conf - removing duplicate transport sections"
if ! command -v python3 >/dev/null 2>&1; then
    echo "  ERROR: python3 not found; aborting before any change."
    exit 2
fi
python3 - "$PJSIP" <<'PYEOF'
import re, sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

# Parse every section: (start_index, name, type, end_index).
# PJSIP legally allows the SAME section name once per OBJECT TYPE (e.g.
# [1001] endpoint / [1001] auth / [1001] aor), so only sections with the
# SAME NAME *and* the SAME type= value are true duplicates that Asterisk
# rejects with "duplicate object ... of type ...".
sections = []
idx = 0
n = len(lines)
while idx < n:
    m = re.match(r'\s*\[([^\]]+)\]\s*', lines[idx])
    if not m:
        idx += 1
        continue
    name = m.group(1).strip()
    end = idx + 1
    while end < n and not re.match(r'\s*\[[^\]]+\]', lines[end]):
        end += 1
    body = ''.join(lines[idx + 1:end])
    tm = re.search(r'^\s*type\s*=\s*(\S+)', body, re.M)
    stype = tm.group(1) if tm else ''
    sections.append((idx, name, stype, end))
    idx = end

groups = {}
for start, name, stype, end in sections:
    groups.setdefault((name, stype), []).append((start, end))

# Collect EVERY deletion range for every true duplicate group FIRST, then
# delete bottom-up in a single pass so line indices never go stale.
ranges = []
for (name, stype), occs in sorted(groups.items()):
    if len(occs) <= 1:
        continue
    label = stype or 'UNKNOWN-TYPE'
    print(f"  Duplicate section [{name}] (type={label}) at lines {[s + 1 for s, _ in occs]}")
    for k, (s, e) in enumerate(occs):
        content = ''.join(lines[s:e]).strip()
        tag = "KEEP" if k == 0 else "DELETE"
        print(f"  --- [{name}] type={label} #{k + 1} ({tag}) lines {s + 1}-{e} ---")
        print(content[:400])
        print("  " + "-" * 30)
    for s, e in occs[1:]:
        ranges.append((s, e))

if ranges:
    for s, e in sorted(ranges, reverse=True):
        del lines[s:e]
        print(f"  Removed lines {s + 1}-{e}")
    with open(path, 'w') as f:
        f.writelines(lines)
    print("  pjsip.conf updated (true duplicates removed).")
else:
    print("  No duplicate sections found - nothing removed.")

# Requirement: "create or repair the required UDP transport".  Re-parse the
# final file so indices are always valid, then ensure a usable [transport-udp]
# section exists and warn if the kept one looks wrong.
def section_bodies(text):
    out = []
    for m in re.finditer(r'^\s*\[([^\]]+)\]\s*', text, re.M):
        name = m.group(1).strip()
        nxt = re.search(r'^\s*\[', text[m.end():], re.M)
        end = m.end() + (nxt.start() if nxt else len(text) - m.end())
        out.append((name, text[m.end():end]))
    return out

with open(path) as f:
    final = f.read()
bodies = section_bodies(final)
have_udp = any(name == 'transport-udp' for name, _ in bodies)

if not have_udp:
    default = "\n[transport-udp]\ntype=transport\nprotocol=udp\nbind=0.0.0.0:5060\n"
    with open(path, 'a') as f:
        f.write(default)
    print("  WARNING: no [transport-udp] section existed - appended a default UDP transport.")
else:
    body = next(b for n, b in bodies if n == 'transport-udp')
    problems = []
    if not re.search(r'^\s*type\s*=\s*transport\s*$', body, re.M):
        problems.append("missing 'type=transport'")
    if not re.search(r'^\s*protocol\s*=\s*udp\s*$', body, re.M):
        problems.append("missing/invalid 'protocol=udp'")
    if not re.search(r'^\s*bind\s*=\s*\S+', body, re.M):
        problems.append("missing 'bind=' address")
    if problems:
        print("  WARNING: [transport-udp] section: " + "; ".join(problems) + ".")
    else:
        print("  [transport-udp] section looks usable (type/protocol/bind present).")
PYEOF

say "[6/8] Disabling chan_sip in modules.conf"
if grep -qE 'noload[[:space:]]*=>?[[:space:]]*chan_sip' "$MODS"; then
    echo "  chan_sip already disabled:"
    grep -n 'chan_sip' "$MODS"
else
    printf 'noload => chan_sip.so\n' >> "$MODS"
    echo "  Added 'noload => chan_sip.so' to modules.conf"
fi
echo "--- last 8 lines of modules.conf:"
tail -8 "$MODS"

say "[7/8] Validating pjsip.conf + restarting Asterisk"
echo "  --- pjsip reload (pre-restart; the transport may still fail to bind here"
echo "      because chan_sip holds 5060 until the restart - this is expected):"
asterisk -rx 'pjsip reload' 2>&1 | head -12
echo "  --- restarting asterisk.service ..."
systemctl restart asterisk
for i in $(seq 1 15); do
    sleep 2
    state=$(systemctl is-active asterisk 2>/dev/null)
    echo "  t+$((i * 2))s: $state"
    [ "$state" = "active" ] && break
done
systemctl is-active asterisk

say "[8/8] Verification (post-fix)"
echo "--- pjsip show transports:"
asterisk -rx 'pjsip show transports' 2>&1
echo "--- pjsip show endpoints:"
asterisk -rx 'pjsip show endpoints' 2>&1
echo "--- pjsip show aors:"
asterisk -rx 'pjsip show aors' 2>&1
echo "--- pjsip show contacts:"
asterisk -rx 'pjsip show contacts' 2>&1
echo "--- pjsip show registrations:"
asterisk -rx 'pjsip show registrations' 2>&1
echo "--- pjsip show auths:"
asterisk -rx 'pjsip show auths' 2>&1
echo "--- chan_sip module state:"
asterisk -rx 'module show like chan_sip' 2>&1 | head -8
echo "--- recent relevant log lines (last 200 lines scanned):"
tail -200 "$LOG" | grep -iE 'duplicate|transport|address already in use|chan_sip|unknown option|invalid|unable to parse' | tail -20

echo
echo "=== SUMMARY ==="
TX=$(asterisk -rx 'pjsip show transports' 2>&1)
case "$TX" in
    *transport-udp*)
        echo "  PASS: a PJSIP transport exists after the fix."
        echo "=== SCRIPT COMPLETE ==="
        exit 0
        ;;
    *)
        echo "  FAIL: no PJSIP transport found - see outputs above."
        echo "=== SCRIPT COMPLETE ==="
        exit 1
        ;;
esac
