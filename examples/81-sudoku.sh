# A minimal nudoku-inspired sudoku demo.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

readonly plain_board='4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......'
user_board=$plain_board

readonly GRID_LINES=19
readonly GRID_COLS=37
readonly GRID_Y=3
readonly GRID_X=3
readonly INFO_LINES=25
readonly INFO_COLS=30
readonly INFO_Y=3
readonly INFO_X=$((GRID_X + GRID_COLS + 5))
readonly GRID_NUMBER_START_Y=1
readonly GRID_NUMBER_START_X=2
readonly GRID_LINE_DELTA=4
readonly GRID_COL_DELTA=2

draw_grid() {
  local w=$1 i j y x node

  for ((i = 0; i < 10; i++)); do
    y=$((i * GRID_COL_DELTA))
    for ((j = 0; j < 10; j++)); do
      x=$((j * GRID_LINE_DELTA))
      if ((i == 0 && j == 0)); then
        node=$ACS_ULCORNER
      elif ((i == 0 && j == 9)); then
        node=$ACS_URCORNER
      elif ((i == 9 && j == 9)); then
        node=$ACS_LRCORNER
      elif ((i == 9 && j == 0)); then
        node=$ACS_LLCORNER
      elif ((i == 0)); then
        node=$ACS_TTEE
      elif ((i == 9)); then
        node=$ACS_BTEE
      elif ((j == 0)); then
        node=$ACS_LTEE
      elif ((j == 9)); then
        node=$ACS_RTEE
      else
        node=$ACS_PLUS
      fi

      wmove "$w" "$y" "$x"
      waddch "$w" "$node"

      if ((j < 9)); then
        wmove "$w" "$y" "$((x + 1))"
        waddch "$w" "$ACS_HLINE"
        waddch "$w" "$ACS_HLINE"
        waddch "$w" "$ACS_HLINE"
      fi
    done

    if ((i < 9)); then
      y=$((i * GRID_COL_DELTA + 1))
      for ((j = 0; j < 10; j++)); do
        x=$((j * GRID_LINE_DELTA))
        wmove "$w" "$y" "$x"
        waddch "$w" "$ACS_VLINE"

        if ((j < 9)); then
          wmove "$w" "$y" "$((x + 1))"
          waddch "$w" ' '
          waddch "$w" ' '
          waddch "$w" ' '
        fi
      done
    fi
  done
}

fill_grid() {
  local w=$1 row col y x c idx

  for ((row = 0; row < 9; row++)); do
    y=$((GRID_NUMBER_START_Y + row * GRID_COL_DELTA))
    for ((col = 0; col < 9; col++)); do
      x=$((GRID_NUMBER_START_X + col * GRID_LINE_DELTA))
      idx=$((row * 9 + col))
      c=${user_board:idx:1}
      if [[ $c == '.' ]]; then
        c=' '
      fi
      mvwprintw "$w" "$y" "$x" "%c" "$c"
    done
  done
}

draw_info() {
  local w=$1

  mvwprintw "$w" 0 0 "sudoku demo"
  mvwprintw "$w" 1 0 "fixed puzzle"
  mvwprintw "$w" 2 0 ""
  mvwprintw "$w" 3 0 "Movement"
  mvwprintw "$w" 4 0 " h left"
  mvwprintw "$w" 5 0 " j down"
  mvwprintw "$w" 6 0 " k up"
  mvwprintw "$w" 7 0 " l right"
  mvwprintw "$w" 8 0 ""
  mvwprintw "$w" 9 0 "Commands"
  mvwprintw "$w" 10 0 " 1-9 enter"
  mvwprintw "$w" 11 0 " x delete"
  mvwprintw "$w" 12 0 " c check"
  mvwprintw "$w" 13 0 " r redraw"
  mvwprintw "$w" 14 0 " q quit"
}

