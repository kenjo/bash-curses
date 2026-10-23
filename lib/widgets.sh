# lib/widgets.sh — interactive widgets on top of lib/layout.sh.
#
# A widget owns an area: it draws it (through the area's draw_NAME) and takes
# its keys (when the area has focus, see bc_focus) and mouse events. The app
# describes what to show through callbacks and reacts to what happens through
# callbacks; it never tracks scroll offsets or hit-tests coordinates.
#
# Widget state lives in BCW_* arrays keyed by area name. Callbacks that the app
# does not define are simply skipped.

[[ -n ${BCW_LOADED:-} ]] && return 0
BCW_LOADED=1
[[ -n ${BCL_LOADED:-} ]] || source "${BASH_SOURCE[0]%/*}/layout.sh"

# ============================================================ list
# bc_list NAME ARRAY — a scrolling list over the items of the array named
# ARRAY (read at every redraw, so the app just updates the array + bc_dirty).
#
# Callbacks (NAME is the area name, e.g. left.list):
#   row_NAME IDX Y SEL     draw one row at content row Y. IDX is the item
#                          index (>= the item count for empty rows below the
#                          list), SEL is 1 for the selected item. Draw the
#                          whole row (e.g. bc_print NAME Y 0 "padded text").
#   select_NAME IDX        the selection moved (keys, click, wheel, drag)
#   enter_NAME IDX         Enter or a double click on an item; bc_pass from it
#                          to let Enter go on to the next key handler
# Keys: Up Down Home End PgUp PgDn; others are passed on.
# Mouse: click selects, double click enters, wheel moves, press-drag selects.
declare -A BCW_SEL=() BCW_TOP=() BCW_ARR=() BCW_DRAG=()

bc_list() { # name array
  local a=$1
  [[ -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_list: unknown area '$a'"; return 1; }
  BCW_ARR[$a]=$2
  BCW_SEL[$a]=${BCW_SEL[$a]:-0} BCW_TOP[$a]=${BCW_TOP[$a]:-0}
  BCL_KEYFN[$a]=_bcw_list_key
  BCL_CLICKFN[$a]=_bcw_list_click
  eval "draw_$a() { _bcw_list_draw \"\$1\"; }"
  bc_dirty "$a"
}

# bc_list_sel NAME [IDX] — set the selection (clamped) or read it into BCL_SEL.
bc_list_sel() {
  local a=$1
  if (( $# > 1 )); then
    BCW_SEL[$a]=$2
    _bcw_list_clamp "$a"
    bc_dirty "$a"
  fi
  BCL_SEL=${BCW_SEL[$a]}
}

_bcw_list_count() { # name -> BCW_N
  local -n _bcw_arr=${BCW_ARR[$1]}
  BCW_N=${#_bcw_arr[@]}
}

_bcw_list_clamp() { # name
  local a=$1
  _bcw_list_count "$a"
  (( BCW_SEL[$a] > BCW_N - 1 )) && BCW_SEL[$a]=$(( BCW_N - 1 ))
  (( BCW_SEL[$a] < 0 )) && BCW_SEL[$a]=0
  return 0
}

# Keep the selection visible: scroll only as far as needed.
_bcw_list_scroll() { # name rows
  local a=$1 h=$2
  local s=${BCW_SEL[$a]} t=${BCW_TOP[$a]}
  (( s < t )) && t=$s
  (( s >= t + h )) && t=$(( s - h + 1 ))
  (( t < 0 )) && t=0
  BCW_TOP[$a]=$t
}

_bcw_list_draw() { # name
  local a=$1 y idx
  bc_size "$a"
  local h=$BCL_H
  _bcw_list_clamp "$a"
  _bcw_list_scroll "$a" "$h"
  local s=${BCW_SEL[$a]} t=${BCW_TOP[$a]} fn="row_$a"
  declare -F "$fn" >/dev/null || return 0
  for (( y = 0; y < h; y++ )); do
    idx=$(( t + y ))
    "$fn" "$idx" "$y" $(( idx == s && idx < BCW_N ))
  done
}

# Move the selection; notify the app if it changed.
_bcw_list_move() { # name newsel
  local a=$1 old=${BCW_SEL[$1]}
  BCW_SEL[$a]=$2
  _bcw_list_clamp "$a"
  (( BCW_SEL[$a] == old )) && return 0
  bc_dirty "$a"
  declare -F "select_$a" >/dev/null && "select_$a" "${BCW_SEL[$a]}"
  return 0
}

_bcw_list_key() { # key   (the focused list is BCL_FOCUS)
  local a=$BCL_FOCUS k=$1 s
  s=${BCW_SEL[$a]}
  bc_size "$a"
  _bcw_list_count "$a"
  case $k in
    "$KEY_UP")    _bcw_list_move "$a" $(( s - 1 )) ;;
    "$KEY_DOWN")  _bcw_list_move "$a" $(( s + 1 )) ;;
    "$KEY_HOME")  _bcw_list_move "$a" 0 ;;
    "$KEY_END")   _bcw_list_move "$a" $(( BCW_N - 1 )) ;;
    "$KEY_PPAGE") _bcw_list_move "$a" $(( s - BCL_H )) ;;
    "$KEY_NPAGE") _bcw_list_move "$a" $(( s + BCL_H )) ;;
    $'\r'|$'\n'|"$KEY_ENTER")
      if declare -F "enter_$a" >/dev/null; then "enter_$a" "$s"; else bc_pass; fi ;;
    *) bc_pass ;;
  esac
}

# Mouse on the list. The event is always passed on afterwards, so the app's
# click_NAME / on_click still sees it (e.g. to activate a panel).
_bcw_list_click() { # name y x bstate
  local a=$1 y=$2 b=$4 idx
  _bcw_list_count "$a"
  idx=$(( BCW_TOP[$a] + y ))
  if (( b & (BUTTON4_PRESSED | BUTTON4_CLICKED) )); then
    _bcw_list_move "$a" $(( BCW_SEL[$a] - 1 ))
  elif (( b & (BUTTON5_PRESSED | BUTTON5_CLICKED) )); then
    _bcw_list_move "$a" $(( BCW_SEL[$a] + 1 ))
  elif (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
    if (( y >= 0 && idx < BCW_N )); then
      _bcw_list_move "$a" "$idx"
      if (( b & (BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
        declare -F "enter_$a" >/dev/null && "enter_$a" "$idx"
      fi
    fi
  elif (( b & BUTTON1_PRESSED )); then
    BCW_DRAG[$a]=1
  elif (( b & BUTTON1_RELEASED )); then
    BCW_DRAG[$a]=0
  elif (( (b & REPORT_MOUSE_POSITION) && ${BCW_DRAG[$a]:-0} )); then
    (( y >= 0 && idx < BCW_N )) && _bcw_list_move "$a" "$idx"
  fi
  bc_pass
}
