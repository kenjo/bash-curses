# Port of the ncurses curs_copywin example: overlay and overwrite.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

fill_background() { # win
  local win=$1 h ww y x
  getmaxyx "$win"
  h=$BC_GMY
  ww=$BC_GMX
  box "$win"
  for (( y = 1; y < h - 1; y++ )); do
    for (( x = 1; x < ww - 1; x++ )); do
      mvwaddch "$win" "$y" "$x" '.'
    done
  done
}

draw_source() { # win
  local win=$1 h ww y x
  getmaxyx "$win"
  h=$BC_GMY
  ww=$BC_GMX
  for (( y = 0; y < h; y++ )); do
    for (( x = 0; x < ww; x++ )); do
      if (( (x + y) % 3 == 0 )); then
        mvwaddch "$win" "$y" "$x" '#'
      else
        mvwaddch "$win" "$y" "$x" ' '
      fi
    done
  done
}

main() {
  initscr || exit 1
  cbreak
  noecho
  curs_set 0

  newwin 7 20 1 1
  local src=$bc_win
  draw_source "$src"

  newwin 9 24 10 1
  local dst1=$bc_win
  newwin 9 24 10 27
  local dst2=$bc_win

  fill_background "$dst1"
  fill_background "$dst2"

  overlay "$src" "$dst1"
  overwrite "$src" "$dst2"

  mvprintw 0 0 "overlay keeps destination blanks; overwrite replaces everything"
  mvprintw 9 1 "overlay"
  mvprintw 9 27 "overwrite"
  mvprintw $(( LINES - 1 )) 0 "q quit"
  clrtoeol

  wrefresh "$src"
  wrefresh "$dst1"
  wrefresh "$dst2"
  refresh

  while :; do
    wgetch || break
    [[ $key == q || $key == Q ]] && break
  done

  endwin
}

main "$@"
