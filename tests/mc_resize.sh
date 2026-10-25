#!/bin/bash
# tmux-driven regression test: terminal resize (SIGWINCH) must reflow the
# layout. Before the fix the clone ignored SIGWINCH and the terminal simply
# clipped the old render (the button bar/hint lines scrolled off the bottom).
# After a resize the button bar must sit on the new last row and the hint line
# must move to its new position.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# MC_SCRIPT: the clone under test (default apps/mc.sh); MC_TAG: prefix for
# this run's tmp files/sockets so two runs can go in parallel.
MC_SCRIPT=${MC_SCRIPT:-$REPO/apps/mc.sh}
MCT=${MC_TAG:-}
SOCK="$REPO/tmp/${MCT}bc_resize.sock"
T=bcresize
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 bash "$MC_SCRIPT"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_resize: $pass passed, $fail FAILED"; exit 1
fi
sleep 1

cap()  { tmux -S "$SOCK" capture-pane -t "$T" -p; }
W()    { tmux -S "$SOCK" display -p -t "$T" '#{window_width}'; }
H()    { tmux -S "$SOCK" display -p -t "$T" '#{window_height}'; }
# the button bar is the only line that contains the word "Help"
btnbar_last() { cap | tail -1 | grep -q 'Help'; }

check_size() { # label wantw wanth
  local w="$(W)" h="$(H)"
  if [[ "$w" == "$2" && "$h" == "$3" ]]; then ok "$1 -> ${w}x${h}"; else bad "$1 (want ${2}x${3} got ${w}x${h})"; fi
}
check_btnbar() { # label
  if btnbar_last; then ok "$1: button bar on last line"; else bad "$1: button bar NOT on last line"; fi
}

# --- start at 100x30 ---
check_size "start" 100 30
check_btnbar "start"

# --- shrink to 80x24 ---
tmux -S "$SOCK" resize-window -t "$T" -x 80 -y 24
sleep 2
check_size "shrink" 80 24
check_btnbar "shrink"
# the hint line sits on row (1+PH)+1 = row 22 (0-indexed 21) for a 24-row screen
if cap | sed -n '22p' | grep -q 'Hint:'; then ok "shrink: hint line on row 22"; else bad "shrink: hint line not on row 22"; fi

# --- grow to 120x40 ---
tmux -S "$SOCK" resize-window -t "$T" -x 120 -y 40
sleep 2
check_size "grow" 120 40
check_btnbar "grow"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_resize: $pass passed"; else echo "mc_resize: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
