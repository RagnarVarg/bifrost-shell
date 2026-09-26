#!/usr/bin/env bash
# Compiles shell/Components/Shaders/*.frag to .qsb (committed, so running
# Bifrost doesn't need the shader tools). Run after editing a shader.
set -euo pipefail
repo="$(cd "$(dirname "$0")/.." && pwd)"
qsb="${QSB:-$(python3 "$repo/tools/dependencies.py" --tool qt-shadertools)}"
for f in "$repo"/shell/Components/Shaders/*.frag; do
    "$qsb" --glsl "100 es,120,150" --hlsl 50 --msl 12 -o "$f.qsb" "$f"
    echo "compiled $(basename "$f")"
done
