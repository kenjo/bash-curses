# Port of the ncurses test clip_printw demo: printw clipping at window edges.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 8 20 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a wprintw long string  b mvwprintw long string  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        wmove "$win" 2 2
        wprintw "$win" "This is a very long string that should be clipped at the window edge"
        msg="wprintw wrote a long clipped string"
        ;;
      b|B)
        mvwprintw "$win" 4 2 "mvwprintw long string that should also be clipped at the window edge"
        msg="mvwprintw wrote a long clipped string"
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
