# Port of the ncurses test mcprint/napms/setcchar/getcchar/wcwidth demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "m mcprint  n napms  c setcchar/getcchar  w wcwidth  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      m|M)
        if mcprint "hello"; then
          msg="mcprint ok"
        else
          msg="mcprint unsupported rc=$?"
        fi
        ;;
      n|N)
        napms 10
        msg="napms 10"
        ;;
      c|C)
        setcchar 'X' 'A' "$A_BOLD" 1
        getcchar "$bc_cchar"
        msg="getcchar wch=$wch attrs=$wcha pair=$wchp"
        ;;
      w|W)
        wcwidth 'A'
        msg="wcwidth A rc=$?"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
