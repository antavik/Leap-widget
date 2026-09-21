#!/bin/sh
# Every copy of the uninstall path list must say the same thing; the app, the
# read-me and the Makefile are exercised in completely different ways.
#
# Uninstall.swift is canonical. Only the paths under ~/Library are compared –
# the app bundle is spelled differently in each source.

set -eu

cd "$(dirname "$0")/.."

CANONICAL=LeapCore/Sources/LeapCore/Uninstall/Uninstall.swift
SOURCES="README.md Makefile"

# `library.appending(components: "Preferences", "…plist")` becomes
# `Library/Preferences/…plist`.
canonical_paths() {
    sed -n 's/.*library\.appending(components: \(.*\)).*/\1/p' "$CANONICAL" |
        tr -d '"' |
        sed 's/, */\//g; s|^|Library/|' |
        sort
}

# Any shell-ish spelling: `~/Library/…`, `"$HOME/…"`, `"$(HOME)/…"`.
documented_paths() {
    grep -o 'Library/[A-Za-z ]*/com\.antavik\.leap[A-Za-z.]*' "$1" | sort -u
}

expected=$(canonical_paths)

if [ -z "$expected" ]; then
    echo "check-uninstall-paths: found no paths in $CANONICAL – has removalPaths changed shape?" >&2
    exit 1
fi

status=0

for source in $SOURCES; do
    actual=$(documented_paths "$source")

    if [ "$expected" = "$actual" ]; then
        continue
    fi

    echo "check-uninstall-paths: $source disagrees with $CANONICAL" >&2
    printf '%s\n' "--- $CANONICAL" >&2
    printf '%s\n' "$expected" >&2
    printf '%s\n' "--- $source" >&2
    printf '%s\n' "$actual" >&2
    status=1
done

if [ "$status" -eq 0 ]; then
    echo "check-uninstall-paths: $(echo "$expected" | wc -l | tr -d ' ') paths agree across $CANONICAL, $SOURCES"
fi

exit "$status"
