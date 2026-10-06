# Port of references/howto-examples/10-colors/main.c — print a centered red
# string; exits if the terminal has no color.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

print_in_middle() { # win starty startx width string
  local win=${1:-0} starty=$2 startx=$3 width=$4 string=$5
  local y x
  getyx "$win"
  y=$BC_GCY
  x=$BC_GCX
  (( startx != 0 )) && x=$startx
  (( starty != 0 )) && y=$starty
  (( width == 0 )) && width=80
  local length=${#string}
  local temp=$(( (width - length) / 2 ))
  x=$(( startx + temp ))
  mvwprintw "$win" "$y" "$x" "%s" "$string"
  refresh
}

main() {
  initscr || exit 1
  if ! has_colors; then
    endwin
    printf "Your terminal does not support color\n"
    exit 1
  fi
  start_color
  init_pair 1 "$COLOR_RED" "$COLOR_BLACK"
  attrset 0 1
  print_in_middle 0 $(( LINES / 2 )) 0 0 "Viola !!! In color ..."
  attrset 0 0
  getch
  endwin
  exit 0
}

main "$@"
