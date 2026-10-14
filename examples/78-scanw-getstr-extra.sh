# Port of the ncurses scanw/getstr wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  echo
  keypad 0 1
  curs_set 1

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting" val
  while :; do
    mvprintw 0 0 "s mvscanw  w mvwscanw  g wgetstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      s|S)
        val=0
        mvscanw 2 0 "%d" val
        msg="mvscanw val=$val count=$bc_scanw_count"
        ;;
      w|W)
        val=0
        mvwscanw "$win" 3 0 "%d" val
        msg="mvwscanw val=$val count=$bc_scanw_count"
        ;;
      g|G)
        wmove "$win" 4 0
        wgetstr "$win" 5
        msg="wgetstr bc_str=$bc_str"
        ;;
      q|Q)
        break
        ;;
    esac
    wrefresh "$win"
  done

  endwin
}

main "$@"
