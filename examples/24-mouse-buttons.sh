# Port of the ncurses curs_mouse example: mousemask, getmouse, wmouse_trafo.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0
  mousemask "$ALL_MOUSE_EVENTS"

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 0 2 " Mouse target "
  mvwprintw "$win" 2 2 "Click inside or outside this box."
  wrefresh "$win"

  local inside wy wx
  while :; do
    mvprintw 0 0 "ALL_MOUSE_EVENTS enabled; q quit"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      "$KEY_MOUSE")
        while getmouse; do
          if wmouse_trafo "$win" "$BC_ME_Y" "$BC_ME_X" 0; then
            wy=$BC_MT_Y
            wx=$BC_MT_X
            inside=yes
          else
            wy=-1
            wx=-1
            inside=no
          fi
          mvprintw $(( LINES - 3 )) 0 "mouse id=%d screen=(%d,%d) win=(%d,%d) inside=%s" \
            "$BC_ME_ID" "$BC_ME_X" "$BC_ME_Y" "$wy" "$wx" "$inside"
          clrtoeol
          mvprintw $(( LINES - 2 )) 0 "bstate=%d" "$BC_ME_BSTATE"
          clrtoeol
        done
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
