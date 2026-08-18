#!/bin/bash
# The release name for a build. Releases are tags on this repository of the
# form v<upstream>[letter], e.g. v10.0.5a: upstream KiCad 10.0.5 plus our
# revision "a" (b, c, ... as we revise on the same base). Prints the KiCad
# version string (without the v). Anything else builds as a dev snapshot.
set -euo pipefail
DEV="$(cd "$(dirname "$0")/.." && pwd)"
source "$DEV/upstream.env"

ref="${GITHUB_REF_NAME:-$(git -C "$DEV" describe --tags --exact-match 2>/dev/null || true)}"
if [[ "$ref" =~ ^v([0-9]+\.[0-9]+\.[0-9]+[a-z]?)$ ]]; then
    echo "${BASH_REMATCH[1]}"
else
    sha="$(git -C "$DEV" rev-parse --short HEAD 2>/dev/null || echo local)"
    echo "${KICAD_REF}-dev-${sha}"
fi
