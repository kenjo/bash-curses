#!/bin/bash
# Discovery harness: drive real Midnight Commander and the bash clone inside the
# same controlled directory tree, feed them an identical key sequence, capture the
# screen (plain + SGR colors) after every step, and report exactly where the two
# diverge. This is a slow, interactive discovery tool -- it is NOT part of
# tests/run.sh. Findings are recorded in ANOMALIES.md at the repo root.
#
# Usage:  bash tests/visual_diff.sh [step ...]
#   With no args it runs every step in the built-in script. Pass one or more step
#   labels to run only those (useful while iterating).
#
# Output (under tmp/vd/):
#   mc/<n>_<label>.{sgr,plain}   real MC screen after that step
#   clone/<n>_<label>.{sgr,plain}  clone screen after that step
#   REPORT.txt                    per-step plain-text diff + a match flag
#   diff_<n>_<label>.txt          raw diff for the (first) differing step, if any

REPO="$(cd "$(dirname "$0")/.." && pwd)"
# per-cell SGR grid parser (text + fg + bg + attrs) for rich color diffs
source "$REPO/tests/lib/screen.sh"
ROOT="$REPO/tmp/vd"
TREE="$ROOT/tree"
SOCKM="$ROOT/mc.sock";  SESSM=vdmcm
SOCKC="$ROOT/cl.sock";  SESSC=vdmcl
X=100; Y=30

pass=0; fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

# ------------------------------------------------------------------ controlled tree
build_tree() {
  rm -rf "$ROOT"; mkdir -p "$TREE/alpha" "$TREE/beta" "$TREE/gamma"
  printf 'aaaa\n'   > "$TREE/a.txt"
  printf 'bb\n'     > "$TREE/b.md"
  printf '#!/bin/sh\necho hi\n' > "$TREE/c.sh"; chmod +x "$TREE/c.sh"
  # deterministic mtimes so both apps print the same "Modify time"
  local f
  for f in "$TREE"/* "$TREE"/*/*; do touch -d '2020-01-02 03:04:05' "$f" 2>/dev/null; done
}

# ------------------------------------------------------------------ app lifecycle
start_app() { # which (mc|clone)
  local which=$1 sock sess
  if [[ $which == mc ]]; then sock=$SOCKM; sess=$SESSM
  else sock=$SOCKC; sess=$SESSC; fi
  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
  rm -f "$sock"
  if [[ $which == mc ]]; then
    tmux -S "$sock" new-session -d -s "$sess" -x "$X" -y "$Y" \
      bash -c "cd '$TREE' && exec /usr/bin/mc"
  else
    tmux -S "$sock" new-session -d -s "$sess" -x "$X" -y "$Y" \
      bash -c "cd '$TREE' && exec bash '$REPO/examples/mc.sh'"
  fi
  local ready=0
  for _ in $(seq 1 120); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -q 'Name'; then ready=1; break; fi
    sleep 0.1
  done
  (( ready )) && sleep 1
  return $(( 1 - ready ))
}

send_seq() { # which keys...
  local which=$1; shift
  local sock sess
  if [[ $which == mc ]]; then sock=$SOCKM; sess=$SESSM; else sock=$SOCKC; sess=$SESSC; fi
  local k
  for k in "$@"; do
    [[ -n $k ]] && { tmux -S "$sock" send-keys -t "$sess" "$k"; sleep 0.5; }
  done
}

cap_step() { # which label -> writes $ROOT/which/<idx>_<label>.*
  local which=$1 label=$2
  local sock sess idx
  if [[ $which == mc ]]; then sock=$SOCKM; sess=$SESSM; else sock=$SOCKC; sess=$SESSC; fi
  printf -v idx '%02d' "$STEP_IDX"
  tmux -S "$sock" capture-pane -t "$sess" -e -p > "$ROOT/$which/$idx.$label.sgr"
  tmux -S "$sock" capture-pane -t "$sess" -p      > "$ROOT/$which/$idx.$label.plain"
}

