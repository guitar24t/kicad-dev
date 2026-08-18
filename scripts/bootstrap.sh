#!/bin/bash
# Check out the pinned upstream sources and apply our patches on top.
#
# Produces the same layout the local dev machine uses:
#   kicad/              upstream KiCad at $KICAD_REF, branch 10.0-custom = ref + patches/kicad/*
#   kicad-mac-builder/  upstream builder at $KMB_REF, branch 10.0-custom = ref + patches/kicad-mac-builder/*
#
# Idempotent: an existing checkout is fetched, reset to the pinned ref and
# re-patched. Uncommitted local edits in those trees would be lost -- commit
# them (and `scripts/export-patches.sh`) first.
#
#   scripts/bootstrap.sh            # both
#   scripts/bootstrap.sh kicad      # just KiCad (CI on Linux/Windows)
#   SHALLOW=1 scripts/bootstrap.sh  # depth-1 clones for CI
set -euo pipefail

DEV="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../upstream.env
source "$DEV/upstream.env"

VERSION_TAG="${VERSION_TAG:-}"   # e.g. 10.0.5a: tag the patched KiCad so `git describe` reports it

checkout() {
    local name="$1" url="$2" ref="$3" patches="$DEV/patches/$1"
    local dir="$DEV/$name"

    if [ ! -d "$dir/.git" ]; then
        echo "== cloning $name ($url @ $ref)"
        if [ -n "${SHALLOW:-}" ]; then
            git clone --depth 1 --branch "$ref" "$url" "$dir" 2>/dev/null \
                || { git clone --depth 1 "$url" "$dir"; git -C "$dir" fetch --depth 1 origin "$ref"; }
        else
            git clone "$url" "$dir"
        fi
    else
        echo "== fetching $name"
        git -C "$dir" fetch origin "$ref" 2>/dev/null || git -C "$dir" fetch origin
    fi

    # Resolve the ref (a tag, branch or sha) to the commit we pin.
    local commit
    commit="$(git -C "$dir" rev-parse -q --verify "$ref^{commit}" 2>/dev/null \
              || git -C "$dir" rev-parse FETCH_HEAD)"

    git -C "$dir" checkout -q -B 10.0-custom "$commit"
    if [ -d "$patches" ] && ls "$patches"/*.patch >/dev/null 2>&1; then
        echo "== applying $(ls "$patches"/*.patch | wc -l | tr -d ' ') patch(es) to $name"
        git -C "$dir" -c user.name="kicad-dev" -c user.email="kicad-dev@localhost" \
            am --whitespace=nowarn "$patches"/*.patch
    fi
    echo "== $name at $(git -C "$dir" log --oneline -1)"
}

want="${1:-all}"
[ "$want" = all ] || [ "$want" = kicad ] && checkout kicad "$KICAD_URL" "$KICAD_REF"
[ "$want" = all ] || [ "$want" = kicad-mac-builder ] && checkout kicad-mac-builder "$KMB_URL" "$KMB_REF"

if [ -n "$VERSION_TAG" ] && [ -d "$DEV/kicad/.git" ]; then
    # KiCad takes its version string from `git describe`; an annotated tag on
    # the patched head makes the build report exactly this release name.
    git -C "$DEV/kicad" -c user.name="kicad-dev" -c user.email="kicad-dev@localhost" \
        tag -f -a "$VERSION_TAG" -m "kicad-dev release $VERSION_TAG" >/dev/null
    echo "== KiCad will report version: $(git -C "$DEV/kicad" describe)"
fi
