# Port of the ncurses test colors demo: init_pair, color_set, pair_content.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  if has_colors && start_color; then
    init_pair 1 1 4
    init_pair 2 6 4
    color_set 1
    mvprintw 2 0 "pair 1: red on blue"
    color_set 2
    mvprintw 3 0 "pair 2: magenta on blue"
    color_set 0
    attr_set 0 1
    mvprintw 4 0 "attr_set pair 1"
    attr_set 0 0
  else
    msg="no colors"
  fi

  while :; do
    mvprintw 0 0 "p pair_content  e extended_pair_content  a attr_set pair  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      p|P)
        if pair_content 1; then
          msg="pair_content 1 fg=$BC_CPF bg=$BC_CPB"
        else
          msg="pair_content 1 failed"
        fi
        ;;
      e|E)
        if extended_pair_content 2; then
          msg="extended_pair_content 2 fg=$BC_EPF bg=$BC_EPB"
        else
          msg="extended_pair_content 2 failed"
        fi
        ;;
      a|A)
        attr_set 0 2
        mvprintw 5 0 "attr_set pair 2"
        attr_set 0 0
        msg="attr_set pair 2"
        ;;
      q|Q)
        break
        ;;
    esac
  done

  endwin
}

main "$@"
