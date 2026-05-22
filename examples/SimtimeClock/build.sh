#!/bin/bash
# Build SimtimeClock.app for iOS Simulator and install on a booted sim.
#
# Usage:
#   ./build.sh                 # build, install on first booted sim, launch
#   ./build.sh --udid <UDID>   # specify which sim
#   ./build.sh --no-launch     # just build + install
set -euo pipefail

UDID=""
DO_LAUNCH=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --udid) UDID="$2"; shift 2;;
        --no-launch) DO_LAUNCH=0; shift;;
        -h|--help) head -8 "$0"; exit 0;;
        *) echo "unknown: $1" >&2; exit 1;;
    esac
done

if [[ -z "$UDID" ]]; then
    UDID=$(xcrun simctl list devices booted 2>/dev/null | grep -oE "\([A-F0-9-]{36}\)" | head -1 | tr -d '()')
    if [[ -z "$UDID" ]]; then
        echo "no booted simulator - boot one first or pass --udid" >&2
        exit 1
    fi
fi

cd "$(dirname "$0")"
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
BUILD=.build/SimtimeClock.app
rm -rf "$BUILD"
mkdir -p "$BUILD"

echo "→ compiling Swift sources for iPhone Simulator (arm64)"
xcrun --sdk iphonesimulator swiftc \
    -target arm64-apple-ios17.0-simulator \
    -sdk "$SDK" \
    -emit-executable \
    -parse-as-library \
    -O \
    Sources/*.swift \
    -o "$BUILD/SimtimeClock"

cp Info.plist "$BUILD/"

echo "→ ad-hoc codesigning (sim doesn't enforce signature identity, but needs *something*)"
codesign --force --sign - --timestamp=none "$BUILD"

echo "→ installing on $UDID"
xcrun simctl install "$UDID" "$BUILD"

if [[ "$DO_LAUNCH" == 1 ]]; then
    xcrun simctl terminate "$UDID" io.simtime.clock 2>/dev/null || true
    echo "→ launching"
    xcrun simctl launch "$UDID" io.simtime.clock
fi

echo "→ done: io.simtime.clock installed on $UDID"
