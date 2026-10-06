# Port of references/howto-examples/07-input-functions/main.c — prompt for a
# string with getstr, then echo it back.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  local mesg="Enter a string: " str="" row col
  initscr || exit 1
  getmaxyx 0
  row=$BC_GMY
  col=$BC_GMX
  mvprintw $(( row / 2 )) $(( (col - ${#mesg}) / 2 )) "%s" "$mesg"
  refresh
  getstr
  str=$bc_str
  mvprintw $(( row - 2 )) 0 "You Entered: %s" "$str"
  refresh
  getch
  endwin
  exit 0
}

main "$@"
