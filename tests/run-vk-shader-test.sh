#!/usr/bin/env bash
# Build tests/vk_shader_test.cpp for the host and check every generated Vulkan shader pair with
# glslangValidator (compile + link, Vulkan 1.1 rules), the way the PS4 backend compiles them.
#   tests/run-vk-shader-test.sh [count]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../scripts/ps4-env.sh"
LUS="$GDX_SRC/libultraship"
DEPS="$PS4_BUILD_ROOT/build/gdx/_deps"
GLSLANG="${GLSLANG:-$DOLPHIN_BUILD_ROOT/host-tools/bin/glslangValidator}"
WORK="$PS4_BUILD_ROOT/build/vk-shader-test"
rm -rf "$WORK"
mkdir -p "$WORK/out"

# prism's invoke.c calls through unprototyped function pointers: C11, not C++.
gcc -std=gnu11 -O1 -w -c "$DEPS"/prism-src/src/prism/utils/invoke.c -o "$WORK/invoke.o"
g++ -std=c++20 -O1 -w -o "$WORK/vk_shader_test" "$HERE/vk_shader_test.cpp" \
    "$LUS/src/fast/backends/gfx_vulkan_shader.cpp" "$DEPS"/prism-src/src/prism/*.cpp \
    "$DEPS"/prism-src/src/prism/utils/*.cpp "$WORK/invoke.o" \
    -I"$LUS/include" -I"$LUS/src" -I"$DEPS/prism-src/src" -I"$DEPS/prism-src/lib" -I"$DEPS/prism-src" \
    -I"$DEPS/imgui-src" -I"$DEPS/spdlog-src/include" -I"$DEPS/nlohmann_json-src/include" \
    -I"$DEPS/tinyxml2-src" -I"$DEPS/gsl-src/include" -DGBI_FLOATS -DF3DEX_GBI_2
"$WORK/vk_shader_test" "$LUS/src/fast/shaders/opengl/default.shader.glsl" "$WORK/out" "${1:-500}"

fail=0
total=0
for vert in "$WORK"/out/*.vert; do
    frag="${vert%.vert}.frag"
    total=$((total + 1))
    if ! "$GLSLANG" -V --target-env vulkan1.1 -l -o /dev/null "$vert" "$frag" > "$WORK/log.txt" 2>&1; then
        fail=$((fail + 1))
        if [ "$fail" -le 3 ]; then
            echo "FAILED: $(basename "${vert%.vert}")"
            grep -iE "error|warning" "$WORK/log.txt" | head -8
        fi
    fi
done
echo "$((total - fail))/$total shader pairs compile and link"
[ "$fail" -eq 0 ]
