#!/bin/bash
# Headless unit tests for lib/layout.sh (no tty required).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
check() { if [[ "$3" == "$2" ]]; then ok "$1"; else bad "$1: want [$2] got [$3]"; fi; }

source "$REPO/lib/layout.sh"

term() { BC_LINES=$1; BC_COLS=$2; LINES=$1; COLS=$2; }
rect() { bc_rect "$1" && printf '%s %s %s %s' "$BCL_Y" "$BCL_X" "$BCL_H" "$BCL_W"; }
fails() { # name expected-error-substring cmd...
  local n=$1 want=$2; shift 2
  BCL_ERR=""
  if "$@" 2>/dev/null; then bad "$n: expected failure"; return; fi
  if [[ $BCL_ERR == *"$want"* ]]; then ok "$n"; else bad "$n: error [$BCL_ERR] lacks [$want]"; fi
}

# --- A. mc-like screen ---
term 30 100
bc_screen "
  menu  menu
  left  right
  keys  keys
" rows="1 * 1" cols="* *"
_bcl_resolve
check "A menu"  "0 0 1 100"   "$(rect menu)"
check "A left"  "1 0 28 50"   "$(rect left)"
check "A right" "1 50 28 50"  "$(rect right)"
check "A keys"  "29 0 1 100"  "$(rect keys)"

# odd width: leftover column goes to the first weighted track
term 30 101; _bcl_resolve
check "A odd left"  "1 0 28 51"  "$(rect left)"
check "A odd right" "1 51 28 50" "$(rect right)"

# --- B. hidden track (0) and weights ---
term 20 90
bc_screen "
  menu menu menu
  a    b    c
  hint hint hint
  keys keys keys
" rows="1 * 0 1" cols="* 2* *"
_bcl_resolve
check "B a"    "1 0 18 23"  "$(rect a)"
check "B b"    "1 23 18 45" "$(rect b)"
check "B c"    "1 68 18 22" "$(rect c)"
check "B hint" "19 0 0 90"  "$(rect hint)"
check "B keys" "19 0 1 90"  "$(rect keys)"

# --- C. border and gap ---
term 12 40
bc_screen "
  a b
  c c
" border=1 gap=1
_bcl_resolve
check "C a" "1 1 5 19"  "$(rect a)"
check "C b" "1 21 5 18" "$(rect b)"
check "C c" "7 1 4 38"  "$(rect c)"

# --- D. auto tracks follow content size ---
term 10 40
bc_screen "
  l1 src
  l2 dst
  .  .
  ok cancel
" rows="1 1 * 1" cols="auto *"
BCL_CW[l1]=5; BCL_CW[l2]=3; BCL_CH[l1]=1
_bcl_resolve
check "D l1"  "0 0 1 5"  "$(rect l1)"
check "D src" "0 5 1 35" "$(rect src)"
check "D dst" "1 5 1 35" "$(rect dst)"
BCL_CW[l2]=9; _bcl_resolve
check "D auto grows" "0 9 1 31" "$(rect src)"

# --- E. fixed overflow shrinks from the last track ---
term 5 20
bc_screen "a
b
c" rows="3 3 3"
_bcl_resolve
check "E a" "0 0 3 20" "$(rect a)"
check "E b" "3 0 2 20" "$(rect b)"
check "E c" "5 0 0 20" "$(rect c)"

# --- F. nested grid + auto from nested minimum ---
term 30 100
bc_screen "
  menu  menu
  left  right
" rows="1 *" cols="* *"
bc_grid left "
  head
  list
  status
" rows="1 * 1" border=1
_bcl_resolve
check "F left grid" "1 0 29 50" "$(rect left)"
check "F head"   "2 1 1 48"  "$(rect head)"
check "F list"   "3 1 25 48" "$(rect list)"
check "F status" "28 1 1 48" "$(rect status)"
bc_screen "
  top
  bar
  rest
" rows="1 auto *"
bc_grid bar "
  x
  y
" rows="2 3" border=1
_bcl_resolve
check "F auto nested" "1 0 7 100" "$(rect bar)"
check "F rest"        "8 0 22 100" "$(rect rest)"

# --- G. redefining a grid drops vanished areas, keeps the rest ---
bc_screen "a b" ; _bcl_resolve
bc_screen "a c" ; _bcl_resolve
check "G b gone" "" "${BCL_KIND[b]:-}"
check "G a kept" "area" "${BCL_KIND[a]}"
check "G x gone (nested of dropped)" "" "${BCL_KIND[x]:-}"

# --- H. bc_cells picks a shape from the aspect ratio ---
term 30 100
bc_screen "main" border=1
bc_cells main 12
_bcl_resolve
check "H shape" "3x5" "${BCL_NR[main]}x${BCL_NC[main]}"
check "H cell0"  "1 1 10 20"  "$(rect main.0)"
check "H cell11" "20 21 9 20" "$(rect main.11)"
term 30 40; _bcl_resolve
check "H reshaped" "4x3" "${BCL_NR[main]}x${BCL_NC[main]}"

# --- I. errors ---
fails "I ragged"     "line 2 has 1 cells, expected 2" bc_screen "a b
c"
fails "I not rect"   "area 'a' is not a rectangle"     bc_screen "a b
b a"
fails "I L-shape"    "area 'a' is not a rectangle"     bc_screen "a a
a b"
fails "I count"      "rows has 1 sizes but the template has 2" bc_screen "a
b" rows="1"
fails "I bad size"   "bad track size 'x'"              bc_screen "a b" cols="x *"
fails "I bad name"   "bad area name '9a'"              bc_screen "9a"
fails "I reserved"   "'screen' is reserved"            bc_screen "screen"
fails "I opt"        "unknown option 'foo=1'"          bc_screen "a" foo=1
bc_screen "a b"
fails "I dup"        "area 'a' is already defined elsewhere" bc_grid b "a"
fails "I grid none"  "unknown area 'zz'"               bc_grid zz "q"


