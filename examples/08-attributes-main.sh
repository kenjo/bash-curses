# Port of references/howto-examples/08-attributes/main.c — a character pager
# that highlights /* ... */ regions in bold.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  if (( $# != 1 )); then
    printf "Usage: %s <a c file name>\n" "$0"
    exit 1
  fi
  local file=$1
  if [[ ! -r $file ]]; then
    printf "Cannot open input file\n" >&2
    exit 1
  fi
  initscr || exit 1
  getmaxyx 0
  local row=$BC_GMY col=$BC_GMX
  local prev="" ch y x
  exec 3< "$file"
  while IFS= read -r -n1 ch <&3; do
    [[ -z $ch ]] && ch=$'\n'
    getyx 0
    y=$BC_GCY
    x=$BC_GCX
    if (( y == row - 1 )); then
      printw "<-Press Any Key->"
      getch
      clear
      move 0 0
    fi
    if [[ $prev == '/' && $ch == '*' ]]; then
      attron "$A_BOLD"
      getyx 0
      y=$BC_GCY
      x=$BC_GCX
      move "$y" $(( x - 1 ))
      printw "%c%c" "/" "$ch"
    else
      printw "%c" "$ch"
    fi
    refresh
    if [[ $prev == '*' && $ch == '/' ]]; then
      attroff "$A_BOLD"
    fi
    prev=$ch
  done
  exec 3>&-
  endwin
  exit 0
}

main "$@"
