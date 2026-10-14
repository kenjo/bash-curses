# Port of the ncurses copywin/clrtobot/insert-string wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 40 2 2
  local src=$bc_win
  newwin 10 40 14 2
  local dst=$bc_win
  box "$src"
  box "$dst"
  mvwprintw "$src" 2 0 "source"
  mvwprintw "$src" 3 0 "data"
  mvwprintw "$dst" 2 0 "target"
  mvwprintw "$dst" 3 0 "base"
  wrefresh "$src"
  wrefresh "$dst"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "c copywin  o copywin overlay  C overwrite  l clrtobot  i mvwinsnstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        copywin "$src" "$dst" 2 0 2 0 5 10 0
        msg="copywin overwrite"
        ;;
      1)
        copywin "$src" "$dst" 2 0 2 0 5 10 1
        msg="copywin overlay"
        ;;
      2)
        overwrite "$src" "$dst"
        msg="overwrite"
        ;;
      l|L)
        clrtobot
        msg="clrtobot"
        ;;
      i|I)
        mvwinsnstr "$dst" 4 0 3 "ins"
        msg="mvwinsnstr dst 4 0 3 ins"
        ;;
      q|Q)
        break
        ;;
    esac
    wrefresh "$dst"
  done

  endwin
}

main "$@"
