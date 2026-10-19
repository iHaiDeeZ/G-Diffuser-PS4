#!/usr/bin/env bash
# Save the PS4 changes in the G-Diffuser tree (and its submodules) as patches against
# patches/BASE.txt: patches/<repo>-ps4.patch, new files included.
#   save-patch.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/ps4-env.sh"
OUT="$HERE/../patches"
save() { # <dir> <name>
    (cd "$1" && git add -A -N . && git diff --binary HEAD -- . ':(exclude)libultraship' ':(exclude)decomp' \
        ':(exclude)torch' ':(exclude)fzerox-expansion-kit') > "$OUT/$2-ps4.patch"
    echo "$2: $(grep -c '^diff --git' "$OUT/$2-ps4.patch") files"
}
save "$GDX_SRC" gdiffuser
for sub in libultraship decomp torch fzerox-expansion-kit; do save "$GDX_SRC/$sub" "$sub"; done
