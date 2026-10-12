# Port of the ncurses test touchline/wtouchln demos: line touch queries.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

flag() {
  if "$@"; then
    printf yes
  else
    printf no
  fi
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "t touchwin  u untouchwin  l touchline  w wtouchln  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 2 0 "is_wintouched=%s line2=%s line3=%s line5=%s" \
      "$(flag is_wintouched "$win")" \
      "$(flag is_linetouched "$win" 2)" \
      "$(flag is_linetouched "$win" 3)" \
      "$(flag is_linetouched "$win" 5)"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      t|T)
        touchwin "$win"
        msg="touchwin"
        ;;
      u|U)
        untouchwin "$win"
        msg="untouchwin"
        ;;
      l|L)
        touchline "$win" 3 4
        msg="touchline start=3 count=4"
        ;;
      w|W)
        wtouchln "$win" 5 3 1
        msg="wtouchln y=5 count=3 changed=1"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
