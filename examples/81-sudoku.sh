# A nudoku-inspired sudoku demo with colors, highlights, undo, and hints.

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

readonly GRID_LINE_PAIR=1
readonly GRID_NODE_PAIR=2
readonly USER_PAIR=3
readonly HIGHLIGHT_PAIR=4
readonly CURSOR_PAIR=5
readonly USER_HIGHLIGHT_PAIR=6

use_highlights=0
use_colors=0
x_cursor=$GRID_NUMBER_START_X
y_cursor=$GRID_NUMBER_START_Y

declare -a undo_x undo_y undo_val
undo_count=0

declare -a _solve_b

draw_grid() {
  local w=$1 i j y x node pair attr

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

      if ((use_colors)) && ((i % 3 == 0 || j % 3 == 0)); then
        pair=$GRID_NODE_PAIR; attr=$A_BOLD
      elif ((use_colors)); then
        pair=$GRID_LINE_PAIR; attr=0
      else
        pair=0; attr=0
      fi

      wmove "$w" "$y" "$x"
      waddch "$w" "$node" "$attr" "$pair"

      if ((j < 9)); then
        if ((use_colors)); then
          pair=$GRID_LINE_PAIR; attr=0
        else
          pair=0; attr=0
        fi
        wmove "$w" "$y" "$((x + 1))"
        waddch "$w" "$ACS_HLINE" "$attr" "$pair"
        waddch "$w" "$ACS_HLINE" "$attr" "$pair"
        waddch "$w" "$ACS_HLINE" "$attr" "$pair"
      fi
    done

    if ((i < 9)); then
      y=$((i * GRID_COL_DELTA + 1))
      for ((j = 0; j < 10; j++)); do
        x=$((j * GRID_LINE_DELTA))
        if ((use_colors)); then
          pair=$GRID_LINE_PAIR; attr=0
        else
          pair=0; attr=0
        fi
        wmove "$w" "$y" "$x"
        waddch "$w" "$ACS_VLINE" "$attr" "$pair"

        if ((j < 9)); then
          wmove "$w" "$y" "$((x + 1))"
          waddch "$w" ' ' 0 0
          waddch "$w" ' ' 0 0
          waddch "$w" ' ' 0 0
        fi
      done
    fi
  done
}

