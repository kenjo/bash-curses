# Port of the ncurses test wide-character mv wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  echo
  keypad 0 1
  curs_set 1

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 2 0 "abc"
  mvprintw 2 0 "xyz"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a mvwadd_wch  A mvadd_wch  w wecho_wchar  W echo_wchar  g mvwget_wch  G mvget_wch  i mvin_wch  I mvwin_wch  n mvin_wchnstr  N mvwin_wchnstr  s mvin_wchstr  S mvwin_wchstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        mvwadd_wch "$win" 3 0 "X"
        msg="mvwadd_wch win 3 0 X"
        ;;
      1)
        mvadd_wch 3 0 "Y"
        msg="mvadd_wch 3 0 Y"
        ;;
      w|W)
        wecho_wchar "$win" "Z"
        msg="wecho_wchar win Z"
        ;;
      2)
        echo_wchar "Q"
        msg="echo_wchar Q"
        ;;
      g|G)
        mvwget_wch "$win" 4 0
        msg="mvwget_wch win 4 0 wch=$wch"
        ;;
      3)
        mvget_wch 4 0
        msg="mvget_wch 4 0 wch=$wch"
        ;;
      i|I)
        mvin_wch 2 0
        msg="mvin_wch 2 0 wch=$wch"
        ;;
      4)
        mvwin_wch "$win" 2 0
        msg="mvwin_wch win 2 0 wch=$wch"
        ;;
      n|N)
        mvin_wchnstr 2 0 3
        msg="mvin_wchnstr 2 0 3 bc_str=$bc_str"
        ;;
      5)
        mvwin_wchnstr "$win" 2 0 3
        msg="mvwin_wchnstr win 2 0 3 bc_str=$bc_str"
        ;;
      s|S)
        mvin_wchstr 2 0
        msg="mvin_wchstr 2 0 bc_str=$bc_str"
        ;;
      6)
        mvwin_wchstr "$win" 2 0
        msg="mvwin_wchstr win 2 0 bc_str=$bc_str"
        ;;
      q|Q)
        break
        ;;
    esac
    wrefresh "$win"
  done

  endwin
}

main "$@"
