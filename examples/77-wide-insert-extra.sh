# Port of the ncurses wide-character insert wrapper demos.

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
  mvwprintw "$win" 2 0 "base"
  mvwprintw "$win" 3 0 "base"
  mvwprintw "$win" 4 0 "base"
  mvwprintw "$win" 5 0 "base"
  mvwprintw "$win" 6 0 "base"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "w wins_wch  W wins_wchnstr  s wins_wchstr  S winsn_wch  n insn_wch  i mvins_wch  I mvins_wchnstr  m mvins_wchstr  M mvinsn_wch  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      w|W)
        wins_wch "$win" "X"
        msg="wins_wch win X"
        ;;
      1)
        wins_wchnstr "$win" "wide" 3
        msg="wins_wchnstr win wide 3"
        ;;
      s|S)
        wins_wchstr "$win" "wide"
        msg="wins_wchstr win wide"
        ;;
      2)
        winsn_wch "$win" "wide" 3
        msg="winsn_wch win wide 3"
        ;;
      n|N)
        insn_wch "wide" 3
        msg="insn_wch wide 3"
        ;;
      i|I)
        mvins_wch 3 0 "Y"
        msg="mvins_wch 3 0 Y"
        ;;
      3)
        mvins_wchnstr 4 0 "wide" 3
        msg="mvins_wchnstr 4 0 wide 3"
        ;;
      m|M)
        mvins_wchstr 5 0 "wide"
        msg="mvins_wchstr 5 0 wide"
        ;;
      4)
        mvinsn_wch 6 0 "wide" 3
        msg="mvinsn_wch 6 0 wide 3"
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
