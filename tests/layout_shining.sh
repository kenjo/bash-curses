#!/bin/bash
# tmux smoke test for examples/91-shining-layout.sh: lib/layout.sh floats
# (random placement, overhang via within=, nested floats, shadows), the
# bc_run fps loop (animation via on_tick), and relayout on resize.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_layout_shining.sock"
T=bclayoutshining
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
source "$REPO/tests/lib/screen.sh"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 \
  "cd '$REPO' && TERM=xterm-256color bash examples/91-shining-layout.sh 2>'$REPO/tmp/layout_shining.err'"
cap() { tmux -S "$SOCK" capture-pane -t "$T" -p; }

ready=0
for _ in $(seq 1 100); do cap | grep -q 'dull boy' && { ready=1; break; }; sleep 0.1; done
if (( ! ready )); then
  bad "shining-layout did not start"; cap; cat "$REPO/tmp/layout_shining.err"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "layout_shining: $pass passed, $fail FAILED"; exit 1
fi
sleep 1.5

s1=$(cap)
[[ $(sed -n 1p <<< "$s1") == ┌*┐ ]] && ok "paper border top" || bad "paper border top: [$(sed -n 1p <<< "$s1")]"
[[ $(sed -n 30p <<< "$s1") == └*┘ ]] && ok "paper border bottom" || bad "paper border bottom"
n=$(grep -o '┌' <<< "$s1" | wc -l)
(( n >= 13 )) && ok "many windows ($n corners)" || bad "many windows: only $n"

tmux -S "$SOCK" capture-pane -e -t "$T" -p > "$REPO/tmp/layout_shining.cap"
screen_load "$REPO/tmp/layout_shining.cap" 100 30
shadow=0
for (( y = 0; y < 30 && ! shadow; y++ )); do
  for (( x = 0; x < 100; x++ )); do
    c=$(cell "$y" "$x"); c=${c#*$'\t'}; [[ ${c#*$'\t'} == 256:238* ]] && { shadow=1; break; }
  done
done
(( shadow )) && ok "shadows drawn" || bad "shadows drawn"

sleep 3
[[ $(cap) != "$s1" ]] && ok "text keeps typing (on_tick)" || bad "text keeps typing"

# a resize rebuilds every window (~140 here), so give it time
tmux -S "$SOCK" resize-window -t "$T" -x 70 -y 20
for _ in $(seq 1 40); do cap | sed -n 20p | grep -q '└' && break; sleep 0.5; done
sleep 1
s2=$(cap)
[[ $(sed -n 20p <<< "$s2") == └*┘ && $(sed -n 20p <<< "$s2" | wc -m) -eq 71 ]] && ok "resize: border on new edges" \
  || bad "resize: border on new edges: [$(sed -n 20p <<< "$s2")]"
n2=$(grep -o '┌' <<< "$s2" | wc -l)
(( n2 >= 5 )) && ok "resize: windows re-placed ($n2 corners)" || bad "resize: windows re-placed: $n2"

tmux -S "$SOCK" send-keys -t "$T" q
for _ in $(seq 1 20); do tmux -S "$SOCK" has-session -t "$T" 2>/dev/null || break; tmux -S "$SOCK" list-panes -t "$T" -F '#{pane_dead}' | grep -q 1 && break; sleep 0.5; done
if ! tmux -S "$SOCK" has-session -t "$T" 2>/dev/null || tmux -S "$SOCK" list-panes -t "$T" -F '#{pane_dead}' | grep -q 1; then
  ok "q quits"
else
  bad "q quits"
fi
if [[ -s $REPO/tmp/layout_shining.err ]]; then bad "stderr: $(head -3 "$REPO/tmp/layout_shining.err")"; else ok "stderr is empty"; fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
echo "layout_shining: $pass passed, $fail failed"
(( fail == 0 ))
