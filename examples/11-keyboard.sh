# Port of references/howto-examples/11-keyboard/main.c — an arrow-key menu.
# Enter selects; other keys report their code.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

WIDTH=30
HEIGHT=10
startx=$(( (80 - WIDTH) / 2 ))
starty=$(( (24 - HEIGHT) / 2 ))
choices=( "Choice 1" "Choice 2" "Choice 3" "Choice 4" "Exit" )
n_choices=${#choices[@]}
menu_win=""

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

main() {
  initscr || exit 1
  clear
  noecho
  cbreak
  newwin "$HEIGHT" "$WIDTH" "$starty" "$startx"
  menu_win=$bc_win
  keypad "$menu_win" 1
  mvprintw 0 0 "Use arrow keys to go up and down, Press enter to select a choice"
  refresh
  local highlight=1 choice=0 key ord
  print_menu "$menu_win" "$highlight"
  while :; do
    wgetch "$menu_win"
    key=$key
    case $key in
      "$KEY_UP")   (( highlight == 1 )) && highlight=$n_choices || (( highlight-- )) ;;
      "$KEY_DOWN") (( highlight == n_choices )) && highlight=1 || (( highlight++ )) ;;
      $'\r' | $'\n') choice=$highlight ;;
      *)
        printf -v ord '%d' "'$key"
        mvprintw 24 0 "Charcter pressed is = %3d Hopefully it can be printed as '%c'" "$ord" "$key"
        refresh
        ;;
    esac
    print_menu "$menu_win" "$highlight"
    (( choice != 0 )) && break
  done
  mvprintw 23 0 "You chose choice %d with choice string %s\n" "$choice" "${choices[choice - 1]}"
  clrtoeol
  refresh
  endwin
  exit 0
}

main "$@"
