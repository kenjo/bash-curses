# Port of references/howto-examples/16-panels/moving-resizing.c — enter move
# mode ('m') or resize mode ('r') with the arrow keys, commit with Enter,
# browse with Tab, F1 to exit.
source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

wins=()
panels=()
# Per-panel data, indexed by panel id (== data index here).
PX=() PY=() PW=() PH=() PLABEL=() PCOLOR=() PNEXT=()

print_in_middle() { # win starty startx width string color
  local win=${1:-$BC_STDSCR} starty=$2 startx=$3 width=$4 string=$5 color=$6
  local y x length
  getyx "$win"; y=$BC_GCY; x=$BC_GCX
  (( startx != 0 )) && x=$startx
  (( starty != 0 )) && y=$starty
  (( width == 0 )) && width=80
  length=${#string}
  x=$(( startx + (width - length) / 2 ))
  wattrset "$win" 0 "$color"
  mvwprintw "$win" "$y" "$x" '%s' "$string"
  wattrset "$win" 0 0
}

win_show() { # win label label_color
  local win=$1 label=$2 color=$3 y x width
  getbegyx "$win"; y=$BC_GBY; x=$BC_GBX
  getmaxyx "$win"; width=$BC_GMX
  box "$win"
  mvwaddch "$win" 2 0 "$ACS_LTEE"
  mvwhline "$win" 2 1 "$ACS_HLINE" $(( width - 2 ))
  mvwaddch "$win" 2 $(( width - 1 )) "$ACS_RTEE"
  print_in_middle "$win" 1 0 "$width" "$label" "$color"
}

init_wins() { # n
  local n=$1 i y=2 x=10 label
  for (( i = 0; i < n; i++ )); do
    newwin 10 40 "$y" "$x"
    wins[i]=$bc_win
    label="Window Number $(( i + 1 ))"
    win_show "${wins[$i]}" "$label" $(( i + 1 ))
    y=$(( y + 3 ))
    x=$(( x + 7 ))
  done
}

set_user_ptrs() { # n
  local n=$1 i win y x h w
  for (( i = 0; i < n; i++ )); do
    win=${wins[$i]}
    getbegyx "$win"; y=$BC_GBY; x=$BC_GBX
    getmaxyx "$win"; h=$BC_GMY; w=$BC_GMX
    PX[i]=$x; PY[i]=$y; PW[i]=$w; PH[i]=$h
    PLABEL[i]="Window Number $(( i + 1 ))"
    PCOLOR[i]=$(( i + 1 ))
    if (( i + 1 == n )); then PNEXT[i]=0; else PNEXT[i]=$(( i + 1 )); fi
    set_panel_userptr "${panels[$i]}" "$i"
  done
}

show_hint() {
  attrset 0 4
  mvprintw $(( LINES - 3 )) 0 "Use 'm' for moving, 'r' for resizing"
  mvprintw $(( LINES - 2 )) 0 "Use tab to browse through the windows (F1 to Exit)"
  attrset 0 0
}

main() {
  initscr || exit 1
  start_color
  cbreak
  noecho
  keypad 0 1
  init_pair 1 "$COLOR_RED" "$COLOR_BLACK"
  init_pair 2 "$COLOR_GREEN" "$COLOR_BLACK"
  init_pair 3 "$COLOR_BLUE" "$COLOR_BLACK"
  init_pair 4 "$COLOR_CYAN" "$COLOR_BLACK"

  init_wins 3

  local i
  for i in 0 1 2; do
    new_panel "${wins[$i]}"
    panels[i]=$bc_panel
  done
  set_user_ptrs 3

  update_panels
  show_hint
  doupdate

  local stack_top=${panels[2]} cur newx newy neww newh nxt size=0 move=0 old_win temp_win
  panel_userptr "$stack_top"; cur=$bc_panel_user
  newx=${PX[$cur]}; newy=${PY[$cur]}; neww=${PW[$cur]}; newh=${PH[$cur]}

  while :; do
    getch || break
    [[ $key == "$KEY_F1" ]] && break
    case $key in
      $'\t')
        panel_userptr "$stack_top"; cur=$bc_panel_user
        nxt=${PNEXT[$cur]}
        top_panel "$nxt"
        stack_top=$nxt
        panel_userptr "$stack_top"; cur=$bc_panel_user
        newx=${PX[$cur]}; newy=${PY[$cur]}; neww=${PW[$cur]}; newh=${PH[$cur]}
        ;;
      r)
        size=1
        attrset 0 4
        mvprintw $(( LINES - 4 )) 0 "Entered Resizing :Use Arrow Keys to resize and press <ENTER> to end resizing"
        attrset 0 0
        ;;
      m)
        move=1
        attrset 0 4
        mvprintw $(( LINES - 4 )) 0 "Entered Moving: Use Arrow Keys to Move and press <ENTER> to end moving"
        attrset 0 0
        ;;
      "$KEY_LEFT")
        (( size )) && { newx=$(( newx - 1 )); neww=$(( neww + 1 )); }
        (( move )) && newx=$(( newx - 1 ))
        ;;
      "$KEY_RIGHT")
        (( size )) && { newx=$(( newx + 1 )); neww=$(( neww - 1 )); }
        (( move )) && newx=$(( newx + 1 ))
        ;;
      "$KEY_UP")
        (( size )) && { newy=$(( newy - 1 )); newh=$(( newh + 1 )); }
        (( move )) && newy=$(( newy - 1 ))
        ;;
      "$KEY_DOWN")
        (( size )) && { newy=$(( newy + 1 )); newh=$(( newh - 1 )); }
        (( move )) && newy=$(( newy + 1 ))
        ;;
      $'\r' | $'\n')
        move $(( LINES - 4 )) 0
        clrtoeol
        refresh
        if (( size )); then
          panel_window "$stack_top"; old_win=$bc_panel_win
          if (( newh >= 1 && neww >= 1 )); then
            newwin "$newh" "$neww" "$newy" "$newx"; temp_win=$bc_win
            replace_panel "$stack_top" "$temp_win"
            win_show "$temp_win" "${PLABEL[$cur]}" "${PCOLOR[$cur]}"
            delwin "$old_win"
          fi
          size=0
        fi
        if (( move )); then
          move_panel "$stack_top" "$newy" "$newx"
          move=0
        fi
        ;;
    esac

    show_hint
    refresh
    update_panels
    doupdate
  done
  endwin
}

main "$@"
