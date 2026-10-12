# Port of the ncurses curs_scr_dump example: dump, restore, and set the screen.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

REPO="${BASH_SOURCE[0]%/*}/.."
SCR_FILE="$REPO/tmp/bc_screen.dump"

draw_a() {
  clear
  wattrset "$BC_STDSCR" "$A_BOLD" 0
  mvprintw 2 2 "Screen A: this state was dumped to SCR_FILE."
  wattrset "$BC_STDSCR" 0 0
  mvprintw 4 2 "Press d to dump, r to restore, s to set, q to quit."
}

draw_b() {
  clear
  wattrset "$BC_STDSCR" "$A_REVERSE" 0
  mvprintw 6 6 "Screen B: a different screen state."
  wattrset "$BC_STDSCR" 0 0
  mvprintw 8 2 "Press d to dump, r to restore, s to set, q to quit."
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0
  mkdir -p "$REPO/tmp"
  scr_init

  draw_a
  refresh

  local status="ready"
  while :; do
    mvprintw $(( LINES - 1 )) 0 "SCR_FILE=%s  %s" "$SCR_FILE" "$status"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      d)
        if scr_dump; then
          status="dumped current screen"
        else
          status="dump failed"
        fi
        ;;
      r)
        if scr_restore; then
          status="restored SCR_FILE"
        else
          status="restore failed"
        fi
        ;;
      s)
        if scr_set; then
          status="set SCR_FILE"
        else
          status="set failed"
        fi
        ;;
      b)
        draw_b
        status="drew screen B"
        ;;
      a)
        draw_a
        status="drew screen A"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
