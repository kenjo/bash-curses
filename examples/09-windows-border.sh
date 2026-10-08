# Port of references/howto-examples/09-windows/border.c — a '+'/'-'/'|' box
# drawn directly on stdscr with mvaddch/mvhline/mvvline; arrow keys move it,
# F1 exits. Only the "Press F1 to exit" line is cyan (COLOR_PAIR 1); the box
# itself is drawn after attroff, in default color.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

startx="" starty="" width="" height=""
ls="" rs="" ts="" bs="" tl="" tr="" bl="" br=""

init_win_params() {
  height=3
  width=10
  starty=$(( (LINES - height) / 2 ))
  startx=$(( (COLS - width) / 2 ))
  ls='|' rs='|' ts='-' bs='-' tl='+' tr='+' bl='+' br='+'
}

print_win_params() { :; }   # only prints under _DEBUG

create_box() { # flag (1=draw, 0=erase)
  local y=$starty x=$startx w=$width h=$height i j
  if (( $1 )); then
    mvaddch "$y" "$x" "$tl"
    mvaddch "$y" $(( x + w )) "$tr"
    mvaddch $(( y + h )) "$x" "$bl"
    mvaddch $(( y + h )) $(( x + w )) "$br"
    mvhline "$y" $(( x + 1 )) "$ts" $(( w - 1 ))
    mvhline $(( y + h )) $(( x + 1 )) "$bs" $(( w - 1 ))
    mvvline $(( y + 1 )) "$x" "$ls" $(( h - 1 ))
    mvvline $(( y + 1 )) $(( x + w )) "$rs" $(( h - 1 ))
  else
    for (( j = y; j <= y + h; j++ )); do
      for (( i = x; i <= x + w; i++ )); do
        mvaddch "$j" "$i" " "
      done
    done
  fi
  refresh
}

main() {
  initscr || exit 1
  start_color
  cbreak
  keypad 0 1
  noecho
  init_pair 1 "$COLOR_CYAN" "$COLOR_BLACK"
  init_win_params
  print_win_params
  attrset 0 1
  printw "Press F1 to exit"
  refresh
  attrset 0 0
  create_box 1
  while :; do
    getch
    [[ $key == "$KEY_F1" ]] && break
    case $key in
      "$KEY_LEFT")  create_box 0; startx=$(( startx - 1 )); create_box 1 ;;
      "$KEY_RIGHT") create_box 0; startx=$(( startx + 1 )); create_box 1 ;;
      "$KEY_UP")    create_box 0; starty=$(( starty - 1 )); create_box 1 ;;
      "$KEY_DOWN")  create_box 0; starty=$(( starty + 1 )); create_box 1 ;;
    esac
  done
  endwin
  exit 0
}

main "$@"
