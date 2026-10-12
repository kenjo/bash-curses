# Port of the ncurses test vidattr/vidputs demos: low-level attribute output.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a vidattr bold  p vidputs  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        vidattr "$A_BOLD"
        mvprintw 2 0 "bold text from vidattr"
        vidattr "$A_NORMAL"
        msg="vidattr A_BOLD then A_NORMAL"
        ;;
      p|P)
        vidputs "plain" "$A_BOLD" 0
        mvprintw 3 0 "after vidputs"
        msg="vidputs plain with A_BOLD"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
