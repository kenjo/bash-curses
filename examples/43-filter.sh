# Port of the ncurses test filter/nofilter demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "f filter  n nofilter  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 2 0 "BC_FILTER=${BC_FILTER:-0} LINES=$LINES COLS=$COLS"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      f|F)
        filter
        msg="filter set"
        ;;
      n|N)
        nofilter
        msg="nofilter set"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
