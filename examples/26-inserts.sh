# Port of the ncurses test inserts demo: insch, insnstr, insstr, deleteln, insertln, insdelln.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 12 50 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 0 2 " inserts "
  mvwprintw "$win" 2 2 "abcdefghijklmnopqrstuvwxyz"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "i insch  n insnstr  s insstr  d deleteln  I insertln  D insdelln  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      i)
        wmove "$win" 2 5
        winsch "$win" 'X'
        msg="winsch inserted X at row 2 col 5"
        ;;
      n)
        wmove "$win" 2 5
        winsnstr "$win" 3 "123"
        msg="winsnstr inserted 123 at row 2 col 5"
        ;;
      s)
        wmove "$win" 2 5
        winsstr "$win" "STR"
        msg="winsstr inserted STR at row 2 col 5"
        ;;
      d)
        wmove "$win" 2 5
        wdeleteln "$win"
        msg="wdeleteln deleted row 2"
        ;;
      I)
        wmove "$win" 2 5
        winsertln "$win"
        msg="winsertln inserted a blank row at row 2"
        ;;
      D)
        wmove "$win" 2 5
        winsdelln "$win" -1
        msg="winsdelln -1 deleted row 2"
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