fill_grid() {
  local w=$1 row col gy gx c idx is_user sel pair attr
  local cur_row=$(( (y_cursor - GRID_NUMBER_START_Y) / GRID_COL_DELTA ))
  local cur_col=$(( (x_cursor - GRID_NUMBER_START_X) / GRID_LINE_DELTA ))
  local sel_idx=$((cur_row * 9 + cur_col))
  sel=${user_board:sel_idx:1}
  [[ $sel == '.' ]] && sel=''

  for ((row = 0; row < 9; row++)); do
    gy=$((GRID_NUMBER_START_Y + row * GRID_COL_DELTA))
    for ((col = 0; col < 9; col++)); do
      gx=$((GRID_NUMBER_START_X + col * GRID_LINE_DELTA))
      idx=$((row * 9 + col))
      c=${user_board:idx:1}
      is_user=0
      if [[ $c == '.' ]]; then
        c=' '
      elif [[ $c != "${plain_board:idx:1}" ]]; then
        is_user=1
      fi

      pair=0; attr=0
      if ((use_colors)); then
        if ((use_highlights)) && [[ -n $sel ]] && [[ $c == "$sel" ]]; then
          if ((row == cur_row && col == cur_col)); then
            pair=$CURSOR_PAIR
          elif ((is_user)); then
            pair=$USER_HIGHLIGHT_PAIR
          else
            pair=$HIGHLIGHT_PAIR
          fi
        elif ((is_user)); then
          pair=$USER_PAIR
        fi
      fi

      mvwaddch "$w" "$gy" "$gx" "$c" "$attr" "$pair"
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
  mvwprintw "$w" 14 0 " m highlight"
  mvwprintw "$w" 15 0 " u undo"
  mvwprintw "$w" 16 0 " H hint"
  mvwprintw "$w" 17 0 " q quit"
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

_valid_at() {
  local row=$1 col=$2 d=$3 r c br bc
  for ((c = 0; c < 9; c++)); do
    [[ ${_solve_b[row * 9 + c]} == "$d" ]] && return 1
  done
  for ((r = 0; r < 9; r++)); do
    [[ ${_solve_b[r * 9 + col]} == "$d" ]] && return 1
  done
  br=$((row / 3 * 3)); bc=$((col / 3 * 3))
  for ((r = br; r < br + 3; r++)); do
    for ((c = bc; c < bc + 3; c++)); do
      [[ ${_solve_b[r * 9 + c]} == "$d" ]] && return 1
    done
  done
  return 0
}

solve_board() {
  local pos=-1 i row col d
  for ((i = 0; i < 81; i++)); do
    if [[ ${_solve_b[i]} == '.' ]]; then pos=$i; break; fi
  done
  ((pos < 0)) && return 0
  row=$((pos / 9)); col=$((pos % 9))
  for ((d = 1; d <= 9; d++)); do
    if _valid_at "$row" "$col" "$d"; then
      _solve_b[pos]=$d
      if solve_board; then return 0; fi
      _solve_b[pos]='.'
    fi
  done
  return 1
}

do_hint() {
  local i
  for ((i = 0; i < 81; i++)); do
    _solve_b[i]=${user_board:i:1}
  done
  if solve_board; then
    for ((i = 0; i < 81; i++)); do
      if [[ ${user_board:i:1} == '.' ]]; then
        user_board=${user_board:0:i}${_solve_b[i]}${user_board:i+1}
        return 0
      fi
    done
  fi
  return 1
}

undo_push() {
  undo_x[$undo_count]=$1
  undo_y[$undo_count]=$2
  undo_val[$undo_count]=$3
  ((undo_count++))
}

undo_pop() {
  ((undo_count <= 0)) && return 1
  ((undo_count--))
  undo_x_ret=${undo_x[$undo_count]}
  undo_y_ret=${undo_y[$undo_count]}
  undo_val_ret=${undo_val[$undo_count]}
  return 0
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  curs_set 0

  if has_colors && start_color; then
    use_colors=1
    use_default_colors
    init_pair $GRID_LINE_PAIR "$COLOR_GREEN" -1
    init_pair $GRID_NODE_PAIR "$COLOR_BLUE" -1
    init_pair $USER_PAIR "$COLOR_CYAN" -1
    init_pair $HIGHLIGHT_PAIR "$COLOR_BLACK" "$COLOR_WHITE"
    init_pair $CURSOR_PAIR "$COLOR_BLACK" "$COLOR_MAGENTA"
    init_pair $USER_HIGHLIGHT_PAIR "$COLOR_BLACK" "$COLOR_CYAN"
  fi

  newwin "$GRID_LINES" "$GRID_COLS" "$GRID_Y" "$GRID_X"
  local grid=$bc_win
  newwin "$INFO_LINES" "$INFO_COLS" "$INFO_Y" "$INFO_X"
  local info=$bc_win

  draw_grid "$grid"
  fill_grid "$grid"
  draw_info "$info"
  wrefresh "$grid"
  wrefresh "$info"

  local help1="h j k l move  1-9 enter  x delete  c check  r redraw  q quit"
  local help2="m highlight  u undo  H hint"
  local msg="Ready"
  local idx prev

  wmove "$grid" "$y_cursor" "$x_cursor"

  while :; do
    mvprintw 0 0 "%s" "$help1"
    clrtoeol
    mvprintw 1 0 "%s" "$help2"
    clrtoeol
    mvprintw 2 "$GRID_X" "%s" "$msg"
    clrtoeol
    refresh

    wgetch 0 || break
    case $key in
      h|"$KEY_LEFT")
        if ((x_cursor <= GRID_NUMBER_START_X)); then
          x_cursor=$((GRID_NUMBER_START_X + GRID_LINE_DELTA * 8))
        else
          x_cursor=$((x_cursor - GRID_LINE_DELTA))
        fi
        ;;
      l|"$KEY_RIGHT")
        if ((x_cursor >= GRID_NUMBER_START_X + GRID_LINE_DELTA * 8)); then
          x_cursor=$GRID_NUMBER_START_X
        else
          x_cursor=$((x_cursor + GRID_LINE_DELTA))
        fi
        ;;
      k|"$KEY_UP")
        if ((y_cursor <= GRID_NUMBER_START_Y)); then
          y_cursor=$((GRID_NUMBER_START_Y + GRID_COL_DELTA * 8))
        else
          y_cursor=$((y_cursor - GRID_COL_DELTA))
        fi
        ;;
      j|"$KEY_DOWN")
        if ((y_cursor >= GRID_NUMBER_START_Y + GRID_COL_DELTA * 8)); then
          y_cursor=$GRID_NUMBER_START_Y
        else
          y_cursor=$((y_cursor + GRID_COL_DELTA))
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
      m)
        if ((use_highlights)); then
          use_highlights=0
          msg="Highlights off"
        else
          use_highlights=1
          msg="Highlights on"
        fi
        fill_grid "$grid"
        ;;
      u)
        if undo_pop; then
          idx=$(((undo_y_ret - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 + (undo_x_ret - GRID_NUMBER_START_X) / GRID_LINE_DELTA))
          user_board=${user_board:0:idx}${undo_val_ret}${user_board:idx+1}
          x_cursor=$undo_x_ret
          y_cursor=$undo_y_ret
          fill_grid "$grid"
          msg="Undone"
        else
          msg="Nothing to undo"
        fi
        ;;
      H)
        if do_hint; then
          fill_grid "$grid"
          msg="Hint"
        else
          msg="No solution"
        fi
        ;;
      x|"$KEY_DC"|"$KEY_BACKSPACE"|127)
        idx=$(((y_cursor - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 + (x_cursor - GRID_NUMBER_START_X) / GRID_LINE_DELTA))
        if [[ ${plain_board:idx:1} == '.' ]]; then
          prev=${user_board:idx:1}
          undo_push "$x_cursor" "$y_cursor" "$prev"
          user_board=${user_board:0:idx}.${user_board:idx+1}
          fill_grid "$grid"
        fi
        ;;
      [1-9])
        idx=$(((y_cursor - GRID_NUMBER_START_Y) / GRID_COL_DELTA * 9 + (x_cursor - GRID_NUMBER_START_X) / GRID_LINE_DELTA))
        if [[ ${plain_board:idx:1} == '.' ]]; then
          prev=${user_board:idx:1}
          undo_push "$x_cursor" "$y_cursor" "$prev"
          user_board=${user_board:0:idx}${key}${user_board:idx+1}
          fill_grid "$grid"
        fi
        ;;
      q|Q|27)
        break
        ;;
    esac

    wmove "$grid" "$y_cursor" "$x_cursor"
    wrefresh "$grid"
    wrefresh "$info"
  done

  endwin
}

main "$@"
