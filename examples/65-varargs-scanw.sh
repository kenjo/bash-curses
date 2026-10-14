# Port of the ncurses test varargs print/scan wrappers.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  echo
  keypad 0 1
  curs_set 1

  local msg="waiting"
  local n=0
  while :; do
    mvprintw 0 0 "p wprintw  v vwprintw  V vw_printw  s wscanw  w vwscanw  W vw_scanw  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      p|P)
        wprintw "$BC_STDSCR" " wprintw %d" 1
        msg="wprintw"
        ;;
      v|V)
        vwprintw "$BC_STDSCR" " vwprintw %d" 2
        msg="vwprintw"
        ;;
      1)
        vw_printw "$BC_STDSCR" " vw_printw %d" 3
        msg="vw_printw"
        ;;
      s|S)
        mvprintw 3 0 "wscanw: "
        clrtoeol
        if wscanw "$BC_STDSCR" "%d" n; then
          msg="wscanw n=$n"
        else
          msg="wscanw failed"
        fi
        ;;
      w|W)
        mvprintw 4 0 "vwscanw: "
        clrtoeol
        if vwscanw "$BC_STDSCR" "%d" n; then
          msg="vwscanw n=$n"
        else
          msg="vwscanw failed"
        fi
        ;;
      2)
        mvprintw 5 0 "vw_scanw: "
        clrtoeol
        if vw_scanw "$BC_STDSCR" "%d" n; then
          msg="vw_scanw n=$n"
        else
          msg="vw_scanw failed"
        fi
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
