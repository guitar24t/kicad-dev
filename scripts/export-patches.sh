#!/bin/bash
# Regenerate patches/ from the commits on each tree's 10.0-custom branch that
# are not in the pinned upstream ref. Run after committing a change in kicad/,
# kicad-mac-builder/, kicad-win-builder/ or kicad-appimage/, then commit the
# result here. Trees that are not checked out are skipped.
set -euo pipefail
DEV="$(cd "$(dirname "$0")/.." && pwd)"
source "$DEV/upstream.env"

export_one() {
    local name="$1" ref="$2"
    [ -d "$DEV/$name/.git" ] || { echo "$name: not checked out, skipped"; return; }
    rm -f "$DEV/patches/$name"/*.patch
    mkdir -p "$DEV/patches/$name"
    git -C "$DEV/$name" format-patch -q "$ref..10.0-custom" -o "$DEV/patches/$name/"
    echo "$name: $(ls "$DEV/patches/$name"/*.patch 2>/dev/null | wc -l | tr -d ' ') patch(es)"
    rmdir "$DEV/patches/$name" 2>/dev/null || true
}
export_one kicad "$KICAD_REF"
export_one kicad-mac-builder "$KMB_REF"
export_one kicad-win-builder "$KWB_REF"
export_one kicad-appimage "$KAI_REF"
