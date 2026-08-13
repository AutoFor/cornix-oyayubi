#!/usr/bin/env bash
# flash.sh -- download the latest Cornix NICOLA firmware release and flash it (macOS / Linux).
#
# No prerequisites: no GitHub account, no gh CLI - just curl.
#
# Run directly:
#   curl -fsSL https://autofor.github.io/cornix-oyayubi/flash.sh | bash
# Left/right only:
#   curl -fsSL https://autofor.github.io/cornix-oyayubi/flash.sh | bash -s left
# Fork users:
#   curl -fsSL https://autofor.github.io/cornix-oyayubi/flash.sh | REPO=you/your-fork bash
#
# Before writing, the current firmware (CURRENT.UF2) is backed up automatically.
set -euo pipefail

REPO="${REPO:-AutoFor/cornix-oyayubi}"
SIDE="${1:-both}"
BASE="https://github.com/$REPO/releases/latest/download"
DEST="${TMPDIR:-/tmp}/cornix-flash"
mkdir -p "$DEST"

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
  local label="$1" file="$2"
  echo ""
  echo "== Put the $label half into bootloader mode (double-tap the reset button) =="
  echo "   waiting for the UF2 volume to appear... (Ctrl+C to abort)"
  local drive=""
  while [ -z "$drive" ]; do drive="$(find_cornix_drive || true)"; sleep 1; done
  echo "   found: $drive"
  # back up the firmware currently on the device (best effort)
  local bak="$DEST/backup-$label-$(date +%Y%m%d-%H%M%S).uf2"
  if cp "$drive/CURRENT.UF2" "$bak" 2>/dev/null; then
    echo "   backup saved: $bak"
  else
    echo "   (backup skipped: CURRENT.UF2 not readable)"
  fi
  echo "   copying $file ..."
  cp "$DEST/$file" "$drive/" 2>/dev/null || true  # device reboots on copy; error is expected
  echo "   writing... waiting for the volume to disappear"
  while find_cornix_drive >/dev/null 2>&1; do sleep 1; done
  echo "   [OK] $label done (rebooted automatically)"
  echo "   (macOS may show a 'disk not ejected properly' notice - that is normal)"
}

for s in left right; do
  [ "$SIDE" = both ] || [ "$SIDE" = "$s" ] || continue
  case "$s" in
    left)  f="cornix_left_default_nosd.uf2" ;;
    right) f="cornix_right_nosd.uf2" ;;
  esac
  echo "Downloading $f ..."
  curl -fsSL "$BASE/$f" -o "$DEST/$f"
  flash_half "$s" "$f"
done

echo ""
echo "[DONE] Flashing complete. Verify the keyboard works."
echo "   Firmware backups (if any) are in: $DEST"
