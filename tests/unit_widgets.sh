#!/bin/bash
# Headless unit tests for lib/widgets.sh (no tty required).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
check() { if [[ "$3" == "$2" ]]; then ok "$1"; else bad "$1: want [$2] got [$3]"; fi; }

source "$REPO/lib/widgets.sh"

fresh() { # lines cols
  BC_LINES=$1; BC_COLS=$2; LINES=$1; COLS=$2
  BC_S=(); BC_SA=(); BC_SP=(); BC_SCROW=(); BC_SPROW=(); BC_DELRECTS=""
  _bc_init_window 0 0 0 "$1" "$2"
}
srow() { local y=$1 x l=""; for (( x = $2; x < $2 + $3; x++ )); do l+="${BC_S[$y $x]:- }"; done; printf '%s' "$l"; }
# fake input: "M:y,x:bstate" injects a mouse event
BCL_STARTED=1
KQ=()
_bcl_readkey() {
  if (( ${#KQ[@]} == 0 )); then bc_quit; return 1; fi
  key=${KQ[0]}; KQ=("${KQ[@]:1}")
  if [[ $key == M:* ]]; then
    local e=${key#M:} yx b
    yx=${e%%:*} b=${e#*:}
    BC_MEVENTS+=("0 ${yx#*,} ${yx%,*} $b")
    key=$KEY_MOUSE
  fi
  return 0
}
run() { KQ=("$@"); bc_run >/dev/null; }

# ---------------------------------------------------------------- bc_list
fresh 8 20
bc_screen "
  top
  list
" rows="1 *"
ITEMS=(a0 a1 a2 a3 a4 a5 a6 a7 a8 a9 a10 a11)
row_list() { # idx y sel
  local t=""
  (( $1 < ${#ITEMS[@]} )) && t=${ITEMS[$1]}
  (( $3 )) && t=">$t" || t=" $t"
  printf -v t '%-20s' "$t"
  bc_print list "$2" 0 "$t"
}
log=""
select_list() { log+="sel:$1 "; }
enter_list() { log+="enter:$1 "; }
on_key() { log+="key:$1 "; }
bc_list list ITEMS
bc_focus list
bc_update >/dev/null
check "list first draw" ">a0" "$(srow 1 0 3)"
check "list shows 7 rows" " a6" "$(srow 7 0 3)"
run "$KEY_DOWN" "$KEY_DOWN"
check "Down moves selection" ">a2" "$(srow 3 0 3)"
check "select callback" "sel:1 sel:2 " "$log"
log=""; run "$KEY_NPAGE"
bc_list_sel list; check "PgDn moves a page" "9" "$BCL_SEL"
check "scrolled to keep it visible" ">a9" "$(srow 7 0 3)"
check "top row after scroll" " a3" "$(srow 1 0 3)"
run "$KEY_END"; bc_list_sel list; check "End" "11" "$BCL_SEL"
log=""; run "$KEY_DOWN"
check "Down at end: no callback" "" "$log"
run "$KEY_HOME"; check "Home" ">a0" "$(srow 1 0 3)"
log=""; run x $'\r'
check "other keys pass on; Enter calls enter_" "key:x enter:0 " "$log"
unset -f enter_list; log=""; run $'\r'
check "Enter without enter_ passes on" "key:"$'\r'" " "$log"
enter_list() { log+="enter:$1 "; }

# mouse
log=""; run "M:3,5:$BUTTON1_CLICKED"
bc_list_sel list; check "click selects row" "2" "$BCL_SEL"
log=""; run "M:4,5:$BUTTON1_DOUBLE_CLICKED"
check "double click selects + enters" "sel:3 enter:3 " "$log"
run "M:4,5:$BUTTON5_PRESSED"; bc_list_sel list; check "wheel down" "4" "$BCL_SEL"
run "M:4,5:$BUTTON4_PRESSED"; bc_list_sel list; check "wheel up" "3" "$BCL_SEL"
run "M:2,5:$BUTTON1_PRESSED" "M:5,5:$REPORT_MOUSE_POSITION" "M:5,5:$BUTTON1_RELEASED"
bc_list_sel list; check "press-drag selects" "4" "$BCL_SEL"
run "M:6,5:$REPORT_MOUSE_POSITION"
bc_list_sel list; check "motion without drag does nothing" "4" "$BCL_SEL"
clicked=""; click_list() { clicked="$1,$2"; }
run "M:7,5:$BUTTON1_CLICKED"
check "click is passed on to click_NAME" "6,5" "$clicked"

# shrinking data clamps the selection; empty rows are drawn
ITEMS=(b0 b1); bc_dirty list; bc_update >/dev/null
bc_list_sel list; check "selection clamped to new count" "1" "$BCL_SEL"
check "rows below the items are empty" "                    " "$(srow 4 0 20)"
bc_list_sel list 0; bc_update >/dev/null
check "bc_list_sel sets it" ">b0" "$(srow 1 0 3)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
