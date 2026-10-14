# Port of the ncurses test mouse interval/ungetmouse demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local oldmask=0
  mousemask "$ALL_MOUSE_EVENTS" oldmask
  mouseinterval 200

  local msg="waiting"
  while :; do
    mvprintw 0 0 "i mouseinterval  h has_mouse  u ungetmouse  s mouse_set  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 2 0 "mouse mask=$BC_MOUSE_MASK interval=$BC_MAXCLICK"
    clrtoeol
    refresh

    wgetch || break
    if (( key == KEY_MOUSE )); then
      while getmouse; do
        msg="mouse x=$BC_ME_X y=$BC_ME_Y bstate=$BC_ME_BSTATE"
      done
    fi
    case $key in
      i|I)
        mouseinterval 100
        msg="mouseinterval 100 old=$BC_OLD_MAXCLICK"
        ;;
      h|H)
        if has_mouse; then
          msg="has_mouse yes"
        else
          msg="has_mouse no"
        fi
        ;;
      u|U)
        BC_ME_X=5
        BC_ME_Y=6
        BC_ME_BSTATE=$BUTTON1_PRESSED
        ungetmouse
        msg="ungetmouse queued"
        ;;
      s|S)
        mouse_set "$ALL_MOUSE_EVENTS"
        msg="mouse_set ALL_MOUSE_EVENTS"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
