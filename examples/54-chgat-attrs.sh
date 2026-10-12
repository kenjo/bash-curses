# Port of the ncurses test chgat/attr_set demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "c chgat  w wchgat  m mvchgat  s attr_set  o attr_on  f attr_off  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        mvprintw 3 0 "ABCDEFGHIJ"
        chgat 5 "$A_BOLD" 0
        msg="chgat 5 A_BOLD"
        ;;
      w|W)
        mvprintw 4 0 "ABCDEFGHIJ"
        wchgat "$BC_STDSCR" 5 "$A_REVERSE" 0
        msg="wchgat 5 A_REVERSE"
        ;;
      m|M)
        mvprintw 5 0 "ABCDEFGHIJ"
        mvchgat 5 2 4 "$A_BOLD" 0
        msg="mvchgat y=5 x=2 n=4 A_BOLD"
        ;;
      s|S)
        attr_set "$A_BOLD" 0
        mvprintw 6 0 "attr_set bold"
        attr_set 0 0
        msg="attr_set A_BOLD"
        ;;
      o|O)
        attr_on "$A_BOLD"
        mvprintw 7 0 "attr_on bold"
        attr_off "$A_BOLD"
        msg="attr_on A_BOLD"
        ;;
      f|F)
        attr_off "$A_BOLD"
        mvprintw 8 0 "attr_off bold"
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
