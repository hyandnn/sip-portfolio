#!/bin/sh
# Honor explicit paths, then the selected full Xcode, then the standard install.
set -eu
is_xcode() {
    [ -n "$1" ] && [ -x "$1/usr/bin/xcodebuild" ] && [ -d "$1/Platforms/MacOSX.platform" ]
}
explicit="${XCODE_DIR:-${DEVELOPER_DIR:-}}"
if [ -n "$explicit" ]; then
    if is_xcode "$explicit"; then printf '%s\n' "$explicit"; exit 0; fi
    printf 'The specified developer directory is not a full Xcode installation.\n' >&2
    exit 1
fi
selected="$(xcode-select -p 2>/dev/null || true)"
if is_xcode "$selected"; then printf '%s\n' "$selected"; exit 0; fi
standard="/Applications/Xcode.app/Contents/Developer"
if is_xcode "$standard"; then printf '%s\n' "$standard"; exit 0; fi
exit 1
