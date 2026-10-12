# Port of the ncurses test echochar/ungetch demos: immediate output and pushback.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "e echochar  w wechochar  u ungetch  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      e|E)
        echochar 'X'
        msg="echochar wrote X"
        ;;
      w|W)
        wechochar "$BC_STDSCR" 'Y'
        msg="wechochar wrote Y"
        ;;
      u|U)
        ungetch 'Z'
        msg="ungetch pushed Z; next wgetch should read it"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
