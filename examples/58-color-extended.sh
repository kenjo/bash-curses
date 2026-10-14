# Port of the ncurses test extended color/pair demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  local msg="waiting"
  if has_colors && start_color; then
    use_default_colors
    assume_default_colors -1 -1
    init_extended_color 8 1000 0 0
    init_extended_pair 3 8 8
  else
    msg="no colors"
  fi

  while :; do
    mvprintw 0 0 "c extended_color_content  p extended_pair_content  a alloc_pair  f find_pair  r free_pair  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        if extended_color_content 8; then
          msg="extended_color_content 8 r=$BC_CR g=$BC_CG b=$BC_CB"
        else
          msg="extended_color_content 8 failed"
        fi
        ;;
      p|P)
        if extended_pair_content 3; then
          msg="extended_pair_content 3 fg=$BC_EPF bg=$BC_EPB"
        else
          msg="extended_pair_content 3 failed"
        fi
        ;;
      a|A)
        if alloc_pair 3 4; then
          msg="alloc_pair -> $bc_pair"
        else
          msg="alloc_pair failed"
        fi
        ;;
      f|F)
        if find_pair 3 4; then
          msg="find_pair -> $bc_pair"
        else
          msg="find_pair failed"
        fi
        ;;
      r|R)
        if free_pair 3; then
          msg="free_pair 3"
        else
          msg="free_pair 3 failed"
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
