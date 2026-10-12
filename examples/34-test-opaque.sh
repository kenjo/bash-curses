# Port of the ncurses test test_opaque demo: window flags and opaque queries.

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

  newwin 12 60 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "c clearok  i idcok  l idlok  m immedok  v leaveok  s syncok  n nodelay  t timeout  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol

    mvprintw 3 0 "is_cleared=%s is_idcok=%s is_idlok=%s is_immedok=%s" \
      "$(flag is_cleared "$win")" "$(flag is_idcok "$win")" \
      "$(flag is_idlok "$win")" "$(flag is_immedok "$win")"
    clrtoeol
    mvprintw 4 0 "is_leaveok=%s is_syncok=%s is_scrollok=%s" \
      "$(flag is_leaveok "$win")" "$(flag is_syncok "$win")" "$(flag is_scrollok "$win")"
    clrtoeol
    mvprintw 5 0 "is_nodelay=%s is_notimeout=%s" \
      "$(flag is_nodelay "$win")" "$(flag is_notimeout "$win")"
    clrtoeol

    wgetdelay "$win"
    wgetscrreg "$win"
    mvprintw 6 0 "delay=%d scrreg=%d,%d" "$bc_delay" "$bc_top" "$bc_bottom"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C) clearok "$win" 1; msg="clearok on" ;;
      i|I) idcok "$win" 1; msg="idcok on" ;;
      l|L) idlok "$win" 1; msg="idlok on" ;;
      m|M) immedok "$win" 1; msg="immedok on" ;;
      v|V) leaveok "$win" 1; msg="leaveok on" ;;
      s|S) syncok "$win" 1; msg="syncok on" ;;
      n|N) nodelay "$win" 1; msg="nodelay on" ;;
      t|T) timeout 250; msg="timeout 250" ;;
      q|Q) break ;;
    esac
  done

  endwin
}

main "$@"
