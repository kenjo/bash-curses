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

# a selection move redraws only the two rows involved (unless more is dirty)
nrows=0
row_list() { nrows=$(( nrows + 1 ))
  local t=""; (( $1 < ${#ITEMS[@]} )) && t=${ITEMS[$1]}
  (( $3 )) && t=">$t" || t=" $t"; printf -v t '%-20s' "$t"; bc_print list "$2" 0 "$t"; }
bc_list_sel list 1; bc_update >/dev/null
nrows=0; run "$KEY_DOWN"
check "Down redraws two rows" "2" "$nrows"
check "  old row unselected, new selected, others kept" " a1|>a2| a0| a6" "$(srow 2 0 3)|$(srow 3 0 3)|$(srow 1 0 3)|$(srow 7 0 3)"
select_list() { log+="sel:$1 "; bc_dirty list; }
nrows=0; run "$KEY_DOWN"
check "a move plus another bc_dirty redraws all rows" "7" "$nrows"
select_list() { log+="sel:$1 "; }
nrows=0; run "$KEY_END"
check "a move that scrolls redraws all rows" "7" "$nrows"

nrows=0; bc_list_redraw_sel list; bc_update >/dev/null
check "bc_list_redraw_sel redraws one row" "1" "$nrows"

# shrinking data clamps the selection; empty rows are drawn
ITEMS=(b0 b1); bc_dirty list; bc_update >/dev/null
bc_list_sel list; check "selection clamped to new count" "1" "$BCL_SEL"
check "rows below the items are empty" "                    " "$(srow 4 0 20)"
bc_list_sel list 0; bc_update >/dev/null
check "bc_list_sel sets it" ">b0" "$(srow 1 0 3)"


# ---------------------------------------------------------------- bc_menubar
fresh 12 40
bc_screen "
  bar
  body
" rows="1 *"
MENU_File=("Open|F3|O" "Save||S" "---" "Quit|F10|Q")
MENU_Edit=("Copy|C-c|C" "Paste||P:2")
bc_menubar bar "File:2 Edit:9" pairs="1 2 3 4 5" reserve=1
log=""
open_bar()  { log+="open "; }
close_bar() { log+="close "; }
pick_bar()  { log+="pick:$1/$2 "; }
bc_focus ""; BCL_QUIT=0
bc_update >/dev/null
check "menubar closed" "  File   Edit" "$(srow 0 0 13)"
check "menubar closed pair" "1" "${BC_SP[0 2]}"
# open on File, Down opens the drop-down, Down Down skips the separator
KQ=("$KEY_DOWN" "$KEY_DOWN"); _bcl_readkey_orig=1
probe() { bc_update >/dev/null; P1="$(srow 1 0 16)|$(srow 2 0 16)|$(srow 4 0 16)|${BC_SP[0 1]}${BC_SP[0 2]}${BC_SP[0 3]}|${BC_SP[2 2]}${BC_SP[2 3]}|${BC_SP[3 2]}"; }
_bcl_readkey() {
  if (( ${#KQ[@]} == 0 )); then probe; bc_modal_done; return 1; fi
  key=${KQ[0]}; KQ=("${KQ[@]:1}")
  if [[ $key == M:* ]]; then local e=${key#M:} yx b; yx=${e%%:*} b=${e#*:}; BC_MEVENTS+=("0 ${yx#*,} ${yx%,*} $b"); key=$KEY_MOUSE; fi
  return 0
}
bc_menubar_run bar 0 >/dev/null
check "drop-down drawn, 2nd item selected" "┌──────────┐    |│ Open  F3 │    |├──────────┤    |454|32|5" "$P1"
check "Esc-less end: open/close callbacks" "open close " "$log"
log=""; KQ=("$KEY_DOWN" "$KEY_DOWN" $'\r'); bc_menubar_run bar 0 >/dev/null
check "Enter picks the selected item" "open close pick:File/Save " "$log"
log=""; KQ=("$KEY_RIGHT" "$KEY_DOWN" p $'\r'); bc_menubar_run bar 0 >/dev/null
check "Right + letter jumps to an item" "open close pick:Edit/Paste " "$log"
log=""; KQ=(e $'\r' $'\r'); bc_menubar_run bar 0 >/dev/null
check "letter on the bar picks a menu" "open close pick:Edit/Copy " "$log"
log=""; KQ=("$KEY_DOWN" "$KEY_UP" $'\e'); bc_menubar_run bar 0 >/dev/null
check "Up on the first item closes the drop-down, Esc the menu" "open close " "$log"
check "drop-down float is gone" "" "${BCL_KIND[bar.dd]:-}"
log=""; KQ=("M:5,5:$BUTTON1_CLICKED"); bc_menubar_run bar 0 1 >/dev/null
check "click on an item picks it" "open close pick:File/Quit " "$log"
log=""; KQ=("M:0,10:$BUTTON1_CLICKED" "M:2,10:$BUTTON1_CLICKED"); bc_menubar_run bar 0 >/dev/null
check "click on a title opens it" "open close pick:Edit/Copy " "$log"
log=""; KQ=("M:8,30:$BUTTON1_CLICKED" x); bc_menubar_run bar 0 1 >/dev/null
check "click outside closes" "open close " "$log"
check "outside click did not leak keys" "x" "${KQ[*]}"
bc_update >/dev/null
check "bar closed again" "1" "${BC_SP[0 2]}"


# ---------------------------------------------------------------- dialogs
fresh 16 40
bc_screen "bg"
BCW_PENS="29 30 25 28"
mkdlg() {
  NAME="ab" FLAG=0
  bc_dialog d "Edit" 7x30 pair=23 tpair=24 margin=1
  bc_grid d "
    .   name  name  .
    .   flag  flag  .
    sep sep   sep   sep
    .   ok    no    .
  " rows="1 1 1 1" cols="1 auto * 1"
  bc_input name NAME button
  bc_check flag FLAG "Flag it" hot=0
  bc_style sep divider
  bc_button ok "OK" ok
  bc_button no "Cancel" cancel
}
dprobe() { bc_update >/dev/null; P1="$(srow 5 7 26)|$(srow 6 7 26)|$(srow 7 5 30)|$(srow 8 7 26)|${BC_SP[5 7]} ${BC_SP[5 30]} ${BC_SP[6 7]} ${BC_SP[6 11]}|${BC_WAY[0]},${BC_WAX[0]}"; }
_bcl_readkey() {
  if (( ${#KQ[@]} == 0 )); then bc_quit; return 1; fi
  key=${KQ[0]}; KQ=("${KQ[@]:1}")
  [[ $key == PROBE ]] && { dprobe; key=$'\e'; }
  if [[ $key == M:* ]]; then local e=${key#M:} yx b; yx=${e%%:*} b=${e#*:}; BC_MEVENTS+=("0 ${yx#*,} ${yx%,*} $b"); key=$KEY_MOUSE; fi
  return 0
}
drun() { BCL_QUIT=0; KQ=("$@"); bc_dialog_run d "${DOPT[@]}" >/dev/null; RC=$?; DOPT=(); }
DOPT=()
mkdlg; drun x "$KEY_LEFT" "$KEY_BACKSPACE" PROBE
check "dialog drawn, field focused with the cursor at the caret" \
  "ax                     [^]|[ ] Flag it               |├────────────────────────────┤|[< OK >][ Cancel ]        |25 28 23 24|5,8" "$P1"
check "Esc cancels" "1" "$RC"
check "the field edits its variable" "ax" "$NAME"
mkdlg; drun "$KEY_DOWN" ' ' PROBE
P2=${P1#*|}; P2=${P2%%|*}; P3=${P1#*|*|*|*|}; P3=${P3%|*}
check "Down focuses the checkbox, Space toggles it" "[x] Flag it               |25 28 29 30" "$P2|$P3"
check "the checkbox toggles its variable" "1" "$FLAG"
mkdlg; drun "$KEY_DOWN" "$KEY_DOWN" "$KEY_DOWN" ' '
check "Space on a cancel button: no result" "1" "$RC"
mkdlg; drun h e y $'\r'
check "Enter in a field presses the ok button" "0 ok abhey" "$RC $BCL_RESULT $NAME"
mkdlg; drun "M:8,9:$BUTTON1_CLICKED"
check "click on OK" "0 ok" "$RC $BCL_RESULT"
mkdlg; drun "M:6,8:$BUTTON1_CLICKED" "M:5,8:$BUTTON1_CLICKED" z "M:8,17:$BUTTON1_CLICKED"
check "clicks: checkbox, caret in field, Cancel" "1 1 azb" "$RC $FLAG $NAME"
mkdlg; DOPT=(focus=no order="no flag name"); drun "$KEY_DOWN" ' ' $'\e'
check "focus= and order=" "1" "$FLAG"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
