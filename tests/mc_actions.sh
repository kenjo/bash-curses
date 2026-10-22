#!/bin/bash
# tmux-driven regression tests for menu actions in examples/mc.sh.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# MC_SCRIPT: the clone under test (default examples/mc.sh); MC_TAG: prefix for
# this run's tmp files/sockets so two runs can go in parallel.
MC_SCRIPT=${MC_SCRIPT:-$REPO/examples/mc.sh}
MCT=${MC_TAG:-}
WORK="$REPO/tmp/${MCT}mc_actions"
SOCK="$REPO/tmp/${MCT}bc_actions.sock"
T=bcactions
W=100
H=30
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$WORK"
mkdir -p "$WORK"
echo alpha > "$WORK/alpha.txt"
echo beta  > "$WORK/beta.txt"
seq 1 200  > "$WORK/sample.txt"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x "$W" -y "$H" bash -c "cd '$WORK' && exec bash '$MC_SCRIPT'"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_actions: $pass passed, $fail FAILED"
  exit 1
fi
sleep 1

cap()   { tmux -S "$SOCK" capture-pane -t "$T" -p; }
capE()  { tmux -S "$SOCK" capture-pane -t "$T" -p -e; }
sendk() { tmux -S "$SOCK" send-keys -t "$T" "$@"; sleep 0.6; }

# Filter... applies a shell pattern to the active panel.
sendk F9
sendk Down
sendk f
sendk Enter
sendk -l 'alpha*'
sendk Enter
sleep 1
left="$(cap | cut -c1-50)"
if [[ "$left" == *alpha.txt* && "$left" != *beta.txt* ]]; then
  ok "Filter... hides non-matching entries in the active panel"
else
  bad "Filter... did not hide beta.txt in the active panel"
fi

# A wildcard filter restores the listing.
sendk F9
sendk Down
sendk f
sendk Enter
for _ in 1 2 3 4 5 6; do sendk BSpace; done
sendk -l '*'
sendk Enter
sleep 1
left="$(cap | cut -c1-50)"
if [[ "$left" == *alpha.txt* && "$left" == *beta.txt* ]]; then
  ok "Filter... with '*' restores the active listing"
else
  bad "Filter... with '*' did not restore the active listing"
fi

# Select group marks matching entries with the selection color.
sendk F9
sendk Right
sendk Down
sendk g
sendk Enter
sendk -l '*'
sendk Enter
sleep 1
if capE | sed -n '4,10p' | grep -q '93m'; then
  ok "Select group marks matching entries"
else
  bad "Select group did not mark matching entries"
fi

# Unselect group clears the selection color.
sendk F9
sendk Right
sendk Down
sendk n
sendk Enter
sendk Enter
sleep 1
if capE | sed -n '4,10p' | grep -q '93m'; then
  bad "Unselect group left selected entries highlighted"
else
  ok "Unselect group clears the selection"
fi

# View file... opens a typed path in the full-screen viewer.
sendk F9
sendk Right
sendk Down
sendk w
sendk Enter
sendk -l 'sample.txt'
sendk Enter
sleep 1
screen="$(cap)"
if [[ "$screen" == *sample.txt* && "$screen" == *'0/'* ]]; then
  ok "View file... opens the typed file"
else
  bad "View file... did not open the typed file"
fi
sendk q
sleep 1

# Command history inserts a previous command into the command line.
sendk -l 'echo hi'
sendk Enter
sleep 1
sendk F9
sendk Right
sendk Right
sendk Down
sendk h
sendk Enter
sleep 1
screen="$(cap)"
if [[ "$screen" == *'echo hi'* ]]; then
  ok "Command history lists the previous command"
else
  bad "Command history did not list the previous command"
fi
sendk Enter
sleep 1
cmdline="$(cap | sed -n '29p')"
if [[ "$cmdline" == *'echo hi'* ]]; then
  ok "Command history inserts the chosen command into the command line"
else
  bad "Command history did not insert the chosen command: '$cmdline'"
fi

# Mkdir refreshes both panels and leaves the new directory selected.
sendk F7
sendk -l 'newdir'
sendk Enter
sleep 1
left="$(cap | cut -c1-50)"
right="$(cap | cut -c51-100)"
status="$(cap | sed -n '26p' | cut -c1-50)"
if [[ "$left" == *newdir* && "$right" == *newdir* && "$status" == */newdir* ]]; then
  ok "Mkdir refreshes both panels and selects the new directory"
else
  bad "Mkdir did not refresh both panels or select the new directory"
fi

# Delete removes the current entry from both panels and moves to the next one.
sendk F8
sendk Enter
sleep 1
left="$(cap | cut -c1-50)"
right="$(cap | cut -c51-100)"
status="$(cap | sed -n '26p' | cut -c1-50)"
if [[ "$left" != *newdir* && "$right" != *newdir* && "$status" == *alpha.txt* ]]; then
  ok "Delete refreshes both panels and moves to the next entry"
else
  bad "Delete did not refresh both panels or move to the next entry"
fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_actions: $pass passed"; else echo "mc_actions: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