# ======================================================= windows (step 2)
# headless stdscr; doupdate output goes to /dev/null, BC_S is what was "sent"
fresh() { # lines cols
  term "$1" "$2"
  BC_S=(); BC_SA=(); BC_SP=(); BC_SCROW=(); BC_SPROW=(); BC_DELRECTS=""
  _bc_init_window 0 0 0 "$1" "$2"
}
srow() { # y x0 n -> composited characters
  local y=$1 x l=""
  for (( x = $2; x < $2 + $3; x++ )); do l+="${BC_S[$y $x]:- }"; done
  printf '%s' "$l"
}
wrect() { local w=${BCL_FWIN[$1]}; printf '%s %s %s %s' "${BC_WY[$w]}" "${BC_WX[$w]}" "${BC_WH[$w]}" "${BC_WW[$w]}"; }

fresh 30 100
bc_screen "
  menu  menu
  left  right
  hint  hint
  keys  keys
" rows="1 * 0 1" cols="* *"
bc_relayout
check "W left window"  "1 0 28 50"  "$(wrect left)"
check "W keys window"  "29 0 1 100" "$(wrect keys)"
check "W hidden hint"  ""           "${BCL_WIN[hint]:-}"
n0=$BC_WN; bc_relayout
check "W relayout no-op creates nothing" "$n0" "$BC_WN"
m0=${BCL_WIN[menu]} l0=${BCL_WIN[left]}
term 31 100; bc_relayout
check "W unchanged rect keeps window" "$m0" "${BCL_WIN[menu]}"
[[ ${BCL_WIN[left]} != "$l0" ]] && ok "W changed rect rebuilds window" || bad "W changed rect rebuilds window"
check "W rebuilt rect" "1 0 29 50" "$(wrect left)"

# show the hidden row
bc_screen "
  menu  menu
  left  right
  hint  hint
  keys  keys
" rows="1 * 1 1" cols="* *"
bc_relayout
check "W hint appears" "29 0 1 100" "$(wrect hint)"
check "W panel order = template order" "4" "$(( ${#BC_PSTACK[@]} - 1 ))"

# border + title: content is an inset derwin; text is retained and replayed
fresh 12 40
bc_screen "
  top
  body
" rows="1 *"
bc_style body border title=Files
bc_relayout
bc_text top "Left File" align=center
bc_text body "one
two"
bc_update >/dev/null
check "W content inset" "2 1 9 38" "${BC_WY[${BCL_WIN[body]}]} ${BC_WX[${BCL_WIN[body]}]} ${BC_WH[${BCL_WIN[body]}]} ${BC_WW[${BCL_WIN[body]}]}"
check "W centered text" "               Left File                " "$(srow 0 0 40)"
check "W border+title"  "┌─────────────── Files ────────────────┐" "$(srow 1 0 40)"
check "W text row 1"    "│one" "$(srow 2 0 4)"
check "W text row 2"    "│two" "$(srow 3 0 4)"
check "W bottom border" "└" "$(srow 11 0 1)"
term 12 30; bc_relayout; BC_FORCEFULL=1; bc_update >/dev/null
check "W text replayed after rebuild" "│one" "$(srow 2 0 4)"
check "W title re-centred" "┌────────── Files ───────────┐" "$(srow 1 0 30)"

# bc_print clips at the area edge (no wrap) and takes pair/attr
fresh 5 20
bc_screen "a b" cols="10 *"
bc_relayout
bc_print a 0 6 "abcdefgh" pair=3 attr=$A_BOLD
bc_print a 0 -2 "XYZ"
bc_update >/dev/null
check "W print clip" "Z     abcd" "$(srow 0 0 10)"
check "W print no spill into b" " " "$(srow 0 10 1)"
check "W print pair" "3" "${BC_SP[0 7]}"
check "W print attr" "$A_BOLD" "${BC_SA[0 7]}"

# auto column sized by bc_text, relayout picks it up
fresh 6 30
bc_screen "
  l1 f1
  l2 f2
" cols="auto *"
bc_text l1 "From:"
bc_text l2 "To:"
bc_update >/dev/null
check "W auto label col" "0 5 3 25" "$(wrect f1)"
bc_text l2 "Destination:"
bc_update >/dev/null
check "W auto grows on new text" "0 12 3 18" "$(wrect f1)"

# draw_NAME + on_draw dispatch, bc_dirty
calls=""
draw_f1() { calls+="f1($1) "; }
on_draw() { calls+="all "; }
bc_dirty f1; bc_update >/dev/null
check "W draw dispatch" "f1(f1) all " "$calls"
calls=""; bc_update >/dev/null
check "W nothing pending -> no draw" "" "$calls"
unset -f draw_f1 on_draw
# draw_NAME starts from a cleared area
draw_f2() { bc_print f2 0 0 "$msg"; }
msg="long text"; bc_dirty f2; bc_update >/dev/null
msg="hi"; bc_dirty f2; bc_update >/dev/null
check "W draw_NAME on cleared area" "hi       " "$(srow 3 12 9)"
unset -f draw_f2

# hit testing with content-relative coordinates
fresh 12 40
bc_screen "
  top
  body
" rows="1 *"
bc_style body border
bc_relayout
bc_hit 5 10
check "W hit body" "body 3 9" "$BCL_AREA $BCL_MY $BCL_MX"
bc_hit 0 3
check "W hit top" "top 0 3" "$BCL_AREA $BCL_MY $BCL_MX"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
