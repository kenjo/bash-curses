# Port of the ncurses test wide-character input demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  mvprintw 2 0 "ABC"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "w wget_wch  g get_wch  m mvwget_wch  i win_wch  n win_wchnstr  s win_wchstr  u unget_wch  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      w|W)
        unget_wch 'A'
        wget_wch "$BC_STDSCR"
        msg="wget_wch wch=$wch attrs=$wcha pair=$wchp"
        ;;
      g|G)
        unget_wch 'B'
        get_wch
        msg="get_wch wch=$wch attrs=$wcha pair=$wchp"
        ;;
      m|M)
        unget_wch 'C'
        mvwget_wch "$BC_STDSCR" 3 0
        msg="mvwget_wch wch=$wch attrs=$wcha pair=$wchp"
        ;;
      i|I)
        win_wch "$BC_STDSCR"
        msg="win_wch wch=$wch attrs=$wcha pair=$wchp"
        ;;
      n|N)
        win_wchnstr "$BC_STDSCR" 3
        msg="win_wchnstr bc_str=$bc_str"
        ;;
      s|S)
        win_wchstr "$BC_STDSCR"
        msg="win_wchstr bc_str=$bc_str"
        ;;
      u|U)
        unget_wch 'Z'
        msg="unget_wch Z; next wgetch should read it"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
