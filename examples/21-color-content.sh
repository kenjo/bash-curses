# Port of the ncurses curs_color example: color_content, init_color, alloc_pair.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  if ! has_colors; then
    mvprintw 0 0 "This terminal reports no color support."
    mvprintw 2 0 "q quit"
    refresh
    while :; do
      wgetch || break
      [[ $key == q || $key == Q ]] && break
    done
    endwin
    exit 0
  fi

  start_color
  mvprintw 0 0 "COLORS=%d  COLOR_PAIRS=%d" "$COLORS" "$COLOR_PAIRS"
  mvprintw 1 0 "can_change_color=%s" "$(can_change_color && echo yes || echo no)"

  local c n=$COLORS
  (( n > 16 )) && n=16
  for (( c = 0; c < n; c++ )); do
    color_content "$c"
    mvwaddch "$BC_STDSCR" $(( 3 + c )) 0 '#' 0 "$c"
    mvprintw $(( 3 + c )) 2 "color %02d: r=%d g=%d b=%d" "$c" "$BC_CR" "$BC_CG" "$BC_CB"
    clrtoeol
  done

  if can_change_color; then
    init_color 1 1000 0 0
    color_content 1
    mvprintw $(( 3 + n )) 0 "after init_color 1: r=%d g=%d b=%d" "$BC_CR" "$BC_CG" "$BC_CB"
    clrtoeol
  fi

  alloc_pair "$COLOR_RED" "$COLOR_BLUE" >/dev/null
  local pair=$bc_pair
  if (( pair > 0 )); then
    wattrset "$BC_STDSCR" 0 "$pair"
    mvprintw $(( LINES - 3 )) 0 "alloc_pair red/blue returned pair %d" "$pair"
    wattrset "$BC_STDSCR" 0 0
    clrtoeol
    find_pair "$COLOR_RED" "$COLOR_BLUE" >/dev/null
    mvprintw $(( LINES - 2 )) 0 "find_pair red/blue returned pair %d" "$bc_pair"
    clrtoeol
    free_pair "$pair"
  fi

  mvprintw $(( LINES - 1 )) 0 "q quit"
  clrtoeol
  refresh

  while :; do
    wgetch || break
    [[ $key == q || $key == Q ]] && break
  done

  endwin
}

main "$@"
