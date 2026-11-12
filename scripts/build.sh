#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

app=build/TSQuickLook.app
appex=$app/Contents/PlugIns/TSQuickLookPreview.appex

rm -rf build
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$appex/Contents/MacOS"
cp Resources/App-Info.plist "$app/Contents/Info.plist"
cp Resources/Extension-Info.plist "$appex/Contents/Info.plist"
cp Resources/Extension.entitlements "$app/Contents/Resources/Extension.entitlements"

xcrun actool Icon/TSQuickLook.icon --compile "$app/Contents/Resources" --app-icon TSQuickLook \
    --platform macosx --minimum-deployment-target 13.0 \
    --output-partial-info-plist /dev/null >/dev/null 2>&1 ||
    echo "warning: app icon skipped, actool needs Xcode 26 or later" >&2

target="$(uname -m)-apple-macos13.0"
swiftc -O -parse-as-library -module-name TSQuickLook -target "$target" \
    -o "$app/Contents/MacOS/TSQuickLook" Sources/App/*.swift Sources/Shared/*.swift
swiftc -O -parse-as-library -application-extension -module-name TSQuickLookPreview \
    -target "$target" -Xlinker -e -Xlinker _NSExtensionMain \
    -o "$appex/Contents/MacOS/TSQuickLookPreview" Sources/Extension/*.swift Sources/Shared/*.swift

codesign -f -s - --entitlements Resources/Extension.entitlements "$appex"
codesign -f -s - "$app"
echo "Built $app"
