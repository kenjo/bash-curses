#!/bin/bash
# tmux-driven test for examples/dtail.sh: two commands get their own bordered
# panes, the command is shown in the border, and q exits cleanly.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/tmp/dtail"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$T"; mkdir -p "$T"
sock="$T/bc.sock" out="$T/rc.out" err="$T/stderr.log" sess=dtail
tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
rm -f "$sock" "$out" "$err"

CMD1='seq 1 3 | sed "s/^/top /"'
CMD2='seq 1 3 | sed "s/^/bot /"'

tmux -S "$sock" new-session -d -s "$sess" -x 100 -y 30 \
  bash -c 'bash "$1" "$2" "$3" 2>"$4"; rc=$?; printf "%s\n" "$rc" > "$5"' _ \
  "$REPO/examples/dtail.sh" "$CMD1" "$CMD2" "$err" "$out"

wait_for() { # needle
  local needle=$1 _
  for _ in $(seq 1 100); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -qF -- "$needle"; then return 0; fi
    sleep 0.1
  done
  return 1
}
cap() { tmux -S "$sock" capture-pane -t "$sess" -p; }

if wait_for "top 1"; then ok "top pane shows output"; else bad "top pane shows output"; cap; fi
if wait_for "bot 1"; then ok "bot pane shows output"; else bad "bot pane shows output"; cap; fi
if wait_for "[exited]"; then ok "exited marker shown"; else bad "exited marker shown"; cap; fi
grep -q "seq 1 3" <<<"$(cap)" && ok "command shown in border" || bad "command shown in border"

tmux -S "$sock" send-keys -t "$sess" q
for _ in $(seq 1 50); do [[ -f $out ]] && break; sleep 0.1; done
tmux -S "$sock" kill-session -t "$sess" 2>/dev/null; rm -f "$sock"

[[ $(cat "$out" 2>/dev/null) == 0 ]] && ok "clean quit rc=0" || bad "clean quit rc=0"
[[ ! -s $err ]] && ok "stderr is empty" || { bad "stderr is empty"; cat "$err"; }

printf '\ndtail: %d passed\n' "$pass"
exit $(( fail > 0 ))
