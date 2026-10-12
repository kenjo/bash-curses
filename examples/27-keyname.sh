# Port of the ncurses curs_util example: keyname, has_key, key_defined.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local name hk
  while :; do
    mvprintw 0 0 "Press keys to see keyname(); q quits"
    clrtoeol
    mvprintw 2 0 "Try arrows, function keys, letters, and control keys."
    clrtoeol
    refresh

    wgetch || break
    [[ $key == q || $key == Q ]] && break

    name=$(keyname "$key")
    if has_key "$key"; then
      hk=yes
    else
      hk=no
    fi

    mvprintw 4 0 "key=%s" "$key"
    clrtoeol
    mvprintw 5 0 "keyname=%s" "$name"
    clrtoeol
    mvprintw 6 0 "has_key=%s" "$hk"
    clrtoeol
    refresh
  done

  endwin
}

main "$@"
