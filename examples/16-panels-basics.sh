# Port of references/howto-examples/16-panels/basics.c — three overlapping
# windows as panels; panels are stacked bottom-up so the last-created one
# (panel 2) sits on top. Any key exits.
source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

main() {
  initscr || exit 1
  cbreak
  noecho

  local lines=10 cols=40 y=2 x=4
  local -a wins
  newwin "$lines" "$cols" "$y" "$x";             wins[0]=$bc_win
  newwin "$lines" "$cols" $(( y + 1 )) $(( x + 5 )); wins[1]=$bc_win
  newwin "$lines" "$cols" $(( y + 2 )) $(( x + 10 )); wins[2]=$bc_win

  local i
  for i in 0 1 2; do box "${wins[$i]}"; done

  # Attach a panel to each window, bottom-up: panel 2 ends on top.
  for i in 0 1 2; do new_panel "${wins[$i]}"; done

  update_panels
  doupdate
  getch
  endwin
}

main "$@"
