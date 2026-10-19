# G-Diffuser for PS4

[G-Diffuser](https://github.com/Zorkats/G-Diffuser) (the F-Zero X + 64DD Expansion Kit source port)
for jailbroken PS4 homebrew, built in WSL with DolphinPS4's toolchain (clang 21 + libc++ 21 over the
PacBrew OpenOrbis runtime) and DolphinPS4's GPU driver (Mesa's RADV on GNM).

Status (v01.20): runs on a console at about 60 fps. Races, menus, HUD, machines, shadows, track,
buildings, booster flames and the pit force field render correctly. Audio, DualShock 4 and saves work.

## Features

- **Quick menu** (touchpad, or L3+R3): pauses the game behind a PS3-style side panel with Resume,
  Reset, volume, FPS counter, widescreen, and every G-Diffuser Settings/Enhancements page, driven by
  the pad (L1/R1 change page, Left/Right change a value). The original full-screen menu is not used.
- **FSR 1.0** (Settings > Graphics): AMD FidelityFX Super Resolution 1 (EASU + RCAS). Renders at
  77/67/59/50% and upscales to 1080p, with adjustable sharpening. Off by default.
- **Full-screen 16:9**: the N64 overscan border is removed by default on PS4.

## How it works

- **Graphics:** a new Fast3D Vulkan backend, `libultraship/src/fast/backends/gfx_vulkan.cpp`, on
  RADV. RADV has no window system on the PS4, so three linear images are registered as VideoOut
  buffers and flipped GPU-side behind each frame (`ac_ps4_submit_flip`), as DolphinPS4 does.
  Shaders are the OpenGL template rewritten for Vulkan (`gfx_vulkan_shader.cpp`), compiled with
  glslang on the console, pipelines cached in `/data/gdiffuser/vulkan-pipeline-cache.bin`. ImGui
  draws through the same device.
- **Addresses below 4 GiB:** the PS4 loads the eboot at 0x400000, so the game's own addresses
  collide with N64 segment addresses (0x01xxxxxx-0x04xxxxxx), something the Windows build never sees.
  The display-list bridge and `Gdx_ResolvePortAddress` tell the two apart under `GDX_IMAGE_BELOW_4G`
  (`port/n64_gfx_bridge.cpp`, `port/decomp_port.c`, `port/gen/AssetBindings.c`).
- **PC reproduction:** configuring the Windows build with `-DGDX_LOW_IMAGE=ON` links it so its image
  ends where the PS4's does and keeps the heap above 4 GiB (`port/gdx_lowimage_win.cpp`). That
  reproduces PS4 rendering bugs on a PC with the D3D11 renderer. The env var `GDX_LOWFIX=<mask>`
  switches the individual address fixes for bisecting.
- **Audio:** `Ps4AudioPlayer` on `sceAudioOut`, resampling the game's 32 kHz stream to 48 kHz.
- **Window and input:** `gfx_ps4.cpp`, fixed 1920x1080 output, SDL (PacBrew) for the DualShock 4.
- **Game scheduler:** `port/gdx_fiber_ps4.c`, an x86-64 context switch (the PS4's libc has no
  ucontext). `tests/fiber_test.c` checks it on Linux.
- **Game data:** the package carries the archives that the **PC version's first boot** built from
  your ROM, Expansion Kit disk and 64DD IPL (`fzerox.o2r`, `fzerox-disk.o2r`, `n64ddipl.o2r` and the
  two state files). They are copied to `/data/gdiffuser` on first launch. The console never sees the
  ROM. The package therefore contains Nintendo-derived data: keep it to yourself. Nothing
  Nintendo- or Sony-owned is in this repository.

## Building

Needs DolphinPS4's build tree in `~/dolphinps4-build` (sysroot from `build-libcxx.sh` /
`build-runtime.sh`, Mesa from `build-mesa.sh`), and the G-Diffuser sources with the patches applied
in `~/gdiffuserps4-build/src/G-Diffuser` (see `patches/BASE.txt`; branch `ps4` in each repo). Run
from WSL through `~/gdiffuserps4` (the space in "PS4 Projects" breaks linker flags):

```
scripts/configure-gdx.sh
scripts/build-gdx.sh
GDX_GAME_DATA=/mnt/e/gdx-pc/dist/<your PC G-Diffuser folder> scripts/package-gdx.sh [upload]
scripts/save-patch.sh            # refresh patches/*-ps4.patch from the G-Diffuser tree
tests/run-vk-shader-test.sh 3000 # host check: every generated Vulkan shader compiles and links
```

The package lands in `~/gdiffuserps4-build/out/` (also copied to `out/` here). `upload` sends it
to the console's `/data/pkg/` over FTP (`PS4_HOST`, `PS4_FTP_PORT`).

## On the console

| Path | What |
|---|---|
| `/app0/gdiffuser` | packaged game data, engine archive, fonts |
| `/data/gdiffuser` | the game folder: copied data, `gdiffuser.cfg.json`, `saves/`, `logs/` |
| `/data/gdiffuser/boot-trace.log` | startup milestones, renderer, warnings |
| `/data/gdiffuser/crash.log` | fatal signals with addresses relative to `.text` |

Title ID `GDXF00001`. To move PC saves over, copy the PC folder's `saves/` to
`/data/gdiffuser/saves/`.
