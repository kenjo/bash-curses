# Port of the ncurses test clear/refresh/mode demos.

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
  mvwprintw "$win" 1 0 "clear/refresh"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "c wclear  t wclrtobot  e wclrtoeol  n wnoutrefresh  d doupdate  s syncup  u syncdown  o notimeout  r raw/noraw  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        wclear "$win"
        msg="wclear"
        ;;
      t|T)
        mvwprintw "$win" 2 0 "bottom"
        wclrtobot "$win"
        msg="wclrtobot"
        ;;
      e|E)
        mvwprintw "$win" 3 0 "eol"
        wclrtoeol "$win"
        msg="wclrtoeol"
        ;;
      n|N)
        wnoutrefresh "$win"
        doupdate
        msg="wnoutrefresh+doupdate"
        ;;
      d|D)
        doupdate
        msg="doupdate"
        ;;
      s|S)
        syncup
        msg="syncup"
        ;;
      u|U)
        syncdown
        msg="syncdown"
        ;;
      o|O)
        notimeout "$win" 1
        msg="notimeout"
        ;;
      r|R)
        raw
        noraw
        msg="raw/noraw"
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
