#!/bin/bash
# tmux-driven end-to-end test for the F9 menu in examples/mc.sh.
#
# Regression guards (all were broken before the menu rework):
#   - the menu bar is always visible (Left File Command Options Right) and cyan
#   - F9 highlights "Left" (black bg) and opens NO dropdown
#   - Down opens the dropdown for the highlighted item (Left -> "Quick view")
#   - Esc closes the dropdown
#   - Right moves to the next bar item; its dropdown shows that menu's items
#     (File -> "Filtered view"), not the previous menu's
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_menu.sock"
T=bcmenu
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 bash "$REPO/examples/mc.sh"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_menu: $pass passed, $fail FAILED"; exit 1
fi
sleep 1

cap()  { tmux -S "$SOCK" capture-pane -t "$T" -p; }
capE() { tmux -S "$SOCK" capture-pane -t "$T" -p -e; }
key()  { tmux -S "$SOCK" send-keys -t "$T" "$@"; sleep 1.5; }
bar()  { cap | sed -n '1p'; }
dd()   { cap | sed -n '2,9p'; }   # dropdown region

# 1. menu bar always visible with all five items, on a cyan background
b="$(bar)"
if [[ $b == *Left* && $b == *File* && $b == *Command* && $b == *Options* && $b == *Right* ]]; then
  ok "menu bar shows Left File Command Options Right"
else
  bad "menu bar missing items (got: $b)"
fi
if capE | sed -n '1p' | grep -q '46m'; then ok "menu bar is cyan"; else bad "menu bar not cyan"; fi

# 2. F9 highlights the first item (black bg = SGR bg 40) and opens no dropdown
key F9
if capE | sed -n '1p' | grep -q '40m'; then ok "F9 highlights first item"; else bad "F9 did not highlight first item"; fi
if dd | grep -q 'Quick view'; then bad "F9 opened a dropdown (should not)"; else ok "F9 opens no dropdown"; fi

# 3. Down opens the dropdown for the highlighted item (Left -> Quick view)
key Down
if dd | grep -q 'Quick view'; then ok "Down opens Left dropdown (Quick view)"; else bad "Down did not open Left dropdown"; fi

# 4. Esc closes the dropdown. Send the real 0x1b byte (not the string "Esc").
# A lone 0x1b waits the full ESCDELAY (1s) before wgetch returns it, so allow
# extra time beyond the ESCDELAY for the re-render.
tmux -S "$SOCK" send-keys -H -t "$T" 1b; sleep 2.5
if dd | grep -q 'Quick view'; then bad "Esc did not close dropdown"; else ok "Esc closes dropdown"; fi

# 5. Right -> File; its dropdown shows File's items (Filtered view), not Left's
key F9; key Right; key Down
if dd | grep -q 'Filtered view'; then ok "File dropdown shows File items (Filtered view)"; else bad "File dropdown wrong items"; fi
if dd | grep -q 'Quick view'; then bad "File dropdown shows Left items (leak)"; else ok "File dropdown does not leak Left items"; fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_menu: $pass passed"; else echo "mc_menu: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
