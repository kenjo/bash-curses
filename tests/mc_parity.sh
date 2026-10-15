#!/bin/bash
# tmux-driven regression tests for MC-vs-clone parity findings.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_parity.sock"
TREE="$REPO/tmp/test_parity"
CAP="$REPO/tmp/mc_parity.sgr"
T=bcp
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$TREE"
mkdir -p "$TREE/alpha"
printf 'a\n' > "$TREE/a.txt"
printf 'b\n' > "$TREE/b.md"
printf 'c\n' > "$TREE/c.sh"
ln -s a.txt "$TREE/link.txt"
printf 'sample\n' > "$TREE/sample.txt"
printf 'z\n' > "$TREE/z.txt"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 -c "$TREE" bash "$REPO/examples/mc.sh"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_parity: $pass passed, $fail FAILED"; exit 1
fi
sleep 1

tmux -S "$SOCK" capture-pane -t "$T" -p -e > "$CAP"

source "$REPO/tests/lib/screen.sh"
screen_load "$CAP" 100 30

found=0
for (( y = 0; y < 30; y++ )); do
  for (( x = 0; x < 100; x++ )); do
    IFS=$'\t' read -r ch fg bg attrs <<< "$(cell "$y" "$x")"
    [[ $ch == @ ]] || continue
    found=1
    if [[ $fg == 16:7 && $bg == 16:4 ]]; then
      ok "symlink marker uses white-on-blue"
    else
      bad "symlink marker uses white-on-blue (got fg=$fg bg=$bg)"
    fi
    IFS=$'\t' read -r ch2 _ _ _ <<< "$(cell "$y" $((x + 1)))"
    if [[ $ch2 == l ]]; then
      ok "symlink marker is followed by the name"
    else
      bad "symlink marker is followed by the name (got $ch2)"
    fi
    break 2
  done
done
(( found )) || bad "symlink marker @link.txt is present"

plain="$(tmux -S "$SOCK" capture-pane -t "$T" -p)"
avail_kb=$(df -P -k "$TREE" | tail -1 | awk '{print $4}')
if (( avail_kb < 10240 * 1024 )); then
  if grep -q '[0-9]\+M / [0-9]\+G' <<<"$plain"; then
    ok "free space below 10G is shown in megabytes"
  else
    bad "free space below 10G is shown in megabytes"
  fi
fi

tmux -S "$SOCK" send-keys -t "$T" F9; sleep 1
tmux -S "$SOCK" capture-pane -t "$T" -p -e > "$REPO/tmp/mc_parity_menu.sgr"
screen_load "$REPO/tmp/mc_parity_menu.sgr" 100 30
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 0 1)"
if [[ $bg == 16:0 ]]; then
  ok "selected menu item has a black leading space"
else
  bad "selected menu item has a black leading space (got bg=$bg)"
fi
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 3 1)"
if [[ $bg == 16:4 ]]; then
  ok "panel selection highlight is suppressed while the menu bar is open"
else
  bad "panel selection highlight is suppressed while the menu bar is open (got bg=$bg)"
fi

tmux -S "$SOCK" send-keys -t "$T" Down; sleep 1
tmux -S "$SOCK" capture-pane -t "$T" -p -e > "$REPO/tmp/mc_parity_dd.sgr"
if tmux -S "$SOCK" capture-pane -t "$T" -p | grep -q '└'; then
  ok "Left dropdown has a bottom border"
else
  bad "Left dropdown has a bottom border"
fi
screen_load "$REPO/tmp/mc_parity_dd.sgr" 100 30
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 2 27)"
if [[ $bg == 16:0 ]]; then
  ok "dropdown has a black right shadow"
else
  bad "dropdown has a black right shadow (got bg=$bg)"
fi
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 3 29)"
if [[ $bg == 16:4 ]]; then
  ok "panel selection highlight is suppressed under an open dropdown"
else
  bad "panel selection highlight is suppressed under an open dropdown (got bg=$bg)"
fi

tmux -S "$SOCK" send-keys -t "$T" Escape; sleep 1.2
tmux -S "$SOCK" send-keys -t "$T" F9; sleep 1
tmux -S "$SOCK" send-keys -t "$T" Right Right Right Down; sleep 1
plain="$(tmux -S "$SOCK" capture-pane -t "$T" -p)"
top='┌'
for ((i = 0; i < 19; i++)); do top+='─'; done
top+='┐'
if grep -qF "$top" <<<"$plain"; then
  ok "Options dropdown has the correct width"
else
  bad "Options dropdown has the correct width"
fi

