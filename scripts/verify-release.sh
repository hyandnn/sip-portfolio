#!/bin/sh
# Inspect and launch the archived app using only an isolated temporary collection.
set -eu
release_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' packaging/Info.plist)"
archive="build/dist/Sipfolio-$release_version-universal.zip"
staging="$(mktemp -d build/.Sipfolio-package-check.XXXXXX)"
trap 'rm -rf "$staging"' EXIT HUP INT TERM
ditto -x -k "$archive" "$staging"
app="$staging/Sipfolio.app"
codesign --verify --deep --strict "$app"
plutil -lint "$app/Contents/Info.plist"
mode="${1:-app-shell}"
case "$mode" in
    app-shell) "$app/Contents/MacOS/Sipfolio" --data-directory "$staging/data" --verify-app-shell "$staging/app-shell.json" ;;
    --resources-only) "$app/Contents/MacOS/Sipfolio" --verify-bundle-resources "$staging/app-shell.json" ;;
    *) printf 'Unknown verification mode.\n' >&2; exit 1 ;;
esac
python3 - "$staging" "$mode" <<'PY'
from pathlib import Path
import json
import sys

root = Path(sys.argv[1])
report = json.loads((root / 'app-shell.json').read_text())
assert report['bundleIdentifier'] == 'com.merci.sipfolio'
assert report['hasBundledIcon'] and report['hasPixelFont']
if sys.argv[2] == 'app-shell':
    assert report['activationPolicy'] == 0 and report['hasApplicationIcon']
else:
    assert report['hasDecodedIcon']
app = root / 'Sipfolio.app'
assert len(list(app.rglob('fusion-pixel-12px-proportional-zh_hans.otf'))) == 1
assert list(app.rglob('OFL.txt'))
assert not any('SipfolioTestSupport' in str(p) or p.name in {'hendricks.jpg', 'gin-tonic.jpg'} for p in app.rglob('*'))
print('Archived executable and bundled resources verified; mode: ' + sys.argv[2])
PY
(cd build/dist && shasum -a 256 -c SHA256SUMS.txt)
