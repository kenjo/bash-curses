#!/bin/bash
# tmux-driven regression test for the Copy/Move dialog focus model (examples/mc.sh).
#
# Covers:
#   - F5 opens the Copy dialog
#   - checkboxes/buttons are not highlighted before arrow navigation
#   - Down moves focus to "Follow links" (black-on-cyan pair 29)
#   - Left toggles the focused checkbox
#   - focus moves to "Preserve attributes" and leaves "Follow links" unhighlighted
#   - Space on the focused Cancel button closes the dialog
REPO="$(cd "$(dirname "$0")/.." && pwd)"
# MC_SCRIPT: the clone under test (default examples/mc.sh); MC_TAG: prefix for
# this run's tmp files/sockets so two runs can go in parallel.
MC_SCRIPT=${MC_SCRIPT:-$REPO/examples/mc.sh}
MCT=${MC_TAG:-}
SOCK="$REPO/tmp/${MCT}bc_dialog.sock"
T=bcdialog
WORK="$REPO/tmp/${MCT}dialog_test"
TMP="$REPO/tmp/${MCT}mc_dialog"
W=100
H=30
pass=0
fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$WORK" "$TMP"
mkdir -p "$WORK" "$TMP"
seq 1 60 > "$WORK/sample.txt"

source "$REPO/tests/lib/screen.sh"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x "$W" -y "$H" \
  bash -c "cd '$WORK' && exec bash '$MC_SCRIPT'"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_dialog: $pass passed, $fail FAILED"
  exit 1
fi
sleep 1

cap()    { tmux -S "$SOCK" capture-pane -p -t "$T"; }
sendk()  { tmux -S "$SOCK" send-keys -t "$T" "$@"; sleep 0.6; }
load()   {
  tmux -S "$SOCK" capture-pane -e -p -t "$T" > "$TMP/sgr"
  screen_load "$TMP/sgr" "$W" "$H"
}
find_box() { # needle -> sets BOX_ROW/BOX_COL to the checkbox's '[' cell
  local needle=$1 hit n line prefix
  hit=$(grid_plain | grep -n -F -- "$needle" | head -1)
  [[ -z $hit ]] && return 1
  n=${hit%%:*}
  BOX_ROW=$((n - 1))
  line=$(grid_plain | sed -n "${n}p")
  prefix=${line%%"$needle"*}
  BOX_COL=$(( ${#prefix} - 4 ))
  return 0
}
is_focused() { # needle -> 0 when the checkbox box is black-on-cyan
  local needle=$1
  find_box "$needle" || return 1
  local k="$BOX_ROW $BOX_COL"
  [[ ${GRID_C[$k]:- } == '[' && ${GRID_FG[$k]:-d} == 16:0 && ${GRID_BG[$k]:-d} == 16:6 ]]
}

sendk Down
sendk F5
sleep 1
if cap | grep -q 'Copy file "sample.txt"'; then
  ok "F5 opens Copy dialog"
else
  bad "F5 did not open Copy dialog"
fi

load
if is_focused "Follow links"; then
  bad "Follow links is highlighted before navigation"
else
  ok "no checkbox highlighted before navigation"
fi

sendk Down
load
if is_focused "Follow links"; then
  ok "Down focuses Follow links (black-on-cyan)"
else
  bad "Down did not focus Follow links"
fi

sendk Left
if cap | grep -q '\[x\] Follow links'; then
  ok "Left toggles focused Follow links"
else
  bad "Left did not toggle focused Follow links"
fi

sendk Down
load
if is_focused "Preserve attributes" && ! is_focused "Follow links"; then
  ok "Down moves focus from Follow links to Preserve attributes"
else
  bad "focus did not move from Follow links to Preserve attributes"
fi

for _ in $(seq 1 5); do sendk Down; done
sendk " "
sleep 1
if cap | grep -q 'Copy file "sample.txt"'; then
  bad "Space on Cancel did not close Copy dialog"
else
  ok "Space on Cancel closes Copy dialog"
fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_dialog: $pass passed"; else echo "mc_dialog: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
