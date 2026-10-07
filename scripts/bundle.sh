#!/bin/sh
set -eu
configuration="${1:-debug}"
app_root="build/Sipfolio.app"
mkdir -p "$app_root/Contents/MacOS" "$app_root/Contents/Resources"
cp ".build/$configuration/Sipfolio" "$app_root/Contents/MacOS/Sipfolio"
chmod +x "$app_root/Contents/MacOS/Sipfolio"
cp packaging/Info.plist "$app_root/Contents/Info.plist"
if [ -d ".build/$configuration/Sipfolio_Sipfolio.bundle" ]; then
    cp -R ".build/$configuration/Sipfolio_Sipfolio.bundle" "$app_root/Contents/Resources/"
fi
if [ -f packaging/AppIcon.icns ]; then
    cp packaging/AppIcon.icns "$app_root/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$app_root"
printf 'Built %s\n' "$app_root"
