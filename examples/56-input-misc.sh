# Port of the ncurses test input/misc demos: meta, erase/kill, flush, beeps.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  while :; do
    mvprintw 0 0 "m meta  e erasechar  k killchar  E erasewchar  K killwchar  i intrflush"
    clrtoeol
    mvprintw 1 0 "u qiflush  n noqiflush  d delay_output  f flushinp  b beep  l flash  c has_ic/has_il  q quit"
    clrtoeol
    mvprintw 2 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      m|M)
        meta "$BC_STDSCR" 1
        msg="meta on BC_META=$BC_META"
        ;;
      e|E)
        msg="erasechar=$(erasechar)"
        ;;
      k|K)
        msg="killchar=$(killchar)"
        ;;
      1)
        erasewchar
        msg="erasewchar BC_ERASEWCHAR=$BC_ERASEWCHAR"
        ;;
      2)
        killwchar
        msg="killwchar BC_KILLWCHAR=$BC_KILLWCHAR"
        ;;
      i|I)
        intrflush "$BC_STDSCR" 1
        msg="intrflush rc=$?"
        ;;
      u|U)
        qiflush
        msg="qiflush rc=$?"
        ;;
      n|N)
        noqiflush
        msg="noqiflush rc=$?"
        ;;
      d|D)
        delay_output 10
        msg="delay_output 10"
        ;;
      f|F)
        flushinp
        msg="flushinp"
        ;;
      b|B)
        beep
        msg="beep"
        ;;
      l|L)
        flash
        msg="flash"
        ;;
      c|C)
        if has_ic && has_il; then
          msg="has_ic and has_il yes"
        else
          msg="has_ic or has_il no"
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
