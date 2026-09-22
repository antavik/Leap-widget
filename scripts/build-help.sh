#!/bin/sh
# Builds `docs/manual` into an Apple Help Book – `Leap.help` – and indexes it
# with `hiutil`, so Help Viewer works offline and the Help menu's search field
# finds the manual's own text, not just menu titles.
#
# Run by `make project`, before XcodeGen: the book has to exist on disk for the
# generated project to reference it as a resource.

set -eu

cd "$(dirname "$0")/.."

SOURCE=docs/manual
TEMPLATE=scripts/help
OUT=${1:-build/help}
BOOK=$OUT/Leap.help
LPROJ=$BOOK/Contents/Resources/en.lproj

# Kept in step with Leap/Info.plist's CFBundleHelpBookName by
# scripts/check-help.sh – Help Viewer finds the book by this identifier.
IDENTIFIER=com.antavik.leap.help
TITLE="Leap Help"
VERSION=$(sed -n 's/^MARKETING_VERSION = //p' Config/Base.xcconfig | tr -d ' ')

# The system Python: the converter is written against 3.9 so a build needs
# nothing installed.
PYTHON=/usr/bin/python3

rm -rf "$BOOK"
mkdir -p "$LPROJ"

"$PYTHON" scripts/md2help.py --source "$SOURCE" --out "$LPROJ" --book-title "$TITLE"

cp "$TEMPLATE/style.css" "$LPROJ/style.css"

# Screenshots are optional while the manual is still being illustrated; the
# pages show their alt text as a caption until the files land.
if ls "$SOURCE"/assets/*.png >/dev/null 2>&1; then
    mkdir -p "$LPROJ/assets"
    cp "$SOURCE"/assets/*.png "$LPROJ/assets/"
    shots=$(ls -1 "$SOURCE"/assets/*.png | wc -l | tr -d ' ')
else
    shots=0
fi

cat > "$BOOK/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleIdentifier</key>
	<string>$IDENTIFIER</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>$TITLE</string>
	<key>CFBundlePackageType</key>
	<string>BNDL</string>
	<key>CFBundleShortVersionString</key>
	<string>$VERSION</string>
	<key>CFBundleSignature</key>
	<string>hbwr</string>
	<key>HPDBookAccessPath</key>
	<string>index.html</string>
	<key>HPDBookIndexPath</key>
	<string>search.helpindex</string>
	<key>HPDBookTitle</key>
	<string>$TITLE</string>
	<key>HPDBookType</key>
	<string>3</string>
</dict>
</plist>
PLIST

# `-I corespotlight` is the index Help Viewer's search field reads on macOS 10.7
# and later. `-a` indexes the section anchors, so a hit opens at the right
# heading; `-g` writes a summary per page for the result list; `-s en` supplies
# English stop words.
/usr/bin/hiutil -Cagf "$LPROJ/search.helpindex" -I corespotlight -s en -l en "$LPROJ"

pages=$(ls -1 "$LPROJ"/*.html | wc -l | tr -d ' ')
echo "build-help: $BOOK – $pages pages, $shots screenshots, indexed"
