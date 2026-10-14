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
    if [[ $k == raw:* ]]; then
      tmux -S "$SOCK" send-keys -H -t "$T" ${k#raw:} 2>/dev/null || true
    else
      tmux -S "$SOCK" send-keys -t "$T" "$k" 2>/dev/null || true
    fi
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
  20-copywin-overlay.sh \
  21-color-content.sh \
  22-scanw-getstr.sh \
  23-halfdelay.sh \
  24-mouse-buttons.sh \
  25-background.sh \
  26-inserts.sh \
  27-keyname.sh \
  28-inchs.sh \
  29-addchstr.sh \
  30-instr.sh \
  31-subwin.sh \
  32-movewindow.sh \
  33-clip-printw.sh \
  34-test-opaque.sh \
  35-test-delwin.sh \
  36-wresize.sh \
  37-use-window.sh \
  38-touch-lines.sh \
  39-echochar.sh \
  40-defkey.sh \
  41-slk.sh \
  42-prog-mode.sh \
  43-filter.sh \
  44-vidattr.sh \
  45-color-pair.sh \
  46-wide-output.sh \
  47-wide-input.sh \
  48-wide-insert.sh \
  49-dupwin.sh \
  50-mcprint.sh \
  51-wenclose.sh \
  52-pad-extra.sh \
  53-putwin-getwin.sh \
  54-chgat-attrs.sh \
  55-border-lines.sh \
  56-input-misc.sh \
  57-mouse-extra.sh \
  58-color-extended.sh \
  59-wide-extra.sh \
  60-attr-get.sh \
  61-string-wrappers.sh \
  62-window-query.sh \
  63-clear-refresh.sh \
  64-slk-extra.sh \
  65-varargs-scanw.sh
do
  case $ex in
    13-screen-dump.sh)
      run_example "$ex" r
      ;;
    15-window-dump.sh)
      run_example "$ex" g d
      ;;
    18-pads.sh)
      run_example "$ex" Up Down Left Right
      ;;
    19-scroll-regions.sh)
      run_example "$ex" Down Up NPage PPage
      ;;
    24-mouse-buttons.sh)
      run_example "$ex" "raw:1b 5b 3c 30 3b 35 3b 36 4d 1b 5b 3c 30 3b 35 3b 36 6d"
      ;;
    25-background.sh)
      run_example "$ex" b s g
      ;;
    26-inserts.sh)
      run_example "$ex" i n s d I D
      ;;
    27-keyname.sh)
      run_example "$ex" Up F1 a
      ;;
    28-inchs.sh)
      run_example "$ex" i n s m
      ;;
    29-addchstr.sh)
      run_example "$ex" a n m b
      ;;
    30-instr.sh)
      run_example "$ex" i n m b
      ;;
    31-subwin.sh)
      run_example "$ex" p c m
      ;;
    32-movewindow.sh)
      run_example "$ex" p c
      ;;
    33-clip-printw.sh)
      run_example "$ex" a b
      ;;
    34-test-opaque.sh)
      run_example "$ex" c i l m v s n t
      ;;
    35-test-delwin.sh)
      run_example "$ex" c d c d
      ;;
    36-wresize.sh)
      run_example "$ex" + - r
      ;;
    37-use-window.sh)
      run_example "$ex" 1 2 s d
      ;;
    38-touch-lines.sh)
      run_example "$ex" t u l w
      ;;
    39-echochar.sh)
      run_example "$ex" e w u
      ;;
    40-defkey.sh)
      run_example "$ex" d k b o
      ;;
    41-slk.sh)
      run_example "$ex" c r t l a
      ;;
    42-prog-mode.sh)
      run_example "$ex" d r
      ;;
    43-filter.sh)
      run_example "$ex" f n
      ;;
    44-vidattr.sh)
      run_example "$ex" a p
      ;;
    45-color-pair.sh)
      run_example "$ex" p e a
      ;;
    46-wide-output.sh)
      run_example "$ex" a w n s e
      ;;
    47-wide-input.sh)
      run_example "$ex" w g m i n s u
      ;;
    48-wide-insert.sh)
      run_example "$ex" w i m n s
      ;;
    49-dupwin.sh)
      run_example "$ex" d d
      ;;
    50-mcprint.sh)
      run_example "$ex" m n c w
      ;;
    51-wenclose.sh)
      run_example "$ex" u d l r t
      ;;
    52-pad-extra.sh)
      run_example "$ex" Up Down Left Right s p n e
      ;;
    53-putwin-getwin.sh)
      run_example "$ex" s l
      ;;
    54-chgat-attrs.sh)
      run_example "$ex" c w m s o f
      ;;
    55-border-lines.sh)
      run_example "$ex" b x m h v
      ;;
    56-input-misc.sh)
      run_example "$ex" m e k 1 2 i u n d f b l c
      ;;
    57-mouse-extra.sh)
      run_example "$ex" i h u s
      ;;
    58-color-extended.sh)
      run_example "$ex" c p a f r
      ;;
    59-wide-extra.sh)
      run_example "$ex" n a i s r
      ;;
    60-attr-get.sh)
      run_example "$ex" s e g w a o f
      ;;
    61-string-wrappers.sh)
      run_example "$ex" a n m b w c s i
      ;;
    62-window-query.sh)
      run_example "$ex" c b m a k d e h
      ;;
    63-clear-refresh.sh)
      run_example "$ex" c t e n d s u o r
      ;;
    64-slk-extra.sh)
      run_example "$ex" a o f s 1 2 c n
      ;;
    65-varargs-scanw.sh)
      run_example "$ex" p v 1 s 42 Enter w 43 Enter 2 44 Enter
      ;;
    *)
      run_example "$ex"
      ;;
  esac
done

echo
if (( fail == 0 )); then
  echo "examples: $pass passed"
else
  echo "examples: $pass passed, $fail FAILED"
fi
(( fail == 0 ))
