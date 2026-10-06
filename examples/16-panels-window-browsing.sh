# Port of references/howto-examples/16-panels/window-browsing.c — each panel's
# user pointer holds the "next" panel (a ring); Tab makes the next panel the
# top. F1 exits.
source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

wins=()
panels=()

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

  # User pointers form a ring: panel i -> panel (i + 1) % 3.
  set_panel_userptr "${panels[0]}" "${panels[1]}"
  set_panel_userptr "${panels[1]}" "${panels[2]}"
  set_panel_userptr "${panels[2]}" "${panels[0]}"

  update_panels

  attrset 0 4
  mvprintw $(( LINES - 2 )) 0 "Use tab to browse through the windows (F1 to Exit)"
  attrset 0 0
  doupdate

  local top=${panels[2]} nxt
  while :; do
    getch || break
    [[ $key == "$KEY_F1" ]] && break
    case $key in
      $'\t')
        panel_userptr "$top"; nxt=$bc_panel_user
        top_panel "$nxt"
        top=$nxt
        ;;
    esac
    update_panels
    doupdate
  done
  endwin
}

main "$@"
