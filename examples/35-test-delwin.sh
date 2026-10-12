# Port of the ncurses test test_delwin demo: delwin and window cleanup.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local win="" msg="no window"
  while :; do
    mvprintw 0 0 "c create window  d delwin  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        if [[ -z ${BC_WY[$win]:-} ]]; then
          newwin 8 30 2 2
          win=$bc_win
          box "$win"
          mvwprintw "$win" 0 2 " win "
          wrefresh "$win"
          msg="created window $win"
        else
          msg="window $win already exists"
        fi
        ;;
      d|D)
        if [[ -n ${BC_WY[$win]:-} ]]; then
          delwin "$win"
          msg="deleted window $win"
        else
          msg="no window to delete"
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
