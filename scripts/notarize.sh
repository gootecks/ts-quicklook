#!/bin/sh
set -eu

app="$1"
dir="$(mktemp -d)"
trap 'rm -rf "$dir"' EXIT

if [ -n "${NOTARY_PROFILE:-}" ]; then
    set -- --keychain-profile "$NOTARY_PROFILE"
else
    set -- --key "$APPLE_API_KEY" --key-id "$APPLE_API_KEY_ID" --issuer "$APPLE_API_ISSUER"
fi

ditto -c -k --keepParent "$app" "$dir/notarize.zip"
echo "Notarizing $app (usually a few minutes)"
xcrun notarytool submit "$dir/notarize.zip" "$@" --wait --output-format json | tee "$dir/result.json"
if ! grep -q '"status" *: *"Accepted"' "$dir/result.json"; then
    id="$(grep -o '"id" *: *"[^"]*"' "$dir/result.json" | head -1 | cut -d'"' -f4)"
    [ -z "$id" ] || xcrun notarytool log "$id" "$@" || true
    exit 1
fi

xcrun stapler staple "$app"
spctl --assess --type execute --verbose "$app"
