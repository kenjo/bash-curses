# Port of the ncurses test slk demos: soft-key labels.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  slk_init 1 || exit 1
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  slk_set 1 "Menu" 1
  slk_set 2 "Edit" 1
  slk_set 3 "View" 1
  slk_set 4 "Quit" 1
  slk_refresh

  local msg="waiting"
  while :; do
    mvprintw 0 0 "c slk_clear  r slk_restore  t slk_touch  l slk_label  a slk_attrset  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        slk_clear
        msg="slk_clear"
        ;;
      r|R)
        slk_restore
        msg="slk_restore"
        ;;
      t|T)
        slk_touch
        slk_refresh
        msg="slk_touch + slk_refresh"
        ;;
      l|L)
        msg="slk_label 1 -> $(slk_label 1)"
        ;;
      a|A)
        slk_attrset "$A_BOLD"
        slk_touch
        slk_refresh
        msg="slk_attrset A_BOLD"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
