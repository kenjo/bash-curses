#!/bin/bash
# tmux-driven smoke tests for examples/*.sh.
# Each example is run in a real tty, sent a few keys, and must exit cleanly.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
SOCK="$REPO/tmp/bc_examples.sock"
T=bexamples
pass=0
fail=0

ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

cleanup() { tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null; }
trap cleanup EXIT

mkdir -p "$REPO/tmp"
tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
rm -f "$SOCK"

run_example() {
  local name=$1
  shift
  local base="${name%.sh}"
  local out="$REPO/tmp/bc_example_${base}.out"
  local script="$REPO/examples/$name"
  rm -f "$out"

  if [[ ! -f "$script" ]]; then
    bad "$name missing"
    return
  fi

  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
  tmux -S "$SOCK" new-session -d -s "$T" -x 100 -y 30 \
    bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ "$script" "$out"

  sleep 1
  local k
  for k in "$@"; do
    tmux -S "$SOCK" send-keys -t "$T" "$k" 2>/dev/null || true
    sleep 0.3
  done
  tmux -S "$SOCK" send-keys -t "$T" q 2>/dev/null || true

  local waited=0
  while [[ ! -f "$out" ]] && (( waited < 80 )); do
    sleep 0.1
    waited=$((waited+1))
  done

  if [[ ! -f "$out" ]]; then
    bad "$name timed out"
  else
    local rc
    rc=$(cat "$out")
    if [[ "$rc" == "0" ]]; then
      ok "$name"
    else
      bad "$name exited $rc"
    fi
  fi

  tmux -S "$SOCK" kill-session -t "$T" 2>/dev/null
}

for ex in \
  13-screen-dump.sh \
  15-window-dump.sh \
  18-pads.sh \
  19-scroll-regions.sh \
  20-copywin-overlay.sh
do
  run_example "$ex"
done

echo
if (( fail == 0 )); then
  echo "examples: $pass passed"
else
  echo "examples: $pass passed, $fail FAILED"
fi
(( fail == 0 ))
