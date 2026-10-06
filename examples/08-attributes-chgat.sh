# Port of references/howto-examples/08-attributes/chgat.c — apply A_BLINK and
# color pair 1 to an entire line with mvchgat (n=-1 means till end of line).

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  start_color
  init_pair 1 "$COLOR_CYAN" "$COLOR_BLACK"
  printw "A Big string which i didn't care to type fully "
  mvchgat 0 0 -1 "$A_BLINK" 1
  refresh
  getch
  endwin
  exit 0
}

main "$@"
