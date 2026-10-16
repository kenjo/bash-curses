#!/bin/bash
# Compare a numbered bash example with its C ground-truth binary in tmux.
#
# Usage:
#   tests/example_compare.sh [--strict] <base>
#
# Default comparison is character-only (plain capture).  --strict also requires
# the SGR capture (colors/attributes) to match.  Artifacts are written under
# tmp/example_compare/<base>/.

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/lib/example_keys.sh"
source "$REPO/tests/lib/screen.sh"

strict=0
if [[ ${1:-} == --strict ]]; then
  strict=1
  shift
fi

if [[ $# -ne 1 ]]; then
  printf 'usage: %s [--strict] <base>\n' "$0" >&2
  exit 2
fi

base=$1
W=${BC_COMPARE_W:-100}
H=${BC_COMPARE_H:-30}
outdir="$REPO/tmp/example_compare/$base"
mkdir -p "$outdir"

skip=$(example_skip "$base")
if [[ -n $skip ]]; then
  printf 'SKIP %s: %s\n' "$base" "$skip"
  printf 'SKIP %s: %s\n' "$base" "$skip" > "$outdir/result"
  exit 0
fi

bash_script="$REPO/examples/$base.sh"
c_bin="$REPO/examples/$base"
if [[ ! -f "$bash_script" ]]; then
  printf 'FAIL %s missing bash example\n' "$base"
  printf 'FAIL %s missing bash example\n' "$base" > "$outdir/result"
  exit 1
fi
if [[ ! -x "$c_bin" ]]; then
  make -C "$REPO/examples" "$base" >/dev/null
fi
if [[ ! -x "$c_bin" ]]; then
  printf 'FAIL %s missing C binary\n' "$base"
  printf 'FAIL %s missing C binary\n' "$base" > "$outdir/result"
  exit 1
fi

clean_example_files() {
  rm -f \
    "$REPO/tmp/bc_screen.dump" \
    "$REPO/tmp/bc_window.dump" \
    "$REPO/tmp/bc_example_putwin.win" \
    "$REPO/tmp/bc_example_scr_dump.dmp"
}

send_key() {
  local sock=$1 sess=$2 key=$3
  if [[ $key == raw:* ]]; then
    tmux -S "$sock" send-keys -H -t "$sess" ${key#raw:} 2>/dev/null || true
  else
    tmux -S "$sock" send-keys -t "$sess" "$key" 2>/dev/null || true
  fi
}

run_capture() {
  local kind=$1
  local sock="$REPO/tmp/bc_cmp_${base}_${kind}.sock"
  local sess="bc_cmp_${base}_${kind}"
  local marker="$outdir/${kind}.rc"
  local cmd

  if [[ $kind == bash ]]; then
    cmd="bash \"$bash_script\""
  else
    cmd="\"$c_bin\""
  fi

  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null || true
  rm -f "$sock" "$marker"
  clean_example_files

  tmux -S "$sock" new-session -d -s "$sess" -x "$W" -y "$H" \
    "bash -c '$cmd; rc=\$?; printf \"%s\\n\" \"\$rc\" > \"$marker\"; sleep 30'"

  sleep 1
  mapfile -t actions < <(example_actions "$base")
  local key
  for key in "${actions[@]}"; do
    send_key "$sock" "$sess" "$key"
    sleep 0.3
  done
  sleep 0.5

  tmux -S "$sock" capture-pane -t "$sess" -p > "$outdir/${kind}.plain"
  tmux -S "$sock" capture-pane -t "$sess" -e -p > "$outdir/${kind}.sgr"

  send_key "$sock" "$sess" "$(example_quit "$base")"
  local waited=0
  while [[ ! -f "$marker" ]] && (( waited < 80 )); do
    sleep 0.1
    waited=$((waited + 1))
  done

  tmux -S "$sock" kill-session -t "$sess" 2>/dev/null || true
  rm -f "$sock"
}

run_capture bash
run_capture c

normalize_plain() {
  sed -e "s#$REPO/examples/\.\./tmp/#tmp/#g" -e "s#$REPO/tmp/#tmp/#g" "$1" > "$2"
}

normalize_plain "$outdir/bash.plain" "$outdir/bash.plain.norm"
normalize_plain "$outdir/c.plain" "$outdir/c.plain.norm"

# The bash examples print an absolute $REPO-based dump path while the C
# ground truth prints a relative one; collapse both so the per-cell SGR grid
# aligns (the path is example content, not a rendering difference).
normalize_plain "$outdir/bash.sgr" "$outdir/bash.sgr.norm"
normalize_plain "$outdir/c.sgr" "$outdir/c.sgr.norm"

plain_rc=0
diff -u "$outdir/bash.plain.norm" "$outdir/c.plain.norm" > "$outdir/diff.plain" || plain_rc=$?

sgr_rc=0
screen_diff "$outdir/bash.sgr.norm" "$outdir/c.sgr.norm" "$W" "$H" > "$outdir/diff.sgr" || sgr_rc=$?

if (( plain_rc != 0 )); then
  printf 'FAIL %s plain screen differs\n' "$base"
  printf 'FAIL %s plain screen differs\n' "$base" > "$outdir/result"
  exit 1
fi

if (( strict && sgr_rc != 0 )); then
  printf 'FAIL %s SGR screen differs\n' "$base"
  printf 'FAIL %s SGR screen differs\n' "$base" > "$outdir/result"
  exit 1
fi

if (( sgr_rc != 0 )); then
  printf 'ok   %s plain matches; SGR differs (see %s)\n' "$base" "$outdir/diff.sgr"
  printf 'ok   %s plain matches; SGR differs\n' "$base" > "$outdir/result"
else
  printf 'ok   %s plain and SGR match\n' "$base"
  printf 'ok   %s plain and SGR match\n' "$base" > "$outdir/result"
fi
