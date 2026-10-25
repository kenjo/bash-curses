#!/bin/bash
# Run the bash-vs-C example comparison suite.
#
# This is intentionally slower than tests/examples.sh. It is not part of
# tests/run.sh by default. Run it explicitly after changing examples, lib/bc.sh,
# or the C reference sources.
REPO="$(cd "$(dirname "$0")/.." && pwd)"

expected_skip=(
  08-attributes-main
  12-mouse
  14-leave-ncurses
)

expected_fail=(
)

# Examples whose plain capture matches but whose SGR capture is a documented,
# accepted artifact (see internal/example-deviations.md).  The gate runs in strict mode,
# so these are tolerated only when the failure is SGR-only (plain must match).
expected_sgr_fail=(
  64-slk-extra
)

is_expected() {
  local needle=$1
  shift
  local x
  for x in "$@"; do
    [[ $x == "$needle" ]] && return 0
  done
  return 1
}

failures=0
for f in "$REPO"/examples/[0-9]*.sh; do
  base=${f##*/}
  base=${base%.sh}
  out=$(timeout 60 "$REPO/tests/example_compare.sh" --strict "$base" 2>&1)
  rc=$?
  printf '%s\n' "$out"
  if (( rc != 0 )); then
    res="$REPO/tmp/example_compare/$base/result"
    if is_expected "$base" "${expected_fail[@]}"; then
      printf 'expected-fail %s\n' "$base"
    elif grep -q 'SGR screen differs' "$res" 2>/dev/null &&
         is_expected "$base" "${expected_sgr_fail[@]}"; then
      printf 'expected-sgr-fail %s\n' "$base"
    else
      printf 'unexpected-fail %s\n' "$base"
      failures=$((failures + 1))
    fi
  fi
done

if (( failures )); then
  printf 'example_parity: %d unexpected failures\n' "$failures"
  exit 1
fi

printf 'example_parity: ok\n'
