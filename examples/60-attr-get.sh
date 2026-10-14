# Port of the ncurses test attr_get/standout demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "s standout  e standend  g attr_get  w wattr_get  a attr_set  o attr_on  f attr_off  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      s|S)
        standout
        mvprintw 2 0 "standout"
        msg="standout"
        ;;
      e|E)
        standend
        mvprintw 3 0 "standend"
        msg="standend"
        ;;
      g|G)
        attr_get
        msg="attr_get attrs=$BC_AG pair=$BC_AP"
        ;;
      w|W)
        wattr_get "$BC_STDSCR"
        msg="wattr_get attrs=$BC_AG pair=$BC_AP"
        ;;
      a|A)
        attr_set "$A_BOLD" 1
        mvprintw 4 0 "attr_set"
        attr_set 0 0
        msg="attr_set A_BOLD pair 1"
        ;;
      o|O)
        attr_on "$A_BOLD"
        mvprintw 5 0 "attr_on"
        attr_off "$A_BOLD"
        msg="attr_on A_BOLD"
        ;;
      f|F)
        attr_off "$A_BOLD"
        mvprintw 6 0 "attr_off"
        msg="attr_off A_BOLD"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
