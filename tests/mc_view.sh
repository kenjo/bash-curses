#!/bin/bash
# tmux-driven end-to-end test for the F3 full-screen file viewer (examples/mc.sh).
#
# Covers:
#   - F3 opens a full-screen scrollable view (title bar: path + offset/total, fn-key bar)
#   - End scrolls to the bottom (the offset in the title becomes non-zero)
#   - q closes the viewer and restores the file-manager panels
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_view2.sock"
T=bcview2
WORK="$REPO/tmp/view_test"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

# scratch dir with one file taller than one screen so scrolling moves the offset
rm -rf "$WORK"; mkdir -p "$WORK"
seq 1 59 > "$WORK/sample.txt"
printf '█▀▀█ █▀▀█ █▀▀█ █▀▀▄\n' >> "$WORK/sample.txt"

# tab file: line 30 has tabs that must expand to 8-col stops, not jump the
# cursor and leave stale text behind after a scroll (regression)
for i in $(seq 1 59); do printf 'L%d\n' "$i" > "$WORK/tab.txt"; done
{ for i in $(seq 1 29); do printf 'L%d\n' "$i"; done
  printf 'X\tY\tZ\n'
  for i in $(seq 31 59); do printf 'L%d\n' "$i"; done; } > "$WORK/tab.txt"

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 \
  bash -c "cd '$WORK' && exec bash '$REPO/examples/mc.sh'"

# wait for the listing to render
ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  echo "mc_view: $pass passed, $fail FAILED"; exit 1
fi
sleep 1

cap()  { tmux -S "$SOCK" capture-pane -t "$T" -p; }
sendk() { tmux -S "$SOCK" send-keys -t "$T" "$@"; sleep 1; }

# select sample.txt (2nd entry, index 1) and open the viewer
sendk Down
sendk F3
sleep 1

# viewer title bar must show the path and a 0/ offset
title="$(cap | sed -n '1p')"
if [[ "$title" == *sample.txt* && "$title" == *'0/'* ]]; then
  ok "F3 opens full-screen view (title: path + 0/ offset)"
else
  bad "viewer title wrong: '$title'"
fi

# fn-key bar must be present
if cap | sed -n '30p' | grep -q 'Help'; then
  ok "viewer shows fn-key bar (Help)"
else
  bad "viewer fn-key bar missing"
fi

first_line() { cap | sed -n '2p' | sed 's/[[:space:]]*$//'; }

if [[ "$(first_line)" == "1" ]]; then
  ok "viewer starts at first content line"
else
  bad "viewer first content line wrong: '$(first_line)'"
fi

sendk Down
if [[ "$(first_line)" == "2" ]]; then
  ok "Down scrolls viewer by one line"
else
  bad "Down did not scroll viewer: '$(first_line)'"
fi

sendk Up
if [[ "$(first_line)" == "1" ]]; then
  ok "Up scrolls viewer back by one line"
else
  bad "Up did not restore first line: '$(first_line)'"
fi

sendk NPage
if [[ "$(first_line)" == "29" ]]; then
  ok "NPage scrolls viewer by one page"
else
  bad "NPage did not scroll to line 29: '$(first_line)'"
fi

sendk PPage
if [[ "$(first_line)" == "1" ]]; then
  ok "PPage scrolls viewer back to top"
else
  bad "PPage did not restore first line: '$(first_line)'"
fi

# End scrolls to the bottom: the offset in the title becomes non-zero
sendk End
sleep 1
title2="$(cap | sed -n '1p')"
offpair="$(grep -oE '[0-9]+/[0-9]+' <<< "$title2" | tail -1)"
num="${offpair%%/*}"
if [[ -n "$num" && "$num" != "0" ]]; then
  ok "End scrolls to bottom (offset $num)"
else
  bad "End did not change offset: '$title2'"
fi

# multibyte short lines must still be padded with the content color, not the
# previous title-bar color (regression: cyan block at the right edge)
sgr="$(tmux -S "$SOCK" capture-pane -t "$T" -p -e)"
if ! printf '%s\n' "$sgr" | sed -n '2,29p' | grep -qF -- $'\x1b[46m'; then
  ok "viewer content lines have no cyan background padding"
else
  bad "viewer content lines contain cyan background padding"
fi

# q closes the viewer and restores the file manager
sendk q
sleep 1
screen="$(cap)"
if [[ "$screen" == *' Left '* && "$screen" == *'10Quit'* ]]; then
  ok "q closes viewer and restores panels"
else
  bad "viewer did not restore panels"
fi

# the key that closed the modal must not leak into the command line
cmdline="$(cap | sed -n '29p')"
if [[ "$cmdline" != *'$ q'* && "$cmdline" != *'$q'* ]]; then
  ok "q closing viewer does not leak into the command line"
else
  bad "q closing viewer leaked into the command line: '$cmdline'"
fi

# tab regression: open tab.txt, page down, the tab line must render with tabs
# expanded to 8-col stops and must not show stale text from the scroll
sendk Down
sendk F3
sendk NPage
tabrow="$(cap | sed -n '2,29p' | grep -F 'X       Y       Z')"
if [[ -n "$tabrow" ]]; then
  ok "viewer expands tabs to 8-col stops after scroll"
else
  bad "viewer tab line not expanded/stale after scroll: '$(cap | sed -n '2,4p' | tr '\n' '|')'"
fi
sendk q

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_view: $pass passed"; else echo "mc_view: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
