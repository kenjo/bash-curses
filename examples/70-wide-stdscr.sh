# Port of the ncurses test wide-character stdscr wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  mvprintw 2 0 "abc"
  refresh

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a add_wchnstr  A add_wchstr  m mvadd_wchnstr  M mvadd_wchstr  i in_wch  I in_wchnstr  S in_wchstr  n ins_wch  N ins_wchnstr  s ins_wchstr  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        add_wchnstr "wide" 2
        msg="add_wchnstr wide 2"
        ;;
      1)
        add_wchstr "wide"
        msg="add_wchstr wide"
        ;;
      m|M)
        mvadd_wchnstr 3 0 "wide" 2
        msg="mvadd_wchnstr wide 2"
        ;;
      2)
        mvadd_wchstr 4 0 "wide"
        msg="mvadd_wchstr wide"
        ;;
      i|I)
        in_wch
        msg="in_wch wch=$wch"
        ;;
      3)
        in_wchnstr 3
        msg="in_wchnstr bc_str=$bc_str"
        ;;
      4)
        in_wchstr
        msg="in_wchstr bc_str=$bc_str"
        ;;
      n|N)
        ins_wch "X"
        msg="ins_wch X"
        ;;
      5)
        ins_wchnstr "wide" 2
        msg="ins_wchnstr wide 2"
        ;;
      s|S)
        ins_wchstr "wide"
        msg="ins_wchstr wide"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
