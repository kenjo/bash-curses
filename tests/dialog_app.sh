#!/bin/bash
# tmux-driven test for the ported start_local_ai_bc.sh: drives the bash_curses
# menu with fake tools (no real services are started or killed).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
APP=/home/kenjo/proj/ai/start_local_ai_bc.sh
T="$REPO/tmp/dialog_app"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

if [[ ! -f $APP ]]; then
  echo "dialog_app: $APP not present, skipping"
  exit 0
fi

rm -rf "$T"
mkdir -p "$T/bin" "$T/models"

# fake tools: nothing real is contacted or killed
printf '#!/bin/bash\nexit 1\n'            > "$T/bin/curl"        # servers look stopped
printf '#!/bin/bash\necho 123\n'          > "$T/bin/nvidia-smi"
printf '#!/bin/bash\ncat <<EOF\n              total        used        free      shared  buff/cache   available\nMem:             62          10          40           1          12          50\nEOF\n' > "$T/bin/free"
printf '#!/bin/bash\nexit 0\n'            > "$T/bin/pkill"
chmod +x "$T/bin"/*

# two fake models (one with a vision projector)
: > "$T/models/Test-27B.gguf"
: > "$T/models/mmproj-Test-BF16.gguf"

sock="$T/app.sock" out="$T/app.out" sess=bcapp
tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
rm -f "$sock" "$out"
tmux -S "$sock" new-session -d -s "$sess" -x 100 -y 30 \
  env PATH="$T/bin:$PATH" MODELS_DIR="$T/models" BC_LIB_DIR="$REPO" \
  bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ "$APP" "$out"

wait_for() { # needle
  local needle=$1 _
  for _ in $(seq 1 100); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -qF -- "$needle"; then return 0; fi
    sleep 0.1
  done
  return 1
}

# main menu appears
if wait_for "start_local_ai"; then ok "main menu renders"; else
  bad "main menu renders"; tmux -S "$sock" kill-session -t "$sess" 2>/dev/null; rm -f "$sock"; exit 1
fi

# status -> msgbox -> OK
tmux -S "$sock" send-keys -t "$sess" Down Down Enter
if wait_for "Status"; then ok "status msgbox renders"; else bad "status msgbox renders"; fi
tmux -S "$sock" send-keys -t "$sess" Enter
sleep 0.4

# stop -> submenu -> cancel with Esc (back to main menu)
tmux -S "$sock" send-keys -t "$sess" Down Down Down Enter
if wait_for "Stop server"; then ok "stop submenu renders"; else bad "stop submenu renders"; fi
tmux -S "$sock" send-keys -t "$sess" Escape
sleep 0.4

# quit via letter jump + Enter
tmux -S "$sock" send-keys -t "$sess" q Enter

gone=0
for _ in $(seq 1 60); do [[ -f "$out" ]] && { gone=1; break; }; sleep 0.1; done
if (( gone )) && [[ "$(cat "$out")" == "0" ]]; then
  ok "app exits cleanly on quit"
else
  bad "app exits cleanly on quit"
fi

tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
rm -f "$sock"

echo
if (( fail == 0 )); then echo "dialog_app: $pass passed"; else echo "dialog_app: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
