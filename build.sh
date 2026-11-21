#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

build_dir="$PWD/.build"
app="$PWD/CountryFlag.app"
sources=(Sources/CountryFlagApp.swift Sources/IPLocation.swift)

mkdir -p "$build_dir"

for architecture in arm64 x86_64; do
    xcrun swiftc -swift-version 6 -O -parse-as-library \
        -module-cache-path "$build_dir/module-cache" \
        -target "${architecture}-apple-macos13.0" \
        "${sources[@]}" -o "$build_dir/CountryFlag-$architecture"
done

xcrun lipo -create "$build_dir/CountryFlag-arm64" "$build_dir/CountryFlag-x86_64" \
    -output "$build_dir/CountryFlag"

mkdir -p "$app/Contents/MacOS"
install -m 755 "$build_dir/CountryFlag" "$app/Contents/MacOS/CountryFlag"
install -m 644 Info.plist "$app/Contents/Info.plist"

codesign --force --sign - "$app"
codesign --verify --strict "$app"
printf 'Готово. %s\n' "$app"
