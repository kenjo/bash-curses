# Port of the ncurses test stdscr inch/in wrapper demos.

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
  mvprintw 2 0 "xyz"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "i inch  I winch  m mvwinch  n inchnstr  N mvwinchnstr  r mvwinchstr  s instr  t innstr  T mvwinnstr  u mvwinstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      i|I)
        inch
        msg="inch wch=$wch"
        ;;
      1)
        winch "$win"
        msg="winch wch=$wch"
        ;;
      m|M)
        mvwinch "$win" 2 0
        msg="mvwinch win 2 0 wch=$wch"
        ;;
      n|N)
        inchnstr 3
        msg="inchnstr bc_str=$bc_str"
        ;;
      2)
        mvwinchnstr "$win" 2 0 3
        msg="mvwinchnstr win 2 0 3 bc_str=$bc_str"
        ;;
      r|R)
        mvwinchstr "$win" 2 0
        msg="mvwinchstr win 2 0 bc_str=$bc_str"
        ;;
      s|S)
        instr "$BC_STDSCR" 3
        msg="instr stdscr 3 bc_str=$bc_str"
        ;;
      t|T)
        innstr "$BC_STDSCR" 3
        msg="innstr stdscr 3 bc_str=$bc_str"
        ;;
      3)
        mvwinnstr "$win" 2 0 3
        msg="mvwinnstr win 2 0 3 bc_str=$bc_str"
        ;;
      u|U)
        mvwinstr "$win" 2 0
        msg="mvwinstr win 2 0 bc_str=$bc_str"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
