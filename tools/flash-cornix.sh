#!/usr/bin/env bash
# flash-cornix.sh -- download the latest CI build and flash it to Cornix (macOS / Linux).
#
# Prereqs (first time only):
#   1. install GitHub CLI:  brew install gh   (macOS)  /  see cli.github.com  (Linux)
#   2. authenticate:        gh auth login
#
# Usage:
#   ./flash-cornix.sh              # flash both halves in order
#   ./flash-cornix.sh left         # left half only
#   ./flash-cornix.sh right        # right half only
#   BRANCH=xxx ./flash-cornix.sh   # target branch (default: main)
#
# The UF2 bootloader volume is auto-detected via INFO_UF2.TXT "Model: cornix",
# so it works whatever the volume is named. Or just drag-and-drop the UF2 yourself.
set -euo pipefail

REPO="${REPO:-AutoFor/cornix-oyayubi}"
BRANCH="${BRANCH:-main}"
SIDE="${1:-both}"

# --- 1. find the latest successful build ---
echo "Searching latest successful build of $REPO ($BRANCH)..."
RUN_ID="$(gh run list -R "$REPO" -b "$BRANCH" -w "Build ZMK firmware" -s success -L 1 --json databaseId -q '.[0].databaseId')"
if [ -z "$RUN_ID" ]; then
  echo "No successful 'Build ZMK firmware' run on '$BRANCH'. Check GitHub Actions / 'gh auth status'." >&2
  exit 1
fi
echo "  run: https://github.com/$REPO/actions/runs/$RUN_ID"

# --- 2. download the firmware artifact (cached) ---
DEST="${TMPDIR:-/tmp}/cornix-fw-$RUN_ID"
if [ ! -f "$DEST/_done" ]; then
  rm -rf "$DEST"; mkdir -p "$DEST"
  echo "Downloading firmware artifact -> $DEST"
  gh run download "$RUN_ID" -R "$REPO" -n firmware -D "$DEST"
  touch "$DEST/_done"
else
  echo "  using cached download: $DEST"
fi

find_uf2() { find "$DEST" -name '*.uf2' | grep -iE "$1" | grep -viE 'dongle' | grep -viE "$2" | head -n1; }
LEFT_UF2="$(find_uf2 'left' 'debug' || true)"
RIGHT_UF2="$(find_uf2 'right' 'debug|reset' || true)"
echo "  left : ${LEFT_UF2:-<none>}"
echo "  right: ${RIGHT_UF2:-<none>}"

# --- helpers: find the cornix UF2 volume, wait for it, copy ---
mountpoints() {
  case "$(uname -s)" in
    Darwin) ls -d /Volumes/* 2>/dev/null ;;
    *)      ls -d /media/*/* /run/media/*/* /media/* 2>/dev/null ;;
  esac
}
find_cornix_drive() {
  local m
  while IFS= read -r m; do
    [ -f "$m/INFO_UF2.TXT" ] || continue
    grep -qi "Model: cornix" "$m/INFO_UF2.TXT" 2>/dev/null && { echo "$m"; return 0; }
  done < <(mountpoints)
  return 1
}
flash_half() {
  local label="$1" uf2="$2"
  [ -n "$uf2" ] || { echo "$label UF2 not found" >&2; exit 1; }
  echo ""
  echo "== Put $label into bootloader (double-tap reset); waiting for the UF2 volume... =="
  local drive=""
  while [ -z "$drive" ]; do drive="$(find_cornix_drive || true)"; sleep 1; done
  echo "  found: $drive -> copying $(basename "$uf2")"
  cp "$uf2" "$drive/" 2>/dev/null || true   # device reboots on copy; error is expected
  echo "  writing... waiting for the volume to disappear"
  while find_cornix_drive >/dev/null 2>&1; do sleep 1; done
  echo "  [OK] $label done (rebooted automatically)"
}

# --- 3. flash ---
if [ "$SIDE" = both ] || [ "$SIDE" = left ];  then flash_half "LEFT"  "$LEFT_UF2";  fi
if [ "$SIDE" = both ] || [ "$SIDE" = right ]; then flash_half "RIGHT" "$RIGHT_UF2"; fi

echo ""
echo "[DONE] Flashing complete. Verify the keyboard works."
echo "  To roll back, flash the stock UF2 under firmware/stock/."
