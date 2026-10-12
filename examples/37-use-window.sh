# Port of the ncurses test use_window demos: use_window and sync helpers.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 8 30 2 2
  local win1=$bc_win
  box "$win1"
  mvwprintw "$win1" 0 2 " win1 "
  wrefresh "$win1"

  newwin 8 30 12 2
  local win2=$bc_win
  box "$win2"
  mvwprintw "$win2" 0 2 " win2 "
  wrefresh "$win2"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "1 use win1  2 use win2  s wsyncup  d wsyncdown  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 2 0 "current window: $BC_CURR"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      1)
        use_window "$win1"
        msg="use_window win1 previous=$bc_win"
        ;;
      2)
        use_window "$win2"
        msg="use_window win2 previous=$bc_win"
        ;;
      s|S)
        wsyncup "$BC_CURR"
        msg="wsyncup current window"
        ;;
      d|D)
        wsyncdown "$BC_CURR"
        msg="wsyncdown current window"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
