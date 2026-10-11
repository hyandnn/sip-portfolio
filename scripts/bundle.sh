#!/bin/sh
set -eu
configuration="${1:-debug}"
bin_path="${2:-$(swift build -c "$configuration" --show-bin-path)}"
if [ ! -f "$bin_path/Sipfolio" ] || [ ! -d "$bin_path/Sipfolio_Sipfolio.bundle" ]; then
    printf 'Missing executable or resources; build the selected configuration first.\n' >&2
    exit 1
fi
mkdir -p build
staging="$(mktemp -d build/.Sipfolio-bundle.XXXXXX)"
trap 'rm -rf "$staging"' EXIT HUP INT TERM
app_root="$staging/Sipfolio.app"
mkdir -p "$app_root/Contents/MacOS" "$app_root/Contents/Resources"
cp "$bin_path/Sipfolio" "$app_root/Contents/MacOS/Sipfolio"
chmod +x "$app_root/Contents/MacOS/Sipfolio"
cp packaging/Info.plist "$app_root/Contents/Info.plist"
cp -R "$bin_path/Sipfolio_Sipfolio.bundle" "$app_root/Contents/Resources/"
cp packaging/AppIcon.icns "$app_root/Contents/Resources/AppIcon.icns"
plutil -lint "$app_root/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$app_root"
codesign --verify --deep --strict "$app_root"
rm -rf build/Sipfolio.app
mv "$app_root" build/Sipfolio.app
printf 'Built build/Sipfolio.app\n'
