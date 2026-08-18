#!/bin/bash
# Check out the pinned upstream sources and apply our patches on top.
#
# Produces the same layout the local dev machine uses:
#   kicad/              upstream KiCad at $KICAD_REF, branch 10.0-custom = ref + patches/kicad/*
#   kicad-mac-builder/  macOS packager at $KMB_REF   (+ patches/kicad-mac-builder/*)
#   kicad-win-builder/  Windows packager at $KWB_REF (+ patches/kicad-win-builder/*)
#   kicad-appimage/     Linux packager at $KAI_REF   (+ patches/kicad-appimage/*)
#
# Idempotent: an existing checkout is fetched, reset to the pinned ref and
# re-patched. Uncommitted local edits in those trees would be lost -- commit
# them (and `scripts/export-patches.sh`) first.
#
#   scripts/bootstrap.sh                       # everything
#   scripts/bootstrap.sh kicad kicad-appimage  # just these trees (CI picks per platform)
#   SHALLOW=1 scripts/bootstrap.sh             # depth-1 clones for CI
set -euo pipefail

DEV="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=../upstream.env
source "$DEV/upstream.env"

VERSION_TAG="${VERSION_TAG:-}"   # e.g. 10.0.5a: tag the patched KiCad so `git describe` reports it

# upstream.env variable prefix for a tree: KICAD_URL/KICAD_REF, KMB_*, KWB_*, KAI_*
prefix_of() {
    case "$1" in
        kicad) echo KICAD ;;
        kicad-mac-builder) echo KMB ;;
        kicad-win-builder) echo KWB ;;
        kicad-appimage) echo KAI ;;
        *) echo "unknown tree: $1" >&2; exit 2 ;;
    esac
}

checkout() {
    local name="$1" patches="$DEV/patches/$1"
    local prefix; prefix="$(prefix_of "$name")"
    local url_var="${prefix}_URL" ref_var="${prefix}_REF" dir_var="${prefix}_DIR"
    local url="${!url_var}" ref="${!ref_var}"
    # <PREFIX>_DIR overrides where a tree lands (CI on Windows keeps sources on
    # the same drive as their build directories, and kicad-win-builder wants
    # KiCad inside its own .build/).
    local dir="${!dir_var:-$DEV/$name}"

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

if [ $# -eq 0 ] || [ "$1" = all ]; then
    set -- kicad kicad-mac-builder kicad-win-builder kicad-appimage
fi
for tree in "$@"; do
    checkout "$tree"
done

KICAD_TREE="${KICAD_DIR:-$DEV/kicad}"
if [ -n "$VERSION_TAG" ] && [ -d "$KICAD_TREE/.git" ]; then
    # KiCad takes its version string from `git describe`; an annotated tag on
    # the patched head makes the build report exactly this release name.
    git -C "$KICAD_TREE" -c user.name="kicad-dev" -c user.email="kicad-dev@localhost" \
        tag -f -a "$VERSION_TAG" -m "kicad-dev release $VERSION_TAG" >/dev/null
    echo "== KiCad will report version: $(git -C "$KICAD_TREE" describe)"
fi
