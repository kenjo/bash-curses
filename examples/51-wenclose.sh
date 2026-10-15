# Port of the ncurses test wenclose/mouse_trafo demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 8 20 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local y=5 x=10 msg="waiting"
  while :; do
    mvprintw 0 0 "u up  d down  l left  r right  t mouse_trafo  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 2 0 "screen coord: ($y,$x)"
    clrtoeol
    refresh
    touchwin "$win"; wrefresh "$win"

    wgetch || break
    case $key in
      u|U|k)
        y=$(( y - 1 ))
        ;;
      d|D|j)
        y=$(( y + 1 ))
        ;;
      l|L|h)
        x=$(( x - 1 ))
        ;;
      r|R)
        x=$(( x + 1 ))
        ;;
      t|T)
        if wenclose "$win" "$y" "$x"; then
          msg="wenclose inside"
        else
          msg="wenclose outside"
        fi
        if mouse_trafo "$y" "$x" 1; then
          msg="$msg mouse_trafo=($BC_MT_Y,$BC_MT_X)"
        else
          msg="$msg mouse_trafo failed"
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
