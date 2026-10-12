# Port of the ncurses test demo_defkey/demo_keyok demos: key definitions.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "d define_key  k key_defined  b keybound  o keyok  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      d|D)
        define_key $'\E[99~' 400
        msg="define_key \\E[99~ -> 400"
        ;;
      k|K)
        key_defined $'\E[99~'
        msg="key_defined \\E[99~ -> $bc_key"
        ;;
      b|B)
        keybound $'\E[99~' 0
        msg="keybound \\E[99~ -> $bc_key"
        ;;
      o|O)
        keyok 400 0
        msg="keyok 400 disabled previous=$bc_key"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
