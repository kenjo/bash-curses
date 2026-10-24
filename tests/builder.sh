#!/bin/bash
# tmux-driven integration test for the builder (tools/bcbuild.sh): renders the
# three-pane UI, splits areas, sets a title through a prompt, saves a project
# and exports a runnable app, then checks the exported app parses.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
T="$REPO/tmp/builder"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

rm -rf "$T"; mkdir -p "$T"
sock="$T/bc.sock" out="$T/rc.out" sess=bcbuild
tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
rm -f "$sock" "$out"
tmux -S "$sock" new-session -d -s "$sess" -x 120 -y 35 \
  bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ "$REPO/tools/bcbuild.sh" "$out"

wait_for() { # needle
  local needle=$1 _
  for _ in $(seq 1 100); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -qF -- "$needle"; then return 0; fi
    sleep 0.1
  done
  return 1
}
cap() { tmux -S "$sock" capture-pane -t "$sess" -p; }
hexstr() {
  local s=$1 out="" i b
  for (( i = 0; i < ${#s}; i++ )); do
    printf -v b '%02x' "'${s:i:1}"
    out+="$b "
  done
  printf '%s' "${out% }"
}
click() { # x y (1-based screen coords)
  local sx sy
  sx=$(hexstr "$1"); sy=$(hexstr "$2")
  tmux -S "$sock" send-keys -H -t "$sess" 1b 5b 3c 30 3b $sx 3b $sy 4d
  sleep 0.1
  tmux -S "$sock" send-keys -H -t "$sess" 1b 5b 3c 30 3b $sx 3b $sy 6d
  sleep 0.3
}

if wait_for "canvas"; then ok "builder renders"; else
  bad "builder renders"; cap; tmux -S "$sock" kill-session -t "$sess" 2>/dev/null; rm -f "$sock"; exit 1
fi
grep -q "Areas" <<<"$(cap)" && ok "tree panel present" || bad "tree panel present"
grep -q "name:    main" <<<"$(cap)" && ok "properties show main" || bad "properties show main"
grep -q "Split-H" <<<"$(cap)" && ok "toolbar present" || bad "toolbar present"

# mouse: toolbar buttons
click 5 2
if wait_for "name:    main.0"; then ok "click Split-H selects main.0"; else bad "click Split-H selects main.0"; cap; fi
click 17 2
if wait_for "name:    main.0.0"; then ok "click Split-V selects main.0.0"; else bad "click Split-V selects main.0.0"; cap; fi

# mouse: clickable property rows
click 93 10
if wait_for "border:  on"; then ok "click border row toggles border"; else bad "click border row toggles border"; cap; fi

# title through the prompt dialog
tmux -S "$sock" send-keys -t "$sess" t
if wait_for "Title"; then ok "title prompt opens"; else bad "title prompt opens"; cap; fi
tmux -S "$sock" send-keys -t "$sess" "Hi" Enter
if wait_for 'title:   Hi'; then ok "title applied"; else bad "title applied"; cap; fi

# save (Save as prompt: clear the default name first)
tmux -S "$sock" send-keys -t "$sess" C-s
if wait_for "Save as"; then ok "save prompt opens"; else bad "save prompt opens"; cap; fi
tmux -S "$sock" send-keys -t "$sess" BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace BSpace
tmux -S "$sock" send-keys -t "$sess" "$T/proj.bcl" Enter
if wait_for "saved"; then ok "project saved"; else bad "project saved"; cap; fi
[[ -f $T/proj.bcl ]] && ok "project file exists" || bad "project file exists"

# export (default name is already the .sh twin of the project)
tmux -S "$sock" send-keys -t "$sess" C-e
if wait_for "Export"; then ok "export prompt opens"; else bad "export prompt opens"; cap; fi
tmux -S "$sock" send-keys -t "$sess" Enter
if wait_for "exported"; then ok "app exported"; else bad "app exported"; cap; fi

tmux -S "$sock" send-keys -t "$sess" q
for _ in $(seq 1 50); do [[ -f $out ]] && break; sleep 0.1; done
tmux -S "$sock" kill-session -t "$sess" 2>/dev/null; rm -f "$sock"

[[ $(cat "$out" 2>/dev/null) == 0 ]] && ok "clean quit rc=0" || bad "clean quit rc=0"

if [[ -f $T/proj.sh ]]; then
  bash -n "$T/proj.sh" && ok "exported app parses" || bad "exported app parses"
  grep -q 'bc_screen' "$T/proj.sh" && ok "export has layout" || bad "export has layout"
  grep -q 'title="Hi"' "$T/proj.sh" && ok "export keeps title" || bad "export keeps title"
else
  bad "exported app parses"; bad "export has layout"; bad "export keeps title"
fi

echo
if (( fail == 0 )); then echo "builder: $pass passed"; else echo "builder: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
