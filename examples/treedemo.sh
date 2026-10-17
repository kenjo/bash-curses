# Tree of random-sized, overlapping windows that continuously print a string.
#
# A recursive tree: the root window covers most of the screen; each window
# spawns a few child windows at random positions/sizes inside its parent, so
# siblings overlap. Every window scrolls the same sentence. Quit with q.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

readonly SENTENCE="All work and no play makes Jack a dull boy"

# long enough that any window row is a plain substring slice
REP="$SENTENCE"
while (( ${#REP} < 4096 )); do REP+="$REP"; done

declare -a TREE_WINS=()
declare -A TREE_OFF=() TREE_PAIR=()

rand_color_pair() { # -> bc_pair (1..BC_PAIRS)
  local fg=$(( (RANDOM % 7) + 1 )) bg=$(( RANDOM % 8 ))
  if (( fg == bg )); then bg=$(( (bg + 1) % 8 )); fi
  local p=$(( (RANDOM % BC_PAIRS) + 1 ))
  init_pair "$p" "$fg" "$bg"
  bc_pair=$p
}

make_window() { # y x h w depth
  local y=$1 x=$2 h=$3 w=$4 d=$5
  newwin "$h" "$w" "$y" "$x" || return 1
  local win=$bc_win
  rand_color_pair
  TREE_WINS+=("$win")
  TREE_OFF[$win]=$(( RANDOM % ${#SENTENCE} ))
  TREE_PAIR[$win]=$bc_pair
  new_panel "$win" >/dev/null

  # children: 0..2, placed at random spots inside this window (overlap allowed)
  if (( d < 3 )) && (( h > 12 && w > 24 )); then
    local n=$(( RANDOM % 3 )) i cy cx ch cw
    for (( i = 0; i < n; i++ )); do
      ch=$(( 6 + RANDOM % (h - 8) ))
      cw=$(( 12 + RANDOM % (w - 14) ))
      cy=$(( y + 1 + RANDOM % (h - ch - 1) ))
      cx=$(( x + 1 + RANDOM % (w - cw - 1) ))
      make_window "$cy" "$cx" "$ch" "$cw" $(( d + 1 ))
    done
  fi
}

draw_window() { # win
  local win=$1
  local pair=${TREE_PAIR[$win]} off=${TREE_OFF[$win]}
  getmaxyx "$win"; local h=$BC_GMY w=$BC_GMX
  werase "$win"
  wattrset "$win" 0 "$pair"
  box "$win"
  local iw=$(( w - 2 )) r line
  for (( r = 1; r < h - 1; r++ )); do
    line=${REP:off:iw}
    mvwaddstr "$win" "$r" 1 "$line"
    off=$(( off + iw ))
  done
  TREE_OFF[$win]=$(( off % ${#SENTENCE} ))
}

main() {
  initscr || exit 1
  cbreak
  curs_set 0
  if has_colors; then start_color; fi

  local h=$(( BC_LINES - 2 )) w=$(( BC_COLS - 2 ))
  make_window 1 1 "$h" "$w" 0

  nodelay "$BC_STDSCR" 1
  while :; do
    local win
    for win in "${TREE_WINS[@]}"; do
      draw_window "$win"
    done
    doupdate
    napms 120
    if wgetch "$BC_STDSCR"; then
      [[ $key == q || $key == Q ]] && break
    fi
  done

  endwin
}

main "$@"