cleanup() {
  tmux -S "$SOCKM" kill-session -t "$SESSM" 2>/dev/null
  tmux -S "$SOCKC" kill-session -t "$SESSC" 2>/dev/null
  rm -f "$SOCKM" "$SOCKC"
}
trap cleanup EXIT

# ------------------------------------------------------------------ the key script
# Each entry is "label|key1 key2 key3" -- keys are sent in order starting from a
# freshly-started app (each step is independent, so screens are comparable).
ALL_STEPS=(
  "initial|"
  "menu_f9|F9"
  "menu_f9_down|F9 Down"
  "menu_f9_down2|F9 Down Down"
  "menu_f9_right|F9 Right"
  "menu_f9_right_down|F9 Right Down"
  "menu_f2|F2"
  "menu_f2_down|F2 Down"
  "panel_tab|Tab"
  "nav_down2|Down Down"
  "open_alpha|Down Enter"
  "viewer_txt|Down Down F3"
  "f1_help|F1"
)

# ------------------------------------------------------------------ run one step
run_step() { # label keys...
  local label=$1; shift
  local keys=("$@")
  STEP_IDX=$(( STEP_IDX + 1 ))
  local n; printf -v n '%02d' "$STEP_IDX"
  printf '\n== %s: %s ==\n' "$label" "${keys[*]:-(none)}"

  local mcok clok
  start_app mc;    mcok=$?
  start_app clone; clok=$?
  (( mcok != 0 ))  && bad "$label: mc failed to start"
  (( clok != 0 ))  && bad "$label: clone failed to start"
  (( mcok == 0 )) && send_seq mc    "${keys[@]}"
  (( clok == 0 )) && send_seq clone "${keys[@]}"
  (( mcok == 0 )) && cap_step mc    "$label"
  (( clok == 0 )) && cap_step clone "$label"

  local mcp="$ROOT/mc/$n.$label.plain"    ccp="$ROOT/clone/$n.$label.plain"
  local mps="$ROOT/mc/$n.$label.sgr"      cps="$ROOT/clone/$n.$label.sgr"
  if diff -q "$mcp" "$ccp" >/dev/null 2>&1; then
    ok "$label: plain text identical"
  else
    bad "$label: plain text differs"
    { echo "### step $label -- plain diff (mc<  vs  clone>)"; diff "$mcp" "$ccp"; } \
      >> "$ROOT/REPORT.txt"
    cp "$ROOT/REPORT.txt" "$ROOT/diff_$n.$label.txt" 2>/dev/null
  fi
  # colors: per-cell comparison via the SGR grid parser (surfaces fg/bg/attr
  # differences a raw line-diff can't show, down to the exact cell)
  if [[ -s $mps && -s $cps ]]; then
    local sgr_report sgr_rc=0
    sgr_report="$(screen_diff "$mps" "$cps" "$X" "$Y" 2>&1)" || sgr_rc=$?
    if (( sgr_rc != 0 )); then
      {
        echo "   .. $label: per-cell SGR differences (mc<  vs  clone>):"
        printf '%s\n' "$sgr_report"
      } >> "$ROOT/REPORT.txt"
    fi
  fi
}

# ------------------------------------------------------------------ main
build_tree
mkdir -p "$ROOT/mc" "$ROOT/clone"
STEP_IDX=0
: > "$ROOT/REPORT.txt"
{
  echo "MC vs clone -- per-step capture"
  echo "tree: $TREE   (100x30)"
  echo "labels: ${ALL_STEPS[*]}"
} >> "$ROOT/REPORT.txt"

if (( $# > 0 )); then
  # only run the named steps (full "label|keys" entries)
  for want in "$@"; do
    for e in "${ALL_STEPS[@]}"; do
      [[ ${e%%|*} == "$want" ]] && { IFS='|' read -r lab keys <<< "$e"; run_step "$lab" $keys; }
    done
  done
else
  for e in "${ALL_STEPS[@]}"; do
    IFS='|' read -r lab keys <<< "$e"; run_step "$lab" $keys
  done
fi

echo
echo "report: $ROOT/REPORT.txt"
echo "captures: $ROOT/mc/  $ROOT/clone/"
echo "steps run: $pass identical, $fail differing"
exit 0
