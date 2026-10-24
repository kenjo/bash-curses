#!/bin/bash
# Runs the full test suite: headless unit tests, then the tmux integration test.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LOGDIR="$REPO/tmp/logs"
JOBS=${BC_TEST_JOBS:-$(nproc)}
(( JOBS > 4 )) && JOBS=4
(( JOBS < 1 )) && JOBS=1
export BC_TEST_JOBS=${BC_TEST_JOBS:-4}

rm -rf "$LOGDIR"
mkdir -p "$LOGDIR"

tests=(unit.sh unit_screen.sh unit_layout.sh unit_widgets.sh unit_bundle.sh unit_dialog.sh mc_layout.sh layout_demo.sh layout_shining.sh unit_mc_swap.sh integration.sh examples_c.sh examples.sh mc_nav.sh mc_menu.sh mc_view.sh mc_resize.sh mc_dialog.sh mc_actions.sh mc_parity.sh mc_mouse.sh mouse_click.sh bundle_run.sh dialog_app.sh)
PIDS=()
for t in "${tests[@]}"; do
  (
    printf '== %s ==\n' "$t"
    if bash "$REPO/tests/$t"; then
      printf '== %s: PASS\n\n' "$t"
      exit 0
    else
      printf '== %s: FAIL\n\n' "$t"
      exit 1
    fi
  ) > "$LOGDIR/$t.log" 2>&1 &
  PIDS+=("$!")
  if (( ${#PIDS[@]} >= JOBS )); then
    wait -n
    live=()
    for p in "${PIDS[@]}"; do
      if kill -0 "$p" 2>/dev/null; then
        live+=("$p")
      fi
    done
    PIDS=("${live[@]}")
  fi
done
wait

overall=0
for t in "${tests[@]}"; do
  cat "$LOGDIR/$t.log"
  if ! grep -q "^== $t: PASS$" "$LOGDIR/$t.log"; then
    overall=1
  fi
done
exit "$overall"
