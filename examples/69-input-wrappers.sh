# Port of the ncurses test input wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  echo
  keypad 0 1
  curs_set 1

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "k getkey  g mvgetch  w mvwgetch  n mvwgetnstr  s mvwgetstr  N mvgetnstr  S mvgetstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      k|K)
        getkey
        msg="getkey key=$key"
        ;;
      g|G)
        mvgetch 1 0
        msg="mvgetch key=$key"
        ;;
      w|W)
        mvwgetch "$win" 1 0
        msg="mvwgetch key=$key"
        ;;
      n|N)
        mvwgetnstr "$win" 2 0 5
        msg="mvwgetnstr bc_str=$bc_str"
        ;;
      s|S)
        mvwgetstr "$win" 3 0
        msg="mvwgetstr bc_str=$bc_str"
        ;;
      1)
        mvgetnstr 15 0 5
        msg="mvgetnstr bc_str=$bc_str"
        ;;
      2)
        mvgetstr 16 0
        msg="mvgetstr bc_str=$bc_str"
        ;;
      q|Q)
        break
        ;;
    esac
    wrefresh "$win"
  done

  endwin
}

main "$@"
