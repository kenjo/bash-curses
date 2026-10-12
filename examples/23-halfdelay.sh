# Port of the ncurses curs_input example: halfdelay timed input.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0
  halfdelay 5

  local timeouts=0 msg="waiting"
  while :; do
    mvprintw 0 0 "halfdelay 5 (0.5s); timeouts=%d; q quits" "$timeouts"
    clrtoeol
    mvprintw 2 0 "%s" "$msg"
    clrtoeol
    refresh

    if wgetch; then
      case $key in
        q|Q)
          break
          ;;
        *)
          msg="got key: $key"
          ;;
      esac
    else
      timeouts=$(( timeouts + 1 ))
      msg="wgetch returned ERR after halfdelay"
      (( timeouts >= 5 )) && break
    fi
  done

  endwin
}

main "$@"
