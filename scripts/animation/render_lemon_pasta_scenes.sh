#!/bin/bash
# Build local transparent movies for the lemon pasta recipe only.
set -euo pipefail
cd "$(dirname "$0")/../.."
output="${1:-/tmp/PetitChef-lemon-scenes}"
mode="${2:-render}"
case "$mode" in render|preview-only|encode-only) ;; *) echo 'Mode: render, preview-only, encode-only' >&2; exit 2 ;; esac
blender_bin="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
if [[ "$mode" != encode-only ]]; then
    if [[ "$mode" == preview-only ]]; then
        "$blender_bin" -b --threads 4 --python-exit-code 1 --python scripts/animation/lemon_pasta_scenes.py -- "$output" --preview-only
    else
        "$blender_bin" -b --threads 4 --python-exit-code 1 --python scripts/animation/lemon_pasta_scenes.py -- "$output"
    fi
    if [[ "$mode" == preview-only ]]; then exit 0; fi
fi
encoder_dir="$(mktemp -d /tmp/PetitChef-lemon-alpha.XXXXXX)"
swiftc scripts/animation/encode_alpha.swift -o "$encoder_dir/encode-alpha"
assets='Petit Chef/Resources/Animations'
sources='docs/design/lemon-pasta/scenes'
mkdir -p "$assets" "$sources"
for name in pasta-water pasta-zest pasta-boil pasta-sauce pasta-toss pasta-serve; do
    "$encoder_dir/encode-alpha" "$output/$name" "$assets/$name.mov" 24
    cp "$output/$name/start.png" "$assets/$name-start.png"
    cp "$output/$name/poster.png" "$assets/$name-poster.png"
    cp "$output/$name/$name.blend" "$sources/$name.blend"
done
rm "$encoder_dir/encode-alpha"
rmdir "$encoder_dir"
