#!/bin/bash
# tmux-driven integration test: injects raw key/mouse bytes into the battery app
# (tests/battery_app.sh) running on a real pty, then checks the decoded output.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$REPO/tmp/bc_out_int.txt"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
T=bcint
tmux kill-session -t "$T" 2>/dev/null
tmux new-session -d -s "$T" -x 100 -y 30 bash "$REPO/tests/battery_app.sh"

ready=0
for _ in $(seq 1 50); do
  if grep -q '^READY' "$OUT" 2>/dev/null; then ready=1; break; fi
  sleep 0.1
done
if (( ! ready )); then
  echo "FAIL: battery app did not become READY"
  tmux kill-session -t "$T" 2>/dev/null
  exit 1
fi

pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
count() { grep -cE -- "$1" "$OUT" 2>/dev/null || true; }
expect_key() {
  local n; n=$(count "^KEY at .* $1\$")
  if (( n >= 1 )); then ok "KEY $1"; else bad "KEY $1 missing"; fi
}
expect_key_count() {
  local n; n=$(count "^KEY at .* $1\$")
  if (( n == $2 )); then ok "KEY $1 == $2"; else bad "KEY $1 == $n (want $2)"; fi
}
expect_ev_count() {
  local n; n=$(count "^EV at .* x=$1 y=$2 bstate=$3\$")
  if (( n == $4 )); then ok "EV x=$1 y=$2 bstate=$3 == $4"; else bad "EV x=$1 y=$2 bstate=$3 == $n (want $4)"; fi
}

# ---------------- keys ----------------
sendk() { tmux send-keys -H -t "$T" "$@"; sleep 0.3; }
sendk 1b 4f 41        # UP
sendk 1b 4f 42        # DOWN
sendk 1b 4f 44        # LEFT
sendk 1b 4f 43        # RIGHT
sendk 1b 4f 48        # HOME
sendk 1b 4f 46        # END
sendk 1b 4f 50        # F1
sendk 1b 5b 32 31 7e  # F10
sendk 1b 5b 32 34 7e  # F12
sendk 1b 5b 35 7e     # PPAGE
sendk 1b 5b 36 7e     # NPAGE
sendk 61              # 'a'
sendk 1b; sleep 1.5   # bare ESC (waits out ESCDELAY)
sendk 1b 5b 41        # CSI up: not a key -> raw 27 91 65

expect_key 259
expect_key 258
expect_key 260
expect_key 261
expect_key 262
expect_key 360
expect_key 265
expect_key 274
expect_key 276
expect_key 339
expect_key 338
expect_key 97
expect_key_count 27 2   # bare ESC + first byte of CSI-up
expect_key_count 91 1
expect_key_count 65 1

# ---------------- mouse ----------------
Lp='1b 5b 3c 30 3b 35 3b 36 4d'    # left press  (col 4, row 5)
Lr='1b 5b 3c 30 3b 35 3b 36 6d'    # left release
Mp='1b 5b 3c 31 3b 35 3b 36 4d'    # middle press
Mr='1b 5b 3c 31 3b 35 3b 36 6d'    # middle release
Wu='1b 5b 3c 36 34 3b 35 3b 36 4d' # wheel up (b=64)
Lp2='1b 5b 3c 30 3b 39 3b 31 30 4d' # left press  (col 8, row 9)
Lr2='1b 5b 3c 30 3b 39 3b 31 30 6d' # left release
s() { tmux send-keys -H -t "$T" "$@"; }

sleep 0.6
s $Lp; sleep 0.05; s $Lr; sleep 0.6          # click
s $Lp; sleep 0.3;  s $Lr; sleep 0.6          # slow press then release
s $Lp; sleep 0.05; s $Lr; sleep 0.05; s $Lp; sleep 0.05; s $Lr; sleep 0.6   # double
s $Lp; sleep 0.05; s $Lr; sleep 0.05; s $Lp; sleep 0.05; s $Lr; sleep 0.05; s $Lp; sleep 0.05; s $Lr; sleep 0.6  # triple
s $Mp; sleep 0.05; s $Mr; sleep 0.6          # middle click
s $Wu; sleep 0.6                             # wheel up
s $Lp; sleep 0.05; s $Lr; sleep 0.05; s $Lp2; sleep 0.05; s $Lr2; sleep 0.6  # double at different positions

expect_ev_count 4 5 4     1   # click (only the first run)
expect_ev_count 4 5 2     1   # slow press
expect_ev_count 4 5 1     1   # slow release
expect_ev_count 4 5 8     1   # double
expect_ev_count 4 5 16    1   # triple
expect_ev_count 4 5 128   1   # middle click (BUTTON2_CLICKED)
expect_ev_count 4 5 65536 1   # wheel up
expect_ev_count 8 9 8     1   # diff-position double: single event at second position

# ---------------- done ----------------
tmux send-keys -H -t "$T" 71
done=0
for _ in $(seq 1 50); do
  if grep -q '^DONE' "$OUT" 2>/dev/null; then done=1; break; fi
  sleep 0.1
done
if (( done )); then ok "DONE"; else bad "no DONE line"; fi
tmux kill-session -t "$T" 2>/dev/null

echo
if (( fail == 0 )); then echo "integration: $pass passed"; else echo "integration: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
