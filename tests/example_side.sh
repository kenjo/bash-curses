#!/bin/bash
# Run a numbered bash example and its C ground-truth binary side-by-side in tmux.
#
# Usage:
#   tests/example_side.sh <base> [tmux-key ...]
#
# If no keys are supplied, tests/lib/example_keys.sh supplies the action keys.
# The runner leaves both programs running for manual inspection; cleanup kills
# only the uniquely named session created by this script.

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/lib/example_keys.sh"

if [[ $# -lt 1 ]]; then
  printf 'usage: %s <base> [tmux-key ...]\n' "$0" >&2
  exit 2
fi

base=$1
shift

bash_script="$REPO/examples/$base.sh"
c_bin="$REPO/examples/$base"
if [[ ! -f "$bash_script" ]]; then
  printf 'missing bash example: %s\n' "$bash_script" >&2
  exit 1
fi
if [[ ! -x "$c_bin" ]]; then
  make -C "$REPO/examples" "$base" >/dev/null
fi
if [[ ! -x "$c_bin" ]]; then
  printf 'missing C binary: %s\n' "$c_bin" >&2
  exit 1
fi

sock="$REPO/tmp/bc_side_${base}.sock"
sess="bc_side_${base}"
cleanup() {
  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null || true
  rm -f "$sock"
}
trap cleanup EXIT

tmux -S "$sock" kill-session -t "$sess" 2>/dev/null || true
rm -f "$sock"
tmux -S "$sock" new-session -d -s "$sess" -x 200 -y 30 \
  "bash --rcfile /dev/null -i -c 'bash \"$bash_script\"'"
tmux -S "$sock" split-window -h -t "$sess" \
  "bash --rcfile /dev/null -i -c '\"$c_bin\"'"
tmux -S "$sock" select-pane -t "$sess.0"

send_to_pane() {
  local pane=$1 key=$2
  if [[ $key == raw:* ]]; then
    tmux -S "$sock" send-keys -H -t "$sess.$pane" ${key#raw:} 2>/dev/null || true
  else
    tmux -S "$sock" send-keys -t "$sess.$pane" "$key" 2>/dev/null || true
  fi
}

if [[ $# -gt 0 ]]; then
  keys=("$@")
else
  mapfile -t keys < <(example_actions "$base")
fi

sleep 1
for key in "${keys[@]}"; do
  send_to_pane 0 "$key"
  send_to_pane 1 "$key"
  sleep 0.3
done

printf 'side-by-side session: %s\n' "$sess"
printf 'left:  bash examples/%s.sh\n' "$base"
printf 'right: examples/%s\n' "$base"
printf 'attach: tmux -S %s attach -t %s\n' "$sock" "$sess"
printf 'cleanup: tmux -S %s kill-session -t %s\n' "$sock" "$sess"

while tmux -S "$sock" has-session -t "$sess" 2>/dev/null; do
  sleep 1
done
