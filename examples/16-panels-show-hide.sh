# Port of references/howto-examples/16-panels/show-hide.c — toggle each window
# hidden/visible with a/b/c (its user pointer tracks a per-panel hide flag).
# F1 exits.
source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

wins=()
panels=()
hide=()

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

  # Each panel's user pointer is its index into the hide[] array.
  hide=(0 0 0)
  set_panel_userptr "${panels[0]}" 0
  set_panel_userptr "${panels[1]}" 1
  set_panel_userptr "${panels[2]}" 2

  update_panels

  attrset 0 4
  mvprintw $(( LINES - 3 )) 0 "Show or Hide a window with 'a'(first window)  'b'(Second Window)  'c'(Third Window)"
  mvprintw $(( LINES - 2 )) 0 "F1 to Exit"
  attrset 0 0
  doupdate

  while :; do
    getch || break
    [[ $key == "$KEY_F1" ]] && break
    case $key in
      a)
        if (( hide[0] == 0 )); then hide_panel "${panels[0]}"; hide[0]=1; else show_panel "${panels[0]}"; hide[0]=0; fi
        ;;
      b)
        if (( hide[1] == 0 )); then hide_panel "${panels[1]}"; hide[1]=1; else show_panel "${panels[1]}"; hide[1]=0; fi
        ;;
      c)
        if (( hide[2] == 0 )); then hide_panel "${panels[2]}"; hide[2]=1; else show_panel "${panels[2]}"; hide[2]=0; fi
        ;;
    esac
    update_panels
    doupdate
  done
  endwin
}

main "$@"
