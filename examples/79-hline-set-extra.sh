# Port of the ncurses hline/vline set wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "h mvhline_set  v mvvline_set  m vline_set  n hline_set  w mvwhline_set  W mvwvline_set  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      h|H)
        mvhline_set 2 0 "x" 10
        msg="mvhline_set 2 0 x 10"
        ;;
      v|V)
        mvvline_set 3 0 "y" 5
        msg="mvvline_set 3 0 y 5"
        ;;
      m|M)
        vline_set "z" 5
        msg="vline_set z 5"
        ;;
      n|N)
        hline_set "w" 10
        msg="hline_set w 10"
        ;;
      w|W)
        mvwhline_set "$win" 2 0 "u" 10
        msg="mvwhline_set win 2 0 u 10"
        ;;
      1)
        mvwvline_set "$win" 3 0 "t" 5
        msg="mvwvline_set win 3 0 t 5"
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
