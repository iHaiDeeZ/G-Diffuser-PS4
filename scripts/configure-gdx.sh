#!/usr/bin/env bash
# Configure G-Diffuser for PS4: DolphinPS4's modern toolchain (clang 21 + libc++ 21 over the
# PacBrew OpenOrbis runtime) with the love-ps4 link setup (ps4-love-style.cmake, included into the
# top-level project), RADV from DolphinPS4's Mesa build.
#   configure-gdx.sh [extra cmake args...]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ps4-env.sh"
BUILD="$PS4_BUILD_ROOT/build/gdx"
for f in "$PS4_SYSROOT/lib/libc++.a" "$PS4_SYSROOT/lib/libdolphinps4_rt.a" \
         "$PS4_MESA_BUILD/src/amd/vulkan/libvulkan_radeon.a" "$PS4_MESA_SRC/include/vulkan/vulkan_core.h"; do
    [ -f "$f" ] || { echo "missing $f (build DolphinPS4's sysroot and Mesa first)" >&2; exit 1; }
done
ps4_cmake -S "$GDX_SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$HERE/../toolchain/ps4-love-modern.cmake" \
    "-DCMAKE_PROJECT_GDiffuser_INCLUDE=$HERE/../toolchain/ps4-love-style.cmake" \
    -DPS4_MESA_BUILD="$PS4_MESA_BUILD" -DPS4_MESA_SRC="$PS4_MESA_SRC" \
    -DPython3_EXECUTABLE="$(command -v python3)" \
    -DPS4_PAID="${PS4_PAID:-0x3800000000000035}" \
    "$@"
