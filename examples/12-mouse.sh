# Port of references/howto-examples/12-mouse/main.c — a click-to-select menu.
# Left-click a choice to select it; click "Exit" to quit.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

WIDTH=30
HEIGHT=10
startx=$(( (80 - WIDTH) / 2 ))
starty=$(( (24 - HEIGHT) / 2 ))
choices=( "Choice 1" "Choice 2" "Choice 3" "Choice 4" "Exit" )
n_choices=${#choices[@]}
menu_win=""
choice_out=0

print_menu() { # win highlight
  local win=$1 highlight=$2
  local x=2 y=2 i
  box "$win"
  for (( i = 0; i < n_choices; i++ )); do
    if (( highlight == i + 1 )); then
      wattron "$win" "$A_REVERSE"
      mvwprintw "$win" "$y" "$x" "%s" "${choices[i]}"
      wattroff "$win" "$A_REVERSE"
    else
      mvwprintw "$win" "$y" "$x" "%s" "${choices[i]}"
    fi
    (( y++ ))
  done
  wrefresh "$win"
}

report_choice() { # mouse_x mouse_y (1-based) -> choice_out
  local mouse_x=$1 mouse_y=$2
  local i=$(( startx + 2 )) j=$(( starty + 3 ))
  local c
  choice_out=0
  for (( c = 0; c < n_choices; c++ )); do
    if (( mouse_y == j + c )) && (( mouse_x >= i )) && (( mouse_x <= i + ${#choices[c]} )); then
      if (( c == n_choices - 1 )); then
        choice_out=-1
      else
        choice_out=$(( c + 1 ))
      fi
      break
    fi
  done
}

main() {
  initscr || exit 1
  clear
  noecho
  cbreak
  attrset 0 "$A_REVERSE"
  mvprintw 23 1 "Click on Exit or press q to quit"
  refresh
  attrset 0 0
  newwin "$HEIGHT" "$WIDTH" "$starty" "$startx"
  menu_win=$bc_win
  print_menu "$menu_win" 1
  mousemask "$ALL_MOUSE_EVENTS"
  local choice=0 key
  while :; do
    wgetch "$menu_win"
    key=$key
    if [[ $key == q ]]; then
      break
    fi
    if (( key == KEY_MOUSE )); then
      if getmouse; then
        # xterm-style terminals report press+release merged as CLICKED;
        # a Linux console (GPM) reports PRESSED.
        if (( BC_ME_BSTATE & (BUTTON1_PRESSED | BUTTON1_CLICKED) )); then
          report_choice $(( BC_ME_X + 1 )) $(( BC_ME_Y + 1 ))
          choice=$choice_out
          if (( choice == -1 )); then
            break
          fi
          mvprintw 22 1 "Choice made is : %d String Chosen is \"%10s\"" "$choice" "${choices[choice - 1]}"
          refresh
        fi
      fi
      print_menu "$menu_win" "$choice"
    fi
  done
  endwin
  exit 0
}

main "$@"
