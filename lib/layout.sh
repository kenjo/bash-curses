# lib/layout.sh — declarative layout layer on top of lib/bc.sh.
#
# A screen is described by an ASCII template of area names; the library turns
# it into rectangles, one window per area, and keeps them laid out across
# terminal resizes. Overlapping windows (dialogs, popups) are "floats" placed
# relative to an area. Apps draw by area name and never compute coordinates.
#
#   bc_screen "
#     menu  menu
#     left  right
#     keys  keys
#   " rows="1 * 1" cols="* *"
#
# Track sizes (rows=/cols=): N fixed cells, * (or N*) share of the leftover
# space, auto = fit content (bc_text / nested grid minimum), 0 = hidden.
#
# Public names are bc_*; internal state uses the BCL_ prefix so it cannot
# collide with lib/bc.sh (which owns BC_*). Results come back in globals, never
# via command substitution, exactly like lib/bc.sh.

[[ -n ${BCL_LOADED:-} ]] && return 0
BCL_LOADED=1
[[ -n ${BC_LOADED:-} ]] || source "${BASH_SOURCE[0]%/*}/bc.sh"

# ---------------------------------------------------------------- state
# Grids are identified by the area they fill; the root grid is "screen".
declare -A BCL_KIND=()     # name -> screen | area | float
declare -A BCL_PARENT=()   # area -> grid it belongs to
declare -A BCL_KIDS=()     # grid -> "a b c" child areas (template order)
declare -A BCL_TPL=()      # grid -> template rows joined by '|', tokens by ' '
declare -A BCL_ROWSPEC=()  # grid -> "1 * 1"
declare -A BCL_COLSPEC=()  # grid -> "* *"
declare -A BCL_NR=() BCL_NC=()
declare -A BCL_GAP=()      # grid -> cells between tracks
declare -A BCL_BORDER=()   # grid -> inset on every side
declare -A BCL_CELLS=()    # grid -> N for bc_cells grids (template generated)
declare -A BCL_R0=() BCL_R1=() BCL_C0=() BCL_C1=()   # area span (track idx)
declare -A BCL_RY=() BCL_RX=() BCL_RH=() BCL_RW=()   # resolved outer rect
declare -A BCL_CH=() BCL_CW=()                       # measured content size
BCL_ERR=""

_bcl_err() { # msg
  BCL_ERR=$1
  printf 'layout: %s\n' "$1" >&2
  return 1
}

# ------------------------------------------------------------- parsing
# Validate a track list ("1 * 2* auto 0") against the expected count.
_bcl_check_tracks() { # who what spec count
  local who=$1 what=$2 spec=$3 n=$4 t c=0
  local -a _sp; read -r -a _sp <<< "$spec"
  for t in "${_sp[@]}"; do
    [[ $t =~ ^([0-9]+|[0-9]*\*|auto)$ ]] || { _bcl_err "$who: $what: bad track size '$t' (use N, *, N*, auto, 0)"; return 1; }
    c=$(( c + 1 ))
  done
  (( c == n )) || { _bcl_err "$who: $what has $c sizes but the template has $n"; return 1; }
  return 0
}

# Forget a grid's children (and their sub-grids) so it can be redefined.
_bcl_drop_kids() { # grid
  local g=$1 k
  for k in ${BCL_KIDS[$g]:-}; do
    [[ -n ${BCL_TPL[$k]+set} ]] && _bcl_drop_kids "$k"
    _bcl_forget "$k"
  done
  BCL_KIDS[$g]=""
}

# Drop a name's windows and every piece of state kept for it.
_bcl_forget() { # name
  local a=$1 k
  declare -F _bcl_unbind >/dev/null && _bcl_unbind "$a"
  for k in KIND PARENT R0 R1 C0 C1 RY RX RH RW TPL KIDS ROWSPEC COLSPEC NR NC GAP BORDER CELLS \
           CH CW PAIR ATTR FRAME TITLE SHADOW BPAIR TEXT TPAIR TATTR TALIGN NEEDDRAW \
           FIN FAT FSIZE FRND FKEYS; do
    unset "BCL_$k[$a]"
  done
}

