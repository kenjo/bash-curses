# Port of the ncurses test stdscr add wrapper demos.

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
    mvprintw 0 0 "a addch  A mvaddch  m mvwaddch  M waddch  n addchstr  N addchnstr  r mvaddchstr  s mvaddchnstr  t mvwaddchstr  u mvwaddchnstr  v addnstr  w addstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        addch X
        msg="addch X"
        ;;
      1)
        mvaddch 3 0 Y
        msg="mvaddch 3 0 Y"
        ;;
      m|M)
        mvwaddch "$win" 3 0 Z
        msg="mvwaddch win 3 0 Z"
        ;;
      2)
        waddch "$win" Q
        msg="waddch win Q"
        ;;
      n|N)
        addchstr "addchstr"
        msg="addchstr"
        ;;
      3)
        addchnstr "addchnstr" 6
        msg="addchnstr 6"
        ;;
      r|R)
        mvaddchstr 4 0 "mvaddchstr"
        msg="mvaddchstr 4 0"
        ;;
      s|S)
        mvaddchnstr 5 0 "mvaddchnstr" 6
        msg="mvaddchnstr 5 0 6"
        ;;
      t|T)
        mvwaddchstr "$win" 4 0 "mvwaddchstr"
        msg="mvwaddchstr win 4 0"
        ;;
      u|U)
        mvwaddchnstr "$win" 5 0 "mvwaddchnstr" 6
        msg="mvwaddchnstr win 5 0 6"
        ;;
      v|V)
        addnstr "addnstr" 6
        msg="addnstr 6"
        ;;
      w|W)
        addstr "addstr"
        msg="addstr"
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
