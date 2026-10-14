# Port of the ncurses test window query demos.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin 8 30 2 2
  local win=$bc_win
  box "$win"
  mvwprintw "$win" 1 1 "query"
  wrefresh "$win"

  local msg="waiting"
  while :; do
    mvprintw 0 0 "c cursor  b begin  m max  a attrs  k bkgd  d derwin  e isendwin  h has_named_color  q quit"
    clrtoeol
    mvprintw 1 0 "%s" "$msg"
    clrtoeol
    refresh

    wgetch || break
    case $key in
      c|C)
        getcury "$win"
        getcurx "$win"
        msg="cursor y=$BC_GCY x=$BC_GCX"
        ;;
      b|B)
        getbegy "$win"
        getbegx "$win"
        msg="begin y=$BC_GBY x=$BC_GBX"
        ;;
      m|M)
        getmaxy "$win"
        getmaxx "$win"
        msg="max y=$BC_GMY x=$BC_GMX"
        ;;
      a|A)
        getattrs "$win"
        msg="attrs=$BC_GA"
        ;;
      k|K)
        getbkgd "$win"
        msg="bkgd=$BC_GBKG a=$BC_GBKG_A p=$BC_GBKG_P"
        ;;
      d|D)
        if derwin "$win" 4 10 3 3; then
          local sub=$bc_win
          mvwprintw "$sub" 0 0 "derwin"
          wrefresh "$sub"
          msg="derwin id=$sub"
        else
          msg="derwin failed"
        fi
        ;;
      e|E)
        if isendwin; then
          msg="isendwin yes"
        else
          msg="isendwin no"
        fi
        ;;
      h|H)
        if has_named_color red; then
          msg="has_named_color yes"
        else
          msg="has_named_color no"
        fi
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