check_board() {
  local n r c br bc idx

  for ((r = 0; r < 9; r++)); do
    local -a seen=()
    for ((c = 0; c < 9; c++)); do
      idx=$((r * 9 + c))
      n=${user_board:idx:1}
      [[ $n == '.' ]] && continue
      if [[ -n ${seen[$n]:-} ]]; then
        return 1
      fi
      seen[$n]=1
    done
  done

  for ((c = 0; c < 9; c++)); do
    local -a seen=()
    for ((r = 0; r < 9; r++)); do
      idx=$((r * 9 + c))
      n=${user_board:idx:1}
      [[ $n == '.' ]] && continue
      if [[ -n ${seen[$n]:-} ]]; then
        return 1
      fi
      seen[$n]=1
    done
  done

  for ((br = 0; br < 9; br += 3)); do
    for ((bc = 0; bc < 9; bc += 3)); do
      local -a seen=()
      for ((r = br; r < br + 3; r++)); do
        for ((c = bc; c < bc + 3; c++)); do
          idx=$((r * 9 + c))
          n=${user_board:idx:1}
          [[ $n == '.' ]] && continue
          if [[ -n ${seen[$n]:-} ]]; then
            return 1
          fi
          seen[$n]=1
        done
      done
    done
  done

  return 0
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  newwin "$GRID_LINES" "$GRID_COLS" "$GRID_Y" "$GRID_X"
  local grid=$bc_win
  newwin "$INFO_LINES" "$INFO_COLS" "$INFO_Y" "$INFO_X"
  local info=$bc_win

  draw_grid "$grid"
  fill_grid "$grid"
  draw_info "$info"
  wrefresh "$grid"
  wrefresh "$info"

  local x=$GRID_NUMBER_START_X
  local y=$GRID_NUMBER_START_Y
  local help="h j k l move  1-9 enter  x delete  c check  r redraw  q quit"
  local msg="Ready"
  local idx

  wmove "$grid" "$y" "$x"

  while :; do
    mvprintw 0 0 "%s" "$help"
    clrtoeol
    mvprintw 1 "$GRID_X" "%s" "$msg"
    clrtoeol
    refresh

    wgetch 0 || break
    case $key in
      h|"$KEY_LEFT")
        if ((x <= GRID_NUMBER_START_X)); then
          x=$((GRID_NUMBER_START_X + GRID_LINE_DELTA * 8))
        else
          x=$((x - GRID_LINE_DELTA))
        fi
        ;;
      l|"$KEY_RIGHT")
        if ((x >= GRID_NUMBER_START_X + GRID_LINE_DELTA * 8)); then
          x=$GRID_NUMBER_START_X
        else
          x=$((x + GRID_LINE_DELTA))
        fi
        ;;
      k|"$KEY_UP")
        if ((y <= GRID_NUMBER_START_Y)); then
          y=$((GRID_NUMBER_START_Y + GRID_COL_DELTA * 8))
        else
          y=$((y - GRID_COL_DELTA))
        fi
        ;;
      j|"$KEY_DOWN")
        if ((y >= GRID_NUMBER_START_Y + GRID_COL_DELTA * 8)); then
          y=$GRID_NUMBER_START_Y
        else
          y=$((y + GRID_COL_DELTA))
        fi
        ;;
      c)
        if check_board; then
          if [[ $user_board != *.* ]]; then
            msg="Solved"
          else
            msg="Correct so far"
          fi
        else
          msg="Not correct"
        fi
        ;;
      r)
        draw_grid "$grid"
        fill_grid "$grid"
        draw_info "$info"
        ;;
      x|"$KEY_DC"|"$KEY_BACKSPACE"|127)
        idx=$(((y - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 + (x - GRID_NUMBER_START_X) / GRID_LINE_DELTA))
        if [[ ${plain_board:idx:1} == '.' ]]; then
          user_board=${user_board:0:idx}.${user_board:idx+1}
          fill_grid "$grid"
        fi
        ;;
      [1-9])
        idx=$(((y - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 + (x - GRID_NUMBER_START_X) / GRID_LINE_DELTA))
        if [[ ${plain_board:idx:1} == '.' ]]; then
          user_board=${user_board:0:idx}${key}${user_board:idx+1}
          fill_grid "$grid"
        fi
        ;;
      q|Q|27)
        break
        ;;
    esac

    wmove "$grid" "$y" "$x"
    wrefresh "$grid"
    wrefresh "$info"
  done

  endwin
}

main "$@"
