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

make_window() { # y x h w depth   (h,w = visible box; panel is +1 row/col for shadow)
  local y=$1 x=$2 h=$3 w=$4 d=$5
  newwin "$(( h + 1 ))" "$(( w + 1 ))" "$y" "$x" || return 1
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
  getmaxyx "$win"; local H=$BC_GMY W=$BC_GMX
  local bh=$(( H - 1 )) bw=$(( W - 1 ))   # visible box (panel is +1 for the shadow)
  werase "$win"
  wattrset "$win" 0 "$pair"
  # box in the top-left bh x bw region
  local dash; printf -v dash '%*s' $(( bw - 2 )) ''; dash=${dash// /─}
  mvwaddch "$win" 0 0 '┌'; mvwaddch "$win" 0 $(( bw - 1 )) '┐'
  mvwaddch "$win" $(( bh - 1 )) 0 '└'; mvwaddch "$win" $(( bh - 1 )) $(( bw - 1 )) '┘'
  mvwaddstr "$win" 0 1 "$dash"; mvwaddstr "$win" $(( bh - 1 )) 1 "$dash"
  local r c sp
  for (( r = 1; r < bh - 1; r++ )); do
    mvwaddch "$win" "$r" 0 '│'; mvwaddch "$win" "$r" $(( bw - 1 )) '│'
  done
  # mc-style drop shadow, drawn INSIDE this panel (right col + bottom row) so it
  # composites at this window's z-level and is not hidden by windows below it.
  wattrset "$win" 0 "$SHADOW_PAIR"
  for (( r = 1; r <= bh; r++ )); do mvwaddch "$win" "$r" "$bw" '█' 0 "$SHADOW_PAIR"; done
  for (( c = 1; c <= bw; c++ )); do mvwaddch "$win" "$bh" "$c" '█' 0 "$SHADOW_PAIR"; done
  # scrolling text
  wattrset "$win" 0 "$pair"
  local iw=$(( bw - 2 )) pos=$off line seg nl pad
  for (( r = 1; r < bh - 1; r++ )); do
    seg=${REP:pos:iw}
    if [[ $seg == *$'\n'* ]]; then
      line=${seg%%$'\n'*}; pos=$(( pos + ${#line} + 1 ))
    else
      line=$seg; pos=$(( pos + iw ))
    fi
    pad=$(( iw - ${#line} ))
    (( pad > 0 )) && { printf -v sp '%*s' "$pad" ''; line+="$sp"; }
    mvwaddstr "$win" "$r" 1 "$line"
  done
}

main() {
  initscr || exit 1
  cbreak
  curs_set 0
  if has_colors; then
    start_color
    # warm cream "paper" screen background (256-color cube index 230), dark shadow
    if (( BC_COLORS >= 256 )); then init_pair 1 16 230; elif (( BC_COLORS >= 16 )); then init_pair 1 0 7; else init_pair 1 0 0; fi
    if (( BC_COLORS >= 256 )); then init_pair 2 238 238; else init_pair 2 0 0; fi
    if (( BC_COLORS >= 256 )); then init_pair 3 16 230; elif (( BC_COLORS >= 16 )); then init_pair 3 0 7; else init_pair 3 0 0; fi
    BG_PAIR=1 SHADOW_PAIR=2 BORDER_PAIR=3
    wbkgdset 0 ' ' 0 "$BG_PAIR"
    werase 0
  else
    BG_PAIR=0 SHADOW_PAIR=0 BORDER_PAIR=0
  fi
  new_panel "$BC_STDSCR" >/dev/null
  # frame the whole terminal with a border on stdscr (bottom panel)
  wattrset "$BC_STDSCR" 0 "$BORDER_PAIR"
  box "$BC_STDSCR"

  # spread top-level windows over a jittered grid covering the whole terminal so
  # they fill the screen evenly (jitter + oversized windows keep them overlapping
  # rather than clustering). Inset by 1 so the stdscr border stays visible.
  local n=$(( (BC_LINES * BC_COLS) / 700 )); (( n < 12 )) && n=12; (( n > 48 )) && n=48
  local gw=$(( BC_COLS / 46 + 1 ))
  local gh=$(( (n + gw - 1) / gw ))
  local cw=$(( (BC_COLS - 2) / gw ))
  local ch=$(( (BC_LINES - 2) / gh ))
  (( cw < 8 )) && cw=8; (( ch < 6 )) && ch=6
  local i w h x y gx gy
  for (( i = 0; i < n; i++ )); do
    if (( RANDOM % 2 )); then w=$MAXW; else w=$(( 14 + RANDOM % (MAXW - 13) )); fi
    h=$(( 8 + RANDOM % 12 ))
    (( w + 1 >= BC_COLS - 2 )) && w=$(( BC_COLS - 4 ))
    (( h + 1 >= BC_LINES - 2 )) && h=$(( BC_LINES - 4 ))
    gx=$(( i % gw )); gy=$(( i / gw ))
    x=$(( 1 + gx * cw + RANDOM % (cw > 2 ? cw - 1 : 1) ))
    y=$(( 1 + gy * ch + RANDOM % (ch > 2 ? ch - 1 : 1) ))
    (( x + w + 1 > BC_COLS - 1 )) && x=$(( BC_COLS - 2 - w - 1 ))
    (( y + h + 1 > BC_LINES - 1 )) && y=$(( BC_LINES - 2 - h - 1 ))
    (( x < 1 )) && x=1; (( y < 1 )) && y=1
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
