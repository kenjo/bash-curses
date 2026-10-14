# Port of the ncurses test scrl/setscrreg/resizestdscr/mvcur demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  scrollok "$BC_STDSCR" 1
  setscrreg 2 8

  local msg="waiting"
  while :; do
    mvprintw 0 0 "u scrl up  d scrl down  s setscrreg  r resizestdscr  c mvcur  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      u|U)
        scrl -1
        msg="scrl -1"
        ;;
      d|D)
        scrl 1
        msg="scrl 1"
        ;;
      s|S)
        if setscrreg 3 9; then
          msg="setscrreg 3 9"
        else
          msg="setscrreg failed"
        fi
        ;;
      r|R)
        if resizestdscr "$LINES" "$COLS"; then
          msg="resizestdscr ${LINES}x${COLS}"
        else
          msg="resizestdscr failed"
        fi
        ;;
      c|C)
        mvcur 1 0
        msg="mvcur 1 0"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
