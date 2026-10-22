#!/bin/bash
# Benchmark for lib/layout.sh (headless; NOT part of tests/run.sh).
#   bash tests/bench_layout.sh
# Reports the cost of solving the layout (pure arithmetic) separately from
# rebuilding windows, for an mc-like screen and a shining-like stress case.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
export LC_ALL=C
source "$REPO/lib/layout.sh"

term() { BC_LINES=$1; BC_COLS=$2; LINES=$1; COLS=$2; }
resizeterm() { BC_WH[0]=$BC_LINES; BC_WW[0]=$BC_COLS; BC_S=(); BC_SA=(); BC_SP=(); }
now() { local t=${EPOCHREALTIME//[!0-9]/}; NOW=$t; }
bench() { # label reps cmd...
  local label=$1 reps=$2 i t0; shift 2
  now; t0=$NOW
  for (( i = 0; i < reps; i++ )); do "$@"; done
  now
  printf '  %-44s %9d us\n' "$label" $(( (NOW - t0) / reps ))
}
flip() { if (( BC_COLS == 100 )); then term 30 101; else term 30 100; fi; _bcl_resized; }

term 30 100; _bc_init_window 0 0 0 30 100
echo "== mc-like screen (menu, 2 framed panels each with a nested grid, hint, keys)"
bc_screen "
  menu  menu
  left  right
  hint  hint
  keys  keys
" rows="1 * 1 1" cols="* *"
for p in left right; do
  bc_style "$p" border title="$p"
  bc_grid "$p" "
    $p.head
    $p.list
    $p.status
  " rows="1 * 1"
done
bc_relayout
bench "solve rectangles (_bcl_resolve)"            200 _bcl_resolve
bench "bc_relayout, nothing changed"                100 bc_relayout
bench "resize: solve + rebuild changed windows"      20 flip
bc_float copy size=9x60 border shadow title=Copy
bc_grid copy "
  l1 src
  l2 dst
  .  .
  btns btns
" rows="1 1 * 1" cols="auto *" gap=1
bc_grid btns ". ok cancel ." cols="* auto auto *" gap=2
bc_text l1 "From:"; bc_text l2 "To:"
open_close() { bc_float copy size=9x60 border shadow title=Copy; bc_relayout; bc_close copy; bc_relayout; }
bench "solve with a dialog open"                   200 _bcl_resolve
bench "resize with a dialog open"                   20 flip

echo "== shining-like stress (42 cells, ~3 nested floats each, shadows)"
for f in $BCL_FLOATS; do bc_close "$f"; done
term 30 100; resizeterm
RANDOM=1
bc_screen "paper"; bc_style paper border
bc_cells paper 42
grow() {
  bc_float "$1" in="$2" within="$3" at=random size="$4" border shadow
  (( $5 < 2 )) || return
  local i; for (( i = RANDOM % 3; i > 0; i-- )); do grow "$1.$i" "$1" "$1" "50%..85%x45%..85%" $(( $5 + 1 )); done
}
for (( i = 0; i < 42; i++ )); do grow "w$i" "paper.$i" paper "8..19x14..46" 0; done
now; t0=$NOW; bc_relayout; now
printf '  %-44s %9d us   (%d floats, %d panels)\n' "first build" $(( NOW - t0 )) "$(wc -w <<< "$BCL_FLOATS")" "${#BC_PSTACK[@]}"
bench "solve rectangles (_bcl_resolve)"             20 _bcl_resolve
bench "bc_relayout, nothing changed"                10 bc_relayout
bench "resize: solve + rebuild all windows"          2 flip
