#!/bin/bash
# Regenerate patches/ from the commits on each tree's 10.0-custom branch that
# are not in the pinned upstream ref. Run after committing a change in kicad/
# or kicad-mac-builder/, then commit the result here.
set -euo pipefail
DEV="$(cd "$(dirname "$0")/.." && pwd)"
source "$DEV/upstream.env"

export_one() {
    local name="$1" ref="$2"
    rm -f "$DEV/patches/$name"/*.patch
    mkdir -p "$DEV/patches/$name"
    git -C "$DEV/$name" format-patch -q "$ref..10.0-custom" -o "$DEV/patches/$name/"
    echo "$name: $(ls "$DEV/patches/$name"/*.patch 2>/dev/null | wc -l | tr -d ' ') patch(es)"
}
export_one kicad "$KICAD_REF"
export_one kicad-mac-builder "$KMB_REF"
