#!/usr/bin/env bash
# Package G-Diffuser for PS4 (build first: configure-gdx.sh, build-gdx.sh).
#
# The package carries the game data that the PC version's first boot built from your own ROM,
# Expansion Kit disk and 64DD IPL, so the console needs no extraction step. GDX_GAME_DATA is that
# PC game folder. The result contains Nintendo-derived data: keep it to yourself.
#
#   GDX_GAME_DATA=<PC game folder> GDX_PS4_VERSION=01.01 package-gdx.sh [upload]
#
# On the console everything is copied to /data/gdiffuser at first launch; saves, config and logs
# live there too.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ps4-env.sh"
BUILD="$PS4_BUILD_ROOT/build/gdx"
DATA="${GDX_GAME_DATA:-/mnt/e/gdx-pc/dist/G-Diffuser-v1.0.0-local-535abe9-windows-x64}"
VERSION="${GDX_PS4_VERSION:-01.20}"
TITLE_ID="${GDX_TITLE_ID:-GDXF00001}"
OUT="$PS4_BUILD_ROOT/out"
HOST="ftp://${PS4_HOST:-192.168.0.90}:${PS4_FTP_PORT:-2121}"

eboot="$BUILD/port/G-Diffuser_eboot/eboot.bin"
[ -f "$eboot" ] || { echo "missing $eboot: run scripts/build-gdx.sh" >&2; exit 1; }
for f in fzerox.o2r fzerox-disk.o2r n64ddipl.o2r gdx_extract_state.cfg gdx_firstboot.cfg; do
    [ -f "$DATA/$f" ] || {
        echo "missing $DATA/$f: run the PC version once and finish its setup (GDX_GAME_DATA)" >&2
        exit 1
    }
done

stage="$BUILD/stage"
rm -rf "$stage"
mkdir -p "$stage/sce_sys" "$stage/gdiffuser/fonts"
cp "$eboot" "$stage/"
icon="$HERE/../sce_sys/icon0.png"
if [ ! -f "$icon" ]; then
    python3 "$HERE/make-icon.py" "$GDX_SRC/assets/branding/gdiffuser-icon.png" "$icon"
fi
cp "$icon" "$stage/sce_sys/"

# Game data (from the PC first boot) and the engine archive, fonts and pad database (this build).
for f in fzerox.o2r fzerox-disk.o2r n64ddipl.o2r gdx_extract_state.cfg gdx_firstboot.cfg; do
    cp "$DATA/$f" "$stage/gdiffuser/"
done
cp "$BUILD/port/gdiffuser.o2r" "$stage/gdiffuser/"
cp "$GDX_SRC/port/assets/fonts/"*.ttf "$GDX_SRC/port/assets/fonts/"*OFL.txt "$stage/gdiffuser/fonts/"
cp "$GDX_SRC/port/assets/gamecontrollerdb.txt" "$stage/gdiffuser/"
cp "$GDX_SRC/LICENSE" "$GDX_SRC/THIRD_PARTY_NOTICES.md" "$stage/gdiffuser/"
cp -r "$GDX_SRC/LICENSES" "$stage/gdiffuser/"
# The quick menu's sounds (from Resonance, port/ps4/quick_menu.cpp).
mkdir -p "$stage/gdiffuser/quickmenu/sounds"
cp "$HERE/../assets/quickmenu/sounds/"*.wav "$stage/gdiffuser/quickmenu/sounds/"

# Plain homebrew identity (default PAID): RADV draws, no Piglet display needed (DolphinPS4).
pkg="$(SFO_STYLE=plain DOLPHIN_PS4_MODULES_DIR=/nonexistent "$HERE/make-pkg.sh" "$stage" "$TITLE_ID" \
    "G-Diffuser" "$VERSION" GDIFFUSER "$OUT" | tail -1)"
final="$OUT/G-Diffuser-PS4-v$VERSION.pkg"
mv -f "$pkg" "$final"
echo "package: $final ($(du -h "$final" | cut -f1))"
if [ "${1:-}" = upload ]; then
    curl -sS -T "$final" "$HOST/data/pkg/"
    echo "uploaded $(basename "$final")"
fi
