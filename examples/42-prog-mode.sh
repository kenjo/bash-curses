# Port of the ncurses test def_prog_mode/reset_prog_mode demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "d def_prog_mode  r reset_prog_mode  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      d|D)
        def_prog_mode
        msg="def_prog_mode saved current mode"
        ;;
      r|R)
        reset_prog_mode
        msg="reset_prog_mode requested full redraw"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
