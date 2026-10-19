# Shared settings for the G-Diffuser PS4 scripts. Source this from the other scripts.
#
# The toolchain is DolphinPS4's (clang 21 + libc++ 21 over the PacBrew OpenOrbis C runtime), and
# so is the GPU driver: Mesa's RADV on GNM, from DolphinPS4's build tree. Build that first
# (DolphinPS4/BUILDING.md: build-libcxx.sh, build-runtime.sh, build-mesa.sh).
PS4_BUILD_ROOT="${PS4_BUILD_ROOT:-$HOME/gdiffuserps4-build}"
DOLPHIN_BUILD_ROOT="${DOLPHIN_BUILD_ROOT:-$HOME/dolphinps4-build}"
export PS4_SYSROOT="${PS4_SYSROOT:-$DOLPHIN_BUILD_ROOT/sysroot}"
export PS4_MESA_BUILD="${PS4_MESA_BUILD:-$DOLPHIN_BUILD_ROOT/build/mesa}"
export PS4_MESA_SRC="${PS4_MESA_SRC:-$DOLPHIN_BUILD_ROOT/src/mesa}"
GDX_SRC="${GDX_SRC:-$PS4_BUILD_ROOT/src/G-Diffuser}"
OPENORBIS="${OPENORBIS:-/opt/pacbrew/ps4/openorbis}"
# shellcheck disable=SC1091
source "$OPENORBIS/ps4vars.sh"
# PacBrew's ld.lld links against libxml2.so.2; newer distros only ship libxml2.so.16 (same C
# API), so give it a private compat link if needed (from love-ps4's build.sh).
if ldd "$OPENORBIS/bin/ld.lld" | grep -q "libxml2.so.2 => not found"; then
    compat=$(ls /usr/lib/x86_64-linux-gnu/libxml2.so.* 2>/dev/null | grep -E 'libxml2\.so\.[0-9]+$' | head -1)
    if [ -n "$compat" ]; then
        mkdir -p "$PS4_BUILD_ROOT/host-compat"
        ln -sf "$compat" "$PS4_BUILD_ROOT/host-compat/libxml2.so.2"
        export LD_LIBRARY_PATH="$PS4_BUILD_ROOT/host-compat${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    fi
fi
# ps4vars.sh exports CFLAGS/CXXFLAGS/LDFLAGS for makefile projects; CMake would prepend them to
# the toolchain's own flags (and the CXXFLAGS break <cmath>), so clear them for CMake.
ps4_cmake() {
    env -u CFLAGS -u CXXFLAGS -u CPPFLAGS -u LDFLAGS -u LIBS \
        cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 "$@"
}
