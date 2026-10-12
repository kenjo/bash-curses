#!/bin/bash
# tmux-driven regression test for mouse input in examples/mc.sh.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_mouse.sock"
TREE="$REPO/tmp/mc_mouse"
T=bcmouse
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

cleanup() { tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null; }
trap cleanup EXIT

tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"
mkdir -p "$REPO/tmp"
rm -rf "$TREE"
mkdir -p "$TREE/sub"
printf 'hello\n' > "$TREE/alpha"
printf 'beta\n' > "$TREE/sub/beta"
seq 1 100 > "$TREE/big"

tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 -c "$TREE" bash "$REPO/examples/mc.sh"

ready=0
for _ in $(seq 1 80); do
  if tmux -S "$SOCK" capture-pane -t "$T" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  bad "mc.sh did not start (no listing)"
  exit 1
fi
sleep 1

cap() { tmux -S "$SOCK" capture-pane -t "$T" -p; }
sendk() { tmux -S "$SOCK" send-keys -H -t "$T" "$@"; sleep 1; }
hexstr() {
  local s=$1 out="" i b
  for (( i = 0; i < ${#s}; i++ )); do
    printf -v b '%02x' "'${s:i:1}"
    out+="$b "
  done
  printf '%s' "${out% }"
}
press() {
  local x=$1 y=$2 sx=$(( $1 + 1 )) sy=$(( $2 + 1 ))
  tmux -S "$SOCK" send-keys -H -t "$T" 1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 4d
}
release() {
  local x=$1 y=$2 sx=$(( $1 + 1 )) sy=$(( $2 + 1 ))
  tmux -S "$SOCK" send-keys -H -t "$T" 1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 6d
}
click() {
  local x=$1 y=$2 sx=$(( $1 + 1 )) sy=$(( $2 + 1 ))
  tmux -S "$SOCK" send-keys -H -t "$T" \
    1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 4d \
    1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 6d
  sleep 1.0
}
double_click() {
  local x=$1 y=$2 sx=$(( $1 + 1 )) sy=$(( $2 + 1 ))
  tmux -S "$SOCK" send-keys -H -t "$T" \
    1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 4d \
    1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 6d \
    1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 4d \
    1b 5b 3c 30 3b $(hexstr "$sx") 3b $(hexstr "$sy") 6d
  sleep 1.0
}
wheel_down() {
  local x=$1 y=$2 sx=$(( $1 + 1 )) sy=$(( $2 + 1 ))
  tmux -S "$SOCK" send-keys -H -t "$T" 1b 5b 3c $(hexstr "65") 3b $(hexstr "$sx") 3b $(hexstr "$sy") 4d
  sleep 1.0
}
esc() { tmux -S "$SOCK" send-keys -H -t "$T" 1b; sleep 1.5; }

contains() { grep -qF -- "$1" <<<"$(cap)"; }
not_contains() { ! grep -qF -- "$1" <<<"$(cap)"; }
line_contains() { grep -qF -- "$2" <<<"$(cap | sed -n "${1}p")"; }
line_not_contains() { ! grep -qF -- "$2" <<<"$(cap | sed -n "${1}p")"; }
count_line() { cap | sed -n "${1}p" | grep -oF -- "$2" | wc -l; }

check() { if contains "$2"; then ok "$1"; else bad "$1"; fi; }
check_not() { if not_contains "$2"; then ok "$1"; else bad "$1"; fi; }
check_line() { if line_contains "$1" "$2"; then ok "$3"; else bad "$3"; fi; }
check_line_not() { if line_not_contains "$1" "$2"; then ok "$3"; else bad "$3"; fi; }
check_line_count() {
  local n
  n=$(count_line "$1" "$2")
  if (( n == $3 )); then ok "$4"; else bad "$4 (want $3 got $n)"; fi
}

# left panel click selects a file
click 5 5
check_line_count 26 "alpha" 1 "left click selects alpha"

# right panel click selects a file
click 55 5
check_line_count 26 "alpha" 2 "right click selects alpha"

# left double click opens a directory
double_click 5 4
check_line_count 2 "sub" 1 "left double click opens sub"

# right double click opens a directory and activates the right panel
double_click 55 4
check_line_count 2 "sub" 2 "right double click opens sub"

# right panel click selects the file inside sub
click 55 4
check_line_count 26 "beta" 1 "right click selects beta"

# menu bar click opens the dropdown
click 3 0
check "menu bar click opens dropdown" "File listing"

# dropdown click chooses Sort order...
click 12 8
check_line 3 ".s" "dropdown click changes sort header"

# PullDn button opens the menu
click 85 29
check "PullDn click opens menu" "File listing"
esc
check_not "Esc closes menu" "File listing"

# Help button opens the help dialog
click 5 29
check "Help click opens help" "Commander"
esc
check_not "Esc closes help" "Commander"

# Menu button opens the user menu
click 15 29
check "Menu click opens user menu" "User menu"
esc
check_not "Esc closes user menu" "User menu"

# View button opens the viewer for the selected file
click 55 4
click 25 29
check_line 1 "beta" "View click opens viewer"
click 25 29
check_line 30 "Quit" "Viewer Quit click closes viewer"

# Copy button opens the Copy dialog; Cancel button closes it
click 45 29
check_line 8 " Copy " "Copy click opens dialog"
click 60 17
check_line_not 8 " Copy " "Cancel click closes dialog"

# wheel scrolling in the viewer
double_click 5 3
double_click 5 6
check_line 1 " 0/" "viewer starts at top"
wheel_down 5 10
check_line_not 1 " 0/" "wheel down scrolls viewer"
click 25 29

# command line click sets the caret
tmux -S "$SOCK" send-keys -t "$T" q7z
sleep 1
line=$(cap | sed -n '29p')
prompt=${line%%q7z*}
click $(( ${#prompt} + 1 )) 28
tmux -S "$SOCK" send-keys -t "$T" X
sleep 1
check_line 29 "qX7z" "command line click sets caret"
esc

# Quit button exits
click 95 29
gone=0
for _ in $(seq 1 50); do
  if ! tmux -S "$SOCK" has-session -t "$T" 2>/dev/null; then gone=1; break; fi
  sleep 0.1
done
if (( gone )); then ok "Quit click exits"; else bad "Quit click did not exit"; fi

echo
if (( fail == 0 )); then echo "mc_mouse: $pass passed"; else echo "mc_mouse: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
