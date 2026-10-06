# Port of references/howto-examples/14-misc/leave-ncurses.c — print a line,
# leave curses mode to run a shell in cooked mode, then return to curses.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  printw "Hello World !!!\n"
  refresh
  def_prog_mode
  endwin
  /bin/sh
  reset_prog_mode
  refresh
  printw "Another String\n"
  refresh
  endwin
  exit 0
}

main "$@"
