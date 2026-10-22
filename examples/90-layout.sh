# 90-layout: a Midnight-Commander-like screen built with lib/layout.sh.
# No coordinates, no resize code: the screen is a template, areas are drawn
# by name, and the Copy dialog is a modal float. (The dialog copies nothing.)
#
#   bash examples/90-layout.sh [left-dir] [right-dir]
#   keys: Up/Down Enter Tab, F5 or 5 = Copy, q or F10 = quit; mouse works.

source "${BASH_SOURCE[0]%/*}/../lib/layout.sh"

declare -A DIR
DIR[left]=$(cd "${1:-.}" && pwd)
DIR[right]=$(cd "${2:-..}" && pwd)
ACTIVE=left

bc_init mouse
init_pair 1 7 4    # panels
init_pair 2 0 6    # bars, selection
init_pair 3 0 7    # dialog
init_pair 4 3 4    # directories

bc_screen "
  menu  menu
  left  right
  hint  hint
  keys  keys
" rows="1 * 1 1" cols="* *"

bc_style menu  pair=2
bc_style keys  pair=2
bc_style left  pair=1 border
bc_style right pair=1 border
bc_text  menu  " Left   File   Command   Options   Right"
bc_text  keys  " 1Help  2Menu  3View  4Edit  5Copy  6Move  7Mkdir  8Delete  9PullDn 10Quit"

# ---------------------------------------------------------------- panels
declare -A SEL=([left]=0 [right]=0) TOP=([left]=0 [right]=0)
declare -a FILES_left FILES_right

load() { # side
  local -n files=FILES_$1
  local f
  files=(..)
  for f in "${DIR[$1]}"/*; do
    [[ -e $f ]] || continue
    if [[ -d $f ]]; then files+=("${f##*/}/"); else files+=("${f##*/}"); fi
  done
  SEL[$1]=0 TOP[$1]=0
  bc_style "$1" title="${DIR[$1]/#$HOME/\~}"
  bc_dirty "$1"
}

draw_left()  { draw_panel left; }
draw_right() { draw_panel right; }
draw_panel() { # side
  local a=$1 i name pair
  local -n files=FILES_$a
  bc_size "$a"
  (( SEL[$a] < TOP[$a] )) && TOP[$a]=${SEL[$a]}
  (( SEL[$a] >= TOP[$a] + BCL_H )) && TOP[$a]=$(( SEL[$a] - BCL_H + 1 ))
  for (( i = TOP[$a]; i < ${#files[@]} && i < TOP[$a] + BCL_H; i++ )); do
    name=${files[i]}
    pair=1; [[ $name == */ ]] && pair=4
    [[ $a == "$ACTIVE" ]] && (( i == SEL[$a] )) && pair=2
    printf -v name '%-*s' "$BCL_W" "$name"
    bc_print "$a" $(( i - TOP[$a] )) 0 "$name" pair=$pair
  done
  [[ $a == "$ACTIVE" ]] && bc_text hint " ${files[SEL[$a]]}"
}

move() { # delta
  local -n files=FILES_$ACTIVE
  local s=$(( SEL[$ACTIVE] + $1 ))
  (( s < 0 )) && s=0
  (( s >= ${#files[@]} )) && s=$(( ${#files[@]} - 1 ))
  SEL[$ACTIVE]=$s
  bc_dirty "$ACTIVE"
}

enter() {
  local -n files=FILES_$ACTIVE
  local name=${files[SEL[$ACTIVE]]}
  [[ $name == */ || $name == .. ]] || return
  DIR[$ACTIVE]=$(cd "${DIR[$ACTIVE]}/$name" && pwd)
  load "$ACTIVE"
}

other() { [[ $ACTIVE == left ]] && echo right || echo left; }

# ---------------------------------------------------------------- dialog
copy_dialog() {
  local -n files=FILES_$ACTIVE
  local name=${files[SEL[$ACTIVE]]} to
  to=${DIR[$(other)]}
  bc_float copy size=9x60 border title=Copy pair=3 shadow
  bc_grid copy "
    l1   src
    l2   dst
    .    .
    btns btns
  " rows="1 1 * 1" cols="auto *" gap=1
  bc_grid btns ". ok cancel ." cols="* auto auto *" gap=2
  bc_text l1 "From:"
  bc_text l2 "To:"
  bc_text src "$name"
  bc_text dst "$to/"
  bc_text ok "[ OK ]" align=center
  bc_text cancel "[ Cancel ]" align=center
  if bc_modal copy; then
    bc_text hint " Would copy $name -> $to/ (demo: nothing written)"
  else
    bc_text hint " Copy cancelled"
  fi
}
key_copy() {
  case $1 in
    $'\r'|$'\n') bc_close copy ok ;;
    $'\e'|q)     bc_close copy ;;
  esac
}
click_ok()     { bc_close copy ok; }
click_cancel() { bc_close copy; }

# ---------------------------------------------------------------- input
on_key() {
  case $1 in
    "$KEY_UP")    move -1 ;;
    "$KEY_DOWN")  move 1 ;;
    "$KEY_PPAGE") move -10 ;;
    "$KEY_NPAGE") move 10 ;;
    $'\r'|$'\n')  enter ;;
    $'\t')        ACTIVE=$(other); bc_dirty left right ;;
    5|"$(( KEY_F0 + 5 ))")   copy_dialog ;;
    q|"$(( KEY_F0 + 10 ))")  bc_quit ;;
  esac
}
on_click() { # area y x
  [[ $1 == left || $1 == right ]] || return
  ACTIVE=$1
  SEL[$1]=$(( TOP[$1] + $2 ))
  move 0
  bc_dirty left right
}

load left
load right
bc_run
