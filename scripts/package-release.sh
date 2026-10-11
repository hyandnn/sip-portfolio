#!/bin/sh
# Create a downloadable preview without requiring a Developer ID certificate.
set -eu
app="build/Sipfolio.app"
binary="$app/Contents/MacOS/Sipfolio"
codesign --verify --deep --strict "$app"
architectures="$(lipo -archs "$binary")"
case " $architectures " in *" arm64 "*) ;; *) printf 'Missing Apple Silicon slice.\n' >&2; exit 1 ;; esac
case " $architectures " in *" x86_64 "*) ;; *) printf 'Missing Intel slice.\n' >&2; exit 1 ;; esac
xcrun vtool -show-build "$binary" | awk '
    /minos/ { if ($2 != "14.0") exit 1; slices++ }
    END { if (slices != 2) exit 1 }
' || { printf 'Unexpected deployment target; review supported macOS versions.\n' >&2; exit 1; }
version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist")"
case "$version" in ''|*[!0-9A-Za-z.-]*) printf 'Invalid version for release filename.\n' >&2; exit 1 ;; esac
output="build/dist"
mkdir -p "$output"
staging="$(mktemp -d build/.Sipfolio-release.XXXXXX)"
trap 'rm -rf "$staging"' EXIT HUP INT TERM
cp -R "$app" "$staging/Sipfolio.app"
ln -s /Applications "$staging/Applications"
cp packaging/INSTALL.txt "$staging/Read Me.txt"
cp LICENSE "$staging/License.txt"
cp THIRD_PARTY_NOTICES.md "$staging/ThirdPartyNotices.md"
dmg="Sipfolio-$version-universal.dmg"
archive="Sipfolio-$version-universal.zip"
hdiutil create -volname Sipfolio -srcfolder "$staging" -format UDZO -ov "$output/$dmg"
hdiutil verify "$output/$dmg"
ditto -c -k --sequesterRsrc --keepParent "$app" "$output/$archive"
(cd "$output" && shasum -a 256 "$dmg" "$archive" > SHA256SUMS.txt)
printf 'Created %s and %s (ad-hoc signed preview; not notarized).\n' "$output/$dmg" "$output/$archive"
