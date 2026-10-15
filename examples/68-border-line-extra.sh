# Port of the ncurses test border/line wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 40 2 2
  local win=$bc_win
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "b wborder  B wborder_set  m mvborder  h whline  v wvline  H hline  V vline  M mvwvline  s whline_set  t wvline_set  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh
    touchwin "$win"
    wrefresh "$win"

    wgetch || break
    case $key in
      b|B)
        wborder "$win"
        msg="wborder"
        ;;
      1)
        wborder_set "$win"
        msg="wborder_set"
        ;;
      m|M)
        mvborder 14 0
        msg="mvborder 14 0"
        ;;
      h|H)
        mvwhline "$win" 2 0 '-' 10
        whline "$win" '-' 5
        msg="whline"
        ;;
      v|V)
        mvwvline "$win" 2 12 '|' 5
        wvline "$win" '|' 3
        msg="wvline"
        ;;
      2)
        mvhline 15 0 '-' 10
        hline '-' 5
        msg="hline"
        ;;
      3)
        mvvline 15 12 '|' 5
        vline '|' 3
        msg="vline"
        ;;
      4)
        mvwvline "$win" 3 14 '|' 4
        msg="mvwvline"
        ;;
      s|S)
        whline_set "$win" "-" 5
        msg="whline_set"
        ;;
      t|T)
        wvline_set "$win" "|" 3
        msg="wvline_set"
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
