# Port of the ncurses test test_addchstr demo: addchstr, addchnstr, mvwaddchstr, mvwaddchnstr.

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
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a waddchstr  n waddchnstr  m mvwaddchstr  b mvwaddchnstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a)
        wmove "$win" 2 2
        waddchstr "$win" "ADDCHSTR"
        msg="waddchstr wrote ADDCHSTR"
        ;;
      n)
        wmove "$win" 2 2
        waddchnstr "$win" "ADDCHNSTR" 5
        msg="waddchnstr wrote ADDCH"
        ;;
      m)
        mvwaddchstr "$win" 3 2 "MVWADDCHSTR"
        msg="mvwaddchstr wrote MVWADDCHSTR"
        ;;
      b)
        mvwaddchnstr "$win" 4 2 "MVWADDCHNSTR" 7
        msg="mvwaddchnstr wrote MVWADDC"
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
