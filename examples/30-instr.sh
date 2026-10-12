# Port of the ncurses test test_instr demo: instr, innstr, mvwinstr, mvwinnstr.

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
  mvwprintw "$win" 2 2 "ABCDEFGHIJ"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "i instr  n innstr  m mvwinstr  b mvwinnstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      i)
        wmove "$win" 2 2
        instr "$win"
        msg="instr: $bc_str"
        ;;
      n)
        wmove "$win" 2 2
        innstr "$win" 5
        msg="innstr: $bc_str"
        ;;
      m)
        mvwinstr "$win" 2 2
        msg="mvwinstr: $bc_str"
        ;;
      b)
        mvwinnstr "$win" 2 2 5
        msg="mvwinnstr: $bc_str"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
