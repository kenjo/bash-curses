# Port of the ncurses test pad/subpad/pechochar demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newpad 20 40
  local pad=$bc_win
  mvwaddstr "$pad" 0 0 "pad top"
  mvwaddstr "$pad" 19 0 "pad bottom"

  local pminrow=0 pmincol=0 msg="waiting"
  while :; do
    mvprintw 0 0 "Up Down Left Right  s subpad  p prefresh  n pnoutrefresh  e pechochar  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    mvprintw 2 0 "pad origin: ($pminrow,$pmincol)"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      "$KEY_UP")
        (( pminrow > 0 )) && pminrow=$(( pminrow - 1 ))
        ;;
      "$KEY_DOWN")
        pminrow=$(( pminrow + 1 ))
        ;;
      "$KEY_LEFT")
        (( pmincol > 0 )) && pmincol=$(( pmincol - 1 ))
        ;;
      "$KEY_RIGHT")
        pmincol=$(( pmincol + 1 ))
        ;;
      s|S)
        subpad "$pad" 5 10 2 2
        local sub=$bc_win
        if is_pad "$sub"; then
          msg="subpad is_pad yes"
        else
          msg="subpad is_pad no"
        fi
        ;;
      p|P)
        prefresh "$pad" "$pminrow" "$pmincol" 3 0 $(( LINES - 2 )) $(( COLS - 1 ))
        msg="prefresh"
        ;;
      n|N)
        pnoutrefresh "$pad" "$pminrow" "$pmincol" 3 0 $(( LINES - 2 )) $(( COLS - 1 ))
        doupdate
        msg="pnoutrefresh + doupdate"
        ;;
      e|E)
        pechochar "$pad" 'X'
        msg="pechochar X"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
