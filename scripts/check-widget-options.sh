#!/bin/sh
# No widget type may be an `AppEnum` or `AppEntity`: on macOS 26+ those
# resolve through `linkd`, which refuses an ad-hoc signed bundle, so a saved
# choice reaches the widget as nil.

set -eu

cd "$(dirname "$0")/.."

# Declarations only, not the comments that explain why.
if grep -n -E '^[^/]*:.*\b(AppEnum|AppEntity)\b' LeapWidget/*.swift >&2; then
    echo "check-widget-options: widget parameters must be String or Bool, not AppEnum/AppEntity" >&2
    exit 1
fi

echo "check-widget-options: no AppEnum/AppEntity in the widget"
