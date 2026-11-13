#!/bin/sh
set -eu

version="$1"
notes="$2"
changelog="${3:-CHANGELOG.md}"

awk '
    /^## \[Unreleased\]/ { n = 1; next }
    /^## / { n = 0 }
    n && NF { while (blank > 0 && started) { print ""; blank-- } blank = 0; started = 1; print; next }
    n && started { blank++ }
' "$changelog" >"$notes"
[ -s "$notes" ] || {
    echo "CHANGELOG.md has no entries under [Unreleased]" >&2
    exit 1
}

awk -v heading="## [$version] - $(date -u +%Y-%m-%d)" '
    /^## \[Unreleased\]/ && !done { print; print ""; print heading; done = 1; next }
    { print }
' "$changelog" >"$changelog.tmp"
mv "$changelog.tmp" "$changelog"
