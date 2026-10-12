# Port of the ncurses test back_ground/background demos: wbkgd, wbkgdset, getbkgrnd.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  if has_colors; then
    start_color
    init_pair 1 "$COLOR_YELLOW" "$COLOR_BLUE"
    init_pair 2 "$COLOR_BLACK" "$COLOR_CYAN"
  fi

  local msg="waiting"
  while :; do
    mvprintw 0 0 "b wbkgd  s wbkgdset  g getbkgrnd  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 3 0 "Sample: abc def"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      b|B)
        if has_colors; then
          wbkgd "$BC_STDSCR" '#' 0 1
          msg="wbkgd set background to '#' pair 1"
        else
          wbkgd "$BC_STDSCR" '#' 0 0
          msg="wbkgd set background to '#'"
        fi
        ;;
      s|S)
        if has_colors; then
          wbkgdset "$BC_STDSCR" '+' 0 2
          msg="wbkgdset set background to '+' pair 2"
        else
          wbkgdset "$BC_STDSCR" '+' 0 0
          msg="wbkgdset set background to '+'"
        fi
        ;;
      g|G)
        getbkgrnd "$BC_STDSCR"
        msg="getbkgrnd: ch=$wch attr=$wcha pair=$wchp"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
