// Host test for libultraship's gfx_vulkan_shader.cpp (the Vulkan backend's shader text): expands
// the Fast3D template for many combiner states, the way the interpreter decodes them, and writes
// each vertex/fragment pair for glslangValidator (tests/run-vk-shader-test.sh).
//
//   vk_shader_test <default.shader.glsl> <out dir> [count]
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <random>
#include <sstream>
#include <string>

#include "fast/backends/gfx_vulkan_shader.h"
#include "fast/interpreter.h"

// libultraship/src/fast/interpreter.cpp gfx_cc_get_features, minus the custom-shader id.
static void GetFeatures(uint64_t shader_id0, uint64_t shader_id1, CCFeatures* f) {
    for (int i = 0; i < 2; i++)
        for (int j = 0; j < 2; j++)
            for (int k = 0; k < 4; k++)
                f->c[i][j][k] = shader_id0 >> i * 32 + j * 16 + k * 4 & 0xf;
    f->opt_alpha = (shader_id1 & SHADER_OPT(ALPHA)) != 0;
    f->opt_fog = (shader_id1 & SHADER_OPT(FOG)) != 0;
    f->opt_texture_edge = (shader_id1 & SHADER_OPT(TEXTURE_EDGE)) != 0;
    f->opt_noise = (shader_id1 & SHADER_OPT(NOISE)) != 0;
    f->opt_2cyc = (shader_id1 & SHADER_OPT(_2CYC)) != 0;
    f->opt_alpha_threshold = (shader_id1 & SHADER_OPT(ALPHA_THRESHOLD)) != 0;
    f->opt_invisible = (shader_id1 & SHADER_OPT(INVISIBLE)) != 0;
    f->opt_grayscale = (shader_id1 & SHADER_OPT(GRAYSCALE)) != 0;
    f->opt_prim_depth = (shader_id1 & SHADER_OPT(PRIM_DEPTH)) != 0;
    f->clamp[0][0] = shader_id1 & SHADER_OPT(TEXEL0_CLAMP_S);
    f->clamp[0][1] = shader_id1 & SHADER_OPT(TEXEL0_CLAMP_T);
    f->clamp[1][0] = shader_id1 & SHADER_OPT(TEXEL1_CLAMP_S);
    f->clamp[1][1] = shader_id1 & SHADER_OPT(TEXEL1_CLAMP_T);
    f->usedTextures[0] = f->usedTextures[1] = false;
    f->used_masks[0] = f->used_masks[1] = false;
    f->used_blend[0] = f->used_blend[1] = false;
    f->numInputs = 0;
    for (int c = 0; c < 2; c++)
        for (int i = 0; i < 2; i++)
            for (int j = 0; j < 4; j++) {
                const int v = f->c[c][i][j];
                if (v >= SHADER_INPUT_1 && v <= SHADER_INPUT_7 && v > f->numInputs)
                    f->numInputs = v;
                if (v == SHADER_TEXEL0 || v == SHADER_TEXEL0A) {
                    f->usedTextures[0] = true;
                    if (f->opt_2cyc)
                        f->usedTextures[1] = true;
                }
                if (v == SHADER_TEXEL1 || v == SHADER_TEXEL1A) {
                    f->usedTextures[1] = true;
                    if (f->opt_2cyc)
                        f->usedTextures[0] = true;
                }
            }
    for (int c = 0; c < 2; c++) {
        f->do_single[c][0] = f->c[c][0][2] == SHADER_0;
        f->do_single[c][1] = f->c[c][1][2] == SHADER_0;
        f->do_multiply[c][0] = f->c[c][0][1] == SHADER_0 && f->c[c][0][3] == SHADER_0;
        f->do_multiply[c][1] = f->c[c][1][1] == SHADER_0 && f->c[c][1][3] == SHADER_0;
        f->do_mix[c][0] = f->c[c][0][1] == f->c[c][0][3];
        f->do_mix[c][1] = f->c[c][1][1] == f->c[c][1][3];
        f->color_alpha_same[c] = (shader_id0 >> c * 32 & 0xffff) == (shader_id0 >> c * 32 + 16 & 0xffff);
    }
    if (f->usedTextures[0] && shader_id1 & SHADER_OPT(TEXEL0_MASK))
        f->used_masks[0] = true;
    if (f->usedTextures[1] && shader_id1 & SHADER_OPT(TEXEL1_MASK))
        f->used_masks[1] = true;
    if (f->usedTextures[0] && shader_id1 & SHADER_OPT(TEXEL0_BLEND))
        f->used_blend[0] = true;
    if (f->usedTextures[1] && shader_id1 & SHADER_OPT(TEXEL1_BLEND))
        f->used_blend[1] = true;
    f->shader_id = 0;
}

int main(int argc, char** argv) {
    if (argc < 3) {
        fprintf(stderr, "usage: %s <default.shader.glsl> <out dir> [count]\n", argv[0]);
        return 2;
    }
    std::ifstream in(argv[1]);
    std::stringstream buf;
    buf << in.rdbuf();
    const std::string templ = buf.str();
    const std::string out = argv[2];
    const int count = argc > 3 ? atoi(argv[3]) : 500;

    std::mt19937_64 rng(1234);
    for (int n = 0; n < count; n++) {
        uint64_t id0 = 0;
        for (int nib = 0; nib < 16; nib++) {
            // Mostly realistic slots: combiner values 0..14, with SHADER_0 common.
            uint64_t v = (rng() % 3 == 0) ? SHADER_0 : rng() % (SHADER_NOISE + 1);
            id0 |= v << (nib * 4);
        }
        const uint64_t id1 = rng() & 0xFFFFFFFFull & ~0x0ull;
        CCFeatures cc;
        GetFeatures(id0, id1, &cc);
        const bool threePoint = (n & 1) != 0;
        const bool srgb = (n % 7) == 0;
        Fast::GdxVulkanShaderText text = Fast::GdxBuildVulkanShaders(cc, templ, threePoint, srgb, nullptr);
        char name[256];
        snprintf(name, sizeof(name), "%s/%04d_%016llx_%08llx", out.c_str(), n, (unsigned long long)id0,
                 (unsigned long long)id1);
        std::ofstream(std::string(name) + ".vert") << text.vs;
        std::ofstream(std::string(name) + ".frag") << text.fs;
        if (text.numFloats < 4 || text.numFloats > 64) {
            fprintf(stderr, "%s: implausible vertex stride %zu\n", name, text.numFloats);
            return 1;
        }
    }
    printf("wrote %d shader pairs to %s\n", count, out.c_str());
    return 0;
}
