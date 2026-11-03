#!/bin/sh
# The manual is spread over four places that cannot see each other: the
# Markdown in docs/manual, the screenshot list in docs/manual/assets/README.md,
# the book identifier in scripts/build-help.sh, and the two Help Book keys in
# Leap/Info.plist. A broken link or a renamed screenshot only shows up in Help
# Viewer, long after the build passed – so compare them here.

set -eu

cd "$(dirname "$0")/.."

MANUAL=docs/manual
ASSETS=$MANUAL/assets
INDEX=$MANUAL/index.md
BUILD=scripts/build-help.sh
PLIST=Leap/Info.plist
MENU=Leap/AppDelegate+Menu.swift

status=0

fail() {
    echo "check-help: $1" >&2
    status=1
}

plist_string() {
    /usr/bin/plutil -extract "$1" raw -o - "$PLIST" 2>/dev/null || echo "«missing»"
}

contains() {
    printf '%s\n' "$2" | grep -Fxq "$1"
}

# 1. The book identifier the app asks Help Viewer for is the one the book is
#    built with, and the folder key matches the bundle's name.
identifier=$(sed -n 's/^IDENTIFIER=//p' "$BUILD" | tr -d ' ')
name=$(plist_string CFBundleHelpBookName)
folder=$(plist_string CFBundleHelpBookFolder)

if [ "$name" != "$identifier" ]; then
    fail "$PLIST CFBundleHelpBookName is \"$name\", $BUILD builds \"$identifier\""
fi

if [ "$folder" != "Leap.help" ]; then
    fail "$PLIST CFBundleHelpBookFolder is \"$folder\", expected \"Leap.help\""
fi

# 2. The Help menu still has an item wired to showHelp:, which is what opens
#    the book and what AppKit's search field searches.
if ! grep -q 'showHelp' "$MENU"; then
    fail "$MENU has no showHelp: menu item – Help ▸ Leap Widget Manual would be gone"
fi

pages=$(ls -1 "$MANUAL"/*.md | sed 's|.*/||' | sort)

# 3. Every page link resolves, and every page is reachable from index.md.
# `grep -o`, never `sed`: a greedy `.*](` keeps only the *last* link on a line,
# so a broken one beside a good one went unreported.
for page in $pages; do
    targets=$(grep -oE '\]\([a-z0-9-]+\.md' "$MANUAL/$page" | sed 's/^](//' | sort -u)

    for target in $targets; do
        if [ ! -f "$MANUAL/$target" ]; then
            fail "$page links to $target, which does not exist"
        fi
    done
done

linked=$(grep -oE '\]\([a-z0-9-]+\.md\)' "$INDEX" | sed 's/^](//; s/)$//' | sort -u)

for page in $pages; do
    if [ "$page" != "index.md" ] && ! contains "$page" "$linked"; then
        fail "$page is not linked from $INDEX – Help Viewer would leave it orphaned"
    fi
done

# 4. Screenshots: every one a page asks for is described in the assets
#    read-me, and the read-me lists nothing the manual never shows.
referenced=$(grep -ho 'assets/[a-z0-9-]*\.png' "$MANUAL"/*.md | sed 's|assets/||' | sort -u)
described=$(grep -o '`[a-z0-9-]*\.png`' "$ASSETS/README.md" | tr -d '`' | sort -u)

for shot in $referenced; do
    if ! contains "$shot" "$described"; then
        fail "$shot is used by the manual but missing from $ASSETS/README.md"
    fi
done

for shot in $described; do
    if ! contains "$shot" "$referenced"; then
        fail "$shot is listed in $ASSETS/README.md but no page shows it"
    fi
done

if [ "$status" -eq 0 ]; then
    missing=0
    for shot in $referenced; do
        if [ ! -f "$ASSETS/$shot" ]; then
            missing=$((missing + 1))
        fi
    done

    printf 'check-help: %s pages, %s screenshots (%s still to be captured), book id %s\n' \
        "$(printf '%s\n' "$pages" | wc -l | tr -d ' ')" \
        "$(printf '%s\n' "$referenced" | wc -l | tr -d ' ')" \
        "$missing" "$identifier"
fi

exit "$status"
