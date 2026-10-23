#!/bin/bash
# tmux test for examples/90-layout.sh (lib/layout.sh in a real terminal):
# template layout, draw-by-name, selection, a modal float dialog with a
# shadow, mouse clicks by area, and relayout on terminal resize.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_layout_demo.sock"
T=bclayoutdemo
TREE="$REPO/tmp/layout_demo"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
source "$REPO/tests/lib/screen.sh"

rm -rf "$TREE"; mkdir -p "$TREE/L/sub" "$TREE/R"
touch "$TREE/L/alpha.txt" "$TREE/L/beta.sh" "$TREE/L/gamma.md" "$TREE/L/sub/inner.txt" "$TREE/R/one" "$TREE/R/two"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 80 -y 16 \
  "cd '$REPO' && TERM=xterm-256color bash examples/90-layout.sh '$TREE/L' '$TREE/R' 2>'$REPO/tmp/layout_demo.err'"

cap()   { tmux -S "$SOCK" capture-pane -t "$T" -p; }
row()   { cap | sed -n "$(( $1 + 1 ))p"; }
keys()  { tmux -S "$SOCK" send-keys -t "$T" "$@"; }
grid()  { tmux -S "$SOCK" capture-pane -e -t "$T" -p > "$REPO/tmp/layout_demo.cap"; screen_load "$REPO/tmp/layout_demo.cap" "$1" "$2"; }
bg()    { local c; c=$(cell "$1" "$2"); c=${c#*$'\t'}; c=${c#*$'\t'}; printf '%s' "${c%%$'\t'*}"; }
has()   { if row "$2" | grep -qF -- "$3"; then ok "$1"; else bad "$1: row $2 lacks [$3]: [$(row "$2")]"; fi; }
hexs()  { local s=$1 i h o=""; for (( i = 0; i < ${#s}; i++ )); do printf -v h '%02x' "'${s:i:1}"; o+="$h "; done; printf '%s' "$o"; }
click() { # screen y x (0-based): SGR press + release
  local seq="1b 5b 3c 30 3b $(hexs $(( $2 + 1 )))3b $(hexs $(( $1 + 1 )))"
  tmux -S "$SOCK" send-keys -t "$T" -H $seq 4d
  sleep 0.05
  tmux -S "$SOCK" send-keys -t "$T" -H $seq 6d
}
wait_for() { # text
  local i
  for i in $(seq 1 60); do cap | grep -qF -- "$1" && return 0; sleep 0.1; done
  return 1
}

if ! wait_for "layout_demo/L"; then
  bad "demo did not start"; cap; cat "$REPO/tmp/layout_demo.err"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "layout_demo: $pass passed, $fail FAILED"; exit 1
fi
sleep 0.5

# --- A. the template layout
has "A menu bar on row 0"        0  " Left   File   Command"
has "A left panel title"         1  "layout_demo/L"
has "A right panel title"        1  "layout_demo/R"
has "A left panel lists files"   3  "│alpha.txt"
has "A right panel lists files"  3  "││one"
has "A hint row"                 14 " .."
has "A key bar on last row"      15 " 1Help  2Menu"

# --- B. selection (draw_NAME + bc_dirty)
keys Down Down; sleep 0.6
has "B hint follows selection" 14 " beta.sh"
grid 80 16
[[ $(bg 4 1) == 16:6 ]] && ok "B selected row highlighted" || bad "B selected row highlighted: bg $(bg 4 1)"
[[ $(bg 5 1) == 16:4 ]] && ok "B other rows plain" || bad "B other rows plain: bg $(bg 5 1)"

# --- B2. key latency: a Down must not repaint the whole panel (it was ~290 ms
# at 191x74 when every redraw cleared and recomposited every panel cell; now
# ~35 ms, like mc.sh). Measured at 191x74, where the panels are big enough to
# show it. Generous bound: run.sh runs tmux suites in parallel.
tmux -S "$SOCK" resize-window -t "$T" -x 191 -y 74; sleep 2.5
keys Up Up; sleep 0.8
tot=0
for i in 1 2 3 4; do
  before=$(cap | md5sum); t0=${EPOCHREALTIME//[!0-9]/}
  keys Down
  while [[ $(cap | md5sum) == "$before" ]]; do
    sleep 0.005; (( ${EPOCHREALTIME//[!0-9]/} - t0 > 3000000 )) && break
  done
  tot=$(( tot + ${EPOCHREALTIME//[!0-9]/} - t0 )); sleep 0.3
done
keys Up Up Up Up Up Down Down; sleep 0.8
tmux -S "$SOCK" resize-window -t "$T" -x 80 -y 16; sleep 2.5
(( tot / 4000 < 150 )) && ok "B2 Down latency $(( tot / 4000 )) ms" || bad "B2 Down latency $(( tot / 4000 )) ms (want < 150)"

# --- C. modal Copy dialog (float + nested grids + shadow)
keys 5; sleep 1.2
has "C dialog title"     3  "Copy"
has "C dialog From"      4  "│From: beta.sh"
has "C dialog To"        6  "│To:   $TREE/R/"
has "C dialog buttons"   10 "[ OK ]  [ Cancel ]"
grid 80 16
[[ $(bg 4 70) == 16:0 && $(bg 12 11) == 16:0 ]] && ok "C shadow strips" || bad "C shadow strips: $(bg 4 70) $(bg 12 11)"
[[ $(bg 3 70) == 16:4 && $(bg 12 9) == 16:4 ]] && ok "C shadow corners show the panel" || bad "C shadow corners: $(bg 3 70) $(bg 12 9)"
keys Down; sleep 0.6
has "C modal swallows keys" 14 " beta.sh"
keys Enter; sleep 1
has "C OK closes with result" 14 " Would copy beta.sh -> $TREE/R/"
has "C panel revealed again"  3  "│alpha.txt                             │"

# --- D. Tab switches panels, a click selects a row by area
keys Tab Down; sleep 0.8
has "D tab + down in right panel" 14 " one"
sleep 0.6; click 5 3; sleep 1
has "D click selects left row" 14 " gamma.md"

# --- E. a click on Cancel closes the dialog without a result
keys 5; sleep 1.2
c=$(row 10); x=${c%%\[ Cancel*}; x=${#x}
sleep 0.6; click 10 $(( x + 3 )); sleep 1.2
has "E click Cancel" 14 " Copy cancelled"

# --- F. Enter on a directory reloads the panel (title changes)
keys Down; sleep 0.5; keys Enter; sleep 1
has "F entered sub/" 1 "layout_demo/L/sub"
has "F lists inner"  3 "│inner.txt"

# --- G. resize: relayout, no app code involved
tmux -S "$SOCK" resize-window -t "$T" -x 60 -y 12; sleep 1.8
has "G key bar on new last row" 11 " 1Help  2Menu"
has "G panels split at new middle" 2 "│..                          ││..                          │"
tmux -S "$SOCK" resize-window -t "$T" -x 100 -y 20; sleep 1.8
has "G grow: key bar"  19 " 1Help"
[[ $(row 1 | grep -o '┐┌') ]] && ok "G grow: two panels" || bad "G grow: two panels: [$(row 1)]"

# --- H. quit
keys q; sleep 1
if tmux -S "$SOCK" list-panes -t "$T" -F '#{pane_dead}' 2>/dev/null | grep -q 1 || ! tmux -S "$SOCK" has-session -t "$T" 2>/dev/null; then
  ok "H q quits"
else
  bad "H q quits"
fi
if [[ -s $REPO/tmp/layout_demo.err ]]; then bad "stderr is empty: $(head -3 "$REPO/tmp/layout_demo.err")"; else ok "stderr is empty"; fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
echo "layout_demo: $pass passed, $fail failed"
(( fail == 0 ))
