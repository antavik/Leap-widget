#!/bin/sh
# One deliberate run, one folder of evidence: what was tested, on what commit
# and toolchain, how much was covered, and what the UI looked like. Exits with
# the run's own status.

set -eu

cd "$(dirname "$0")/.."

PACKAGE=LeapCore

stamp=$(date -u +%Y%m%d-%H%M%S)
hash=$(git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
# `git diff --quiet` misses untracked files; a half-finished test file is one.
[ -z "$(git status --porcelain)" ] || hash="$hash-dirty"

report="reports/$stamp-$hash"
mkdir -p "$report/results" "$report/coverage" \
         "$report/screenshots/diff" "$report/attachments"

status=0

# --- environment -------------------------------------------------------------

{
    echo "commit:   $(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "branch:   $(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)"
    echo "dirty:    $([ -z "$(git status --porcelain)" ] && echo no || echo yes)"
    echo "macOS:    $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "xcode:    $(xcodebuild -version | tr '\n' ' ')"
    echo "swift:    $(swift --version 2>&1 | head -1)"
    echo "arch:     $(uname -m)"
} > "$report/environment.txt"

# --- L0 ----------------------------------------------------------------------

l0_log="$report/results/l0.txt"
l0_status=0
for check in scripts/check-uninstall-paths.sh scripts/check-localization.sh \
             scripts/check-widget-options.sh scripts/check-test-plan.sh; do
    if ! "./$check" >> "$l0_log" 2>&1; then
        l0_status=1
    fi
done
[ "$l0_status" -eq 0 ] || status=1

# --- L1–L3 -------------------------------------------------------------------

# Separate steps, so a slow compile never reads as a slow suite.
swift build --package-path "$PACKAGE" --build-tests --enable-code-coverage \
    > "$report/results/build.txt" 2>&1 || status=1

test_log="$report/results/swift-test.txt"
LEAP_SCREENSHOTS_DIR="$PWD/$report/screenshots" \
LEAP_DIFF_DIR="$PWD/$report/screenshots/diff" \
swift test --package-path "$PACKAGE" \
    --skip-build \
    --enable-code-coverage \
    --xunit-output "$PWD/$report/results/results.xml" \
    --attachments-path "$PWD/$report/attachments" \
    > "$test_log" 2>&1 || status=1

# SwiftPM renames the file per testing library, so this globs.
results=$(ls "$report"/results/*.xml 2>/dev/null | tr '\n' ' ')

# Test-level only: a suite's skip line and the word in a test name both
# inflate a bare `grep -c skipped`.
skipped=$(grep -c 'Test .* skipped' "$test_log" 2>/dev/null || true)

# On a pinned toolchain a skip means the key is wrong, not that the layer is
# unavailable — so it has to be loud.
snapshot_skipped=no
if grep -q 'Suite "Snapshots".*skipped' "$test_log" 2>/dev/null; then
    snapshot_skipped=yes
fi

# --- coverage ----------------------------------------------------------------

bin=$(swift build --package-path "$PACKAGE" --show-bin-path 2>/dev/null)
profdata="$bin/codecov/default.profdata"
binary="$bin/LeapCorePackageTests.xctest/Contents/MacOS/LeapCorePackageTests"

if [ -f "$profdata" ] && [ -f "$binary" ]; then
    xcrun llvm-cov report "$binary" -instr-profile "$profdata" \
        -ignore-filename-regex='(Tests|\.build)/' \
        > "$report/coverage/summary.txt" 2>/dev/null || true
    xcrun llvm-cov export "$binary" -instr-profile "$profdata" --format=lcov \
        -ignore-filename-regex='(Tests|\.build)/' \
        > "$report/coverage/LeapCore.lcov" 2>/dev/null || true
else
    echo "coverage not measured: no profdata" > "$report/coverage/summary.txt"
fi

# --- contact sheet -----------------------------------------------------------

{
    echo '<!doctype html><meta charset="utf-8"><title>Leap renders</title>'
    echo '<style>body{font:13px -apple-system,sans-serif;margin:24px;background:#fff;color:#111}'
    echo 'figure{display:inline-block;margin:0 16px 24px 0;text-align:center}'
    echo 'img{border:1px solid #ddd;background:#fff}figcaption{margin-top:6px;color:#555}</style>'
    printf '<h1>%s</h1><p>%s</p>\n' "$stamp-$hash" "$(head -3 "$report/environment.txt" | tr '\n' ' ')"
    for image in "$report"/screenshots/*.png; do
        [ -e "$image" ] || continue
        name=$(basename "$image")
        printf '<figure><img src="screenshots/%s"><figcaption>%s</figcaption></figure>\n' \
            "$name" "${name%.png}"
    done
    if ls "$report"/screenshots/diff/*.png >/dev/null 2>&1; then
        echo '<h2>Differences</h2>'
        for image in "$report"/screenshots/diff/*.png; do
            name=$(basename "$image")
            printf '<figure><img src="screenshots/diff/%s"><figcaption>%s</figcaption></figure>\n' \
                "$name" "${name%.png}"
        done
    fi
} > "$report/contact-sheet.html"

# --- summary -----------------------------------------------------------------

renders=$(ls "$report"/screenshots/*.png 2>/dev/null | wc -l | tr -d ' ')

{
    echo "# Leap test report — $stamp-$hash"
    echo
    if [ "$status" -eq 0 ]; then
        echo "**Result: passed.**"
    else
        echo "**Result: FAILED.** See \`results/\`."
    fi
    if [ "$snapshot_skipped" = yes ]; then
        echo
        echo "**The golden layer reported skipped — this run has no UI net.**"
    fi
    echo
    echo '| Layer | Result |'
    echo '|---|---|'
    echo "| L0 consistency checks | $([ "$l0_status" -eq 0 ] && echo passed || echo FAILED) |"
    printf '| L1–L3 (`swift test`) | %s |\n' "$(grep -c 'Test run with' "$test_log" >/dev/null 2>&1 && tail -1 "$test_log" | sed 's/[^ -~]//g' | sed 's/^ *//')"
    echo "| Skipped tests reported | $skipped |"
    echo "| Renders captured | $renders |"
    echo
    echo '## Environment'
    echo
    echo '```'
    cat "$report/environment.txt"
    echo '```'
    echo
    echo '## Coverage'
    echo
    echo 'Scope: `LeapCore` only. `Leap` and `LeapWidget` are **not measured** here —'
    echo 'they have no SwiftPM test target; the L4 plan measures them under `xcodebuild`.'
    echo
    echo '```'
    tail -20 "$report/coverage/summary.txt"
    echo '```'
    echo
    echo '## Artefacts'
    echo
    echo "- \`results/\`: ${results:-none}"
    echo '- `screenshots/`: every render of this run, not only failures'
    echo '- `screenshots/diff/`: expected / actual / amplified diff, on failure only'
    echo '- `contact-sheet.html`: all renders on one page'
} > "$report/summary.md"

# `ln -sfn` onto a real directory drops a dangling link *inside* it instead of
# replacing it, so remove whatever is there first.
rm -rf reports/latest
ln -s "$(basename "$report")" reports/latest

echo "$report"
exit "$status"
