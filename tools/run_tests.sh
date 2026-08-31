#!/usr/bin/env bash
#
# Runs every headless smoke suite in tools/ and reports a summary.
#
# Used by both CI (.github/workflows/release.yml) and local development. On
# Windows, run it from Git Bash. Set GODOT to point at a specific binary:
#
#     GODOT=/c/path/to/godot.exe tools/run_tests.sh
#
# Exit code is 0 only if every suite passes.
#
set -uo pipefail

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."

if ! command -v "$GODOT" >/dev/null 2>&1; then
    echo "error: godot not found (set GODOT to the binary path)" >&2
    exit 127
fi

echo "Godot: $("$GODOT" --version)"

# A clean checkout has no .godot/ cache, so the first run would otherwise pay
# the import cost inside a suite and could trip its watchdog.
if [ ! -d ".godot" ]; then
    echo "No .godot/ cache - importing resources first (this takes a minute)..."
    "$GODOT" --headless --import --quit >/dev/null 2>&1 || true
fi

pass=0
fail=0
failed_suites=()

run_suite() {
    local script="$1"
    local name
    name="$(basename "$script" .gd)"
    local output
    output="$("$GODOT" --headless --path . -s "$script" 2>&1)"
    local code=$?
    local summary
    summary="$(printf '%s\n' "$output" | grep -E '\] (passed|FAILED)' | head -1)"

    # A GDScript runtime error does not always abort the whole call stack: an
    # invalid call aborts only the enclosing function, so _init() can carry on
    # and reach finish(), reporting success despite the error. The exit code
    # cannot see that, so treat any SCRIPT ERROR as a failure on its own.
    if printf '%s\n' "$output" | grep -q 'SCRIPT ERROR'; then
        printf '  FAIL  %-28s script error (exit was %d)\n' "$name" "$code"
        printf '%s\n' "$output" | grep -A2 'SCRIPT ERROR' | head -6 | sed 's/^/          /'
        fail=$((fail + 1))
        failed_suites+=("$name")
        return
    fi

    if [ $code -eq 0 ]; then
        printf '  ok    %-28s %s\n' "$name" "$summary"
        pass=$((pass + 1))
    else
        printf '  FAIL  %-28s exit=%d %s\n' "$name" "$code" "$summary"
        printf '%s\n' "$output" | grep -E '  FAIL \[' | sed 's/^/          /'
        fail=$((fail + 1))
        failed_suites+=("$name")
    fi
}

echo
echo "== smoke suites =="
for script in tools/smoke_*.gd; do
    [ -e "$script" ] || continue
    run_suite "$script"
done

# The harness itself is load-bearing: a regression here would make every suite
# above pass silently, which is exactly the bug this replaced. Each fixture
# asserts its own expected exit code.
echo
echo "== harness self-test =="
declare -A expected=( [pass]=0 [failing]=1 [nochecks]=1 [crash]=1 )
for fixture in pass failing nochecks crash; do
    "$GODOT" --headless --path . -s "tools/harness_selftest/$fixture.gd" >/dev/null 2>&1
    code=$?
    want="${expected[$fixture]}"
    if [ "$code" -eq "$want" ]; then
        printf '  ok    %-28s exit=%d (expected)\n' "$fixture" "$code"
        pass=$((pass + 1))
    else
        printf '  FAIL  %-28s exit=%d, expected %d\n' "$fixture" "$code" "$want"
        fail=$((fail + 1))
        failed_suites+=("harness_selftest/$fixture")
    fi
done

# script_error is the one case the harness cannot catch by itself: the fixture
# exits 0 and prints "passed" despite a runtime error, so the guard in
# run_suite() above has to be what fails it. Assert both halves.
se_output="$("$GODOT" --headless --path . -s tools/harness_selftest/script_error.gd 2>&1)"
se_code=$?
if [ $se_code -eq 0 ] && printf '%s\n' "$se_output" | grep -q 'SCRIPT ERROR'; then
    printf '  ok    %-28s exit=0 but SCRIPT ERROR present (guard has something to catch)\n' "script_error"
    pass=$((pass + 1))
else
    printf '  FAIL  %-28s expected exit=0 with a SCRIPT ERROR, got exit=%d\n' "script_error" "$se_code"
    fail=$((fail + 1))
    failed_suites+=("harness_selftest/script_error")
fi

echo
if [ $fail -eq 0 ]; then
    echo "All $pass suites passed."
    exit 0
fi

echo "$fail of $((pass + fail)) suites FAILED:"
for name in "${failed_suites[@]}"; do
    echo "  - $name"
done
exit 1
