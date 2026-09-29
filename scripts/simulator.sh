#!/bin/bash
# Same entry point for a collaborator's Mac and CI. No Apple account required.
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:-run}"
case "$mode" in run|build|test) ;; *) echo 'Usage: ./scripts/simulator.sh [run|build|test]' >&2; exit 2 ;; esac
xcode_major="$(xcodebuild -version | awk '/^Xcode / {split($2, parts, "."); print parts[1]}')"
if [[ "${xcode_major:-0}" -lt 27 ]]; then
    echo 'Xcode 27 ou plus récent requis. Sélectionnez-le dans Xcode > Settings > Locations > Command Line Tools.' >&2
    exit 1
fi
if ! xcrun metal --version >/dev/null 2>&1; then
    echo 'Installer Metal Toolchain : xcodebuild -downloadComponent MetalToolchain' >&2
    exit 1
fi
# SIMULATOR_ID can explicitly select another installed iPhone running iOS 27+.
if [[ -z "${SIMULATOR_ID:-}" ]]; then
    SIMULATOR_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, sys
candidates = []
for runtime, devices in json.load(sys.stdin)["devices"].items():
    if ".iOS-" not in runtime:
        continue
    version = int(runtime.split(".iOS-")[1].split("-")[0])
    if version < 27:
        continue
    for device in devices:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            candidates.append(device)
candidates.sort(key=lambda d: (d["state"] != "Booted", d["name"] != "iPhone 18 Pro", d["name"]))
if not candidates:
    sys.exit("Installer un simulateur iPhone iOS 27 dans Xcode > Settings > Components.")
print(candidates[0]["udid"])
')"
fi
# Keep build products out of Documents/iCloud (Finder attributes break ad-hoc signing).
derived="${PETITCHEF_DERIVED_DATA:-${TMPDIR:-/tmp}/PetitChefDerivedData}"
args=(-project 'Petit Chef.xcodeproj' -scheme 'Petit Chef' -configuration Debug
    -destination "platform=iOS Simulator,id=$SIMULATOR_ID" -derivedDataPath "$derived"
    'CODE_SIGN_IDENTITY=-' 'DEVELOPMENT_TEAM=')
if [[ "$mode" == test ]]; then
    args+=(-parallel-testing-enabled NO -collect-test-diagnostics never
        -test-timeouts-enabled YES -maximum-test-execution-time-allowance 180
        '-skip-testing:Petit ChefUITests/Petit_ChefUITests/testSystemTimerAuthorizationAndBackground')
    if [[ -n "${PETITCHEF_TEST_RESULTS:-}" ]]; then args+=(-resultBundlePath "$PETITCHEF_TEST_RESULTS"); fi
    xcodebuild "${args[@]}" test
else
    xcodebuild "${args[@]}" build
    if [[ "$mode" == run ]]; then
        state="$(xcrun simctl list devices booted --json)"
        if [[ "$state" != *"$SIMULATOR_ID"* ]]; then xcrun simctl boot "$SIMULATOR_ID"; fi
        xcrun simctl bootstatus "$SIMULATOR_ID" -b
        xcrun simctl install "$SIMULATOR_ID" "$derived/Build/Products/Debug-iphonesimulator/Petit Chef.app"
        xcrun simctl launch --terminate-running-process "$SIMULATOR_ID" com.rafael.Petit-Chef
        xcode_app="$(xcode-select -p)/../Applications/DeviceHub.app"
        if [[ -d "$xcode_app" ]]; then open "$xcode_app"; else open -a Simulator; fi
    fi
fi
