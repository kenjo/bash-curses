# Port of the ncurses test movewindow/subwin demos: subwin, getpary, getparx, wgetparent.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 12 40 2 2
  local parent=$bc_win
  box "$parent"
  mvwprintw "$parent" 0 2 " parent "
  wrefresh "$parent"

  subwin "$parent" 6 20 5 5
  local child=$bc_win
  box "$child"
  mvwprintw "$child" 0 2 " child "
  wrefresh "$child"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "p parent info  c child info  m mvderwin  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      p|P)
        getbegyx "$parent"
        getmaxyx "$parent"
        msg="parent beg=($BC_GBY,$BC_GBX) max=($BC_GMY,$BC_GMX)"
        ;;
      c|C)
        getpary "$child"
        getparx "$child"
        wgetparent "$child"
        if is_subwin "$child"; then
          msg="child parent=$bc_parent beg=($BC_GPY,$BC_GPX) is_subwin=yes"
        else
          msg="child parent=$bc_parent beg=($BC_GPY,$BC_GPX) is_subwin=no"
        fi
        ;;
      m|M)
        mvderwin "$child" 3 3
        wrefresh "$parent"
        wrefresh "$child"
        msg="mvderwin child to parent-relative (3,3)"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
