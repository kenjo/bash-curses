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
declare -A BCW_PSEL=() BCW_PSEQ=() BCW_PTOP=()   # pending selection-only redraw

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

# bc_list_redraw_sel NAME — redraw just the selected row (e.g. because its
# highlight depends on something outside the list, like which panel is active).
bc_list_redraw_sel() {
  local a=$1
  [[ ${BCW_PSEQ[$a]:-} == "${BCL_DIRTYN[$a]:-}" || -z ${BCL_NEEDDRAW[$a]:-} ]] || return 0
  [[ ${BCW_PSEQ[$a]:-} == "${BCL_DIRTYN[$a]:-}" ]] || BCW_PSEL[$a]=${BCW_SEL[$a]}
  bc_dirty "$a"
  BCW_PSEQ[$a]=${BCL_DIRTYN[$a]}
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

# If only the selection moved (nobody else asked for a redraw since) and the
# list did not scroll, only the old and the new selected rows are redrawn.
_bcw_list_draw() { # name
  local a=$1 y idx
  bc_size "$a"
  local h=$BCL_H
  _bcw_list_clamp "$a"
  _bcw_list_scroll "$a" "$h"
  local s=${BCW_SEL[$a]} t=${BCW_TOP[$a]} fn="row_$a"
  local seq=${BCW_PSEQ[$a]:-} old=${BCW_PSEL[$a]:-}
  unset "BCW_PSEQ[$a]"
  declare -F "$fn" >/dev/null || return 0
  if [[ $seq == "${BCL_DIRTYN[$a]:-}" && ${BCW_PTOP[$a]:-} == "$t" ]]; then
    BCL_PARTIAL=1
    local prev=""
    for idx in "$s" "$old"; do
      (( idx >= t && idx < t + h )) || continue
      [[ $idx == $prev ]] && continue
      prev=$idx
      "$fn" "$idx" $(( idx - t )) $(( idx == s && idx < BCW_N ))
    done
  else
    for (( y = 0; y < h; y++ )); do
      idx=$(( t + y ))
      "$fn" "$idx" "$y" $(( idx == s && idx < BCW_N ))
    done
  fi
  BCW_PTOP[$a]=$t
}

# Move the selection; notify the app if it changed.
_bcw_list_move() { # name newsel
  local a=$1 old=${BCW_SEL[$1]}
  BCW_SEL[$a]=$2
  _bcw_list_clamp "$a"
  (( BCW_SEL[$a] == old )) && return 0
  # selection-only redraw unless something else is pending already
  [[ ${BCW_PSEQ[$a]:-} == "${BCL_DIRTYN[$a]:-}" ]] || BCW_PSEL[$a]=$old
  [[ -n ${BCL_NEEDDRAW[$a]:-} && ${BCW_PSEQ[$a]:-} != "${BCL_DIRTYN[$a]:-}" ]] && unset "BCW_PSEL[$a]"
  bc_dirty "$a"
  [[ -n ${BCW_PSEL[$a]:-} ]] && BCW_PSEQ[$a]=${BCL_DIRTYN[$a]}
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
  elif (( b & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
    if (( y >= 0 && idx < BCW_N )); then
      _bcw_list_move "$a" "$idx"
      if (( b & (BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
        declare -F "enter_$a" >/dev/null && "enter_$a" "$idx"
      fi
    fi
    (( b & BUTTON1_PRESSED )) && BCW_DRAG[$a]=1
  elif (( b & BUTTON1_RELEASED )); then
    BCW_DRAG[$a]=0
  elif (( (b & REPORT_MOUSE_POSITION) && ${BCW_DRAG[$a]:-0} )); then
    (( y >= 0 && idx < BCW_N )) && _bcw_list_move "$a" "$idx"
  fi
  bc_pass
}

# ============================================================ menu bar
# bc_menubar NAME "Title:X ..." [pairs="BAR OPEN MNEM SEL SELMNEM"] [reserve=N]
# A menu bar in the one-row area NAME with drop-down menus. Title is shown at
# column X; its items are the array MENU_<Title>: "LABEL|SHORTCUT|MNEMONIC"
# entries ("---" is a separator). MNEMONIC is the hotkey letter (its first
# occurrence in the label is highlighted) or "letter:pos" to highlight
# another position. reserve=N keeps N rows free below a drop-down.
#
# bc_menubar_run NAME [INDEX] [DROPDOWN] opens it (F9, a click on the bar);
# it is modal until an item is picked or it is closed (Esc, a click outside).
# Callbacks: open_NAME / close_NAME when it opens and closes (e.g. to dim the
# rest of the screen), pick_NAME TITLE LABEL after an item was picked.
# Keys: Left/Right switch menus, Down/Up/Enter open and move, letters jump to
# a menu (bar) or an item (drop-down), Esc closes.
declare -A BCW_MTITLES=() BCW_MX=() BCW_MPAIRS=() BCW_MRES=()
BCW_MACT="" BCW_MBAR=0 BCW_MDD=0 BCW_MSEL=0 BCW_MTOP=0 BCW_MPICK=""

bc_menubar() { # name "Title:X ..." [pairs=...] [reserve=N]
  local a=$1 t o; shift
  [[ -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_menubar: unknown area '$a'"; return 1; }
  BCW_MTITLES[$a]="" BCW_MX[$a]="" BCW_MPAIRS[$a]="0 0 0 0 0" BCW_MRES[$a]=0
  for t in $1; do BCW_MTITLES[$a]+=" ${t%%:*}"; BCW_MX[$a]+=" ${t##*:}"; done
  shift
  for o in "$@"; do
    case $o in
      pairs=*)   BCW_MPAIRS[$a]=${o#*=} ;;
      reserve=*) BCW_MRES[$a]=${o#*=} ;;
      *) _bcl_err "bc_menubar: unknown option '$o'"; return 1 ;;
    esac
  done
  BCL_KEYFN[$a]=_bcw_menu_key
  BCL_CLICKFN[$a]=_bcw_menu_click
  eval "draw_$a() { _bcw_menu_draw_bar \"\$1\"; }"
  eval "draw_$a.dd() { _bcw_menu_draw_dd \"\$1\"; }"
  eval "outclick_$a() { _bcw_menu_close; }"
  bc_dirty "$a"
}

_bcw_menu_titles() { read -r -a BCW_T <<< "${BCW_MTITLES[$1]}"; read -r -a BCW_X <<< "${BCW_MX[$1]}"; }

# The items of the selected menu -> BCW_ROWS (with SEP), BCW_REAL (row index
# of each real item), geometry BCW_INNER BCW_MAXSC.
_bcw_menu_items() { # name
  local -n _mi=MENU_${BCW_T[BCW_MBAR]}
  local e lab sc maxl=0 maxs=0 r=0
  BCW_ROWS=() BCW_REAL=()
  for e in "${_mi[@]}"; do
    if [[ $e == --- ]]; then BCW_ROWS+=(SEP)
    else
      BCW_ROWS+=("$e") BCW_REAL+=("$r")
      lab=${e%%|*} sc=${e#*|}; sc=${sc%|*}
      (( ${#lab} > maxl )) && maxl=${#lab}
      (( ${#sc} > maxs )) && maxs=${#sc}
    fi
    r=$(( r + 1 ))
  done
  BCW_MAXSC=$maxs
  BCW_INNER=$(( 1 + maxl + 2 + maxs ))
}

_bcw_menu_draw_bar() { # name
  local a=$1 i x n s p
  local -a pr
  read -r -a pr <<< "${BCW_MPAIRS[$a]}"
  _bcw_menu_titles "$a"
  printf -v s '%*s' "$COLS" ''
  if [[ $BCW_MACT != "$a" ]]; then
    bc_print "$a" 0 0 "$s" pair="${pr[0]}"
    for i in "${!BCW_T[@]}"; do bc_print "$a" 0 "${BCW_X[i]}" "${BCW_T[i]}" pair="${pr[0]}"; done
    return
  fi
  bc_print "$a" 0 0 "$s" pair="${pr[1]}"
  for i in "${!BCW_T[@]}"; do
    n=${BCW_T[i]} x=${BCW_X[i]}
    if (( i == BCW_MBAR )); then
      bc_print "$a" 0 $(( x - 1 )) " " pair="${pr[3]}"
      bc_print "$a" 0 "$x" "${n:0:1}" pair="${pr[4]}"
      bc_print "$a" 0 $(( x + 1 )) "${n:1} " pair="${pr[3]}"
    else
      bc_print "$a" 0 "$x" "${n:0:1}" pair="${pr[2]}"
      bc_print "$a" 0 $(( x + 1 )) "${n:1}" pair="${pr[1]}"
    fi
  done
}

# Rows the drop-down can show.
_bcw_menu_vis() { # name -> BCW_VIS
  BCW_VIS=$(( LINES - 1 - 2 - ${BCW_MRES[$1]} ))
  (( BCW_VIS < 1 )) && BCW_VIS=1
}

# (Re)create the drop-down float for the selected menu.
_bcw_menu_open_dd() { # name
  local a=$1 x n
  local -a pr
  read -r -a pr <<< "${BCW_MPAIRS[$a]}"
  _bcw_menu_titles "$a"; _bcw_menu_items "$a"; _bcw_menu_vis "$a"
  n=${#BCW_ROWS[@]}; (( n > BCW_VIS )) && n=$BCW_VIS
  x=$(( BCW_X[BCW_MBAR] - 2 )); (( x < 0 )) && x=0
  bc_float "$a.dd" in="$a" within=screen at="1,$x" size="$(( n + 2 ))x$(( BCW_INNER + 2 ))" \
    shadow=mc pair="${pr[1]}"
  BCL_CLICKFN[$a.dd]=_bcw_menu_click
  BCW_MDD=1
  bc_dirty "$a.dd"
}

_bcw_menu_close_dd() { # name
  [[ ${BCL_KIND[$1.dd]:-} == float ]] && bc_close "$1.dd"
  BCW_MDD=0
}

_bcw_menu_draw_dd() { # area (NAME.dd)
  local d=$1 a=${1%.dd} r y e lab sc mn mpos i bw line sp tp tp2 sel
  local -a pr
  read -r -a pr <<< "${BCW_MPAIRS[$a]}"
  _bcw_menu_titles "$a"; _bcw_menu_items "$a"; _bcw_menu_vis "$a"
  local n=${#BCW_ROWS[@]} nshow selrow=${BCW_REAL[BCW_MSEL]}
  nshow=$(( n < BCW_VIS ? n : BCW_VIS ))
  # scroll so the selected item is visible
  (( BCW_MTOP > n - nshow )) && BCW_MTOP=$(( n - nshow ))
  (( selrow < BCW_MTOP )) && BCW_MTOP=$selrow
  (( selrow >= BCW_MTOP + nshow )) && BCW_MTOP=$(( selrow - nshow + 1 ))
  (( BCW_MTOP < 0 )) && BCW_MTOP=0
  bw=$(( BCW_INNER + 2 ))
  printf -v line '%*s' $(( bw - 2 )) ''; line=${line// /─}
  printf -v sp '%*s' "$BCW_INNER" ''
  bc_print "$d" 0 0 "┌$line┐" pair="${pr[1]}"
  for (( y = 1; y <= nshow; y++ )); do
    r=$(( BCW_MTOP + y - 1 )); e=${BCW_ROWS[r]}
    if [[ $e == SEP ]]; then bc_print "$d" "$y" 0 "├$line┤" pair="${pr[1]}"; continue; fi
    sel=$(( r == selrow ))
    tp=${pr[1]} tp2=${pr[2]}; (( sel )) && tp=${pr[3]} tp2=${pr[4]}
    lab=${e%%|*} mn=${e##*|} sc=${e#*|}; sc=${sc%|*}
    if [[ $mn == *:* ]]; then mpos=${mn##*:}
    else
      mpos=0
      for (( i = 0; i < ${#lab}; i++ )); do [[ -n $mn && ${lab:i:1} == "$mn" ]] && { mpos=$i; break; }; done
    fi
    bc_print "$d" "$y" 0 "│" pair="${pr[1]}"
    bc_print "$d" "$y" 1 "$sp" pair="$tp"
    bc_print "$d" "$y" 2 "${lab:0:mpos}" pair="$tp"
    bc_print "$d" "$y" $(( 2 + mpos )) "${lab:mpos:1}" pair="$tp2"
    bc_print "$d" "$y" $(( 3 + mpos )) "${lab:mpos+1}" pair="$tp"
    [[ -n $sc ]] && bc_print "$d" "$y" $(( BCW_INNER - BCW_MAXSC + 1 )) "$sc" pair="$tp"
    bc_print "$d" "$y" $(( BCW_INNER + 1 )) "│" pair="${pr[1]}"
  done
  bc_print "$d" $(( nshow + 1 )) 0 "└$line┘" pair="${pr[1]}"
}

# bc_menubar_run NAME [INDEX] [DROPDOWN]
bc_menubar_run() {
  local a=$1
  BCW_MACT=$a BCW_MBAR=${2:-0} BCW_MSEL=0 BCW_MTOP=0 BCW_MPICK=""
  declare -F "open_$a" >/dev/null && "open_$a"
  bc_dirty "$a"
  (( ${3:-0} )) && _bcw_menu_open_dd "$a"
  local pf=$BCL_FOCUS
  bc_focus "$a"
  bc_modal "$a"
  _bcw_menu_close_dd "$a"
  BCW_MACT=""
  bc_focus "$pf"
  bc_dirty "$a"
  declare -F "close_$a" >/dev/null && "close_$a"
  if [[ -n $BCW_MPICK ]]; then
    _bcw_menu_titles "$a"
    declare -F "pick_$a" >/dev/null && "pick_$a" "${BCW_T[BCW_MBAR]}" "$BCW_MPICK"
  fi
  return 0
}

_bcw_menu_close() { bc_modal_done; }

_bcw_menu_pick() { # name
  _bcw_menu_items "$1"
  local e=${BCW_ROWS[${BCW_REAL[BCW_MSEL]}]}
  BCW_MPICK=${e%%|*}
  bc_modal_done picked
}

_bcw_menu_switch() { # name newbar
  local a=$1
  _bcw_menu_titles "$a"
  BCW_MBAR=$(( ($2 + ${#BCW_T[@]}) % ${#BCW_T[@]} )) BCW_MSEL=0 BCW_MTOP=0
  bc_dirty "$a"
  (( BCW_MDD )) && _bcw_menu_open_dd "$a"
}

_bcw_menu_key() { # key
  local a=$BCW_MACT k=$1 i lf
  [[ -n $a ]] || { bc_pass; return; }
  _bcw_menu_titles "$a"; _bcw_menu_items "$a"
  local nreal=${#BCW_REAL[@]}
  case $k in
    "$KEY_LEFT")  _bcw_menu_switch "$a" $(( BCW_MBAR - 1 )) ;;
    "$KEY_RIGHT") _bcw_menu_switch "$a" $(( BCW_MBAR + 1 )) ;;
    "$KEY_DOWN")
      if (( BCW_MDD )); then BCW_MSEL=$(( (BCW_MSEL + 1) % nreal )); bc_dirty "$a.dd"
      else BCW_MSEL=0 BCW_MTOP=0; _bcw_menu_open_dd "$a"; fi ;;
    "$KEY_UP")
      if (( ! BCW_MDD )); then BCW_MSEL=0 BCW_MTOP=0; _bcw_menu_open_dd "$a"
      elif (( BCW_MSEL == 0 )); then _bcw_menu_close_dd "$a"
      else BCW_MSEL=$(( BCW_MSEL - 1 )); bc_dirty "$a.dd"; fi ;;
    $'\r'|$'\n'|"$KEY_ENTER")
      if (( BCW_MDD )); then _bcw_menu_pick "$a"
      else BCW_MSEL=0 BCW_MTOP=0; _bcw_menu_open_dd "$a"; fi ;;
    $'\e'|"$KEY_F10") _bcw_menu_close ;;
    [a-zA-Z])
      if (( BCW_MDD )); then
        for (( i = 0; i < nreal; i++ )); do
          lf=${BCW_ROWS[BCW_REAL[i]]##*|}; lf=${lf%%:*}
          [[ ${lf,,} == "${k,,}" ]] && { BCW_MSEL=$i; bc_dirty "$a.dd"; break; }
        done
      else
        for i in "${!BCW_T[@]}"; do
          [[ ${BCW_T[i]:0:1} == [${k,,}${k^^}] ]] && { _bcw_menu_switch "$a" "$i"; break; }
        done
      fi ;;
  esac
}

_bcw_menu_click() { # area y x bstate
  local d=$1 y=$2 x=$3 b=$4 a i n
  (( b & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  a=${d%.dd}
  if [[ $d == *.dd ]]; then            # an item in the open drop-down
    _bcw_menu_items "$a"
    local r=$(( BCW_MTOP + y - 1 ))
    (( y < 1 || r >= ${#BCW_ROWS[@]} )) && return 0
    [[ ${BCW_ROWS[r]} == SEP ]] && return 0
    for i in "${!BCW_REAL[@]}"; do (( BCW_REAL[i] == r )) && BCW_MSEL=$i; done
    _bcw_menu_pick "$a"
    return 0
  fi
  _bcw_menu_titles "$a"                 # a title on the bar
  for i in "${!BCW_T[@]}"; do
    n=${#BCW_T[i]}
    (( x >= BCW_X[i] && x < BCW_X[i] + n )) || continue
    if [[ $BCW_MACT == "$a" ]]; then
      BCW_MBAR=$i BCW_MSEL=0 BCW_MTOP=0; bc_dirty "$a"; _bcw_menu_open_dd "$a"
    else
      bc_menubar_run "$a" "$i" 1
    fi
    return 0
  done
}

# ============================================================ dialogs
# bc_dialog NAME TITLE HxW [style options] — a dialog: a centred float with a
# border and title (style options as for bc_float/bc_style, e.g. margin=1
# shadow=mc pair=N tpair=N nudge=DY,DX). Lay it out with bc_grid NAME "…",
# fill the areas with bc_label / bc_input / bc_check / bc_cycle / bc_button,
# then bc_dialog_run NAME. Keys: Tab next control (wrapping), Down/Up next and
# previous, Enter presses the focused button or else the default (first
# "ok") button, Esc cancels. A keys=FN option replaces the key handler; FN
# can call _bcw_dialog_key for the default behaviour.
#
# Pens (set BCW_PENS once): "FOCUS FOCUSHOT FIELD FIELDBUTTON" — the focused
# control, its hotkey letter, input fields and their [^] button. Hotkey
# letters of unfocused controls use the dialog's title pair.
BCW_PENS="0 0 0 0"
declare -A BCW_DLG=()      # dialog float -> 1
declare -A BCW_ORDER=()    # dialog -> focus order (area names)
declare -A BCW_KIND=()     # control area -> input | check | button | radio
declare -A BCW_VAR=()      # input/check/radio -> variable name
declare -A BCW_LABEL=() BCW_HOT=() BCW_STYLE=() BCW_CARET=() BCW_BTN=() BCW_VAL=()

bc_dialog() { # name title HxW [options]
  local a=$1 t=$2 sz=$3; shift 3
  bc_float "$a" size="$sz" border title="$t" keys=_bcw_dialog_key "$@" || return 1
  BCW_DLG[$a]=1
  BCW_ORDER[$a]=""
}

# The dialog a control belongs to -> BCW_D
_bcw_dialog_of() { # area
  local p=$1
  BCW_D=""
  while [[ -n $p && $p != screen ]]; do
    [[ -n ${BCW_DLG[$p]:-} ]] && { BCW_D=$p; return 0; }
    if [[ ${BCL_KIND[$p]:-} == float ]]; then p=${BCL_FIN[$p]}; else p=${BCL_PARENT[$p]:-}; fi
  done
  return 1
}

# Controls of a dialog in focus order -> BCW_FO
_bcw_focus_order() { # dialog
  local d=$1 n
  BCW_FO=()
  if [[ -n ${BCW_ORDER[$d]} ]]; then read -r -a BCW_FO <<< "${BCW_ORDER[$d]}"; return; fi
  BCL_LV=(); _bcl_order_tree "$d"
  for n in "${BCL_LV[@]}"; do [[ -n ${BCW_KIND[$n]:-} ]] && BCW_FO+=("$n"); done
}

# Move the focus to control NAME (redrawing the old and new control).
_bcw_focus() { # area
  local old=$BCL_FOCUS
  bc_cursor
  bc_focus "$1"
  [[ -n $old && -n ${BCW_KIND[$old]:-} ]] && bc_dirty "$old"
  bc_dirty "$1"
}

# bc_dialog_run NAME [focus=AREA|-] [order="AREA …"] — run the dialog (modal).
# focus=- starts with no control focused.
# Status 0 when a button other than a cancel button closed it; the button's
# area name is in BCL_RESULT.
bc_dialog_run() {
  local d=$1 o f=""; shift
  for o in "$@"; do
    case $o in
      focus=*) f=${o#*=} ;;
      order=*) BCW_ORDER[$d]=${o#*=} ;;
    esac
  done
  _bcw_focus_order "$d"
  [[ -z $f ]] && f=${BCW_FO[0]:-}
  local pf=$BCL_FOCUS
  if [[ $f == - ]]; then bc_focus ""; elif [[ -n $f ]]; then _bcw_focus "$f"; fi
  bc_modal "$d"; local rc=$?
  bc_cursor
  bc_focus "$pf"
  return "$rc"
}

_bcw_dialog_key() { # key  (keys the focused control did not take)
  local k=$1 d=$BCL_MODAL i n
  [[ -n $BCL_FOCUS ]] && _bcw_dialog_of "$BCL_FOCUS" && d=$BCW_D
  _bcw_focus_order "$d"
  n=${#BCW_FO[@]}
  for (( i = 0; i < n; i++ )); do [[ ${BCW_FO[i]} == "$BCL_FOCUS" ]] && break; done
  case $k in
    $'\t')       (( n )) && _bcw_focus "${BCW_FO[(i + 1) % n]}" ;;
    "$KEY_DOWN") (( i < n - 1 )) && _bcw_focus "${BCW_FO[i+1]}" ;;
    "$KEY_UP")         (( i > 0 && i < n )) && _bcw_focus "${BCW_FO[i-1]}" ;;
    $'\r'|$'\n'|"$KEY_ENTER")
      if [[ ${BCW_KIND[$BCL_FOCUS]:-} == button ]]; then _bcw_press "$BCL_FOCUS"; return; fi
      for (( i = 0; i < n; i++ )); do
        [[ ${BCW_KIND[${BCW_FO[i]}]} == button && ${BCW_STYLE[${BCW_FO[i]}]} == ok ]] && { _bcw_press "${BCW_FO[i]}"; return; }
      done
      bc_close "$d" ok ;;
    $'\e') bc_close "$d" ;;
    *) bc_pass ;;
  esac
}

# Pens for a control -> BCW_P (normal) BCW_PH (hotkey) BCW_PF BCW_PFH BCW_PI BCW_PB
_bcw_pens() { # area
  local -a pp
  read -r -a pp <<< "$BCW_PENS"
  _bcl_eff "$1"; BCW_P=$BCL_EP
  BCW_PH=$BCW_P
  _bcw_dialog_of "$1" && BCW_PH=${BCL_TPEN[$BCW_D]:-$BCW_P}
  BCW_PF=${pp[0]} BCW_PFH=${pp[1]} BCW_PI=${pp[2]} BCW_PB=${pp[3]}
}

# A label with an optional hotkey letter at position HOT -> drawn at y x.
_bcw_hotlabel() { # area y x text hot pen hotpen
  local a=$1 y=$2 x=$3 t=$4 h=$5
  if (( h < 0 )); then bc_print "$a" "$y" "$x" "$t" pair="$6"; return; fi
  bc_print "$a" "$y" "$x" "${t:0:h}" pair="$6"
  bc_print "$a" "$y" $(( x + h )) "${t:h:1}" pair="$7"
  bc_print "$a" "$y" $(( x + h + 1 )) "${t:h+1}" pair="$6"
}

# ---- label
# bc_label NAME TEXT [align=…] [pair=N] — static text (bc_text).
bc_label() { bc_text "$@"; }

# ---- input field
# bc_input NAME VAR [button] — a one-line text field editing the variable
# named VAR. "button" draws mc's [^] history button at its right end.
# Keys: printable characters, Backspace, Delete, Left, Right, Home, End;
# M-H (KEY_ALT_SH) calls history_NAME. A click places the caret.
bc_input() { # name var [button]
  local a=$1
  local -n _v=$2
  BCW_KIND[$a]=input BCW_VAR[$a]=$2 BCW_CARET[$a]=${#_v} BCW_BTN[$a]=0
  [[ ${3:-} == button ]] && BCW_BTN[$a]=1
  BCL_KEYFN[$a]=_bcw_input_key BCL_CLICKFN[$a]=_bcw_input_click
  bc_content "$a" 1 1
  eval "draw_$a() { _bcw_input_draw \"\$1\"; }"
  bc_dirty "$a"
}

_bcw_input_draw() { # area
  local a=$1 s
  local -n _v=${BCW_VAR[$a]}
  bc_size "$a"; _bcw_pens "$a"
  local w=$BCL_W c=${BCW_CARET[$a]} tw=$BCL_W
  (( c > ${#_v} )) && c=${#_v}
  (( BCW_BTN[$a] )) && tw=$(( w - 3 ))
  printf -v s '%-*s' "$tw" "${_v:0:tw}"
  bc_print "$a" 0 0 "$s" pair="$BCW_PI"
  if (( BCW_BTN[$a] )); then bc_print "$a" 0 "$tw" "[^]" pair="$BCW_PB"; (( c > w - 4 )) && c=$(( w - 4 ))
  else (( c > w - 1 )) && c=$(( w - 1 )); fi
  (( c < 0 )) && c=0
  [[ $BCL_FOCUS == "$a" ]] && bc_cursor "$a" 0 "$c"
}

_bcw_input_key() { # key
  local a=$BCL_FOCUS k=$1
  local -n _v=${BCW_VAR[$a]}
  local c=${BCW_CARET[$a]}
  (( c > ${#_v} )) && c=${#_v}
  case $k in
    "$KEY_LEFT")  (( c > 0 )) && c=$(( c - 1 )) ;;
    "$KEY_RIGHT") (( c < ${#_v} )) && c=$(( c + 1 )) ;;
    "$KEY_HOME")  c=0 ;;
    "$KEY_END")   c=${#_v} ;;
    $'\x7f'|$'\b'|"$KEY_BACKSPACE")
      (( c > 0 )) && { _v="${_v:0:c-1}${_v:c}"; c=$(( c - 1 )); } ;;
    "$KEY_DC") _v="${_v:0:c}${_v:c+1}" ;;
    "$KEY_ALT_SH") declare -F "history_$a" >/dev/null && "history_$a" ;;
    *)
      if [[ ${#k} == 1 && $k == [[:print:]] ]]; then _v="${_v:0:c}$k${_v:c}"; c=$(( c + 1 ))
      else bc_pass; return; fi ;;
  esac
  BCW_CARET[$a]=$c
  bc_dirty "$a"
}

_bcw_input_click() { # area y x bstate
  local a=$1 x=$3
  (( $4 & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  local -n _v=${BCW_VAR[$a]}
  bc_size "$a"
  (( BCW_BTN[$a] && x >= BCL_W - 3 )) && return 0
  (( x > ${#_v} )) && x=${#_v}
  BCW_CARET[$a]=$x
  _bcw_focus "$a"
}

# ---- checkbox
# bc_check NAME VAR LABEL [hot=N] — "[x] LABEL" toggling VAR (0/1) with
# Space, Left, Right or a click. hot=N highlights LABEL's N-th letter.
bc_check() { # name var label [hot=N]
  local a=$1 o
  BCW_KIND[$a]=check BCW_VAR[$a]=$2 BCW_LABEL[$a]=$3 BCW_HOT[$a]=-1
  for o in "${@:4}"; do [[ $o == hot=* ]] && BCW_HOT[$a]=${o#*=}; done
  BCL_KEYFN[$a]=_bcw_check_key BCL_CLICKFN[$a]=_bcw_check_click
  bc_content "$a" 1 $(( 4 + ${#3} ))
  eval "draw_$a() { _bcw_check_draw \"\$1\"; }"
  bc_dirty "$a"
}

_bcw_check_draw() { # area
  local a=$1 p ph b="[ ] "
  local -n _v=${BCW_VAR[$a]}
  _bcw_pens "$a"
  p=$BCW_P ph=$BCW_PH
  [[ $BCL_FOCUS == "$a" ]] && p=$BCW_PF ph=$BCW_PFH
  (( _v )) && b="[x] "
  bc_print "$a" 0 0 "$b" pair="$p"
  _bcw_hotlabel "$a" 0 4 "${BCW_LABEL[$a]}" "${BCW_HOT[$a]}" "$p" "$ph"
}

_bcw_check_toggle() { local -n _v=${BCW_VAR[$1]}; _v=$(( 1 - ${_v:-0} )); bc_dirty "$1"; }

_bcw_check_key() { # key
  case $1 in
    ' '|"$KEY_LEFT"|"$KEY_RIGHT") _bcw_check_toggle "$BCL_FOCUS" ;;
    *) bc_pass ;;
  esac
}

_bcw_check_click() { # area y x bstate
  (( $4 & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  _bcw_check_toggle "$1"
  _bcw_focus "$1"
}

# ---- button
# bc_button NAME LABEL [ok] [cancel] [hot=N] — "[ LABEL ]", or mc's default
# button style "[< LABEL >]" with ok. Pressing it (Space, Enter, click) calls
# press_NAME if defined, else closes the dialog with NAME as the result
# (with no result for a cancel button).
bc_button() { # name label [ok] [cancel] [hot=N]
  local a=$1 o
  BCW_KIND[$a]=button BCW_LABEL[$a]=$2 BCW_STYLE[$a]=plain BCW_HOT[$a]=0 BCW_VAL[$a]=""
  for o in "${@:3}"; do
    case $o in
      ok) BCW_STYLE[$a]=ok ;;
      cancel) BCW_VAL[$a]=cancel ;;
      hot=*) BCW_HOT[$a]=${o#*=} ;;
    esac
  done
  BCL_KEYFN[$a]=_bcw_button_key BCL_CLICKFN[$a]=_bcw_button_click
  local w=$(( ${#2} + 4 )); [[ ${BCW_STYLE[$a]} == ok ]] && w=$(( ${#2} + 6 ))
  bc_content "$a" 1 "$w"
  eval "draw_$a() { _bcw_button_draw \"\$1\"; }"
  bc_dirty "$a"
}

_bcw_button_draw() { # area
  local a=$1 p ph l r
  _bcw_pens "$a"
  p=$BCW_P ph=$BCW_PH
  [[ $BCL_FOCUS == "$a" ]] && p=$BCW_PF ph=$BCW_PFH
  if [[ ${BCW_STYLE[$a]} == ok ]]; then l="[< " r=" >]"; else l="[ " r=" ]"; fi
  bc_print "$a" 0 0 "$l" pair="$p"
  _bcw_hotlabel "$a" 0 "${#l}" "${BCW_LABEL[$a]}" "${BCW_HOT[$a]}" "$p" "$ph"
  bc_print "$a" 0 $(( ${#l} + ${#BCW_LABEL[$a]} )) "$r" pair="$p"
}

_bcw_press() { # area
  local a=$1
  if declare -F "press_$a" >/dev/null; then "press_$a"; return; fi
  _bcw_dialog_of "$a" || return 0
  if [[ ${BCW_VAL[$a]} == cancel ]]; then bc_close "$BCW_D"; else bc_close "$BCW_D" "$a"; fi
}

_bcw_button_key() { # key
  case $1 in
    ' '|$'\r'|$'\n'|"$KEY_ENTER") _bcw_press "$BCL_FOCUS" ;;
    *) bc_pass ;;
  esac
}

_bcw_button_click() { # area y x bstate
  (( $4 & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  _bcw_press "$1"
}

# ---- cycling value
# bc_cycle NAME VAR PREFIX VALUE… — "PREFIX value" that steps VAR through the
# values with Space, Enter, Left, Right or a click.
bc_cycle() { # name var prefix values...
  local a=$1
  BCW_KIND[$a]=cycle BCW_VAR[$a]=$2 BCW_LABEL[$a]=$3 BCW_VAL[$a]="${*:4}"
  BCL_KEYFN[$a]=_bcw_cycle_key BCL_CLICKFN[$a]=_bcw_cycle_click
  eval "draw_$a() { _bcw_cycle_draw \"\$1\"; }"
  bc_dirty "$a"
}

_bcw_cycle_draw() { # area
  local a=$1 p
  local -n _v=${BCW_VAR[$a]}
  _bcw_pens "$a"; p=$BCW_P
  [[ $BCL_FOCUS == "$a" ]] && p=$BCW_PF
  bc_print "$a" 0 0 "${BCW_LABEL[$a]}$_v" pair="$p"
}

_bcw_cycle_step() { # area
  local a=$1 i
  local -n _v=${BCW_VAR[$a]}
  local -a vs
  read -r -a vs <<< "${BCW_VAL[$a]}"
  for (( i = 0; i < ${#vs[@]}; i++ )); do [[ ${vs[i]} == "$_v" ]] && break; done
  _v=${vs[(i + 1) % ${#vs[@]}]}
  bc_dirty "$a"
}

_bcw_cycle_key() { # key
  case $1 in
    ' '|$'\r'|"$KEY_LEFT"|"$KEY_RIGHT") _bcw_cycle_step "$BCL_FOCUS" ;;
    *) bc_pass ;;
  esac
}

_bcw_cycle_click() { # area y x bstate
  (( $4 & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  _bcw_cycle_step "$1"; _bcw_focus "$1"
}
