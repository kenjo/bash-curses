#!/bin/bash
# Headless tests for the bundle/unbundle CLI in lib/bc.sh.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BC="$REPO/lib/bc.sh"
T="$REPO/tmp/bundle_unit"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$T"
mkdir -p "$T"

check_roundtrip() { # example-base (uses its real source line)
  local base=$1
  bash "$BC" bundle "$REPO/examples/$base.sh" -o "$T/$base.bundled" >/dev/null 2>"$T/$base.err"
  if [[ $? != 0 || ! -f "$T/$base.bundled" ]]; then
    bad "$base: bundle failed"
    return
  fi
  bash "$BC" unbundle "$T/$base.bundled" -o "$T/$base.out" >/dev/null 2>>"$T/$base.err"
  if [[ $? != 0 ]]; then
    bad "$base: unbundle failed"
    return
  fi
  local libs=()
  case $base in
    90-layout) libs=(bc.sh layout.sh) ;;
    92-mc-layout) libs=(bc.sh layout.sh widgets.sh) ;;
    *) libs=(bc.sh) ;;
  esac
  local lib badlib=0
  for lib in "${libs[@]}"; do
    cmp -s "$T/$base.out/$lib" "$REPO/lib/$lib" || badlib=1
  done
  if (( badlib )); then bad "$base: unbundled libs differ from lib/"; else ok "$base: unbundled libs identical"; fi
  if diff -q <(grep -vE '^[[:space:]]*source .*(bc|layout|widgets|dialog).sh"?[[:space:]]*$' "$REPO/examples/$base.sh") \
             <(grep -vE '^[[:space:]]*source .*(bc|layout|widgets|dialog).sh"?[[:space:]]*$' "$T/$base.out/$base.bundled") >/dev/null; then
    ok "$base: script body identical after round-trip"
  else
    bad "$base: script body identical after round-trip"
  fi
  # re-bundling the unbundled script yields the same embedded libraries
  # (only the src: path recorded in the begin marker changes)
  bash "$BC" bundle "$T/$base.out/$base.bundled" -o "$T/$base.rebundled" >/dev/null 2>>"$T/$base.err"
  if diff -q <(grep -v '^# >>> bc-bundle begin' "$T/$base.bundled") \
             <(grep -v '^# >>> bc-bundle begin' "$T/$base.rebundled") >/dev/null; then
    ok "$base: re-bundle reproduces the bundle"
  else
    bad "$base: re-bundle reproduces the bundle"
  fi
}

check_roundtrip 12-mouse
check_roundtrip 90-layout
check_roundtrip 92-mc-layout

# dialog.sh as a fourth layer
printf '#!/bin/bash\nsource "%s/lib/dialog.sh"\nbc_menu "T" "M" a "A"\n' "$REPO" > "$T/dlg.sh"
bash "$BC" bundle "$T/dlg.sh" -o "$T/dlg.bundled" >/dev/null 2>"$T/dlg.err"
if [[ $? == 0 && -f "$T/dlg.bundled" ]]; then
  ok "bundle an app that sources dialog.sh"
else
  bad "bundle an app that sources dialog.sh"
fi
bash "$BC" unbundle "$T/dlg.bundled" -o "$T/dlg.out" >/dev/null 2>>"$T/dlg.err"
if [[ $? != 0 ]]; then
  bad "dialog: unbundle failed"
else
  badlib=0
  for lib in bc.sh layout.sh widgets.sh dialog.sh; do
    cmp -s "$T/dlg.out/$lib" "$REPO/lib/$lib" || badlib=1
  done
  if (( badlib )); then bad "dialog: unbundled libs differ from lib/"; else ok "dialog: unbundled libs identical"; fi
  if grep -q '}/dialog.sh"' "$T/dlg.out/dlg.bundled"; then
    ok "dialog: unbundle restores the dialog.sh source line"
  else
    bad "dialog: unbundle restores the dialog.sh source line"
  fi
fi

# error: bundling an already bundled file
bash "$BC" bundle "$T/12-mouse.bundled" -o "$T/again" >"$T/e1.out" 2>&1
if [[ $? == 2 ]] && grep -q 'already bundled' "$T/e1.out"; then
  ok "bundle refuses an already bundled file"
else
  bad "bundle refuses an already bundled file"
fi

# error: script without a library source line
printf '#!/bin/bash\necho hi\n' > "$T/plain.sh"
bash "$BC" bundle "$T/plain.sh" -o "$T/plain.bundled" >"$T/e2.out" 2>&1
if [[ $? == 2 ]] && grep -q 'no library source line' "$T/e2.out"; then
  ok "bundle refuses a script with no library source line"
else
  bad "bundle refuses a script with no library source line"
fi

# error: unbundle of a file without markers
bash "$BC" unbundle "$REPO/examples/12-mouse.sh" -o "$T/nope" >"$T/e3.out" 2>&1
if [[ $? == 2 ]] && grep -q 'not a bundle' "$T/e3.out"; then
  ok "unbundle refuses a file without markers"
else
  bad "unbundle refuses a file without markers"
fi

# no args prints usage
bash "$BC" >"$T/e4.out" 2>&1
if [[ $? == 2 ]] && grep -q 'usage:' "$T/e4.out"; then
  ok "bare invocation prints usage"
else
  bad "bare invocation prints usage"
fi

# sourcing the library must not run the CLI
if [[ "$(bash -c "source '$BC'; echo sourced-ok")" == "sourced-ok" ]]; then
  ok "sourcing bc.sh does not trigger the CLI"
else
  bad "sourcing bc.sh does not trigger the CLI"
fi

echo
if (( fail == 0 )); then echo "unit_bundle: $pass passed"; else echo "unit_bundle: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
