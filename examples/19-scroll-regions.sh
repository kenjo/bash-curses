# Port of the ncurses curs_scroll example: wsetscrreg and wscrl.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  curs_set 0

  newwin 15 60 2 5
  local win=$bc_win
  keypad "$win" 1
  scrollok "$win" 1
  wsetscrreg "$win" 1 13

  box "$win"
  mvwprintw "$win" 0 2 " Scroll region: rows 1-13 "
  mvwprintw "$win" 14 2 " arrows scroll, PgUp/PgDn jump, q quit "

  local i
  for (( i = 1; i <= 13; i++ )); do
    mvwprintw "$win" "$i" 2 "line %02d inside the scrolling region" "$i"
  done
  wrefresh "$win"

  local status="ready"
  while :; do
    mvprintw 0 0 "wsetscrreg 1 13; wscrl: %s" "$status"
    clrtoeol
    refresh

    wgetch "$win" || break
    case $key in
      "$KEY_DOWN")
        wscrl "$win" 1
        status="down 1"
        ;;
      "$KEY_UP")
        wscrl "$win" -1
        status="up 1"
        ;;
      "$KEY_NPAGE")
        wscrl "$win" 5
        status="down 5"
        ;;
      "$KEY_PPAGE")
        wscrl "$win" -5
        status="up 5"
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
