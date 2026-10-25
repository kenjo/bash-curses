#!/bin/bash
# tmux-driven smoke tests for numbered examples/*.sh.
# Each example is run in a real tty, sent a few keys, and must exit cleanly.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
RES="$REPO/tmp/examples_results"
LOGS="$REPO/tmp/examples_logs"
JOBS=${BC_TEST_JOBS:-$(nproc)}
(( JOBS > 8 )) && JOBS=8
(( JOBS < 1 )) && JOBS=1

cleanup() {
  for sock in "$REPO"/tmp/bc_example_*.sock; do
    [[ -e $sock ]] || continue
    base=${sock##*/bc_example_}
    base=${base%.sock}
    tmux -S "$sock" kill-session -t "bc_${base}" 2>/dev/null || true
    rm -f "$sock"
  done
}
trap cleanup EXIT

mkdir -p "$REPO/tmp"
rm -rf "$RES" "$LOGS"
mkdir -p "$RES" "$LOGS"
rm -f "$REPO"/tmp/bc_example_*.sock "$REPO"/tmp/bc_example_*.out "$REPO"/tmp/bc_example_*.log

PIDS=()
start_example() {
  local name=$1
  shift
  local base="${name%.sh}"
  local sock="$REPO/tmp/bc_example_${base}.sock"
  local sess="bc_${base}"
  local out="$REPO/tmp/bc_example_${base}.out"
  local log="$LOGS/${base}.log"
  local res="$RES/${base}.res"
  local script="$REPO/examples/$name"
  rm -f "$out" "$log" "$res"

  if [[ ! -f "$script" ]]; then
    printf 'FAIL %s missing\n' "$name" > "$res"
    return
  fi

  (
    tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
    rm -f "$sock"
    tmux -S "$sock" new-session -d -s "$sess" -x 100 -y 30 \
      bash -c 'bash "$1"; rc=$?; printf "%s\n" "$rc" > "$2"' _ "$script" "$out"

    sleep 1
    local k
    for k in "$@"; do
      if [[ $k == raw:* ]]; then
        tmux -S "$sock" send-keys -H -t "$sess" ${k#raw:} 2>/dev/null || true
      else
        tmux -S "$sock" send-keys -t "$sess" "$k" 2>/dev/null || true
      fi
      sleep 0.3
    done
    tmux -S "$sock" send-keys -t "$sess" q 2>/dev/null || true

    local waited=0
    while [[ ! -f "$out" ]] && (( waited < 80 )); do
      sleep 0.1
      waited=$((waited+1))
    done

    if [[ ! -f "$out" ]]; then
      printf 'FAIL %s timed out\n' "$name" > "$res"
    else
      local rc
      rc=$(cat "$out")
      if [[ "$rc" == "0" ]]; then
        printf 'ok   %s\n' "$name" > "$res"
      else
        printf 'FAIL %s exited %s\n' "$name" "$rc" > "$res"
      fi
    fi

    tmux -S "$sock" kill-session -t "$sess" 2>/dev/null
    rm -f "$sock"
  ) > "$log" 2>&1 &

  PIDS+=("$!")
  if (( ${#PIDS[@]} >= JOBS )); then
    wait -n
    local live=()
    local p
    for p in "${PIDS[@]}"; do
      if kill -0 "$p" 2>/dev/null; then
        live+=("$p")
      fi
    done
    PIDS=("${live[@]}")
  fi
}

for ex in \
  12-mouse.sh \
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
  65-varargs-scanw.sh \
  66-screen-dump-sp.sh \
  67-scroll-regions-extra.sh \
  68-border-line-extra.sh \
  69-input-wrappers.sh \
  70-wide-stdscr.sh \
  71-stdscr-del-ins.sh \
  72-stdscr-in.sh \
  73-stdscr-add.sh \
  74-wide-mv.sh \
  75-attr-bg-extra.sh \
  76-panel-bottom.sh \
  77-wide-insert-extra.sh \
  78-scanw-getstr-extra.sh \
  79-hline-set-extra.sh \
  80-copywin-clrtobot.sh \
  81-sudoku.sh
do
  case $ex in
    12-mouse.sh)
      # click "Choice 2" (fixed 80x24 layout: screen col 28, row 11, 1-based)
      start_example "$ex" "raw:1b 5b 3c 30 3b 32 38 3b 31 31 4d 1b 5b 3c 30 3b 32 38 3b 31 31 6d"
      ;;
    13-screen-dump.sh)
      start_example "$ex" r
      ;;
    15-window-dump.sh)
      start_example "$ex" g d
      ;;
    18-pads.sh)
      start_example "$ex" Up Down Left Right
      ;;
    19-scroll-regions.sh)
      start_example "$ex" Down Up NPage PPage
      ;;
    23-halfdelay.sh)
      start_example "$ex" q
      ;;
    24-mouse-buttons.sh)
      start_example "$ex" "raw:1b 5b 3c 30 3b 35 3b 36 4d 1b 5b 3c 30 3b 35 3b 36 6d"
      ;;
    25-background.sh)
      start_example "$ex" b s g
      ;;
    26-inserts.sh)
      start_example "$ex" i n s d I D
      ;;
    27-keyname.sh)
      start_example "$ex" Up F1 a
      ;;
    28-inchs.sh)
      start_example "$ex" i n s m
      ;;
    29-addchstr.sh)
      start_example "$ex" a n m b
      ;;
    30-instr.sh)
      start_example "$ex" i n m b
      ;;
    31-subwin.sh)
      start_example "$ex" p c m
      ;;
    32-movewindow.sh)
      start_example "$ex" p c
      ;;
    33-clip-printw.sh)
      start_example "$ex" a b
      ;;
    34-test-opaque.sh)
      start_example "$ex" c i l m v s n t
      ;;
    35-test-delwin.sh)
      start_example "$ex" c d c d
      ;;
    36-wresize.sh)
      start_example "$ex" + - r
      ;;
    37-use-window.sh)
      start_example "$ex" 1 2 s d
      ;;
    38-touch-lines.sh)
      start_example "$ex" t u l w
      ;;
    39-echochar.sh)
      start_example "$ex" e w u
      ;;
    40-defkey.sh)
      start_example "$ex" d k b o
      ;;
    41-slk.sh)
      start_example "$ex" c r t l a
      ;;
    42-prog-mode.sh)
      start_example "$ex" d r
      ;;
    43-filter.sh)
      start_example "$ex" f n
      ;;
    44-vidattr.sh)
      start_example "$ex" a p
      ;;
    45-color-pair.sh)
      start_example "$ex" p e a
      ;;
    46-wide-output.sh)
      start_example "$ex" a w n s e
      ;;
    47-wide-input.sh)
      start_example "$ex" w g m i n s u
      ;;
    48-wide-insert.sh)
      start_example "$ex" w i m n s
      ;;
    49-dupwin.sh)
      start_example "$ex" d d
      ;;
    50-mcprint.sh)
      start_example "$ex" m n c w
      ;;
    51-wenclose.sh)
      start_example "$ex" u d l r t
      ;;
    52-pad-extra.sh)
      start_example "$ex" Up Down Left Right s p n e
      ;;
    53-putwin-getwin.sh)
      start_example "$ex" s l
      ;;
    54-chgat-attrs.sh)
      start_example "$ex" c w m s o f
      ;;
    55-border-lines.sh)
      start_example "$ex" b x m h v
      ;;
    56-input-misc.sh)
      start_example "$ex" m e k 1 2 i u n d f b l c
      ;;
    57-mouse-extra.sh)
      start_example "$ex" i h u s
      ;;
    58-color-extended.sh)
      start_example "$ex" c p a f r
      ;;
    59-wide-extra.sh)
      start_example "$ex" n a i s r
      ;;
    60-attr-get.sh)
      start_example "$ex" s e g w a o f
      ;;
    61-string-wrappers.sh)
      start_example "$ex" a n m b w c s i
      ;;
    62-window-query.sh)
      start_example "$ex" c b m a k d e h
      ;;
    63-clear-refresh.sh)
      start_example "$ex" c t e n d s u o r
      ;;
    64-slk-extra.sh)
      start_example "$ex" a o f s 1 2 c n
      ;;
    65-varargs-scanw.sh)
      start_example "$ex" p v 1 s 42 Enter w 43 Enter 2 44 Enter
      ;;
    66-screen-dump-sp.sh)
      start_example "$ex" d i r s
      ;;
    67-scroll-regions-extra.sh)
      start_example "$ex" u d s r c
      ;;
    68-border-line-extra.sh)
      start_example "$ex" b 1 m h v 2 3 4 s t
      ;;
    69-input-wrappers.sh)
      start_example "$ex" k a g b w c n 12345 Enter s abc Enter 1 67890 Enter 2 def Enter
      ;;
    70-wide-stdscr.sh)
      start_example "$ex" a 1 m 2 i 3 4 n 5 s
      ;;
    71-stdscr-del-ins.sh)
      start_example "$ex" d 1 w 2 i 3 m 4 s 5 n 6
      ;;
    72-stdscr-in.sh)
      start_example "$ex" i 1 m n 2 r s t 3 u
      ;;
    73-stdscr-add.sh)
      start_example "$ex" a 1 m 2 n 3 r s t u v w
      ;;
    74-wide-mv.sh)
      start_example "$ex" a 1 w 2 g a 3 b i 4 n 5 s 6
      ;;
    75-attr-bg-extra.sh)
      start_example "$ex" a o f 1 2 3 b 4 k 5 g p v 6 u t
      ;;
    76-panel-bottom.sh)
      start_example "$ex" b t h s m r w u
      ;;
    77-wide-insert-extra.sh)
      start_example "$ex" w 1 s 2 n i 3 m 4
      ;;
    78-scanw-getstr-extra.sh)
      start_example "$ex" s 4 2 Enter w 4 3 Enter g a b c Enter
      ;;
    79-hline-set-extra.sh)
      start_example "$ex" h v m n w 1
      ;;
    80-copywin-clrtobot.sh)
      start_example "$ex" c 1 2 l i
      ;;
    81-sudoku.sh)
      start_example "$ex" l 5 x u m c r
      ;;
    *)
      start_example "$ex"
      ;;
  esac
done

wait

pass=0
fail=0
for res in "$RES"/*.res; do
  [[ -e $res ]] || continue
  line=$(cat "$res")
  printf '%s\n' "$line"
  if [[ $line == ok* ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
  fi
done

echo
if (( fail == 0 )); then
  echo "examples: $pass passed"
else
  echo "examples: $pass passed, $fail FAILED"
fi
(( fail == 0 ))
