# Tree of random-sized, overlapping windows that continuously print a string.
#
# A recursive tree: the root window covers most of the screen; each window
# spawns a few child windows at random positions/sizes inside its parent, so
# siblings overlap. Every window scrolls the same sentence. Quit with q.

source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

readonly SENTENCE="All work and no play makes Jack a dull boy."
# ~4 words/sec: advance 20 chars/s (≈5 chars/word), time-based so the rate is
# independent of how long a redraw pass takes.
readonly CPS=20 FRAME_MS=100

# stream = sentence + newline, repeated; the newline forces a line break so the
# sentence prints one (width-wrapped) line at a time.
readonly SLEN=$(( ${#SENTENCE} + 1 ))
# window width never exceeds the whole sentence (+3 incl. border slack)
readonly MAXW=$(( ${#SENTENCE} + 3 ))
REP="$SENTENCE"$'\n'
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
  TREE_OFF[$win]=$(( RANDOM % SLEN ))
  TREE_PAIR[$win]=$bc_pair
  new_panel "$win" >/dev/null

  # children: 0..2, placed at random spots inside this window (overlap allowed)
  if (( d < 3 )) && (( h > 12 && w > 24 )); then
    local n=$(( RANDOM % 3 )) i cy cx ch cw
    for (( i = 0; i < n; i++ )); do
      ch=$(( 6 + RANDOM % (h - 8) ))
      cw=$(( 12 + RANDOM % (w - 14) ))
      (( cw > MAXW )) && cw=$MAXW
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
  local iw=$(( w - 2 )) r pos=$off line seg nl pad
  for (( r = 1; r < h - 1; r++ )); do
    seg=${REP:pos:iw}
    if [[ $seg == *$'\n'* ]]; then
      line=${seg%%$'\n'*}; pos=$(( pos + ${#line} + 1 ))
    else
      line=$seg; pos=$(( pos + iw ))
    fi
    pad=$(( iw - ${#line} ))
    (( pad > 0 )) && { local sp; printf -v sp '%*s' "$pad" ''; line+="$sp"; }
    mvwaddstr "$win" "$r" 1 "$line"
  done
}

main() {
  initscr || exit 1
  cbreak
  curs_set 0
  if has_colors; then start_color; fi

  # scatter irregular top-level windows over the whole terminal (overlap ok);
  # each still spawns overlapping children inside make_window.
  local n=$(( (BC_LINES * BC_COLS) / 1500 )); (( n < 6 )) && n=6; (( n > 14 )) && n=14
  local i w h x y
  for (( i = 0; i < n; i++ )); do
    w=$(( 14 + RANDOM % (MAXW - 13) ))
    h=$(( 8 + RANDOM % 12 ))
    x=$(( RANDOM % (BC_COLS - w + 1) ))
    y=$(( RANDOM % (BC_LINES - h + 1) ))
    make_window "$y" "$x" "$h" "$w" 0
  done

  nodelay "$BC_STDSCR" 1
  local now el adv carry=0
  local last=${EPOCHREALTIME//[!0-9]/}
  while :; do
    local win
    for win in "${TREE_WINS[@]}"; do
      draw_window "$win"
    done
    doupdate
    napms "$FRAME_MS"
    now=${EPOCHREALTIME//[!0-9]/}
    el=$(( now - last )); last=$now
    adv=$(( (el * CPS + carry) / 1000000 ))
    carry=$(( (el * CPS + carry) % 1000000 ))
    (( adv > 0 )) && for win in "${TREE_WINS[@]}"; do
      TREE_OFF[$win]=$(( (TREE_OFF[$win] + adv) % SLEN ))
    done
    if wgetch "$BC_STDSCR"; then
      [[ $key == q || $key == Q ]] && break
    fi
  done

  endwin
}

main "$@"
