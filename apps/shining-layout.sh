# shining-layout: apps/shining.sh rewritten with lib/layout.sh.
# A screen full of random-sized, overlapping windows that each keep typing
# "All work and no play makes Jack a dull boy." on cream paper. Quit with q.
#
# Same picture as apps/shining.sh, but nothing computes a coordinate: the screen is
# one framed area split into cells, every window is a float placed at random
# inside a cell (or inside its parent window), and the library clamps,
# shadows, stacks and re-places them on resize.

source "${BASH_SOURCE[0]%/*}/../lib/layout.sh"

readonly SENTENCE="All work and no play makes Jack a dull boy."
readonly CPS=20 MAXW=$(( ${#SENTENCE} + 3 )) SLEN=$(( ${#SENTENCE} + 1 ))
REP="$SENTENCE"$'\n'
while (( ${#REP} < 4096 )); do REP+="$REP"; done
declare -A OFF=()
CARRY=0

bc_init
if (( BC_COLORS >= 256 )); then
  init_pair 1 16 230; init_pair 2 238 238          # cream paper, dark shadow
else
  init_pair 1 0 7;    init_pair 2 0 0
fi
BCL_SHADOW_PAIR=2

bc_screen "paper"
bc_style paper border pair=1

# n windows over the paper, each a little tree of overlapping windows
n=$(( LINES * COLS / 700 )); (( n < 12 )) && n=12; (( n > 48 )) && n=48
bc_cells paper "$n"

# a window with its top-left corner somewhere in its cell (it may overhang the
# cell but stays on the paper), plus 0..2 smaller windows inside it
grow() { # name in-area within-area size depth
  local fg=$(( RANDOM % 7 + 1 )) bg=$(( RANDOM % 8 )) pair=$(( RANDOM % 200 + 10 )) i
  (( fg == bg )) && bg=$(( (bg + 1) % 8 ))
  init_pair "$pair" "$fg" "$bg"
  bc_float "$1" in="$2" within="$3" at=random size="$4" border shadow pair=$pair
  OFF[$1]=$(( RANDOM % SLEN ))
  (( $5 < 2 )) || return
  for (( i = RANDOM % 3; i > 0; i-- )); do
    grow "$1.$i" "$1" "$1" "50%..85%x45%..85%" $(( $5 + 1 ))
  done
}
for (( i = 0; i < n; i++ )); do grow "w$i" "paper.$i" paper "8..19x14..$MAXW" 0; done

# each window types the sentence from its own offset, one line at a time
on_draw() {
  local a line seg pos r
  for a in "${!OFF[@]}"; do
    bc_size "$a"
    pos=${OFF[$a]}
    for (( r = 0; r < BCL_H; r++ )); do
      seg=${REP:pos:BCL_W}
      line=${seg%%$'\n'*}
      pos=$(( pos + ${#line} + (${#line} < ${#seg} ? 1 : 0) ))
      printf -v line '%-*s' "$BCL_W" "$line"    # pad: no separate clear needed
      bc_print "$a" "$r" 0 "$line"
    done
  done
}

on_tick() { # ms since the last frame -> advance CPS characters per second
  local adv=$(( ($1 * CPS + CARRY) / 1000 )) a
  CARRY=$(( ($1 * CPS + CARRY) % 1000 ))
  (( adv )) || return
  for a in "${!OFF[@]}"; do OFF[$a]=$(( (OFF[$a] + adv) % SLEN )); done
  bc_dirty all
}

on_key() { [[ $1 == q || $1 == Q ]] && bc_quit; }

bc_run fps=10
