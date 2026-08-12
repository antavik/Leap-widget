#!/bin/sh
# G11: QuaterlyCore must declare zero package dependencies (DESIGN.md §6).
set -e
cd "$(dirname "$0")/.."

count=$(swift package --package-path QuaterlyCore dump-package \
    | python3 -c 'import json, sys; print(len(json.load(sys.stdin)["dependencies"]))')

if [ "$count" != "0" ]; then
    echo "error: QuaterlyCore declares $count package dependencies; G11 requires zero." >&2
    exit 1
fi
echo "G11 OK: QuaterlyCore declares zero package dependencies."
