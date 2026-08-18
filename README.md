# kicad-dev — a patched KiCad 10, built and packaged

Our KiCad 10: upstream stable plus a small patch queue, with a reproducible
local dev build and CI that ships packages for Linux, macOS (Apple Silicon)
and Windows on the releases page.

Why: KiCad 10's schematic editor cannot be asked over its API to select or
show a symbol (its API has no selection handlers). KiCad master added a
`SyncSelection` cross-probe command; our patch brings it to 10.0 so the
JLCPCB parts-filler plugin can jump the schematic editor to a part with no
PCB open. See `patches/`.

## Layout

```
upstream.env         pinned upstream refs (KiCad tag, kicad-mac-builder commit, library tag)
patches/kicad/       our KiCad commits, as `git format-patch` output (the source of truth)
patches/kicad-mac-builder/   ditto for the macOS dependency builder
scripts/bootstrap.sh check out upstream at the pins and apply the patches -> kicad/, kicad-mac-builder/
scripts/export-patches.sh    regenerate patches/ after committing in kicad/ or kicad-mac-builder/
scripts/version.sh   release name from the git tag (v10.0.5a -> 10.0.5a)
build-kicad.sh       macOS local dev build (incremental) -> install/KiCad.app
.github/workflows/build.yml   CI: build all three platforms; publish a release on tags
kicad/, kicad-mac-builder/, install/, logs/   local only (git-ignored)
```

## Versioning

Releases are tags of the form **`v<upstream><letter>`**: `v10.0.5a` is upstream
KiCad 10.0.5 plus our patches, revision *a*; if we change the patches on the
same upstream base the next tag is `v10.0.5b`, and moving to 10.0.6 restarts at
`v10.0.6a`. The built KiCad reports exactly that name (`10.0.5a`) in About and
over the API — CI puts an annotated `10.0.5a` tag on the patched KiCad tree so
`git describe` produces it. Untagged builds report `10.0.5-1-g…-dev-…`.

## Local development (macOS)

```bash
scripts/bootstrap.sh          # first time: clone + patch (kicad/, kicad-mac-builder/)
cd kicad-mac-builder && WX_SKIP_DOXYGEN_VERSION_CHECK=1 ./build.py --arch arm64 --target setup-kicad-dependencies && cd ..
./build-kicad.sh              # configure + build + install -> install/KiCad.app  (~10 min full, seconds incremental)
open install/KiCad.app        # quit the release KiCad first: both bind the same API socket
```

Edit under `kicad/` on branch `10.0-custom`, commit there, then
`scripts/export-patches.sh` and commit the regenerated `patches/` here. The dev
build shares the release KiCad's settings, libraries and plugin directories,
so the plugin works in it unchanged. macOS will ask once to allow the app
access to Documents (the plugin directory lives there).

Two local snags are already handled in the scripts: ngspice's bundled cppduals
does not compile under Apple clang 21 (patched in `patches/kicad-mac-builder`),
and a stray protobuf 28 in `/usr/local` shadows Homebrew's unless
`CMAKE_OSX_SYSROOT` is set (build-kicad.sh does).

## Releasing

```bash
git tag v10.0.5b && git push origin v10.0.5b
```

CI (`build.yml`) then builds Linux, macOS and Windows and creates the GitHub
release with a `.tar.zst`, `.dmg` and `.zip`. `workflow_dispatch` runs the
builds without a release. Nothing runs on ordinary pushes.

**Cost:** a full KiCad build is hours of runner time per platform, and macOS
runners are billed at 10× on private repositories (a single macOS build can
exceed a Free plan's monthly minutes). Making this repository public makes the
builds free; alternatively run only the platform you need via
`workflow_dispatch` on a fork, or accept the metered minutes.

**First Windows run:** the vcpkg dependency set (OCCT, wxWidgets, Boost, Python,
wxPython…) is several hours to compile; it is cached per port, and the cache is
saved even if the job times out, so if the first Windows job runs out of time,
simply re-run it — the second attempt continues from the cache.

## Package notes

* macOS: `.dmg` from kicad-mac-builder (nightly-style packaging, libraries
  included, unsigned — right-click > Open the first time).
* Windows: portable `.zip` (no installer): unzip, run `bin\kicad.exe`. Python is
  bundled (KiCad's plugin venvs need it); symbol/footprint libraries are not.
* Linux: `.tar.zst` built on Ubuntu 24.04, installs to `/opt/kicad-custom`;
  needs the distro's runtime packages (README-INSTALL.txt inside).
