#!/usr/bin/env bash
# Check the layout of RubyExtension/MSPhysics/libraries/stage/.
#
# Required (new layout, analysis/04 §3.2):
#   win64/3.2  win64/3.4  osx64/3.2  osx64/3.4
# Forbidden (SU2024+ has no 32-bit build and no Ruby <= 2.5):
#   win32/  osx32/
#   win64/{1.8,2.0,2.2,2.5}  osx64/{1.8,2.0,2.2,2.5}
#
# Usage: bash scripts/check_stage.sh [--warn-only]
#   Default: any violation fails (exit 1) — this is what CI runs.
#   --warn-only: report violations but exit 0 (local inspection).
#
# Old binaries are NOT deleted by this script. Remove them with git so
# they stay recoverable in history, e.g.:
#   git rm -r RubyExtension/MSPhysics/libraries/stage/win32
#   git rm -r RubyExtension/MSPhysics/libraries/stage/osx64/2.5

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STAGE="$REPO_ROOT/RubyExtension/MSPhysics/libraries/stage"

WARN_ONLY=0
[ "${1:-}" = "--warn-only" ] && WARN_ONLY=1

fail=0
fail_msg() { echo "ERROR: $1" >&2; fail=1; }

[ -d "$STAGE" ] || { echo "ERROR: stage/ directory missing: $STAGE" >&2; exit 1; }

echo "Checking stage/ layout: $STAGE"

for d in win64/3.2 win64/3.4 osx64/3.2 osx64/3.4; do
  if [ -d "$STAGE/$d" ]; then
    echo "  OK: $d/ exists"
  else
    fail_msg "missing required directory: $d/ (create it; it holds msp_lib.so/.bundle for that Ruby version)"
  fi
done

for d in win32 osx32; do
  if [ -e "$STAGE/$d" ]; then
    fail_msg "forbidden directory present: $d/ — delete it: git rm -r RubyExtension/MSPhysics/libraries/stage/$d"
  else
    echo "  OK: no $d/"
  fi
done

for plat in win64 osx64; do
  for ver in 1.8 2.0 2.2 2.5; do
    if [ -e "$STAGE/$plat/$ver" ]; then
      fail_msg "forbidden old-Ruby directory present: $plat/$ver/ — delete it: git rm -r RubyExtension/MSPhysics/libraries/stage/$plat/$ver"
    fi
  done
done

echo "  OK: no 1.8/2.0/2.2/2.5 directories under win64/ or osx64/"

if [ "$fail" -ne 0 ]; then
  echo "stage/ check FAILED." >&2
  [ "$WARN_ONLY" -eq 1 ] && { echo "(warn-only mode: exiting 0 anyway)"; exit 0; }
  exit 1
fi

echo "stage/ check PASSED."
