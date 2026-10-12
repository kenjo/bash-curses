# Port of the ncurses curs_input example: wgetnstr and wscanw.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local name="" age=0 rc
  while :; do
    mvprintw 0 0 "s scanw  g getnstr  q quit"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      s|S)
        mvprintw 2 0 "Enter name and age: "
        clrtoeol
        wscanw "$BC_STDSCR" "%s %d" name age
        rc=$?
        mvprintw 4 0 "scanw returned %d, count=%d" "$rc" "$bc_scanw_count"
        clrtoeol
        if (( rc > 0 )); then
          mvprintw 5 0 "name=%s age=%d" "$name" "$age"
        else
          mvprintw 5 0 "no conversions were performed"
        fi
        clrtoeol
        ;;
      g|G)
        mvprintw 2 0 "Enter text (max 20 chars): "
        clrtoeol
        if wgetnstr "$BC_STDSCR" 20; then
          mvprintw 4 0 "getnstr got: %s" "$bc_str"
        else
          mvprintw 4 0 "getnstr failed"
        fi
        clrtoeol
        ;;
      q|Q)
        break
        ;;
    esac
    clrtoeol
    refresh
  done

  endwin
}

main "$@"
