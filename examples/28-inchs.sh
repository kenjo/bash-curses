# Port of the ncurses test inchs demo: inch, inchnstr, inchstr, mvwinch.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 2 2 "ABCDEFGHIJ"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "i winch  n inchnstr  s inchstr  m mvwinch  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      i)
        wmove "$win" 2 2
        winch "$win"
        msg="winch: ch=$wch attr=$wcha pair=$wchp"
        ;;
      n)
        wmove "$win" 2 2
        inchnstr "$win" 5
        msg="inchnstr: $bc_str count=${#bc_chstr[@]}"
        ;;
      s)
        wmove "$win" 2 2
        inchstr "$win"
        msg="inchstr: $bc_str"
        ;;
      m)
        mvwinch "$win" 2 3
        msg="mvwinch(2,3): ch=$wch attr=$wcha pair=$wchp"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
