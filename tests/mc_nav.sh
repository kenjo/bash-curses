#!/bin/bash
# tmux-driven end-to-end test for examples/mc.sh navigation.
#
# Regression guard: PageUp/PageDown once drove POS negative (out of range), which
# hid the selection (no highlighted row) and garbled the status line. The
# selection row must stay visible (black-on-cyan, pair 6 -> SGR bg 46) at all
# times. The menu bar must also be cyan (pair 6).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# MC_SCRIPT: the clone under test (default examples/mc.sh); MC_TAG: prefix for
# this run's tmp files/sockets so two runs can go in parallel.
MC_SCRIPT=${MC_SCRIPT:-$REPO/examples/mc.sh}
MCT=${MC_TAG:-}
SOCK="$REPO/tmp/${MCT}bc_nav.sock"
T=bcnav
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 bash "$MC_SCRIPT"

# wait for the file view to render
ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_nav: $pass passed, $fail FAILED"; exit 1
fi
sleep 1

capE()  { tmux -S "$SOCK" capture-pane -t "$T" -p -e; }
sendk() { tmux -S "$SOCK" send-keys -H -t "$T" "$@"; sleep 1; }
# number of left-list rows (4..24) that show a cyan background (pair 6 selection)
cy()    { capE | sed -n '4,24p' | grep -c '46m'; }

check_cy() { # desc expected
  local n; n="$(cy)"
  if [[ "$n" == "$2" ]]; then ok "$1 (cyan rows=$n)"; else bad "$1 (want cyan rows=$2 got $n)"; fi
}

check_cy "initial selection visible" 1
sendk 1b 5b 35 7e            # PageUp from the very top (the original bug)
check_cy "PageUp-from-top keeps selection visible" 1
sendk $(printf '1b 4f 41 %.0s' {1..50}) # many Up at the top must drain, not redraw-loop
check_cy "many Up at top keeps selection visible" 1
sendk 1b 4f 42               # Down
check_cy "Down keeps selection visible" 1
sendk 1b 4f 41               # Up
check_cy "Up keeps selection visible" 1
sendk 1b 5b 36 7e            # PageDown
check_cy "PageDown keeps selection visible" 1
sendk 1b 5b 35 7e            # PageUp
check_cy "PageUp after PageDown keeps selection visible" 1

# menu bar must be cyan (pair 6)
if capE | sed -n '1p' | grep -q '46m'; then ok "menu bar is cyan"; else bad "menu bar not cyan"; fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_nav: $pass passed"; else echo "mc_nav: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
