#!/bin/bash
# Runs the full test suite: headless unit tests, then the tmux integration test.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
overall=0
for t in unit.sh unit_screen.sh integration.sh mc_nav.sh mc_menu.sh mc_view.sh mc_resize.sh mc_dialog.sh mc_actions.sh mc_parity.sh mc_mouse.sh; do
  echo "== $t =="
  if bash "$REPO/tests/$t"; then
    echo "== $t: PASS"
  else
    echo "== $t: FAIL"
    overall=1
  fi
  echo
done
exit "$overall"
