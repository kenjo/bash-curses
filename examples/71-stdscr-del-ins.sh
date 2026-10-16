# Port of the ncurses test stdscr delete/insert wrapper demos.

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
  mvwprintw "$win" 2 0 "delete"
  mvwprintw "$win" 3 0 "insert"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "d delch  D mvdelch  w mvwdelch  W wdelch  i insch  I mvinsch  m mvwinsch  M winsch  s insstr  S mvinsstr  n mvwinsstr  N mvinsnstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      d|D)
        delch
        msg="delch"
        ;;
      1)
        mvdelch 2 0
        msg="mvdelch 2 0"
        ;;
      w|W)
        mvwdelch "$win" 2 0
        msg="mvwdelch win 2 0"
        ;;
      2)
        wdelch "$win"
        msg="wdelch win"
        ;;
      i|I)
        insch X
        msg="insch X"
        ;;
      3)
        mvinsch 3 0 Y
        msg="mvinsch 3 0 Y"
        ;;
      m|M)
        mvwinsch "$win" 3 0 Z
        msg="mvwinsch win 3 0 Z"
        ;;
      4)
        winsch "$win" Q
        msg="winsch win Q"
        ;;
      s|S)
        insstr "ins"
        msg="insstr ins"
        ;;
      5)
        mvinsstr 4 0 "ins"
        msg="mvinsstr 4 0 ins"
        ;;
      n|N)
        mvwinsstr "$win" 4 0 "ins"
        msg="mvwinsstr win 4 0 ins"
        ;;
      6)
        mvwinsnstr "$win" 5 0 3 "ins"
        msg="mvinsnstr win 5 0 3 ins"
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
