# Port of the ncurses test wide-character extra wrapper demos.

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
  mvwprintw "$win" 2 0 "abc"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "n mvwadd_wchnstr  a mvwadd_wchstr  i mvwins_wchnstr  s mvwins_wchstr  r mvwin_wchnstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      n|N)
        mvwadd_wchnstr "$win" 3 0 "wide" 2
        msg="mvwadd_wchnstr wide 2"
        ;;
      a|A)
        mvwadd_wchstr "$win" 4 0 "wide"
        msg="mvwadd_wchstr wide"
        ;;
      i|I)
        mvwins_wchnstr "$win" 5 0 "wide" 2
        msg="mvwins_wchnstr wide 2"
        ;;
      s|S)
        mvwins_wchstr "$win" 6 0 "wide"
        msg="mvwins_wchstr wide"
        ;;
      r|R)
        mvwin_wchnstr "$win" 2 0 3
        msg="mvwin_wchnstr bc_str=$bc_str"
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
