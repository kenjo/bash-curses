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
seq 1 60 > "$WORK/sample.txt"

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

# q closes the viewer and restores the file manager
sendk q
sleep 1
screen="$(cap)"
if [[ "$screen" == *' Left '* && "$screen" == *'10Quit'* ]]; then
  ok "q closes viewer and restores panels"
else
  bad "viewer did not restore panels"
fi

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
echo
if (( fail == 0 )); then echo "mc_view: $pass passed"; else echo "mc_view: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
