#!/usr/bin/env bash
# Package MSPhysics as an unsigned .rbz (a ZIP with a different suffix).
#
# Usage:
#   bash scripts/package.rbz.sh [--version 1.2.0] [--out dist/MSPhysics-1.2.0-unsigned.rbz]
#
# The .rbz root contains ONLY:
#   MSPhysics.rb
#   MSPhysics/            (all Ruby code, HTML/JS/CSS, models, libraries/stage/)
# It never contains C++Extension/, .git/, .github/, __MACOSX/ or .DS_Store.
# Packing is done with python3 zipfile (ZIP_DEFLATED, sorted entries, no
# absolute paths, UTF-8 file names). After packing, the script verifies the
# archive with `unzip -l` and lists the stage/ contents.
#
# The output is UNSIGNED. It is for internal testing only; a releasable
# package must go through the Trimble signing portal first (see PORTING.md).
# This script does not sign anything and must never be pointed at a
# signed .rbz.

set -euo pipefail

VERSION="1.2.0"
OUT=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

while [ $# -gt 0 ]; do
  case "$1" in
    --version)
      VERSION="${2:?--version needs a value}"; shift 2 ;;
    --out)
      OUT="${2:?--out needs a value}"; shift 2 ;;
    -h|--help)
      sed -n '2,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *)
      echo "ERROR: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -z "$OUT" ] && OUT="$REPO_ROOT/dist/MSPhysics-${VERSION}-unsigned.rbz"
case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac

ENTRY_RB="$REPO_ROOT/RubyExtension/MSPhysics.rb"
EXT_DIR="$REPO_ROOT/RubyExtension/MSPhysics"
[ -f "$ENTRY_RB" ] || { echo "ERROR: missing $ENTRY_RB" >&2; exit 1; }
[ -d "$EXT_DIR" ] || { echo "ERROR: missing $EXT_DIR" >&2; exit 1; }

# VERSION in MSPhysics.rb must match --version (and therefore the file name).
if ! grep -q "VERSION *= *'${VERSION}'" "$ENTRY_RB"; then
  echo "ERROR: MSPhysics.rb VERSION does not match --version ${VERSION}" >&2
  grep "VERSION" "$ENTRY_RB" >&2 || true
  exit 1
fi

mkdir -p "$(dirname "$OUT")"
[ -f "$OUT" ] && rm -f "$OUT"

MSPHYSICS_RB="$ENTRY_RB" EXT_DIR="$EXT_DIR" OUT="$OUT" python3 - <<'PYEOF'
import os, zipfile

out = os.environ["OUT"]
entry_rb = os.environ["MSPHYSICS_RB"]
ext_dir = os.environ["EXT_DIR"]

def arcname_ok(name):
    # Reject anything that must never be inside an .rbz.
    bad = ("__MACOSX", ".DS_Store", ".git/")
    return not any(b in name for b in bad)

with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
    zf.write(entry_rb, "MSPhysics.rb")
    for root, dirs, files in os.walk(ext_dir):
        dirs[:] = sorted(d for d in dirs if d not in ("__MACOSX", ".git"))
        for fn in sorted(files):
            if fn == ".DS_Store":
                continue
            full = os.path.join(root, fn)
            arc = os.path.relpath(full, os.path.dirname(ext_dir))
            # arc is "MSPhysics/..." — exactly the required root layout.
            assert arc.startswith("MSPhysics/"), arc
            if arcname_ok(arc):
                zf.write(full, arc)
print(f"Wrote {out}")
PYEOF

echo "--- unzip -l (structure check) ---"
unzip -l "$OUT"

echo "--- stage/ contents in the .rbz ---"
unzip -l "$OUT" 'MSPhysics/libraries/stage/*' || echo "(no stage/ entries — native binaries not built yet)"

echo "--- root entries (must be exactly MSPhysics.rb + MSPhysics/) ---"
unzip -Z1 "$OUT" | cut -d/ -f1 | sort -u

echo "--- forbidden-path check ---"
if unzip -l "$OUT" | grep -Eq '(^|/)(win32|osx32|1\.8|2\.0|2\.2|2\.5)/|__MACOSX|\.DS_Store|C\+\+Extension/|\.github/'; then
  echo "ERROR: forbidden path found in $OUT" >&2
  exit 1
fi
echo "OK: no forbidden paths."

echo "OK: $OUT"
