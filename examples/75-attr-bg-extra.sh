# Port of the ncurses test attr/background wrapper demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 10 40 2 2
  local win=$bc_win
  box "$win"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "a wattr_set  o wattr_on  f wattr_off  A attr_set  O attr_on  F attr_off  b bkgdset  B bkgrndset  k bkgrnd  K wbkgset  g getbkgd  p PAIR_NUMBER  v vid_attr  V vid_puts  u use_screen  t wtimeout  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      a|A)
        wattr_set "$win" "$A_BOLD" 0
        msg="wattr_set win A_BOLD"
        ;;
      o|O)
        wattr_on "$win" "$A_BOLD"
        msg="wattr_on win A_BOLD"
        ;;
      f|F)
        wattr_off "$win" "$A_BOLD"
        msg="wattr_off win A_BOLD"
        ;;
      1)
        attr_set "$A_BOLD" 0
        msg="attr_set A_BOLD"
        ;;
      2)
        attr_on "$A_BOLD"
        msg="attr_on A_BOLD"
        ;;
      3)
        attr_off "$A_BOLD"
        msg="attr_off A_BOLD"
        ;;
      b|B)
        bkgdset "@" 0 0
        msg="bkgdset @"
        ;;
      4)
        bkgrndset "$BC_STDSCR" "@" 0 0
        msg="bkgrndset stdscr @"
        ;;
      k|K)
        bkgrnd "$BC_STDSCR" "@" 0 0
        msg="bkgrnd stdscr @"
        ;;
      5)
        wbkgset "$win" "@" 0 0
        msg="wbkgset win @"
        ;;
      g|G)
        getbkgd "$win"
        msg="getbkgd win $BC_GBKG"
        ;;
      p|P)
        msg="PAIR_NUMBER 3 = $(PAIR_NUMBER 3)"
        ;;
      v|V)
        vid_attr "$A_BOLD"
        msg="vid_attr A_BOLD"
        ;;
      6)
        vid_puts "x" "$A_BOLD" 0
        msg="vid_puts x A_BOLD"
        ;;
      u|U)
        if use_screen; then
          msg="use_screen ok"
        else
          msg="use_screen unsupported"
        fi
        ;;
      t|T)
        wtimeout "$win" 100
        msg="wtimeout win 100"
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
