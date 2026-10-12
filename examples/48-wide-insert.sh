# Port of the ncurses test wide-character insert demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 8 30 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 2 0 "abc"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "w mvwins_wch  i mvwins_wch  m mvwins_wch  n mvwinsn_wch  s mvwins_wchstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      w|W)
        mvwins_wch "$win" 3 0 'X'
        msg="mvwins_wch X"
        ;;
      i|I)
        mvwins_wch "$win" 4 0 'Y'
        msg="mvwins_wch Y"
        ;;
      m|M)
        mvwins_wch "$win" 5 0 'Z'
        msg="mvwins_wch Z"
        ;;
      n|N)
        mvwinsn_wch "$win" 6 0 "wide" 2
        msg="mvwinsn_wch wide 2"
        ;;
      s|S)
        mvwins_wchstr "$win" 7 0 "wide"
        msg="mvwins_wchstr wide"
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
