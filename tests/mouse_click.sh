#!/bin/bash
# tmux-driven regression test for examples/12-mouse.sh: a real xterm-style
# click must select a choice (press+release arrive merged as BUTTON1_CLICKED),
# and clicking Exit must exit cleanly.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_mouseclick.sock"
T=bcmclick
OUT="$REPO/tmp/bc_mouseclick.out"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

cleanup() { tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null; }
trap cleanup EXIT

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK" "$OUT"
mkdir -p "$REPO/tmp"

tmux -S "$SOCK" new-session -d -s "$T" -x 80 -y 24 \
  bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ \
  "$REPO/examples/12-mouse.sh" "$OUT"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Choice 1'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "12-mouse.sh did not start (no menu)"
  exit 1
fi
sleep 1

cap() { tmux -S "$SOCK" capture-pane -t "$T" -p; }
hexstr() {
  local s=$1 out="" i b
  for (( i = 0; i < ${#s}; i++ )); do
    printf -v b '%02x' "'${s:i:1}"
    out+="$b "
  done
  printf '%s' "${out% }"
}
# click at 1-based tmux coords (col row)
click() {
  local col=$1 row=$2
  tmux -S "$SOCK" send-keys -H -t "$T" \
    1b 5b 3c 30 3b $(hexstr "$col") 3b $(hexstr "$row") 4d \
    1b 5b 3c 30 3b $(hexstr "$col") 3b $(hexstr "$row") 6d
  sleep 1.0
}

# The menu is fixed at (startx,starty)=(25,7) 0-based; choices print at window
# y=2..6, x=2 -> screen rows 9..13, cols 27..34 (0-based) -> tmux rows 10..14.
# "Choice 2" is row 11, "Exit" is row 14.
click 28 11
if cap | grep -qF 'Choice made is : 2'; then
  ok "click on Choice 2 reports the choice"
else
  bad "click on Choice 2 reports the choice"
fi

# clicking Exit ends the program with status 0
click 28 14
gone=0
for _ in $(seq 1 50); do
  if [[ -f "$OUT" ]]; then gone=1; break; fi
  sleep 0.1
done
if (( gone )) && [[ "$(cat "$OUT")" == "0" ]]; then
  ok "click on Exit exits cleanly"
else
  bad "click on Exit exits cleanly"
fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null

# q also quits (the port's addition over the C demo)
tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK" "$OUT"
tmux -S "$SOCK" new-session -d -s "$T" -x 80 -y 24 \
  bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ \
  "$REPO/examples/12-mouse.sh" "$OUT"
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Choice 1'; then break; fi
  sleep 0.1
done
sleep 1
tmux -S "$SOCK" send-keys -t "$T" q
gone=0
for _ in $(seq 1 50); do
  if [[ -f "$OUT" ]]; then gone=1; break; fi
  sleep 0.1
done
if (( gone )) && [[ "$(cat "$OUT")" == "0" ]]; then
  ok "q exits cleanly"
else
  bad "q exits cleanly"
fi

echo
if (( fail == 0 )); then echo "mouse_click: $pass passed"; else echo "mouse_click: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
