#!/bin/bash
# Battery app: runs inside a tmux pane (real pty), driven by tests/integration.sh.
# Writes a log of decoded keys and mouse events to $BC_OUT (default: $REPO/tmp/bc_out_int.txt).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${BC_OUT:-$REPO/tmp/bc_out_int.txt}"
mkdir -p "$(dirname "$OUT")"
exec 3> "$OUT"
export TERM=xterm-256color
source "$REPO/lib/bc.sh"
initscr
mousemask $(( ALL_MOUSE_EVENTS | REPORT_MOUSE_POSITION )) oldmask
printf 'READY at %s\n' "$EPOCHREALTIME" >&3
while :; do
  wgetch || break
  if [[ $key =~ ^[0-9]+$ ]]; then kn=$key; else kn=$(printf '%d' "'$key"); fi
  if (( kn == KEY_MOUSE )); then
    while getmouse; do
      printf 'EV at %s x=%d y=%d bstate=%d\n' "$EPOCHREALTIME" "$BC_ME_X" "$BC_ME_Y" "$BC_ME_BSTATE" >&3
    done
  elif [[ $key == q ]]; then
    break
  else
    printf 'KEY at %s %d\n' "$EPOCHREALTIME" "$kn" >&3
  fi
done
endwin
printf 'DONE\n' >&3
