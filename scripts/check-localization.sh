#!/bin/sh
# Inside a package, a localized literal resolves against `Bundle.main` unless
# told otherwise – compiling, rendering correct English, and silently no longer
# localising. Three spellings, one per type:
#   String(localized:)        -> bundle: .module
#   Text("…") / Link("…")     -> bundle: .module
#   LocalizedStringResource() -> bundle: .atURL(Bundle.module.bundleURL)
#
# Every key found must also exist in the package's own catalogue.

set -eu

cd "$(dirname "$0")/.."

SOURCES=LeapCore/Sources/LeapCore
CATALOGUE=$SOURCES/Resources/Localizable.xcstrings

if [ ! -f "$CATALOGUE" ]; then
    echo "check-localization: no catalogue at $CATALOGUE" >&2
    exit 1
fi

found=$(mktemp)
keys=$(mktemp)
trap 'rm -f "$found" "$keys"' EXIT

# Format specifiers collapse to `%`, so a key written with interpolation in
# Swift compares equal to its catalogue spelling.
sed -n 's/^    "\(.*\)" : {$/\1/p' "$CATALOGUE" |
    sed 's/%[0-9]*\$*[@a-zA-Z]*/%/g' |
    sort -u > "$keys"

status=0

find "$SOURCES" -name '*.swift' |
    sort |
    while IFS= read -r file; do
        awk -v file="$file" -v found="$found" '
        # One record per file.
        BEGIN { RS = "\001" }

        # Reads the literal whose opening quote is at `i`; sets LITERAL_END.
        function readLiteral(text, i,    out, c, n) {
            n = length(text); i++; out = ""
            while (i <= n) {
                c = substr(text, i, 1)
                if (c == "\\" && substr(text, i + 1, 1) == "\"") { out = out "\""; i += 2; continue }
                if (c == "\\") { out = out c substr(text, i + 1, 1); i += 2; continue }
                if (c == "\"") { LITERAL_END = i; return out }
                out = out c; i++
            }
            LITERAL_END = n
            return out
        }

        # From just past the literal to the close paren of the enclosing call.
        function callSpan(text, from,    i, n, depth, c) {
            n = length(text); depth = 1; i = from
            while (i <= n) {
                c = substr(text, i, 1)
                if (c == "\"") { readLiteral(text, i); i = LITERAL_END + 1; continue }
                if (c == "(") depth++
                else if (c == ")") { depth--; if (depth == 0) return substr(text, from, i - from) }
                i++
            }
            return substr(text, from)
        }

        # Interpolations collapse to `%`, matching the catalogue key.
        function normalise(literal,    out, i, n, c, depth) {
            n = length(literal); out = ""
            for (i = 1; i <= n; i++) {
                c = substr(literal, i, 1)
                if (c == "\\" && substr(literal, i + 1, 1) == "(") {
                    depth = 0; i++
                    while (i <= n) {
                        c = substr(literal, i, 1)
                        if (c == "(") depth++
                        else if (c == ")") { depth--; if (depth == 0) break }
                        i++
                    }
                    out = out "%"
                    continue
                }
                out = out c
            }
            return out
        }

        function context(text, i,    from, prior) {
            from = i - 80; if (from < 1) from = 1
            prior = substr(text, from, i - from)
            gsub(/[ \t\r\n]+/, "", prior)
            return prior
        }

        function report(message) {
            printf "check-localization: %s: %s\n", file, message > "/dev/stderr"
            failed = 1
        }

        {
            text = $0
            n = length(text)
            isView = (text ~ /import SwiftUI/)
            i = 1

            while (i <= n) {
                c = substr(text, i, 1)

                if (c == "/" && substr(text, i + 1, 1) == "/") {
                    while (i <= n && substr(text, i, 1) != "\n") i++
                    continue
                }

                if (c != "\"") { i++; continue }

                literal = readLiteral(text, i)
                prior = context(text, i)
                kind = ""

                if (prior ~ /LocalizedStringResource\($/) kind = "resource"
                else if (prior ~ /String\(localized:$/) kind = "string"
                else if (isView && prior ~ /[^a-zA-Z]Text\($/) kind = "key"
                else if (isView && prior ~ /[^a-zA-Z]Link\($/) kind = "key"

                if (kind != "") {
                    span = callSpan(text, LITERAL_END + 1)
                    need = (kind == "resource") \
                        ? "bundle: .atURL(Bundle.module.bundleURL)" : "bundle: .module"

                    if (index(span, need) == 0)
                        report(sprintf("\"%s\" is missing %s", literal, need))

                    print normalise(literal) >> found
                }

                i = LITERAL_END + 1
            }

            # A bare literal assigned to a LocalizedStringResource carries no
            # bundle at all.
            if (text ~ /: *LocalizedStringResource *= *"/)
                report("a LocalizedStringResource is assigned a bare literal; construct it with LocalizedStringResource(_:bundle:)")
        }

        END { exit failed }
        ' "$file" || echo "$file" >> "$found.failures"
    done

if [ -f "$found.failures" ]; then
    rm -f "$found.failures"
    status=1
fi

missing=$(sort -u "$found" | while IFS= read -r key; do
    [ -n "$key" ] || continue
    grep -Fxq "$key" "$keys" || echo "$key"
done)

if [ -n "$missing" ]; then
    echo "check-localization: keys missing from $CATALOGUE:" >&2
    printf '%s\n' "$missing" >&2
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "check-localization: $(sort -u "$found" | grep -c . || true) localized keys agree with $CATALOGUE"
fi

exit "$status"
