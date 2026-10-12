# Port of the ncurses curs_window example: putwin, getwin, and dupwin.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

REPO="${BASH_SOURCE[0]%/*}/.."
WIN_FILE="$REPO/tmp/bc_window.dump"

draw_window() { # win label
  local win=$1 label=$2
  box "$win"
  mvwprintw "$win" 0 2 " %s " "$label"
  mvwprintw "$win" 2 2 "This window was saved with putwin()."
  mvwprintw "$win" 3 2 "getwin() recreates it from the file."
  mvwprintw "$win" 4 2 "dupwin() copies the live window."
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0
  mkdir -p "$REPO/tmp"

  newwin 10 40 2 2
  local win=$bc_win
  draw_window "$win" "Original"
  wrefresh "$win"

  local status="ready"
  while :; do
    mvprintw 0 0 "WIN_FILE=%s  %s" "$WIN_FILE" "$status"
    clrtoeol
    mvprintw $(( LINES - 1 )) 0 "g getwin  d dupwin  q quit"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      g)
        if getwin "$WIN_FILE"; then
          win=$bc_win
          wrefresh "$win"
          status="getwin restored a window"
        else
          status="getwin failed"
        fi
        ;;
      d)
        if [[ -n ${BC_WY[$win]:-} ]]; then
          dupwin "$win"
          local dup=$bc_win
          getbegyx "$win"
          mvwin "$dup" $(( BC_GBY + 2 )) $(( BC_GBX + 2 ))
          wrefresh "$dup"
          status="dupwin copied the window"
        else
          status="no live window to duplicate"
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
