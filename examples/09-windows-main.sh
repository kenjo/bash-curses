# Port of references/howto-examples/09-windows/main.c — move a boxed window
# with the arrow keys; F1 exits.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

my_win=""

create_newwin() { # height width starty startx
  newwin "$1" "$2" "$3" "$4"
  box "$bc_win"
  wrefresh "$bc_win"
  my_win=$bc_win
}

destroy_win() { # win
  wborder "$1" " " " " " " " " " " " " " "
  wrefresh "$1"
  delwin "$1"
}

main() {
  initscr || exit 1
  cbreak
  keypad 0 1
  local height=3 width=10
  local starty=$(( (LINES - height) / 2 )) startx=$(( (COLS - width) / 2 ))
  printw "Press F1 to exit"
  refresh
  create_newwin "$height" "$width" "$starty" "$startx"
  while :; do
    getch
    [[ $key == "$KEY_F1" ]] && break
    case $key in
      "$KEY_LEFT")  destroy_win "$my_win"; startx=$(( startx - 1 )); create_newwin "$height" "$width" "$starty" "$startx" ;;
      "$KEY_RIGHT") destroy_win "$my_win"; startx=$(( startx + 1 )); create_newwin "$height" "$width" "$starty" "$startx" ;;
      "$KEY_UP")    destroy_win "$my_win"; starty=$(( starty - 1 )); create_newwin "$height" "$width" "$starty" "$startx" ;;
      "$KEY_DOWN")  destroy_win "$my_win"; starty=$(( starty + 1 )); create_newwin "$height" "$width" "$starty" "$startx" ;;
    esac
  done
  endwin
  exit 0
}

main "$@"
