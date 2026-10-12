# Port of the ncurses test wide-character add_wch demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a mvadd_wch  w wadd_wch  n wadd_wchnstr  s wadd_wchstr  e echo_wchar  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        mvadd_wch 2 0 'A'
        msg="mvadd_wch A"
        ;;
      w|W)
        wadd_wch "$BC_STDSCR" 'B'
        msg="wadd_wch B"
        ;;
      n|N)
        mvwadd_wchnstr "$BC_STDSCR" 3 0 "wide" 2
        msg="mvwadd_wchnstr wide 2"
        ;;
      s|S)
        mvwadd_wchstr "$BC_STDSCR" 4 0 "wide"
        msg="mvwadd_wchstr wide"
        ;;
      e|E)
        echo_wchar 'C'
        msg="echo_wchar C"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
