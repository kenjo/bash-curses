# Port of the ncurses test border/box_set/hline_set demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 30 2 2
  local win=$bc_win
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "b border  x box_set  m mvwborder  h mvwhline_set  v mvwvline_set  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      b|B)
        border '*' '#' '=' '-' '+' '+' '+' '+'
        msg="border on stdscr"
        ;;
      x|X)
        box_set "$win" '|' '-' '+' '+' '+' '+'
        msg="box_set on window"
        ;;
      m|M)
        mvwborder "$win" 1 1 '|' '-' '+' '+' '+' '+' '+' '+'
        msg="mvwborder at 1,1"
        ;;
      h|H)
        mvwhline_set "$win" 3 2 '=' 10
        msg="mvwhline_set at 3,2"
        ;;
      v|V)
        mvwvline_set "$win" 4 4 '|' 5
        msg="mvwvline_set at 4,4"
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
