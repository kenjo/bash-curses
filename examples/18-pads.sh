# Port of the ncurses curs_pad example: create a pad and scroll a viewport.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

PAD_H=40
PAD_W=100

fill_pad() { # pad
  local pad=$1 y x
  for (( y = 0; y < PAD_H; y++ )); do
    mvwprintw "$pad" "$y" 0 "pad row %02d:" "$y"
    for (( x = 0; x < 20; x++ )); do
      wprintw "$pad" " [%02d]" "$x"
    done
  done
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newpad "$PAD_H" "$PAD_W"
  local pad=$bc_win
  fill_pad "$pad"

  local top=0 left=0
  local maxtop=$(( PAD_H - LINES ))
  local maxleft=$(( PAD_W - COLS ))
  (( maxtop < 0 )) && maxtop=0
  (( maxleft < 0 )) && maxleft=0

  while :; do
    prefresh "$pad" "$top" "$left" 0 0 $(( LINES - 1 )) $(( COLS - 1 ))
    mvprintw $(( LINES - 1 )) 0 "top=%d left=%d  arrows scroll, q quit" "$top" "$left"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      "$KEY_UP")
        (( top > 0 )) && top=$(( top - 1 ))
        ;;
      "$KEY_DOWN")
        (( top < maxtop )) && top=$(( top + 1 ))
        ;;
      "$KEY_LEFT")
        (( left > 0 )) && left=$(( left - 1 ))
        ;;
      "$KEY_RIGHT")
        (( left < maxleft )) && left=$(( left + 1 ))
        ;;
      "$KEY_PPAGE")
        top=$(( top - 5 ))
        (( top < 0 )) && top=0
        ;;
      "$KEY_NPAGE")
        top=$(( top + 5 ))
        (( top > maxtop )) && top=$maxtop
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
