# Port of the ncurses test scr_* screen dump demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  SCR_FILE='tmp/bc_example_scr_dump.dmp'
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  mvprintw 2 0 "screen dump"
  refresh

  local msg="waiting"
  while :; do
    mvprintw 0 0 "d scr_dump  i scr_init_sp  r scr_restore_sp  s scr_set_sp  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      d|D)
        if scr_dump; then
          msg="scr_dump $SCR_FILE"
        else
          msg="scr_dump failed"
        fi
        ;;
      i|I)
        if scr_init_sp; then
          msg="scr_init_sp $SCR_FILE"
        else
          msg="scr_init_sp failed"
        fi
        ;;
      r|R)
        if scr_restore_sp; then
          msg="scr_restore_sp $SCR_FILE"
        else
          msg="scr_restore_sp failed"
        fi
        ;;
      s|S)
        if scr_set_sp; then
          msg="scr_set_sp $SCR_FILE"
        else
          msg="scr_set_sp failed"
        fi
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
