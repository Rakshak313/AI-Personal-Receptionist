#!/bin/bash
# ============================================================================
#  fix_modules_conf.sh — ensure chan_sip.so is disabled in the [modules] section
#
#  Background: 'noload => chan_sip.so' was originally appended AFTER the
#  [global] section, where noload directives are ignored.  An earlier version
#  of this script also had a bug where the insert lacked a trailing newline,
#  merging [global] onto the noload line ('noload => chan_sip.so[global]').
#
#  This script:
#    1. backs up modules.conf
#    2. removes any stray chan_sip noload line, including a merged
#       'noload => chan_sip.so[global]' abomination
#    3. restores the [global] header if it was destroyed
#    4. inserts 'noload => chan_sip.so' inside the [modules] section
#  Run as root:  sudo bash fix_modules_conf.sh
# ============================================================================
set -eu

[ "$(id -u)" -eq 0 ] || { echo "ERROR: run with sudo (e.g. 'sudo bash fix_modules_conf.sh')."; exit 1; }

MODS=/etc/asterisk/modules.conf
TS=$(date +%Y%m%d-%H%M%S)
cp -a "$MODS" "${MODS}.bak-${TS}"
echo "Backup created: ${MODS}.bak-${TS}"

python3 - "$MODS" <<'PYEOF'
import sys, re

path = sys.argv[1]
with open(path) as f:
    text = f.read()

# 1) Remove EVERY chan_sip noload line, including a merged
#    'noload => chan_sip.so[global]' (trailing junk after the module name).
text = re.sub(r'(?m)^\s*noload\s*=>\s*chan_sip\.so.*$', '', text)

# 2) Restore the [global] header if the previous bad merge destroyed it.
if not re.search(r'(?m)^\s*\[global\]\s*$', text):
    text = text.rstrip() + '\n\n[global]\n'
    print('Restored missing [global] section header.')

# 3) Insert 'noload => chan_sip.so' inside the [modules] section,
#    with proper trailing newline so the next section header stays separate.
marker = '[modules]'
if marker not in text:
    print('ERROR: [modules] section not found!')
    sys.exit(1)
idx = text.index(marker) + len(marker)
rest = text[idx:]
m = re.search(r'(?m)^\s*\[', rest)
end = idx + (m.start() if m else len(rest))
insert = '\nnoload => chan_sip.so\n'
text = text[:end] + insert + text[end:]

with open(path, 'w') as f:
    f.write(text)
print('modules.conf updated: noload => chan_sip.so is now inside [modules].')
PYEOF

echo "--- verification:"
grep -n 'noload => chan_sip' "$MODS" || echo "  (noload => chan_sip NOT FOUND - check manually!)"
grep -n '^\[global\]' "$MODS" && echo "  [global] header present" || echo "  WARNING: [global] header missing!"
