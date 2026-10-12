# Port of the ncurses test dupwin demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 8 30 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 0 2 " orig "
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "d dupwin  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      d|D)
        dupwin "$win"
        local dup=$bc_win
        mvwprintw "$dup" 1 2 " dup "
        wrefresh "$dup"
        msg="dupwin -> $dup"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
