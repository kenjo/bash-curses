# Port of the ncurses test string wrapper demos.

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
  mvwprintw "$win" 1 0 "window"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a addstr  n addnstr  m mvaddstr  b mvaddnstr  w waddnstr  c waddch  s waddstr  i winsn  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh
    touchwin "$win"
    wrefresh "$win"

    wgetch || break
    case $key in
      a|A)
        addstr "addstr"
        msg="addstr"
        ;;
      n|N)
        addnstr "addnstr" 6
        msg="addnstr 6"
        ;;
      m|M)
        mvaddstr 3 0 "mvaddstr"
        msg="mvaddstr"
        ;;
      b|B)
        mvaddnstr 4 0 "mvaddnstr" 6
        msg="mvaddnstr 6"
        ;;
      w|W)
        waddnstr "$win" "waddnstr" 6
        msg="waddnstr 6"
        ;;
      c|C)
        waddch "$win" X
        msg="waddch X"
        ;;
      s|S)
        waddstr "$win" "waddstr"
        msg="waddstr"
        ;;
      i|I)
        winsn "$win" 5 0 4 "ins"
        msg="winsn ins 4"
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
