# Port of the ncurses test wresize/resize_term demos: window and terminal resizing.

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
  mvwprintw "$win" 0 2 " win "
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "+ grow window  - shrink window  r resize_term  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh
    touchwin "$win"; wrefresh "$win"

    wgetch || break
    case $key in
      +)
        wresize "$win" 12 30
        wrefresh "$win"
        msg="wresize 12x30"
        ;;
      -)
        wresize "$win" 6 15
        wrefresh "$win"
        msg="wresize 6x15"
        ;;
      r|R)
        resize_term $(( LINES - 1 )) $(( COLS - 1 ))
        msg="resize_term $(( LINES - 1 ))x$(( COLS - 1 ))"
        ;;
      q|Q)
        break
        ;;
    esac

    getmaxyx "$win"
    if is_term_resized "$LINES" "$COLS"; then
      mvprintw 2 0 "window max=($BC_GMY,$BC_GMX) is_term_resized=yes"
    else
      mvprintw 2 0 "window max=($BC_GMY,$BC_GMX) is_term_resized=no"
    fi
    clrtoeol
    refresh
    touchwin "$win"; wrefresh "$win"
  done

  endwin
}

main "$@"
