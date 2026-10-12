# Port of the ncurses test movewindow demo: mvwin and mvderwin.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 30 2 2
  local parent=$bc_win
  box "$parent"
  mvwprintw "$parent" 0 2 " parent "
  wrefresh "$parent"

  subwin "$parent" 5 15 4 4
  local child=$bc_win
  box "$child"
  mvwprintw "$child" 0 2 " child "
  wrefresh "$child"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "p mvwin parent  c mvderwin child  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      p|P)
        mvwin "$parent" 5 5
        wrefresh "$parent"
        wrefresh "$child"
        msg="mvwin parent to (5,5)"
        ;;
      c|C)
        mvderwin "$child" 2 2
        wrefresh "$parent"
        wrefresh "$child"
        msg="mvderwin child to parent-relative (2,2)"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
