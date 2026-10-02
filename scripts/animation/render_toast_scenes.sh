#!/bin/bash
# Rebuild six movies, stills and editable scenes, one scene at a time.
set -euo pipefail
cd "$(dirname "$0")/../.."
output="${1:-/tmp/PetitChef-toast-scenes}"
mode="${2:-render}"
case "$mode" in render|encode-only|preview-only) ;; *) echo 'Mode: render, encode-only or preview-only' >&2; exit 2 ;; esac
blender_bin="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
if [[ "$mode" != encode-only ]]; then
    "$blender_bin" -b --python-exit-code 1 --python scripts/animation/toast_scenes.py -- "$output" --preview-only
    "$blender_bin" -b --python-exit-code 1 --python scripts/animation/validate_toast_scenes.py -- "$output"
    if [[ "$mode" == preview-only ]]; then exit 0; fi
fi
encoder_dir="$(mktemp -d /tmp/PetitChef-alpha.XXXXXX)"
trap 'find "$encoder_dir" -type f -delete; rmdir "$encoder_dir"' EXIT
swiftc scripts/animation/encode_alpha.swift -o "$encoder_dir/encode-alpha"
assets='Petit Chef/Resources/Animations'
sources='docs/design/animation-pilot/scenes'
mkdir -p "$assets" "$sources"
for name in toast-preheat toast-cutting toast-building toast-baking toast-seasoning toast-plating; do
    if [[ -n "${3:-}" && "$name" != "$3" ]]; then continue; fi
    if [[ "$mode" == render ]]; then
        "$blender_bin" -b --python-exit-code 1 --python scripts/animation/toast_scenes.py -- "$output" --scene "$name"
    fi
    "$encoder_dir/encode-alpha" "$output/$name" "$encoder_dir/$name.mov" 24
    cp "$encoder_dir/$name.mov" "$assets/$name.mov"
    cp "$output/$name/start.png" "$assets/$name-start.png"
    cp "$output/$name/poster.png" "$assets/$name-poster.png"
    cp "$output/$name/$name.blend" "$sources/$name.blend"
    if [[ "$mode" == render && "${PETITCHEF_KEEP_FRAMES:-0}" != 1 ]]; then
        find "$output/$name" -type f -name 'frame_[0-9][0-9][0-9][0-9].png' -delete
    fi
done
