#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

app=build/TSQuickLook.app
appex=$app/Contents/PlugIns/TSQuickLookPreview.appex

rm -rf build
mkdir -p "$app/Contents/MacOS" "$appex/Contents/MacOS"
cp Resources/App-Info.plist "$app/Contents/Info.plist"
cp Resources/Extension-Info.plist "$appex/Contents/Info.plist"

clang -o "$app/Contents/MacOS/TSQuickLook" Sources/App/main.c
swiftc -O -parse-as-library -application-extension -module-name TSQuickLookPreview \
    -target "$(uname -m)-apple-macos13.0" -Xlinker -e -Xlinker _NSExtensionMain \
    -o "$appex/Contents/MacOS/TSQuickLookPreview" Sources/Extension/*.swift Sources/Shared/*.swift

codesign -f -s - --entitlements Resources/Extension.entitlements "$appex"
codesign -f -s - "$app"
echo "Built $app"
