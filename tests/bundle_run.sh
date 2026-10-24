#!/bin/bash
# tmux-driven test: a bundled script runs standalone (no lib/ next to it),
# and an unbundled script runs with the libraries beside it.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BC="$REPO/lib/bc.sh"
T="$REPO/tmp/bundle_run"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$T"
mkdir -p "$T/alone" "$T/split"

bash "$BC" bundle "$REPO/examples/12-mouse.sh" -o "$T/alone/12-mouse" || { bad "bundle 12-mouse"; }
bash "$BC" bundle "$REPO/examples/90-layout.sh" -o "$T/alone/90-layout" || { bad "bundle 90-layout"; }
bash "$BC" unbundle "$T/alone/90-layout" -o "$T/split" || { bad "unbundle 90-layout"; }

run_check() { # script needle label
  local script=$1 needle=$2 label=$3
  local sock="$T/run.sock" out="$T/run.out" sess=bcrun
  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
  rm -f "$sock" "$out"
  tmux -S "$sock" new-session -d -s "$sess" -x 100 -y 30 \
    bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ "$script" "$out"
  local ready=0 _
  for _ in $(seq 1 80); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -qF -- "$needle"; then ready=1; break; fi
    sleep 0.1
  done
  if (( ! ready )); then
    bad "$label: screen never showed '$needle'"
    tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
    return
  fi
  tmux -S "$sock" send-keys -t "$sess" q
  local gone=0
  for _ in $(seq 1 50); do
    if [[ -f "$out" ]]; then gone=1; break; fi
    sleep 0.1
  done
  if (( gone )) && [[ "$(cat "$out")" == "0" ]]; then
    ok "$label"
  else
    bad "$label"
  fi
  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
  rm -f "$sock"
}

run_check "$T/alone/12-mouse" "Choice 1" "bundled core app runs standalone"
run_check "$T/alone/90-layout" "Left" "bundled layout app runs standalone"
run_check "$T/split/90-layout" "Left" "unbundled app runs with libs beside it"

# a dialog app: bundled, it runs standalone; Esc cancels bc_menu -> rc 1
printf '#!/bin/bash\nsource "%s/lib/dialog.sh"\nbc_menu "T" "M" a "A" b "B"\nrc=$?; printf "rc=%%s\\n" "$rc"; exit "$rc"\n' "$REPO" > "$T/dlg.sh"
bash "$BC" bundle "$T/dlg.sh" -o "$T/alone/dlg" || bad "bundle dialog app"
dlg_check() { # script label
  local script=$1 label=$2
  local sock="$T/dlg.sock" out="$T/dlg.out" sess=bcdlg
  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
  rm -f "$sock" "$out"
  tmux -S "$sock" new-session -d -s "$sess" -x 100 -y 30 \
    bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ "$script" "$out"
  local ready=0 _
  for _ in $(seq 1 80); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -qF -- "M"; then ready=1; break; fi
    sleep 0.1
  done
  if (( ! ready )); then
    bad "$label: menu never appeared"
    tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
    return
  fi
  tmux -S "$sock" send-keys -t "$sess" Escape
  local gone=0
  for _ in $(seq 1 50); do
    if [[ -f "$out" ]]; then gone=1; break; fi
    sleep 0.1
  done
  if (( gone )) && [[ "$(cat "$out")" == "1" ]]; then
    ok "$label"
  else
    bad "$label"
  fi
  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
  rm -f "$sock"
}
dlg_check "$T/alone/dlg" "bundled dialog app runs standalone"

echo
if (( fail == 0 )); then echo "bundle_run: $pass passed"; else echo "bundle_run: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
