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

# pair=0 is a real pair, not "unset": it must override the area background
fresh 5 20
bc_screen "a b" cols="10 *"
bc_style a pair=4
bc_relayout
bc_print a 0 0 "x" pair=0
bc_print a 1 0 "y"
bc_update >/dev/null
check "W explicit pair 0" "0" "${BC_SP[0 0]}"
check "W inherited pair" "4" "${BC_SP[1 0]}"

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


# change-only drawing: same result as drawing on a cleared area, but only
# changed cells are written (and marked dirty)
ndirty() { local w n=0 k; for w in "${!BC_WD[@]}"; do local IFS=','; for k in ${BC_WD[$w]}; do [[ -n $k ]] && n=$(( n + 1 )); done; done; echo $n; }
fresh 12 40
bc_screen "list" border=0
bc_style list border
SEL=1; ITEMS=(alpha beta gamma delta)
draw_list() { local i p; bc_size list
  for (( i = 0; i < ${#ITEMS[@]}; i++ )); do
    p=0; (( i == SEL )) && p=2
    printf -v l '%-*s' "$BCL_W" "${ITEMS[i]}"; bc_print list "$i" 0 "$l" pair=$p
  done; }
bc_update >/dev/null
check "C first draw" "│beta" "$(srow 2 0 5)"
bc_dirty list; bc_update >/dev/null
bc_dirty list; _bcl_draw_pending
check "C unchanged redraw dirties nothing" "0" "$(ndirty)"
doupdate >/dev/null
SEL=2; bc_dirty list; _bcl_draw_pending
check "C moving selection dirties 2 rows" "$(( 2 * 38 ))" "$(ndirty)"
doupdate >/dev/null
check "C new selection pair" "2" "${BC_SP[3 1]}"
check "C old selection pair" "0" "${BC_SP[2 1]}"
draw_list() { bc_print list 0 0 "hi"; bc_print list 1 3 "x"; }
bc_dirty list; bc_update >/dev/null
check "C leftovers blanked row 0" "│hi    " "$(srow 1 0 7)"
check "C leftovers blanked row 1" "│   x  " "$(srow 2 0 7)"
check "C leftovers blanked row 3" "│      " "$(srow 4 0 7)"
draw_list() { bc_win list; mvwaddstr "$bc_win" 0 0 "${RAWTXT:-raw text}"; }
bc_dirty list; bc_update >/dev/null
RAWTXT=ab; bc_dirty list; bc_update >/dev/null
check "C raw-drawn area is cleared first" "│ab      " "$(srow 1 0 9)"
unset -f draw_list
# the per-row memory of the last write must not survive a clear / repaint
fresh 6 20
bc_screen "box"
bc_style box border
draw_box() { bc_print box 0 0 "keep me"; }
bc_update >/dev/null
bc_clear box; bc_dirty box; bc_update >/dev/null
check "C reprinted after bc_clear" "│keep me" "$(srow 1 0 8)"
bc_style box pair=4; bc_update >/dev/null
check "C reprinted after frame repaint" "│keep me" "$(srow 1 0 8)"
check "C repaint uses new pair" "4" "${BC_SP[1 2]}"
unset -f draw_box
# a draw_NAME that sets another area's text shows up in the same update
fresh 6 30
bc_screen "
  body
  status
" rows="* 1"
draw_body() { bc_text status "sel=$SEL"; }
SEL=7; bc_update >/dev/null
check "C bc_text from draw_NAME same update" "sel=7" "$(srow 5 0 5)"
SEL=8; bc_dirty body; bc_update >/dev/null
check "C ...and on later updates" "sel=8" "$(srow 5 0 5)"
unset -f draw_body

# ======================================================= floats (step 3)
frect() { printf '%s %s %s %s' "${BCL_RY[$1]}" "${BCL_RX[$1]}" "${BCL_RH[$1]}" "${BCL_RW[$1]}"; }
fresh 30 100
bc_screen "
  menu  menu
  left  right
" rows="1 *" cols="* *"
bc_float d1 size=7x40
bc_relayout
check "F center"         "11 30 7 40" "$(frect d1)"
bc_float d1 shadow
bc_relayout
check "F shadow adds 1"  "11 30 8 41" "$(frect d1)"
check "F shadow content" "7 40" "$(bc_size d1; echo "$BCL_H $BCL_W")"
bc_float d1 size=50x200
bc_relayout
check "F clamped"        "0 0 30 100" "$(frect d1)"
bc_close d1
bc_float d2 size=50%x25% at=bottomright
bc_relayout
check "F percent+corner" "15 75 15 25" "$(frect d2)"
bc_close d2
bc_float dd in=right at=below:menu size=5x12
bc_relayout
check "F below: clamped into parent" "1 50 5 12" "$(frect dd)"
bc_float dd at=below:left
bc_relayout
check "F below: bottom edge clamps" "25 50 5 12" "$(frect dd)"
bc_close dd
bc_float pos in=left at=3,4 size=2x5
bc_relayout
check "F Y,X offset in parent" "4 4 2 5" "$(frect pos)"
bc_close pos

# shadow: two strips; the outer corners show what is underneath
fresh 10 20
bc_screen "bg"
hash10=""; for i in {1..10}; do hash10+="####################"$'\n'; done
bc_text bg "$hash10"
bc_float sh size=3x6 shadow
bc_update >/dev/null
check "F shadow corner top-right shows below"  "#" "${BC_S[3 13]}"
check "F shadow corner bottom-left shows below" "#" "${BC_S[6 7]}"
check "F shadow right strip"  "[ ] $A_REVERSE" "[${BC_S[4 13]}] ${BC_SA[4 13]}"
check "F shadow bottom strip" "[ ] $A_REVERSE" "[${BC_S[6 8]}] ${BC_SA[6 8]}"
check "F shadow box + strip"  "       #" "$(srow 5 7 8)"
bc_close sh
bc_update >/dev/null
check "F shadow gone after close" "#######" "$(srow 6 7 7)"
fresh 30 100
bc_screen "
  menu  menu
  left  right
" rows="1 *" cols="* *"

# within=: placed in a small cell, clamped to a bigger area (may overhang)
bc_float ov in=left within=screen at=topleft size=4x70
bc_relayout
check "F within: overhangs its cell" "1 0 4 70" "$(frect ov)"
bc_float ov at=bottomright
bc_relayout
check "F within: clamped to within area" "26 0 4 70" "$(frect ov)"
bc_close ov
# percentage ranges are relative to the in= parent and fixed at creation
RANDOM=3
bc_float pr in=left size=50%..50%x10%..20%
bc_relayout
read -r _ _ ph pw <<< "$(frect pr)"
(( ph == 14 && pw >= 5 && pw <= 10 )) && ok "F percent range" || bad "F percent range: $ph x $pw"
bc_close pr

# auto size from text, including border insets
bc_float msg border title=Info
bc_text msg "hello
world!"
bc_relayout
check "F auto from text" "13 46 4 8" "$(frect msg)"
bc_update >/dev/null
check "F float drawn on top" "│hello │" "$(srow 14 46 8)"
bc_close msg
bc_update >/dev/null
check "F close reveals below" "        " "$(srow 14 46 8)"
check "F close frees windows" "" "${BCL_WIN[msg]:-}${BCL_TEXT[msg]:-}"

# random placement is fixed at creation and scales with the parent
RANDOM=7
bc_float r1 in=left at=random size=4..8x10..20
bc_relayout
read -r ry rx rh rw <<< "$(frect r1)"
(( ry >= 1 && ry + rh <= 30 && rx >= 0 && rx + rw <= 50 && rh >= 4 && rh <= 8 && rw >= 10 && rw <= 20 )) \
  && ok "F random inside parent" || bad "F random inside parent: $ry $rx $rh $rw"
s1="$rh $rw"
term 60 200; bc_relayout
read -r ry2 rx2 rh2 rw2 <<< "$(frect r1)"
check "F random size kept on resize" "$s1" "$rh2 $rw2"
(( ry2 > ry && rx2 > rx )) && ok "F random position scales" || bad "F random position scales: $ry,$rx -> $ry2,$rx2"
bc_close r1
term 30 100; bc_relayout

# a dialog: float + grid, children inherit its colours
bc_float copy size=8x40 border title=Copy pair=5 shadow
bc_grid copy "
  l1  src
  l2  dst
  .   .
  ok  cancel
" rows="1 1 * 1" cols="auto *" gap=1
bc_text l1 "From:"
bc_text l2 "To:"
bc_relayout
check "F dialog rect"      "11 30 9 41" "$(frect copy)"
check "F dialog label"     "12 31 1 5"  "$(frect l1)"
check "F dialog field"     "12 37 1 32" "$(frect src)"
check "F dialog buttons"   "17 31 1 5"  "$(frect ok)"
check "F child inherits pair" "5" "${BC_WBGP[${BCL_WIN[src]}]}"
bc_update >/dev/null
check "F dialog painted" "│From: " "$(srow 12 30 7)"
check "F dialog pair on screen" "5" "${BC_SP[14 51]}"
bc_hit 12 41
check "F hit dialog child" "src 0 4" "$BCL_AREA $BCL_MY $BCL_MX"
bc_hit 2 2
check "F hit tiled below" "left 1 2" "$BCL_AREA $BCL_MY $BCL_MX"

# stacking + raise + nested floats + close cascade
bc_float a size=5x10 at=2,2
bc_float b size=5x10 at=4,6
bc_float c in=a size=1x3 at=0,0
blk() { local l; printf -v l "%10s" ""; l=${l// /$1}; printf "%s\n%s\n%s\n%s\n%s" "$l" "$l" "$l" "$l" "$l"; }
bc_text a "$(blk A)"; bc_text b "$(blk B)"; bc_text c "ccc"
bc_update >/dev/null
check "F later float on top"    "AAAABBBBBB" "$(srow 5 2 10)"
check "F order"                 "copy a b c" "$(echo $BCL_FLOATS)"
bc_raise a
check "F raise moves children"  "copy b a c" "$(echo $BCL_FLOATS)"
bc_update >/dev/null
check "F raised float on top"   "AAAAAAAAAA" "$(srow 5 2 10)"
check "F child float above parent" "cccAAAAAAA" "$(srow 2 2 10)"
np=${#BC_PSTACK[@]}
bc_close a
check "F close cascades"        "copy b" "$(echo $BCL_FLOATS)"
check "F close frees panels"    "$(( np - 2 ))" "${#BC_PSTACK[@]}"
bc_close copy
check "F close dialog drops kids" "" "${BCL_KIND[src]:-}${BCL_WIN[src]:-}"
bc_float copy size=6x30
bc_grid copy "l1 src"
check "F reopen has no stale text" "" "${BCL_TEXT[l1]:-}"
bc_close copy; bc_close b

fails "F bad at"   "bad at='middle'" bc_float x at=middle
fails "F bad size" "bad size='7'"    bc_float x size=7
fails "F parent"   "unknown parent 'nope'" bc_float x in=nope
fails "F tiled"    "already a tiled area" bc_float left
fails "F raise"    "'left' is not a float" bc_raise left


# ======================================================= event loop (step 3b)
# fake key source: KQ holds "key" entries; "M:y,x" injects a click there
BCL_STARTED=1
KQ=()
_bcl_readkey() {
  if (( ${#KQ[@]} == 0 )); then bc_quit; return 1; fi
  key=${KQ[0]}; KQ=("${KQ[@]:1}")
  if [[ $key == M:* ]]; then
    local yx=${key#M:}
    BC_MEVENTS+=("0 ${yx#*,} ${yx%,*} $BUTTON1_CLICKED")
    key=$KEY_MOUSE
  fi
  return 0
}
fresh 20 60
bc_screen "
  top
  body
" rows="1 *"
log=""
on_key()   { log+="key:$1 "; [[ $1 == q ]] && bc_quit; }
on_click() { log+="click:$1@$2,$3 "; }
click_top() { log+="top@$2 "; }
draws=0
draw_body() { draws=$(( draws + 1 )); }
KQ=(a M:5,7 M:0,3 q z)
bc_run >/dev/null
check "L keys + clicks routed" "key:a click:body@4,7 top@3 key:q " "$log"
check "L bc_quit stops before later keys" "z" "${KQ[*]}"
(( draws >= 1 )) && ok "L draw_body ran" || bad "L draw_body ran"

# keys go to the topmost float with a handler; modal swallows the rest
log=""
key_pop() { log+="pop:$1 "; [[ $1 == x ]] && bc_close pop; }
bc_float pop size=3x10
KQ=(a x b)
bc_run >/dev/null
check "L float handler first, then on_key" "pop:a pop:x key:b " "$log"

log=""
dlg_keys() { log+="dlg:$1 "; case $1 in y) bc_close dlg yes ;; n) bc_close dlg ;; esac; }
bc_float dlg size=5x20 keys=dlg_keys
KQ=(a M:2,2 M:10,30 y after)
BCL_QUIT=0
if bc_modal dlg >/dev/null; then r="ok:$BCL_RESULT"; else r="cancel"; fi
check "L modal result" "ok:yes" "$r"
check "L modal routes keys, ignores outside clicks" "dlg:a click:dlg@3,10 dlg:y " "$log"
check "L modal leaves later keys" "after" "${KQ[*]}"
bc_float dlg size=5x20 keys=dlg_keys
KQ=(n); log=""
if bc_modal dlg >/dev/null; then r="ok"; else r="cancel"; fi
check "L modal closed without result" "cancel" "$r"

# ticks: fps with a key source that only times out
ticks=0
on_tick() { ticks=$(( ticks + 1 )); (( ticks >= 3 )) && bc_quit; }
_bcl_readkey() { sleep 0.02; return 1; }
bc_run fps=100 >/dev/null
check "L on_tick until quit" "3" "$ticks"
unset -f on_key on_click click_top draw_body key_pop dlg_keys on_tick


# ======================================================= mc-style frames, focus
fresh 20 40
bc_screen "bg"
txt=""; for i in {1..20}; do txt+="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMN"$'\n'; done
bc_text bg "$txt"
bc_float dlg size=4x10 border margin=1 shadow=mc spair=9 pair=5 title=T tpair=6 nudge=-2,0
bc_relayout
check "M outer rect = box + margin + shadow" "5 14 7 14" "$(frect dlg)"
bc_size dlg
check "M content inside margin+border" "2 8" "$BCL_H $BCL_W"
bc_update >/dev/null
check "M margin ring is background" "            " "$(srow 5 14 12)"
check "M border inside margin" " ┌── T ───┐ " "$(srow 6 14 12)"
check "M title pen" "6" "${BC_SP[6 19]}"
check "M mc shadow right is see-through" "AB 9" "${BC_S[6 26]}${BC_S[6 27]} ${BC_SP[6 26]}"
check "M top-right corner untouched" "A 0" "${BC_S[5 26]} ${BC_SP[5 26]}"
check "M mc shadow bottom row" "q 9" "${BC_S[11 16]} ${BC_SP[11 16]}"
check "M bottom-left corner untouched" "p 0" "${BC_S[11 15]} ${BC_SP[11 15]}"
bc_close dlg; bc_update >/dev/null
check "M closed: shadow gone" "AB 0" "${BC_S[6 26]}${BC_S[6 27]} ${BC_SP[6 26]}"

# cursor follows an area
bc_float inp size=1x10 at=2,3
bc_cursor inp 0 4; bc_update >/dev/null
check "M cursor parked in area" "2 7" "${BC_WAY[0]} ${BC_WAX[0]}"
bc_cursor; bc_close inp

# focus first, bc_pass hands on; registered widget handlers
log=""
on_key() { log+="on:$1 "; }
fk() { log+="f:$1 "; [[ $1 == p ]] && bc_pass; }
bc_float w1 size=2x5 at=0,0
BCL_KEYFN[w1]=fk
bc_float w2 size=2x5 at=0,10 keys=w2k
w2k() { log+="w2:$1 "; bc_pass; }
bc_focus w1; bc_update >/dev/null
BCL_STARTED=1; KQ=(x p q); _bcl_readkey() { if (( ${#KQ[@]} == 0 )); then bc_quit; return 1; fi; key=${KQ[0]}; KQ=("${KQ[@]:1}"); }
bc_run >/dev/null
check "M focus first, pass goes to floats then on_key" "f:x f:p w2:p on:p f:q " "$log"
bc_focus; bc_close w1; bc_close w2; unset -f on_key fk w2k

printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
