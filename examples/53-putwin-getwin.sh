# Port of the ncurses test putwin/getwin demos.

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
  mvwprintw "$win" 0 2 " win "
  wrefresh "$win"

  local file="tmp/bc_example_putwin.win"
  local msg="waiting"
  while :; do
    mvprintw 0 0 "s putwin  l getwin  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      s|S)
        if putwin "$win" "$file"; then
          msg="putwin saved $file"
        else
          msg="putwin failed"
        fi
        ;;
      l|L)
        if getwin "$file"; then
          local loaded=$bc_win
          wrefresh "$loaded"
          msg="getwin loaded -> $loaded"
        else
          msg="getwin failed"
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
