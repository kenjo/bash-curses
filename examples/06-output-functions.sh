# Port of references/howto-examples/06-output-functions/main.c — centre a
# message, then report the screen size.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  local mesg="Just a string" row col
  initscr || exit 1
  getmaxyx 0
  row=$BC_GMY
  col=$BC_GMX
  mvprintw $(( row / 2 )) $(( (col - ${#mesg}) / 2 )) "%s" "$mesg"
  mvprintw $(( row - 2 )) 0 "This screen has %d rows and %d columns\n" "$row" "$col"
  printw "Try resizing your window(if possible) and then run this program again"
  refresh
  getch
  endwin
  exit 0
}

main "$@"
