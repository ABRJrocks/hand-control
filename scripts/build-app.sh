#!/bin/zsh
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_ROOT/dist/HandFlow.app"
CONTENTS_PATH="$APP_PATH/Contents"
SIGN_IDENTITY="${HANDFLOW_SIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="$(/usr/bin/security find-identity -v -p codesigning 2>/dev/null | /usr/bin/awk -F\" '/Apple Development/{print $2; exit}')"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
    SIGN_IDENTITY="-"
    echo "Warning: no Apple Development signing identity found; Accessibility approval may reset after rebuilds."
fi

RUNNING_PID="$(/usr/bin/pgrep -f "$APP_PATH/Contents/MacOS/HandFlow" | /usr/bin/head -n 1 || true)"
if [[ -n "$RUNNING_PID" ]]; then
    /bin/kill -TERM "$RUNNING_PID"
    for _ in {1..20}; do
        /bin/kill -0 "$RUNNING_PID" 2>/dev/null || break
        /bin/sleep 0.1
    done
fi

swift build --package-path "$PROJECT_ROOT" -c release
BIN_PATH="$(swift build --package-path "$PROJECT_ROOT" -c release --show-bin-path)"

if [[ -d "$APP_PATH" ]]; then
    /bin/rm -rf "$APP_PATH"
fi

/bin/mkdir -p "$CONTENTS_PATH/MacOS" "$CONTENTS_PATH/Resources"
/bin/cp "$BIN_PATH/HandFlow" "$CONTENTS_PATH/MacOS/HandFlow"
/bin/cp "$PROJECT_ROOT/Sources/HandFlow/Resources/Info.plist" "$CONTENTS_PATH/Info.plist"

/usr/bin/codesign \
    --force \
    --deep \
    --options runtime \
    --timestamp=none \
    --sign "$SIGN_IDENTITY" \
    --entitlements "$PROJECT_ROOT/Sources/HandFlow/Resources/HandFlow.entitlements" \
    "$APP_PATH"

echo "$APP_PATH"