tmux -S "$SOCK" send-keys -t "$T" Escape; sleep 1.2
tmux -S "$SOCK" send-keys -t "$T" F9; sleep 1
tmux -S "$SOCK" send-keys -t "$T" Right Right Down; sleep 1
plain="$(tmux -S "$SOCK" capture-pane -t "$T" -p)"
tmux -S "$SOCK" capture-pane -t "$T" -p -e > "$REPO/tmp/mc_parity_hot.sgr"
screen_load "$REPO/tmp/mc_parity_hot.sgr" 100 30
mapfile -t lines <<<"$plain"
for want in "Show directory sizes|i|s" "Viewed/edited files history|s|i" "Edit extension file|e| "; do
  IFS='|' read -r label wantch wantprev <<<"$want"
  row=-1
  for ((r = 0; r < ${#lines[@]}; r++)); do
    [[ ${lines[r]} == *"$label"* ]] && { row=$r; break; }
  done
  if (( row < 0 )); then
    bad "dropdown row for '$label' is present"
    continue
  fi
  hx=-1
  for ((c = 0; c < 100; c++)); do
    IFS=$'\t' read -r ch fg bg _ <<< "$(cell "$row" "$c")"
    if [[ $fg == 16:11 && $bg == 16:6 ]]; then hx=$c; break; fi
  done
  if (( hx < 0 )); then
    bad "hotkey is highlighted in '$label'"
    continue
  fi
  IFS=$'\t' read -r ch _ _ _ <<< "$(cell "$row" "$hx")"
  IFS=$'\t' read -r prev _ _ _ <<< "$(cell "$row" $((hx - 1)))"
  if [[ $ch == "$wantch" && $prev == "$wantprev" ]]; then
    ok "hotkey position matches MC in '$label'"
  else
    bad "hotkey position matches MC in '$label' (got $ch after '$prev')"
  fi
done

cap()   { tmux -S "$SOCK" capture-pane -t "$T" -p; }
capE()  { tmux -S "$SOCK" capture-pane -t "$T" -p -e; }
sendk() { tmux -S "$SOCK" send-keys -t "$T" "$@"; sleep 0.6; }

sendk Escape
sleep 0.6

# Space is ignored by MC in the panel; it must not create a selection summary.
sendk Space
plain="$(cap)"
if [[ "$plain" == *'Hint: Tab changes your current panel.'* && "$plain" != *'in 1 file'* ]]; then
  ok "Space does not select an entry"
else
  bad "Space does not select an entry"
fi

# Insert selects the current entry and moves the cursor down.
sendk Down
sendk Down
sendk Insert
plain="$(cap)"
if [[ "$plain" == *'in 1 file'* ]]; then
  ok "Insert selects one entry and shows a selection summary"
else
  bad "Insert selects one entry and shows a selection summary"
fi

# '*' selects all files, but not directories.
sendk -l '*'
plain="$(cap)"
if [[ "$plain" == *'in 6 files'* ]]; then
  ok "'*' selects all files and leaves directories unselected"
else
  bad "'*' selects all files and leaves directories unselected"
fi

# '+' opens MC's Select dialog with the correct frame, field button, and shadow.
sendk -l '+'
plain="$(cap)"
if [[ "$plain" == *'┌'*'Select'*'┐'* ]]; then
  ok "'+' opens the Select dialog"
else
  bad "'+' opens the Select dialog"
fi
capE > "$REPO/tmp/mc_parity_plus.sgr"
screen_load "$REPO/tmp/mc_parity_plus.sgr" 100 30
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 9 22)"
if [[ $bg == 16:7 ]]; then
  ok "Select dialog has a white top shadow"
else
  bad "Select dialog has a white top shadow (got bg=$bg)"
fi
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 10 77)"
if [[ $bg == 16:0 ]]; then
  ok "Select dialog has a black right shadow"
else
  bad "Select dialog has a black right shadow (got bg=$bg)"
fi
IFS=$'\t' read -r _ _ bg _ <<< "$(cell 16 24)"
if [[ $bg == 16:0 ]]; then
  ok "Select dialog has a black bottom shadow"
else
  bad "Select dialog has a black bottom shadow (got bg=$bg)"
fi
IFS=$'\t' read -r ch fg bg _ <<< "$(cell 11 71)"
if [[ $ch == '[' && $fg == 16:7 && $bg == 16:4 ]]; then
  ok "Select dialog completer button is white on blue"
else
  bad "Select dialog completer button is white on blue (got $ch fg=$fg bg=$bg)"
fi
sendk Escape

# F1 Help draws MC's white margin and gray-on-black dialog shadow.
sendk F1
sleep 1
capE > "$REPO/tmp/mc_parity_help.sgr"
screen_load "$REPO/tmp/mc_parity_help.sgr" 100 30
shadow=0
for (( y = 0; y < 30; y++ )); do
  for (( x = 0; x < 100; x++ )); do
    IFS=$'\t' read -r _ fg bg _ <<< "$(cell "$y" "$x")"
    if [[ $fg == 16:8 && $bg == 16:0 ]]; then shadow=1; break 2; fi
  done
done
if (( shadow )); then
  ok "Help dialog has a gray-on-black shadow"
else
  bad "Help dialog has a gray-on-black shadow"
fi
sendk Escape
sleep 1

# Entering a directory replaces the Tab hint with MC's VFS hint.
sendk Up
sendk Up
sendk Enter
sleep 1
plain="$(cap)"
if [[ "$plain" == *'VFS coolness: tap enter on a tar file to examine its contents.'* ]]; then
  ok "entering a directory shows the VFS hint"
else
  bad "entering a directory shows the VFS hint"
fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_parity: $pass passed"; else echo "mc_parity: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
