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
    declare -F _bcl_unbind >/dev/null && _bcl_unbind "$k"
    unset "BCL_KIND[$k]" "BCL_PARENT[$k]" "BCL_R0[$k]" "BCL_R1[$k]" "BCL_C0[$k]" "BCL_C1[$k]"
    unset "BCL_RY[$k]" "BCL_RX[$k]" "BCL_RH[$k]" "BCL_RW[$k]"
    unset "BCL_TPL[$k]" "BCL_KIDS[$k]" "BCL_CELLS[$k]"
  done
  BCL_KIDS[$g]=""
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
  local k keep
  for k in ${BCL_KIDS[$g]:-}; do
    [[ -n ${cnt[$k]+set} ]] && continue
    keep=$k
    [[ -n ${BCL_TPL[$keep]+set} ]] && _bcl_drop_kids "$keep"
    declare -F _bcl_unbind >/dev/null && _bcl_unbind "$keep"
    unset "BCL_KIND[$keep]" "BCL_PARENT[$keep]" "BCL_TPL[$keep]" "BCL_KIDS[$keep]"
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
  y=$(( y + b )); x=$(( x + b )); h=$(( h - 2 * b )); w=$(( w - 2 * b ))
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
