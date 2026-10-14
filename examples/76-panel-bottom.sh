# Port of the ncurses panel bottom/top/reorder demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

wins=()
panels=()

win_show() { # win label color
  local win=$1 label=$2 color=$3 width
  getmaxyx "$win"; width=$BC_GMX
  box "$win"
  mvwprintw "$win" 1 2 "%s" "$label"
}

init_wins() { # n
  local n=$1 i y=2 x=10
  for (( i = 0; i < n; i++ )); do
    newwin 10 40 "$y" "$x"
    wins[i]=$bc_win
    win_show "${wins[$i]}" "Window $(( i + 1 ))" $(( i + 1 ))
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
  curs_set 0
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

  update_panels
  doupdate

  local msg="waiting" temp_win
  while :; do
    mvprintw 0 0 "b bottom_panel  t top_panel  h hide_panel  s show_panel  m move_panel  r replace_panel  w panel_window  u update_panels  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh
    update_panels
    doupdate

    getch || break
    case $key in
      b|B)
        bottom_panel "${panels[0]}"
        msg="bottom_panel panel0"
        ;;
      t|T)
        top_panel "${panels[0]}"
        msg="top_panel panel0"
        ;;
      h|H)
        hide_panel "${panels[1]}"
        msg="hide_panel panel1"
        ;;
      s|S)
        show_panel "${panels[1]}"
        msg="show_panel panel1"
        ;;
      m|M)
        move_panel "${panels[2]}" 4 20
        msg="move_panel panel2 4 20"
        ;;
      r|R)
        newwin 8 30 6 6
        temp_win=$bc_win
        box "$temp_win"
        mvwprintw "$temp_win" 1 2 "replaced"
        replace_panel "${panels[2]}" "$temp_win"
        msg="replace_panel panel2"
        ;;
      w|W)
        panel_window "${panels[0]}"
        msg="panel_window panel0 win=$bc_panel_win"
        ;;
      u|U)
        update_panels
        msg="update_panels"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
