#!/bin/sh
# The widget's `AppEnum`s and the package's plain enums are two spellings of
# one thing, and nothing in the compiler notices when they drift. The raw
# values are persisted widget configuration: a dropped or renamed case silently
# resets someone's widget.
#
# Also checks that every `ClickPreset` has a `ClickAction`, and the reverse
# apart from `.doNothing`.

set -eu

cd "$(dirname "$0")/.."

CORE=LeapCore/Sources/LeapCore/Widget/WidgetOptions.swift
WIDGET=LeapWidget/ConfigurationIntent.swift
PRESETS=LeapCore/Sources/LeapCore/Widget/ClickPreset.swift

# Case names of `enum <name>`, in declaration order, one per line.
cases() {
    awk -v name="$2" '
        $0 ~ "enum " name ":" { inside = 1; next }
        inside && /^}/ { exit }
        # Declarations only: a switch arm (`case .a: …`) is not a case list.
        inside && /^ *case [A-Za-z_][A-Za-z0-9_]*(, *[A-Za-z_][A-Za-z0-9_]*)* *$/ {
            line = $0
            sub(/^ *case /, "", line)
            gsub(/ /, "", line)
            n = split(line, parts, ",")
            for (i = 1; i <= n; i++) if (parts[i] != "") print parts[i]
        }
    ' "$1"
}

status=0

for option in Companion DisplayedMonth FirstWeekday MonthNumberDisplay ClickAction; do
    core=$(cases "$CORE" "$option")
    widget=$(cases "$WIDGET" "$option")

    if [ -z "$core" ] || [ -z "$widget" ]; then
        echo "check-widget-options: $option not found in both files" >&2
        status=1
        continue
    fi

    if [ "$core" != "$widget" ]; then
        echo "check-widget-options: $option differs between $CORE and $WIDGET" >&2
        printf -- '--- %s\n%s\n--- %s\n%s\n' "$CORE" "$core" "$WIDGET" "$widget" >&2
        status=1
    fi
done

presets=$(cases "$PRESETS" ClickPreset | sort)
actions=$(cases "$CORE" ClickAction | grep -v '^doNothing$' | sort)

if [ "$presets" != "$actions" ]; then
    echo "check-widget-options: ClickPreset and ClickAction (minus doNothing) disagree" >&2
    printf -- '--- ClickPreset\n%s\n--- ClickAction\n%s\n' "$presets" "$actions" >&2
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "check-widget-options: 5 option enums and the click presets agree"
fi

exit "$status"
