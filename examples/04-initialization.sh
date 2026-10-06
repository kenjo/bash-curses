# Port of references/howto-examples/04-initialization/main.c — raw + keypad +
# noecho; read one key, print F1 specially, otherwise the key in bold.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  local ch
  initscr || exit 1
  raw
  keypad 0 1
  noecho
  printw "Type any character to see it in bold\n"
  getch
  ch=$key
  if (( ch == KEY_F1 )); then
    printw "F1 Key pressed"
  else
    printw "The pressed key is "
    attron "$A_BOLD"
    printw "%c" "$ch"
    attroff "$A_BOLD"
  fi
  refresh
  getch
  endwin
  exit 0
}

main "$@"