# Parse a template into areas with rectangular spans.
_bcl_parse() { # who grid template
  local who=$1 g=$2 tpl=$3
  local -a lines=() toks=()
  local line r c nc=-1 name rows=""
  while IFS= read -r line; do
    line=${line//$'\t'/ }
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    read -r -a toks <<< "$line"
    if (( nc < 0 )); then nc=${#toks[@]}
    elif (( ${#toks[@]} != nc )); then
      _bcl_err "$who: template line $(( ${#lines[@]} + 1 )) has ${#toks[@]} cells, expected $nc"
      return 1
    fi
    lines+=("${toks[*]}")
  done <<< "$tpl"
  (( ${#lines[@]} )) || { _bcl_err "$who: empty template"; return 1; }

  local -A r0=() r1=() c0=() c1=() cnt=()
  local -a order=()
  for (( r = 0; r < ${#lines[@]}; r++ )); do
    read -r -a toks <<< "${lines[r]}"
    for (( c = 0; c < nc; c++ )); do
      name=${toks[c]}
      [[ $name == . ]] && continue
      [[ $name =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]] || { _bcl_err "$who: template line $(( r + 1 )): bad area name '$name'"; return 1; }
      [[ $name == screen ]] && { _bcl_err "$who: 'screen' is reserved"; return 1; }
      if [[ -z ${cnt[$name]+set} ]]; then
        if [[ -n ${BCL_KIND[$name]+set} && ${BCL_PARENT[$name]:-} != "$g" ]]; then
          _bcl_err "$who: area '$name' is already defined elsewhere"; return 1
        fi
        order+=("$name"); cnt[$name]=0
        r0[$name]=$r; r1[$name]=$r; c0[$name]=$c; c1[$name]=$c
      fi
      cnt[$name]=$(( cnt[$name] + 1 ))
      (( r > r1[$name] )) && r1[$name]=$r
      (( c < c0[$name] )) && c0[$name]=$c
      (( c > c1[$name] )) && c1[$name]=$c
    done
  done
  # every area must fill its bounding box exactly (a rectangle)
  for name in "${order[@]}"; do
    if (( cnt[$name] != (r1[$name] - r0[$name] + 1) * (c1[$name] - c0[$name] + 1) )); then
      _bcl_err "$who: area '$name' is not a rectangle (rows $(( r0[$name] + 1 ))-$(( r1[$name] + 1 )), cols $(( c0[$name] + 1 ))-$(( c1[$name] + 1 )))"
      return 1
    fi
    for (( r = r0[$name]; r <= r1[$name]; r++ )); do
      read -r -a toks <<< "${lines[r]}"
      for (( c = c0[$name]; c <= c1[$name]; c++ )); do
        [[ ${toks[c]} == "$name" ]] && continue
        _bcl_err "$who: area '$name' is not a rectangle ('${toks[c]}' at line $(( r + 1 )), col $(( c + 1 )))"
        return 1
      done
    done
  done

  # commit: keep areas that survive a redefinition (their windows stay bound)
  local k
  for k in ${BCL_KIDS[$g]:-}; do
    [[ -n ${cnt[$k]+set} ]] && continue
    [[ -n ${BCL_TPL[$k]+set} ]] && _bcl_drop_kids "$k"
    _bcl_forget "$k"
  done
  local IFS='|'
  BCL_TPL[$g]="${lines[*]}"
  IFS=' '
  BCL_NR[$g]=${#lines[@]}
  BCL_NC[$g]=$nc
  BCL_KIDS[$g]="${order[*]}"
  for name in "${order[@]}"; do
    BCL_KIND[$name]=area
    BCL_PARENT[$name]=$g
    BCL_R0[$name]=${r0[$name]}; BCL_R1[$name]=${r1[$name]}
    BCL_C0[$name]=${c0[$name]}; BCL_C1[$name]=${c1[$name]}
  done
  return 0
}

# Shared option parsing for bc_screen / bc_grid.
_bcl_define() { # who grid template opts...
  local who=$1 g=$2 tpl=$3; shift 3
  local rows="" cols="" gap=0 border=0 o
  for o in "$@"; do
    case $o in
      rows=*)   rows=${o#rows=} ;;
      cols=*)   cols=${o#cols=} ;;
      gap=*)    gap=${o#gap=} ;;
      border=*) border=${o#border=} ;;
      *) _bcl_err "$who: unknown option '$o'"; return 1 ;;
    esac
  done
  [[ $gap =~ ^[0-9]+$ && $border =~ ^[0-9]+$ ]] || { _bcl_err "$who: gap/border must be numbers"; return 1; }
  _bcl_parse "$who" "$g" "$tpl" || return 1
  local n
  if [[ -z $rows ]]; then rows=""; for (( n = 0; n < BCL_NR[$g]; n++ )); do rows+="* "; done; fi
  if [[ -z $cols ]]; then cols=""; for (( n = 0; n < BCL_NC[$g]; n++ )); do cols+="* "; done; fi
  _bcl_check_tracks "$who" rows "$rows" "${BCL_NR[$g]}" || return 1
  _bcl_check_tracks "$who" cols "$cols" "${BCL_NC[$g]}" || return 1
  BCL_ROWSPEC[$g]=$rows
  BCL_COLSPEC[$g]=$cols
  BCL_GAP[$g]=$gap
  BCL_BORDER[$g]=$border
  BCL_LAYOUT_DIRTY=1
  return 0
}

# bc_screen TEMPLATE [rows=…] [cols=…] [gap=N] [border=N]
bc_screen() {
  BCL_KIND[screen]=screen
  unset "BCL_CELLS[screen]"
  _bcl_define bc_screen screen "$@"
}

# bc_grid AREA TEMPLATE [rows=…] [cols=…] [gap=N] [border=N]
# Splits an existing area into its own template (the area gets no window).
bc_grid() {
  local a=$1; shift
  [[ -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_grid: unknown area '$a'"; return 1; }
  unset "BCL_CELLS[$a]"
  _bcl_define "bc_grid $a" "$a" "$@"
}

# bc_cells AREA N [gap=N] — split an area into N roughly square cells named
# AREA.0 … AREA.N-1. The rows x cols shape follows the area's aspect ratio and
# is recomputed on every relayout.
bc_cells() {
  local a=$1 n=$2; shift 2
  [[ -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_cells: unknown area '$a'"; return 1; }
  [[ $n =~ ^[1-9][0-9]*$ ]] || { _bcl_err "bc_cells: bad count '$n'"; return 1; }
  # provisional single-row shape; the real one is chosen at resolve time
  _bcl_cells_tpl "$a" "$n" "$n" || return 1
  _bcl_define "bc_cells $a" "$a" "$BCL_T" "$@" || return 1
  BCL_CELLS[$a]=$n
}

_bcl_cells_tpl() { # area n ncols -> BCL_T
  local a=$1 n=$2 nc=$3 i r line
  BCL_T=""
  for (( r = 0; r * nc < n; r++ )); do
    line=""
    for (( i = r * nc; i < (r + 1) * nc; i++ )); do
      if (( i < n )); then line+="$a.$i "; else line+=". "; fi
    done
    BCL_T+="$line"$'\n'
  done
}

# ------------------------------------------------------------- solving
# Minimum extent of an area along an axis (0 = rows/height, 1 = cols/width):
# measured content for leaves, fixed+auto tracks for nested grids.
_bcl_min() { # area axis -> BCL_M
  local a=$1 ax=$2
  if [[ -z ${BCL_TPL[$a]+set} ]]; then
    if (( ax == 0 )); then BCL_M=${BCL_CH[$a]:-0}; else BCL_M=${BCL_CW[$a]:-0}; fi
    return 0
  fi
  local spec
  if (( ax == 0 )); then spec=${BCL_ROWSPEC[$a]}; else spec=${BCL_COLSPEC[$a]}; fi
  _bcl_auto_sizes "$a" "$ax"
  local -a au=("${BCL_AU[@]}")
  local t i=0 sum=0 vis=0
  local -a _sp; read -r -a _sp <<< "$spec"
  for t in "${_sp[@]}"; do
    case $t in
      auto) sum=$(( sum + au[i] )); vis=$(( vis + 1 )) ;;
      *\*)  vis=$(( vis + 1 )) ;;
      0)    ;;
      *)    sum=$(( sum + t )); vis=$(( vis + 1 )) ;;
    esac
    i=$(( i + 1 ))
  done
  (( vis > 1 )) && sum=$(( sum + BCL_GAP[$a] * (vis - 1) ))
  _bcl_insets "$a"
  if (( ax == 0 )); then sum=$(( sum + BCL_IT + BCL_IB )); else sum=$(( sum + BCL_IL + BCL_IR )); fi
  BCL_M=$(( sum + 2 * BCL_BORDER[$a] ))
}

# Content size of each track of a grid along an axis (for auto tracks): the
# largest minimum of the areas that span only that track.
_bcl_auto_sizes() { # grid axis -> BCL_AU (indexed)
  local g=$1 ax=$2 k i n lo hi
  local -a au=()
  if (( ax == 0 )); then n=${BCL_NR[$g]}; else n=${BCL_NC[$g]}; fi
  for (( i = 0; i < n; i++ )); do au[i]=0; done
  for k in ${BCL_KIDS[$g]}; do
    if (( ax == 0 )); then lo=${BCL_R0[$k]}; hi=${BCL_R1[$k]}; else lo=${BCL_C0[$k]}; hi=${BCL_C1[$k]}; fi
    (( lo == hi )) || continue
    _bcl_min "$k" "$ax"
    (( BCL_M > au[lo] )) && au[lo]=$BCL_M
  done
  BCL_AU=("${au[@]}")
}

# Distribute TOTAL cells over a track list. Fixed and auto tracks get their
# size first (shrinking from the last track if they overflow); the rest is split
# by weight, with rounding leftovers going to the first weighted tracks so the
# tracks always tile TOTAL exactly.
_bcl_tracks() { # spec total gap -> BCL_TS BCL_TP (relative positions); uses BCL_AU
  local spec=$1 total=$2 gap=$3
  local -a sz=() wt=()
  local t i=0 n vis=0 fixed=0 wsum=0
  local -a _sp; read -r -a _sp <<< "$spec"
  for t in "${_sp[@]}"; do
    wt[i]=0
    case $t in
      auto) sz[i]=${BCL_AU[i]:-0}; vis=$(( vis + 1 )) ;;
      \*)   sz[i]=0; wt[i]=1; vis=$(( vis + 1 )) ;;
      *\*)  sz[i]=0; wt[i]=${t%\*}; vis=$(( vis + 1 )) ;;
      0)    sz[i]=0 ;;
      *)    sz[i]=$t; vis=$(( vis + 1 )) ;;
    esac
    fixed=$(( fixed + sz[i] )); wsum=$(( wsum + wt[i] ))
    i=$(( i + 1 ))
  done
  n=$i
  local avail=$total
  (( vis > 1 )) && avail=$(( avail - gap * (vis - 1) ))
  (( avail < 0 )) && avail=0
  local over=$(( fixed - avail ))
  for (( i = n - 1; i >= 0 && over > 0; i-- )); do
    if (( sz[i] >= over )); then sz[i]=$(( sz[i] - over )); over=0
    else over=$(( over - sz[i] )); sz[i]=0; fi
  done
  local left=$(( avail - fixed ))
  if (( left > 0 && wsum > 0 )); then
    local used=0
    for (( i = 0; i < n; i++ )); do
      (( wt[i] )) || continue
      sz[i]=$(( left * wt[i] / wsum )); used=$(( used + sz[i] ))
    done
    for (( i = 0; i < n && used < left; i++ )); do
      (( wt[i] )) || continue
      sz[i]=$(( sz[i] + 1 )); used=$(( used + 1 ))
    done
  fi
  local pos=0
  local -a tp=() sp
  read -r -a sp <<< "$spec"
  for (( i = 0; i < n; i++ )); do
    tp[i]=$pos
    [[ ${sp[i]} == 0 ]] || pos=$(( pos + sz[i] + gap ))
  done
  BCL_TS=("${sz[@]}")
  BCL_TP=("${tp[@]}")
}

# Choose a rows x cols shape for a bc_cells grid from the area's aspect ratio
# (a terminal cell is about twice as tall as it is wide).
_bcl_cells_shape() { # grid h w
  local g=$1 h=$2 w=$3 n=${BCL_CELLS[$g]} nc=1 c nr d best=-1
  (( h < 1 )) && h=1
  # cell width w/c should be about twice the cell height h/nr: minimise
  # |w*nr - 2*h*c| over the column counts
  for (( c = 1; c <= n; c++ )); do
    nr=$(( (n + c - 1) / c ))
    d=$(( w * nr - 2 * h * c )); (( d < 0 )) && d=$(( -d ))
    if (( best < 0 || d < best )); then best=$d; nc=$c; fi
  done
  if (( nc != BCL_NC[$g] )); then
    _bcl_cells_tpl "$g" "$n" "$nc"
    local rows="" cols="" i
    _bcl_parse "bc_cells $g" "$g" "$BCL_T" || return 1
    for (( i = 0; i < BCL_NR[$g]; i++ )); do rows+="* "; done
    for (( i = 0; i < BCL_NC[$g]; i++ )); do cols+="* "; done
    BCL_ROWSPEC[$g]=$rows; BCL_COLSPEC[$g]=$cols
  fi
}

# Lay out a grid inside a rectangle, then recurse into nested grids.
_bcl_layout_grid() { # grid y x h w
  local g=$1 y=$2 x=$3 h=$4 w=$5
  BCL_RY[$g]=$y; BCL_RX[$g]=$x; BCL_RH[$g]=$h; BCL_RW[$g]=$w
  local b=${BCL_BORDER[$g]:-0}
  _bcl_insets "$g"
  y=$(( y + b + BCL_IT )); x=$(( x + b + BCL_IL ))
  h=$(( h - 2 * b - BCL_IT - BCL_IB )); w=$(( w - 2 * b - BCL_IL - BCL_IR ))
  (( h < 0 )) && h=0
  (( w < 0 )) && w=0
  [[ -n ${BCL_CELLS[$g]:-} ]] && { _bcl_cells_shape "$g" "$h" "$w" || return 1; }
  _bcl_auto_sizes "$g" 0
  _bcl_tracks "${BCL_ROWSPEC[$g]}" "$h" "${BCL_GAP[$g]}"
  local -a rs=("${BCL_TS[@]}") rp=("${BCL_TP[@]}")
  _bcl_auto_sizes "$g" 1
  _bcl_tracks "${BCL_COLSPEC[$g]}" "$w" "${BCL_GAP[$g]}"
  local -a cs=("${BCL_TS[@]}") cp=("${BCL_TP[@]}")
  local k ky kx kh kw r0 r1 c0 c1
  for k in ${BCL_KIDS[$g]}; do
    r0=${BCL_R0[$k]} r1=${BCL_R1[$k]} c0=${BCL_C0[$k]} c1=${BCL_C1[$k]}
    ky=$(( y + rp[r0] )); kh=$(( rp[r1] + rs[r1] - rp[r0] ))
    kx=$(( x + cp[c0] )); kw=$(( cp[c1] + cs[c1] - cp[c0] ))
    (( kh < 0 )) && kh=0
    (( kw < 0 )) && kw=0
    if [[ -n ${BCL_TPL[$k]+set} ]]; then
      _bcl_layout_grid "$k" "$ky" "$kx" "$kh" "$kw" || return 1
    else
      BCL_RY[$k]=$ky; BCL_RX[$k]=$kx; BCL_RH[$k]=$kh; BCL_RW[$k]=$kw
    fi
  done
}

# Compute every rectangle from the current terminal size.
_bcl_resolve() {
  [[ -n ${BCL_TPL[screen]+set} ]] || { _bcl_err "no screen defined (call bc_screen first)"; return 1; }
  _bcl_layout_grid screen 0 0 "$BC_LINES" "$BC_COLS" || return 1
  declare -F _bcl_place_floats >/dev/null && _bcl_place_floats
  BCL_LAYOUT_DIRTY=0
  return 0
}

# bc_rect NAME -> BCL_Y BCL_X BCL_H BCL_W (screen coordinates, outer rect)
bc_rect() {
  local a=$1
  [[ -n ${BCL_RY[$a]+set} ]] || { _bcl_err "bc_rect: '$a' has no rectangle"; return 1; }
  BCL_Y=${BCL_RY[$a]} BCL_X=${BCL_RX[$a]} BCL_H=${BCL_RH[$a]} BCL_W=${BCL_RW[$a]}
}

# ============================================================ windows
# Every visible leaf area (and float) is bound to a frame window F that is a
# panel. If a leaf has a border, the drawable content is a derwin C of F inset
# by it, stacked as its own panel right above F (doupdate only collects dirty
# cells from panel windows). Otherwise C == F. A shadow is two more windows.
declare -A BCL_WIN=()     # name -> content window (what apps draw into)
declare -A BCL_FWIN=()    # name -> frame window
declare -A BCL_PANS=()    # name -> its panels, bottom -> top
declare -A BCL_WINS=()    # name -> its windows, derwins before their parent
declare -A BCL_SWINS=()   # name -> shadow strip windows
declare -A BCL_WRECT=()   # name -> "y x h w" the windows were built for
declare -A BCL_NEEDDRAW=()
# style
declare -A BCL_PAIR=() BCL_ATTR=() BCL_FRAME=() BCL_TITLE=() BCL_SHADOW=() BCL_BPAIR=()
# retained text (bc_text) — replayed whenever the window is rebuilt
declare -A BCL_TEXT=() BCL_TPAIR=() BCL_TATTR=() BCL_TALIGN=()
BCL_LAYOUT_DIRTY=0
BCL_STARTED=0

# Insets of an area's content inside its rectangle.
_bcl_insets() { # name -> BCL_IT BCL_IL BCL_IB BCL_IR
  local a=$1 f=${BCL_FRAME[$1]:-0} s=${BCL_SHADOW[$1]:-0}
  BCL_IT=$f BCL_IL=$f BCL_IB=$(( f + s )) BCL_IR=$(( f + s ))
}

# Does a name get windows? Leaves always; containers only when they have
# something to show themselves (floats, borders, shadows, colours).
_bcl_bindable() { # name
  local a=$1
  [[ $a == screen ]] && return 1
  [[ -z ${BCL_TPL[$a]+set} ]] && return 0
  [[ ${BCL_KIND[$a]} == float || -n ${BCL_FRAME[$a]:-} || -n ${BCL_SHADOW[$a]:-} || -n ${BCL_PAIR[$a]:-} || -n ${BCL_ATTR[$a]:-} || -n ${BCL_TITLE[$a]:-} ]]
}

# Every bindable name in stacking order (bottom -> top) -> BCL_LV: the tiled
# tree depth first (a container's frame below its kids), then each float with
# its own sub-tree, in float order.
_bcl_order() {
  BCL_LV=()
  _bcl_order_tree screen
  local f
  for f in ${BCL_FLOATS:-}; do _bcl_order_tree "$f"; done
}
_bcl_order_tree() { # name
  local k
  _bcl_bindable "$1" && BCL_LV+=("$1")
  for k in ${BCL_KIDS[$1]:-}; do _bcl_order_tree "$k"; done
}

# Effective pen: own pair/attr, else inherited from the enclosing grids.
_bcl_eff() { # name -> BCL_EP BCL_EA
  local a=$1
  BCL_EP="" BCL_EA=""
  while [[ -n $a ]]; do
    [[ -z $BCL_EP && -n ${BCL_PAIR[$a]:-} ]] && BCL_EP=${BCL_PAIR[$a]}
    [[ -z $BCL_EA && -n ${BCL_ATTR[$a]:-} ]] && BCL_EA=${BCL_ATTR[$a]}
    a=${BCL_PARENT[$a]:-}
  done
  BCL_EP=${BCL_EP:-0} BCL_EA=${BCL_EA:-0}
}

_bcl_unbind() { # name
  local a=$1 p w
  [[ -n ${BCL_FWIN[$a]:-} ]] || return 0
  for p in ${BCL_PANS[$a]}; do del_panel "$p"; done
  for w in ${BCL_WINS[$a]}; do delwin "$w"; done
  unset "BCL_WIN[$a]" "BCL_FWIN[$a]" "BCL_PANS[$a]" "BCL_WINS[$a]" "BCL_SWINS[$a]" "BCL_WRECT[$a]"
}

# Paint the frame window (background, border, title) and the shadow strips.
_bcl_paint_frame() { # name
  local a=$1 f=${BCL_FWIN[$1]} sw
  _bcl_eff "$a"
  local bh=${BC_WH[$f]} bw=${BC_WW[$f]} p=$BCL_EP at=$BCL_EA
  wbkgd "$f" ' ' "$at" "$p"
  werase "$f"
  if (( ${BCL_FRAME[$a]:-0} && bh >= 2 && bw >= 2 )); then
    local bp=${BCL_BPAIR[$a]:-$p} r line
    printf -v line '%*s' $(( bw - 2 )) ''; line=${line// /$ACS_HLINE}
    wattrset "$f" "$at" "$bp"
    mvwaddstr "$f" 0 0 "$ACS_ULCORNER$line$ACS_URCORNER"
    for (( r = 1; r < bh - 1; r++ )); do
      mvwaddch "$f" "$r" 0 "$ACS_VLINE"; mvwaddch "$f" "$r" $(( bw - 1 )) "$ACS_VLINE"
    done
    mvwaddstr "$f" $(( bh - 1 )) 0 "$ACS_LLCORNER$line"
    mvwaddch "$f" $(( bh - 1 )) $(( bw - 1 )) "$ACS_LRCORNER"
    if [[ -n ${BCL_TITLE[$a]:-} ]]; then
      local t=" ${BCL_TITLE[$a]} "
      # too long: keep the end (paths read best from the right)
      (( ${#t} > bw - 2 )) && t=" …${t:${#t}-(bw-5)}"
      mvwaddstr "$f" 0 $(( (bw - ${#t}) / 2 )) "$t"
    fi
    wattrset "$f" "$at" "$p"
  fi
  local sp=${BCL_SHADOW_PAIR:-0} sa=0
  (( sp )) || sa=$A_REVERSE
  for sw in ${BCL_SWINS[$a]:-}; do
    wbkgd "$sw" ' ' "$sa" "$sp"; werase "$sw"
  done
}

# Build the windows for a rectangle: frame (the box), content derwin inset by
# the border (leaves only), and the shadow as two strips right and below the
# box — leaving the two outer corners uncovered so the screen shows through.
_bcl_bind() { # name y x h w
  local a=$1 y=$2 x=$3 h=$4 w=$5
  local s=${BCL_SHADOW[$a]:-0} fr=${BCL_FRAME[$a]:-0}
  (( h <= s || w <= s )) && s=0
  local bh=$(( h - s )) bw=$(( w - s )) pans="" wins=""
  newwin "$bh" "$bw" "$y" "$x" || return 1
  local f=$bc_win
  new_panel "$f"; pans=$bc_panel
  BCL_FWIN[$a]=$f; BCL_WIN[$a]=$f
  if [[ -z ${BCL_TPL[$a]+set} ]] && (( fr )); then
    local ch=$(( bh - 2 )) cw=$(( bw - 2 ))
    if (( ch > 0 && cw > 0 )) && derwin "$f" "$ch" "$cw" 1 1; then
      BCL_WIN[$a]=$bc_win
      new_panel "$bc_win"; pans+=" $bc_panel"; wins="$bc_win "
    fi
  fi
  wins+=$f
  BCL_SWINS[$a]=""
  if (( s )); then
    newwin "$bh" 1 $(( y + 1 )) $(( x + bw )) && { new_panel "$bc_win"; pans+=" $bc_panel"; wins+=" $bc_win"; BCL_SWINS[$a]+=" $bc_win"; }
    if (( bw > 1 )); then
      newwin 1 $(( bw - 1 )) $(( y + bh )) $(( x + 1 )) && { new_panel "$bc_win"; pans+=" $bc_panel"; wins+=" $bc_win"; BCL_SWINS[$a]+=" $bc_win"; }
    fi
  fi
  BCL_PANS[$a]=$pans BCL_WINS[$a]=$wins
  local c=${BCL_WIN[$a]}
  _bcl_eff "$a"
  wbkgd "$c" ' ' "$BCL_EA" "$BCL_EP"
  wattrset "$c" "$BCL_EA" "$BCL_EP"
  _bcl_paint_frame "$a"
  BCL_WRECT[$a]="$y $x $h $w"
  BCL_NEEDDRAW[$a]=1
}

# Put the layout's panels in order: tiled areas at the bottom, panels created
# directly by the app in the middle, floats on top (in float order).
_bcl_restack() {
  local -A mine=() isf=()
  local -a low=() high=() mid=() ns=()
  local a p f
  # names inside floats (the float itself and its sub-tree) go on top
  for f in ${BCL_FLOATS:-}; do isf[$f]=1; done
  _bcl_order
  for a in "${BCL_LV[@]}"; do
    [[ -n ${BCL_PANS[$a]:-} ]] || continue
    f=$a
    while [[ -n ${BCL_PARENT[$f]:-} ]]; do f=${BCL_PARENT[$f]}; done
    for p in ${BCL_PANS[$a]}; do mine[$p]=1; done
    if [[ -n ${isf[$f]:-} ]]; then high+=(${BCL_PANS[$a]}); else low+=(${BCL_PANS[$a]}); fi
  done
  for p in "${BC_PSTACK[@]}"; do [[ -n ${mine[$p]:-} ]] || mid+=("$p"); done
  ns=("${low[@]}" "${mid[@]}" "${high[@]}")
  if [[ "${ns[*]}" != "${BC_PSTACK[*]}" ]]; then
    BC_PSTACK=("${ns[@]}")
    _bc_stack_dirty
  fi
}

# bc_relayout — recompute every rectangle and rebuild only the windows whose
# rectangle changed (rebuilding is far cheaper than wresize/mvwin here).
bc_relayout() {
  _bcl_resolve || return 1
  _bcl_order
  local a key
  for a in "${BCL_LV[@]}"; do
    key="${BCL_RY[$a]} ${BCL_RX[$a]} ${BCL_RH[$a]} ${BCL_RW[$a]}"
    [[ ${BCL_WRECT[$a]:-} == "$key" ]] && continue
    _bcl_unbind "$a"
    (( BCL_RH[$a] > 0 && BCL_RW[$a] > 0 )) || continue
    _bcl_bind "$a" "${BCL_RY[$a]}" "${BCL_RX[$a]}" "${BCL_RH[$a]}" "${BCL_RW[$a]}"
  done
  _bcl_restack
  return 0
}

# ------------------------------------------------------------ styling
# bc_style NAME [pair=N] [attr=N] [border|border=0] [title=TEXT] [bpair=N] [shadow|shadow=0]
# "screen" styles the background (stdscr).
bc_style() {
  local a=$1 o; shift
  [[ $a == screen || -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_style: unknown area '$a'"; return 1; }
  local geom=0
  for o in "$@"; do
    case $o in
      pair=*)   BCL_PAIR[$a]=${o#*=} ;;
      attr=*)   BCL_ATTR[$a]=${o#*=} ;;
      bpair=*)  BCL_BPAIR[$a]=${o#*=} ;;
      title=*)  BCL_TITLE[$a]=${o#*=} ;;
      border)   BCL_FRAME[$a]=1; geom=1 ;;
      border=*) BCL_FRAME[$a]=$(( ${o#*=} ? 1 : 0 )); geom=1 ;;
      shadow)   BCL_SHADOW[$a]=1; geom=1 ;;
      shadow=*) BCL_SHADOW[$a]=$(( ${o#*=} ? 1 : 0 )); geom=1 ;;
      *) _bcl_err "bc_style: unknown option '$o'"; return 1 ;;
    esac
  done
  if [[ $a == screen ]]; then
    wbkgd "$BC_STDSCR" ' ' "${BCL_ATTR[screen]:-0}" "${BCL_PAIR[screen]:-0}"
    werase "$BC_STDSCR"
    return 0
  fi
  # insets changed -> rebuild the windows; otherwise just repaint in place
  if (( geom )); then
    unset "BCL_WRECT[$a]"; BCL_LAYOUT_DIRTY=1
    # content size includes the insets: re-measure retained text
    [[ -n ${BCL_TEXT[$a]+set} ]] && bc_text "$a" "${BCL_TEXT[$a]}" pair="${BCL_TPAIR[$a]}" attr="${BCL_TATTR[$a]}" align="${BCL_TALIGN[$a]}"
  else
    # repaint this area and everything inheriting its colours
    _bcl_order
    local n p
    for n in "${BCL_LV[@]}"; do
      p=$n
      while [[ -n $p && $p != "$a" ]]; do p=${BCL_PARENT[$p]:-}; done
      [[ $p == "$a" && -n ${BCL_FWIN[$n]:-} ]] || continue
      _bcl_eff "$n"
      wbkgd "${BCL_WIN[$n]}" ' ' "$BCL_EA" "$BCL_EP"
      wattrset "${BCL_WIN[$n]}" "$BCL_EA" "$BCL_EP"
      _bcl_paint_frame "$n"
      BCL_NEEDDRAW[$n]=1
    done
    # a container that just became visible needs a window
    _bcl_bindable "$a" && [[ -z ${BCL_FWIN[$a]:-} ]] && BCL_LAYOUT_DIRTY=1
  fi
}

# ------------------------------------------------------------ drawing
# bc_win NAME -> bc_win = content window handle (use any lib/bc.sh call on it).
# Returns 1 if the area is currently hidden (no window).
bc_win() {
  bc_win=${BCL_WIN[$1]:-}
  [[ -n $bc_win ]]
}

# bc_size NAME -> BCL_H BCL_W (drawable content size; 0 0 when hidden)
bc_size() {
  if [[ -n ${BCL_WIN[$1]:-} ]]; then
    BCL_H=${BC_WH[${BCL_WIN[$1]}]} BCL_W=${BC_WW[${BCL_WIN[$1]}]}
  else
    BCL_H=0 BCL_W=0
  fi
}

_bcl_pen() { # name opts... -> BCL_PA BCL_PP BCL_AL (attr, pair, align)
  local a=$1 o; shift
  _bcl_eff "$a"
  BCL_PA=$BCL_EA BCL_PP=$BCL_EP BCL_AL=left
  for o in "$@"; do
    case $o in
      pair=*)  BCL_PP=${o#*=} ;;
      attr=*)  BCL_PA=${o#*=} ;;
      align=*) BCL_AL=${o#*=} ;;
      *) _bcl_err "unknown option '$o'"; return 1 ;;
    esac
  done
}

# Write one clipped string into a content window.
_bcl_put() { # win y x str attr pair
  local c=$1 y=$2 x=$3 s=$4
  local w=${BC_WW[$c]}
  (( y < 0 || y >= BC_WH[$c] || x >= w )) && return 0
  if (( x < 0 )); then s=${s:$(( -x ))}; x=0; fi
  (( ${#s} > w - x )) && s=${s:0:w-x}
  [[ -n $s ]] || return 0
  wattrset "$c" "$5" "$6"
  mvwaddstr "$c" "$y" "$x" "$s"
}

# bc_print NAME Y X TEXT [pair=N] [attr=N] — clipped to the area (no wrap).
bc_print() {
  local a=$1 y=$2 x=$3 s=$4; shift 4
  local c=${BCL_WIN[$a]:-}
  [[ -n $c ]] || return 0
  _bcl_pen "$a" "$@" || return 1
  _bcl_put "$c" "$y" "$x" "$s" "$BCL_PA" "$BCL_PP"
  _bcl_eff "$a"; wattrset "$c" "$BCL_EA" "$BCL_EP"
}

# bc_clear NAME — erase the content to the area background.
bc_clear() {
  local c=${BCL_WIN[$1]:-}
  [[ -n $c ]] && werase "$c"
  return 0
}

# bc_text NAME TEXT [pair=N] [attr=N] [align=left|center|right]
# Sets the area's content: it is measured (auto tracks and auto-sized floats
# fit it), drawn now, and redrawn automatically whenever the window is rebuilt.
bc_text() {
  local a=$1 t=$2; shift 2
  [[ -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_text: unknown area '$a'"; return 1; }
  _bcl_pen "$a" "$@" || return 1
  BCL_TEXT[$a]=$t BCL_TPAIR[$a]=$BCL_PP BCL_TATTR[$a]=$BCL_PA BCL_TALIGN[$a]=$BCL_AL
  local line n=0 mw=0
  while IFS= read -r line; do
    n=$(( n + 1 )); (( ${#line} > mw )) && mw=${#line}
  done <<< "$t"
  _bcl_insets "$a"
  n=$(( n + BCL_IT + BCL_IB )); mw=$(( mw + BCL_IL + BCL_IR ))
  if [[ ${BCL_CH[$a]:-} != "$n" || ${BCL_CW[$a]:-} != "$mw" ]]; then
    BCL_CH[$a]=$n BCL_CW[$a]=$mw
    _bcl_content_sized "$a" && BCL_LAYOUT_DIRTY=1
  fi
  _bcl_draw_text "$a"
}

# Can NAME's content size change the layout? True when it (or an enclosing
# grid) sits alone in an auto track, or it is (inside) an auto-sized float.
_bcl_content_sized() { # name
  local a=$1 g t
  local -a sp
  while [[ -n $a && $a != screen ]]; do
    if [[ ${BCL_KIND[$a]:-} == float ]]; then
      [[ ${BCL_FSIZE[$a]} == *auto* ]] && return 0
      a=${BCL_FIN[$a]}; continue
    fi
    g=${BCL_PARENT[$a]:-}
    [[ -n $g ]] || return 1
    if (( BCL_R0[$a] == BCL_R1[$a] )); then
      read -r -a sp <<< "${BCL_ROWSPEC[$g]}"; [[ ${sp[BCL_R0[$a]]} == auto ]] && return 0
    fi
    if (( BCL_C0[$a] == BCL_C1[$a] )); then
      read -r -a sp <<< "${BCL_COLSPEC[$g]}"; [[ ${sp[BCL_C0[$a]]} == auto ]] && return 0
    fi
    a=$g
  done
  return 1
}

_bcl_draw_text() { # name
  local a=$1 c=${BCL_WIN[$1]:-} line r=0 x w
  [[ -n $c ]] || return 0
  werase "$c"
  w=${BC_WW[$c]}
  while IFS= read -r line; do
    case ${BCL_TALIGN[$a]} in
      center) x=$(( (w - ${#line}) / 2 )) ;;
      right)  x=$(( w - ${#line} )) ;;
      *)      x=0 ;;
    esac
    (( x < 0 )) && x=0
    _bcl_put "$c" "$r" "$x" "$line" "${BCL_TATTR[$a]}" "${BCL_TPAIR[$a]}"
    r=$(( r + 1 ))
  done <<< "${BCL_TEXT[$a]}"
  _bcl_eff "$a"; wattrset "$c" "$BCL_EA" "$BCL_EP"
}

# bc_dirty NAME... — ask for NAME to be redrawn (draw_NAME / on_draw) before
# the next screen update. "all" marks every bound area.
bc_dirty() {
  local a
  for a in "$@"; do
    if [[ $a == all ]]; then
      for a in "${!BCL_WIN[@]}"; do BCL_NEEDDRAW[$a]=1; done
      return 0
    fi
    BCL_NEEDDRAW[$a]=1
  done
}

# Redraw what needs it: retained text, then draw_NAME functions (called on a
# freshly cleared area, so they always describe its whole content), then on_draw
# (once, if anything at all was pending). Returns 1 if nothing was pending.
_bcl_draw_pending() {
  local a any=0
  for a in "${!BCL_NEEDDRAW[@]}"; do
    unset "BCL_NEEDDRAW[$a]"
    [[ -n ${BCL_WIN[$a]:-} ]] || continue
    any=1
    if [[ -n ${BCL_TEXT[$a]+set} ]]; then
      _bcl_draw_text "$a"
    elif declare -F "draw_$a" >/dev/null; then
      werase "${BCL_WIN[$a]}"
    fi
    declare -F "draw_$a" >/dev/null && "draw_$a" "$a"
  done
  (( any )) || return 1
  declare -F on_draw >/dev/null && on_draw
  return 0
}

# bc_update — relayout if needed, redraw what is pending, push to the terminal.
bc_update() {
  (( BCL_LAYOUT_DIRTY )) && bc_relayout
  _bcl_draw_pending
  doupdate
}

# ------------------------------------------------------------ input
# Which area (topmost) is at screen cell y,x -> BCL_AREA, BCL_MY, BCL_MX
# (coordinates relative to the area's content). BCL_AREA="" if none.
bc_hit() {
  local y=$1 x=$2 a i
  BCL_AREA="" BCL_MY=-1 BCL_MX=-1
  _bcl_order
  for (( i = ${#BCL_LV[@]} - 1; i >= 0; i-- )); do
    a=${BCL_LV[i]}
    [[ -n ${BCL_FWIN[$a]:-} ]] || continue
    _bcl_in "$a" "$y" "$x" && return 0
  done
  return 1
}

_bcl_in() { # name y x
  local a=$1 y=$2 x=$3 f=${BCL_FWIN[$1]} c=${BCL_WIN[$1]}
  (( y >= BC_WY[$f] && y < BC_WY[$f] + BC_WH[$f] && x >= BC_WX[$f] && x < BC_WX[$f] + BC_WW[$f] )) || return 1
  BCL_AREA=$a BCL_MY=$(( y - BC_WY[$c] )) BCL_MX=$(( x - BC_WX[$c] ))
  return 0
}

# bc_init [mouse] — initscr + the usual terminal modes, colours if available,
# endwin on exit, and SIGWINCH -> KEY_RESIZE.
bc_init() {
  local o mouse=0
  for o in "$@"; do [[ $o == mouse ]] && mouse=1; done
  initscr || return 1
  cbreak; noecho; keypad "$BC_STDSCR" 1; curs_set 0
  if has_colors; then
    start_color
    if [[ -z ${BCL_SHADOW_PAIR:-} ]]; then
      BCL_SHADOW_PAIR=$BC_PAIRS
      init_pair "$BCL_SHADOW_PAIR" 0 0
    fi
  fi
  (( mouse )) && mousemask "$ALL_MOUSE_EVENTS" >/dev/null
  trap 'endwin' EXIT
  trap 'BC_WINCH=1' WINCH
  BCL_STARTED=1
}

# Handle a resize: new terminal size, relayout, full repaint.
_bcl_resized() {
  resizeterm
  [[ -n ${BCL_TPL[screen]+set} ]] && bc_relayout
  # deleted windows queue their old rects for repaint; after a shrink those can
  # lie off-screen, and the forced full repaint covers everything anyway
  BC_DELRECTS=""
  bc_dirty all
  BC_FORCEFULL=1
}

# bc_getkey — for app-owned loops. Flushes pending drawing to the screen, then
# reads one key into $key (like wgetch). KEY_RESIZE is handled (relayout +
# redraw) before it is returned; KEY_MOUSE consumes the event into BC_ME_* and
# sets BCL_AREA / BCL_MY / BCL_MX / BCL_MB for the clicked area.
bc_getkey() {
  bc_update
  wgetch "$BC_STDSCR" || return 1
  if [[ $key == "$KEY_RESIZE" ]]; then
    _bcl_resized
    bc_update
  elif [[ $key == "$KEY_MOUSE" ]]; then
    BCL_AREA="" BCL_MB=0
    if getmouse; then
      BCL_MB=$BC_ME_BSTATE
      bc_hit "$BC_ME_Y" "$BC_ME_X"
    fi
  fi
  return 0
}

# ============================================================ floats
# A float is a window on top of the tiled screen, placed relative to a parent
# (the screen, an area or another float) and kept inside it. It can hold text
# (bc_text, auto-sized) or a grid of its own (bc_grid NAME "…") — a dialog.
BCL_FLOATS=""              # bottom -> top
declare -A BCL_FIN=()      # float -> parent name
declare -A BCL_FAT=()      # float -> placement spec
declare -A BCL_FSIZE=()    # float -> size spec "HxW"
declare -A BCL_FRND=()     # float -> random choices "h w fy fx" (fixed at creation)
declare -A BCL_FKEYS=()    # float -> key handler function (bc_run / bc_modal)

# bc_float NAME [in=PARENT] [at=PLACE] [size=HxW] [style options…] [keys=FN]
#   PLACE: center top bottom left right topleft topright bottomleft bottomright
#          below:X above:X right:X left:X  random  Y,X (offset in the parent)
#   H, W:  N  N%  auto  A..B (random in range, chosen once)
#   style: border title=… shadow pair=N attr=N bpair=N (see bc_style)
# Calling it again for an existing float updates it in place.
bc_float() {
  local a=$1 o; shift
  [[ $a =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ && $a != screen ]] || { _bcl_err "bc_float: bad name '$a'"; return 1; }
  if [[ -n ${BCL_KIND[$a]+set} && ${BCL_KIND[$a]} != float ]]; then
    _bcl_err "bc_float: '$a' is already a tiled area"; return 1
  fi
  local new=0 in=${BCL_FIN[$a]:-screen} at=${BCL_FAT[$a]:-center} size=${BCL_FSIZE[$a]:-autoxauto}
  local -a style=()
  [[ -z ${BCL_KIND[$a]+set} ]] && new=1
  for o in "$@"; do
    case $o in
      in=*)   in=${o#*=} ;;
      at=*)   at=${o#*=} ;;
      size=*) size=${o#*=}; size=${size// /} ;;
      keys=*) BCL_FKEYS[$a]=${o#*=} ;;
      *)      style+=("$o") ;;
    esac
  done
  [[ $in == screen || -n ${BCL_KIND[$in]+set} ]] || { _bcl_err "bc_float $a: unknown parent '$in'"; return 1; }
  [[ $at =~ ^(center|top|bottom|left|right|topleft|topright|bottomleft|bottomright|random|(below|above|right|left):[A-Za-z_][A-Za-z0-9_.-]*|[0-9]+,[0-9]+)$ ]] \
    || { _bcl_err "bc_float $a: bad at='$at'"; return 1; }
  [[ $size =~ ^(auto|[0-9]+%?|[0-9]+\.\.[0-9]+)x(auto|[0-9]+%?|[0-9]+\.\.[0-9]+)$ ]] \
    || { _bcl_err "bc_float $a: bad size='$size' (HxW, each N, N%, auto or A..B)"; return 1; }
  # random choices are made once so the float keeps its look across relayouts
  local rh=0 rw=0 fy=$(( RANDOM % 1001 )) fx=$(( RANDOM % 1001 )) d lo hi
  if (( ! new )) && [[ $size == "${BCL_FSIZE[$a]}" ]]; then
    read -r rh rw fy fx <<< "${BCL_FRND[$a]}"
  else
    for d in h w; do
      local spec=${size%x*}; [[ $d == w ]] && spec=${size#*x}
      if [[ $spec == *..* ]]; then
        lo=${spec%..*} hi=${spec#*..}; (( hi < lo )) && hi=$lo
        local v=$(( lo + RANDOM % (hi - lo + 1) ))
        if [[ $d == h ]]; then rh=$v; else rw=$v; fi
      fi
    done
  fi
  BCL_KIND[$a]=float BCL_FIN[$a]=$in BCL_FAT[$a]=$at BCL_FSIZE[$a]=$size
  BCL_FRND[$a]="$rh $rw $fy $fx"
  (( new )) && BCL_FLOATS+=" $a"
  (( ${#style[@]} )) && { bc_style "$a" "${style[@]}" || return 1; }
  unset "BCL_WRECT[$a]"
  BCL_LAYOUT_DIRTY=1
}

# Content rectangle of a parent (outer rect minus its frame insets).
_bcl_inner() { # name -> BCL_Y BCL_X BCL_H BCL_W
  local a=$1
  if [[ $a == screen ]]; then BCL_Y=0 BCL_X=0 BCL_H=$BC_LINES BCL_W=$BC_COLS; return 0; fi
  _bcl_insets "$a"
  BCL_Y=$(( ${BCL_RY[$a]:-0} + BCL_IT )) BCL_X=$(( ${BCL_RX[$a]:-0} + BCL_IL ))
  BCL_H=$(( ${BCL_RH[$a]:-0} - BCL_IT - BCL_IB )) BCL_W=$(( ${BCL_RW[$a]:-0} - BCL_IL - BCL_IR ))
  (( BCL_H < 0 )) && BCL_H=0
  (( BCL_W < 0 )) && BCL_W=0
  return 0
}

# One float dimension: N / N% / auto / A..B -> BCL_D (outer size incl. shadow)
_bcl_fdim() { # float spec parentsize axis rnd
  local a=$1 spec=$2 ps=$3 ax=$4 r=$5 s=${BCL_SHADOW[$1]:-0}
  case $spec in
    auto) _bcl_min "$a" "$ax"; BCL_D=$BCL_M ;;
    *%)   BCL_D=$(( ps * ${spec%\%} / 100 + s )) ;;
    *..*) BCL_D=$(( r + s )) ;;
    *)    BCL_D=$(( spec + s )) ;;
  esac
  (( BCL_D > ps )) && BCL_D=$ps
  (( BCL_D < 1 )) && BCL_D=1
  return 0
}

# Place every float (parents before children: float order guarantees it).
_bcl_place_floats() {
  local a py px ph pw h w y x rh rw fy fx at ref
  for a in ${BCL_FLOATS}; do
    _bcl_inner "${BCL_FIN[$a]}"
    py=$BCL_Y px=$BCL_X ph=$BCL_H pw=$BCL_W
    read -r rh rw fy fx <<< "${BCL_FRND[$a]}"
    _bcl_fdim "$a" "${BCL_FSIZE[$a]%x*}" "$ph" 0 "$rh"; h=$BCL_D
    _bcl_fdim "$a" "${BCL_FSIZE[$a]#*x}" "$pw" 1 "$rw"; w=$BCL_D
    (( ph == 0 )) && h=0
    (( pw == 0 )) && w=0
    at=${BCL_FAT[$a]}
    y=$(( py + (ph - h) / 2 )) x=$(( px + (pw - w) / 2 ))
    case $at in
      top|topleft|topright)          y=$py ;;&
      bottom|bottomleft|bottomright) y=$(( py + ph - h )) ;;&
      left|topleft|bottomleft)       x=$px ;;&
      right|topright|bottomright)    x=$(( px + pw - w )) ;;&
      random) y=$(( py + (ph - h) * fy / 1000 )); x=$(( px + (pw - w) * fx / 1000 )) ;;
      *,*)    y=$(( py + ${at%,*} )); x=$(( px + ${at#*,} )) ;;
      *:*)
        ref=${at#*:}
        if [[ -n ${BCL_RY[$ref]+set} ]]; then
          case ${at%%:*} in
            below) y=$(( BCL_RY[$ref] + BCL_RH[$ref] )); x=${BCL_RX[$ref]} ;;
            above) y=$(( BCL_RY[$ref] - h ));            x=${BCL_RX[$ref]} ;;
            right) y=${BCL_RY[$ref]}; x=$(( BCL_RX[$ref] + BCL_RW[$ref] )) ;;
            left)  y=${BCL_RY[$ref]}; x=$(( BCL_RX[$ref] - w )) ;;
          esac
        fi ;;
    esac
    # keep it inside the parent
    (( y + h > py + ph )) && y=$(( py + ph - h ))
    (( x + w > px + pw )) && x=$(( px + pw - w ))
    (( y < py )) && y=$py
    (( x < px )) && x=$px
    if [[ -n ${BCL_TPL[$a]+set} ]]; then
      _bcl_layout_grid "$a" "$y" "$x" "$h" "$w"
    else
      BCL_RY[$a]=$y BCL_RX[$a]=$x BCL_RH[$a]=$h BCL_RW[$a]=$w
    fi
  done
}

# Floats whose parent chain (via in=) reaches NAME, NAME included, in float
# order -> BCL_SUB. A float inside an area of a float's grid counts too.
_bcl_subfloats() { # name
  local f p hit
  BCL_SUB=()
  for f in ${BCL_FLOATS}; do
    p=$f
    while [[ -n $p && $p != screen ]]; do
      [[ $p == "$1" ]] && { BCL_SUB+=("$f"); break; }
      if [[ ${BCL_KIND[$p]} == float ]]; then p=${BCL_FIN[$p]}; else p=${BCL_PARENT[$p]:-}; fi
    done
  done
}

# bc_raise NAME — bring a float (with the floats inside it) to the top.
bc_raise() {
  local a=$1 f
  [[ ${BCL_KIND[$a]:-} == float ]] || { _bcl_err "bc_raise: '$a' is not a float"; return 1; }
  _bcl_subfloats "$a"
  local -A mv=()
  for f in "${BCL_SUB[@]}"; do mv[$f]=1; done
  local rest=""
  for f in ${BCL_FLOATS}; do [[ -n ${mv[$f]:-} ]] || rest+=" $f"; done
  BCL_FLOATS="$rest ${BCL_SUB[*]}"
  _bcl_restack
}

# bc_close NAME [RESULT] — remove a float, the floats inside it and all their
# windows. RESULT is handed to a waiting bc_modal (in BCL_RESULT).
bc_close() {
  local a=$1 f k
  [[ -n ${2:-} ]] && BCL_RESULT=$2
  [[ ${BCL_KIND[$a]:-} == float ]] || { _bcl_err "bc_close: '$a' is not a float"; return 1; }
  _bcl_subfloats "$a"
  local -A gone=()
  for f in "${BCL_SUB[@]}"; do gone[$f]=1; done
  local rest=""
  for f in ${BCL_FLOATS}; do [[ -n ${gone[$f]:-} ]] || rest+=" $f"; done
  BCL_FLOATS=$rest
  for f in "${BCL_SUB[@]}"; do
    [[ -n ${BCL_TPL[$f]+set} ]] && _bcl_drop_kids "$f"
    _bcl_forget "$f"
  done
  BCL_LAYOUT_DIRTY=1
  return 0
}

# ============================================================ event loop
# bc_run owns the loop and calls the app's handlers:
#   draw_NAME / on_draw     redraw (see bc_dirty)
#   on_key KEY              keys not taken by a float handler
#   on_tick MS              every frame when fps=N is given (MS since last tick)
#   click_NAME Y X BSTATE   mouse on an area (else on_click NAME Y X BSTATE)
# Keys go to the topmost float that has a handler (keys=FN on bc_float, or a
# function named key_NAME), otherwise to on_key. bc_modal NAME runs a nested
# loop that only lets NAME (and what is inside it) see keys and clicks.
BCL_QUIT=0
BCL_FPS=""
BCL_RESULT=""
BCL_MODAL=""

# One key -> $key; status 1 when nothing arrived (timeout). Tests replace this.
_bcl_readkey() { wgetch "$BC_STDSCR"; }

_bcl_now_ms() { local t=${EPOCHREALTIME//[!0-9]/}; BCL_NOW=$(( t / 1000 )); }

# Key handler of a float, if it has one -> BCL_FN
_bcl_keyfn() { # float
  BCL_FN=${BCL_FKEYS[$1]:-}
  [[ -z $BCL_FN ]] && declare -F "key_$1" >/dev/null && BCL_FN="key_$1"
  [[ -n $BCL_FN ]]
}

# Is NAME inside float F (F itself, its grid, or floats placed in it)?
_bcl_inside() { # name float
  local p=$1
  while [[ -n $p && $p != screen ]]; do
    [[ $p == "$2" ]] && return 0
    if [[ ${BCL_KIND[$p]:-} == float ]]; then p=${BCL_FIN[$p]}; else p=${BCL_PARENT[$p]:-}; fi
  done
  return 1
}

_bcl_dispatch() { # key (modal float or "")
  local k=$1 m=$2 f i
  if [[ $k == "$KEY_RESIZE" ]]; then
    _bcl_resized
    declare -F on_resize >/dev/null && on_resize
    return 0
  fi
  if [[ $k == "$KEY_MOUSE" ]]; then
    while getmouse; do
      bc_hit "$BC_ME_Y" "$BC_ME_X" || continue
      [[ -n $m ]] && ! _bcl_inside "$BCL_AREA" "$m" && continue
      BCL_MB=$BC_ME_BSTATE
      if declare -F "click_$BCL_AREA" >/dev/null; then
        "click_$BCL_AREA" "$BCL_MY" "$BCL_MX" "$BCL_MB"
      elif declare -F on_click >/dev/null; then
        on_click "$BCL_AREA" "$BCL_MY" "$BCL_MX" "$BCL_MB"
      fi
    done
    return 0
  fi
  local -a fl
  read -r -a fl <<< "$BCL_FLOATS"
  for (( i = ${#fl[@]} - 1; i >= 0; i-- )); do
    [[ -n $m ]] && ! _bcl_inside "${fl[i]}" "$m" && continue
    _bcl_keyfn "${fl[i]}" && { "$BCL_FN" "$k"; return 0; }
  done
  [[ -n $m ]] && return 0
  declare -F on_key >/dev/null && on_key "$k"
  return 0
}

_bcl_loop() { # modal-float or ""
  local m=$1 frame=0 last next wait
  [[ -n $BCL_FPS ]] && frame=$(( 1000 / BCL_FPS ))
  (( frame < 1 && ${BCL_FPS:-0} > 0 )) && frame=1
  _bcl_now_ms; last=$BCL_NOW
  while (( ! BCL_QUIT )); do
    [[ -n $m && ${BCL_KIND[$m]:-} != float ]] && break
    bc_update
    if (( frame )); then
      _bcl_now_ms
      wait=$(( last + frame - BCL_NOW ))
      (( wait < 1 )) && wait=1
      wtimeout "$BC_STDSCR" "$wait"
    else
      wtimeout "$BC_STDSCR" -1
    fi
    if _bcl_readkey; then
      _bcl_dispatch "$key" "$m"
    fi
    if (( frame )); then
      _bcl_now_ms
      if (( BCL_NOW - last >= frame )); then
        declare -F on_tick >/dev/null && on_tick $(( BCL_NOW - last ))
        last=$BCL_NOW
      fi
    fi
  done
}

# bc_run [fps=N] — run the app until bc_quit.
bc_run() {
  local o own=0
  for o in "$@"; do
    case $o in
      fps=*) BCL_FPS=${o#*=} ;;
      *) _bcl_err "bc_run: unknown option '$o'"; return 1 ;;
    esac
  done
  if (( ! BCL_STARTED )); then bc_init mouse || return 1; own=1; fi
  BCL_QUIT=0
  _bcl_loop ""
  (( own )) && endwin
  return 0
}

# bc_modal NAME — run until the float NAME is closed. Returns 0 if it was closed
# with a result (bc_close NAME RESULT), which is left in BCL_RESULT.
bc_modal() {
  local a=$1 prev=$BCL_MODAL
  [[ ${BCL_KIND[$a]:-} == float ]] || { _bcl_err "bc_modal: '$a' is not a float"; return 1; }
  BCL_RESULT=""
  BCL_MODAL=$a
  _bcl_loop "$a"
  BCL_MODAL=$prev
  [[ -n $BCL_RESULT ]]
}

# bc_quit — leave bc_run (and any bc_modal inside it).
bc_quit() { BCL_QUIT=1; }
