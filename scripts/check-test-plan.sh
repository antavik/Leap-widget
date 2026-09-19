#!/bin/sh
# The L4 wiring, which no build failure would tell you about.
#
# A scheme whose `test:` block lists no targets generates an empty
# `<Testables>`: `xcodebuild test` then exits 0 having run nothing, and the UI
# layer disappears from CI without a red mark. So does a plan that stops
# listing a target.
#
# The plan is also the only place `LEAP_UI_TEST_SAFE_MODE` is set. Without it,
# `testConfirmingUninstallIsBlockedBySafeMode` clicks a real Uninstall button
# and trashes the developer's own machine. It is an interlock, not a setting.

set -eu

cd "$(dirname "$0")/.."

SPEC=project.yml
PLAN=Leap.xctestplan
SAFE_MODE_KEY=LEAP_UI_TEST_SAFE_MODE
SCHEME=Leap

for file in "$SPEC" "$PLAN"; do
    if [ ! -f "$file" ]; then
        echo "check-test-plan: no $file" >&2
        exit 1
    fi
done

# Every test target the spec declares, whatever its name.
declared=$(awk '
    /^targets:/ { section = "targets"; next }
    /^[a-zA-Z]/ { section = "" }
    section == "targets" && /^  [A-Za-z_][A-Za-z0-9_]*:/ {
        name = $1; sub(":", "", name); next
    }
    section == "targets" && /^    type: bundle\.(ui-testing|unit-test)/ { print name }
' "$SPEC" | sort -u)

# Read as XcodeGen reads it: `schemes.<SCHEME>.test.{targets,testPlans[].path}`.
scheme_field() {
    awk -v scheme="$SCHEME" -v field="$1" '
        /^schemes:/ { top = "schemes"; next }
        /^[a-zA-Z]/ { top = "" }
        top != "schemes" { next }
        /^  [A-Za-z_][A-Za-z0-9_]*:/ { current = $1; sub(":", "", current); block = ""; next }
        /^    [a-zA-Z]+:/ { block = $1; sub(":", "", block); entry = ""; next }
        /^      [a-zA-Z]+:/ { entry = $1; sub(":", "", entry); next }
        current == scheme && block == "test" && entry == field && /^ *- / {
            print ($2 == "path:") ? $3 : $2
        }
    ' "$SPEC" | sort -u
}

status=0

scheme_targets=$(scheme_field targets)
scheme_plans=$(scheme_field testPlans)

if [ -z "$declared" ]; then
    echo "check-test-plan: $SPEC declares no test target" >&2
    status=1
fi

if [ "$declared" != "$scheme_targets" ]; then
    echo "check-test-plan: the $SCHEME scheme's test targets do not match the spec's test targets" >&2
    printf -- '--- declared in %s\n%s\n--- schemes.%s.test.targets\n%s\n' \
        "$SPEC" "$declared" "$SCHEME" "$scheme_targets" >&2
    status=1
fi

if [ "$scheme_plans" != "$PLAN" ]; then
    echo "check-test-plan: schemes.$SCHEME.test.testPlans does not reference $PLAN (found: ${scheme_plans:-none})" >&2
    status=1
fi

# Same targets, or they run under no plan options — safe mode included.
for target in $declared; do
    if ! grep -q "\"name\" *: *\"$target\"" "$PLAN"; then
        echo "check-test-plan: $PLAN does not list the test target $target" >&2
        status=1
    fi
done

# The interlock itself: the key, and the value the app compares against.
if ! grep -q "\"$SAFE_MODE_KEY\"" "$PLAN"; then
    echo "check-test-plan: $PLAN no longer sets $SAFE_MODE_KEY — the uninstall UI test would run unguarded" >&2
    status=1
elif ! grep -A1 "\"$SAFE_MODE_KEY\"" "$PLAN" | grep -q '"value" *: *"1"'; then
    echo "check-test-plan: $PLAN sets $SAFE_MODE_KEY to something other than \"1\"" >&2
    status=1
fi

# …and the side that reads it, so a rename cannot pass by agreeing with itself.
if ! grep -rq "\"$SAFE_MODE_KEY\"" Leap LeapUITests; then
    echo "check-test-plan: nothing in Leap/ or LeapUITests/ reads $SAFE_MODE_KEY" >&2
    status=1
fi

if [ "$status" -eq 0 ]; then
    echo "check-test-plan: $SCHEME runs $(echo "$declared" | wc -l | tr -d ' ') test target(s) through $PLAN, with $SAFE_MODE_KEY armed"
fi

exit "$status"
