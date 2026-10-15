# Port of the ncurses test SLK attribute/color demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  slk_init 3 || exit 1
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  if has_colors; then
    start_color
    init_pair 1 "$COLOR_YELLOW" "$COLOR_BLUE"
  fi

  slk_set 1 "One" 1
  slk_set 2 "Two" 1
  slk_set 3 "Three" 1
  slk_refresh

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a slk_attr  o slk_attron  f slk_attroff  s slk_attr_set  O slk_attr_on  F slk_attr_off  c slk_color  n slk_noutrefresh  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        msg="slk_attr=$(slk_attr)"
        ;;
      o|O)
        slk_attron "$A_BOLD"
        msg="slk_attron A_BOLD"
        ;;
      f|F)
        slk_attroff "$A_BOLD"
        msg="slk_attroff A_BOLD"
        ;;
      s|S)
        if slk_attr_set "$A_BOLD" 1; then
          msg="slk_attr_set A_BOLD pair 1"
        else
          msg="slk_attr_set failed"
        fi
        ;;
      1)
        slk_attr_on "$A_BOLD"
        msg="slk_attr_on A_BOLD"
        ;;
      2)
        slk_attr_off "$A_BOLD"
        msg="slk_attr_off A_BOLD"
        ;;
      c|C)
        if slk_color 1; then
          msg="slk_color 1"
        else
          msg="slk_color failed"
        fi
        ;;
      n|N)
        slk_noutrefresh
        doupdate
        msg="slk_noutrefresh"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
