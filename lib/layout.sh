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
           FIN FAT FSIZE FRND FKEYS FWITHIN FNUDGE MARGIN SPAIR TPEN KEYFN CLICKFN DIVIDER TLEFT; do
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
declare -A BCL_MARGIN=()  # name -> cells of background around the border
declare -A BCL_DIVIDER=() # name -> 1: a horizontal rule joined to the enclosing border
declare -A BCL_TLEFT=()   # name -> 1: title at the left of the border, not centred
declare -A BCL_SPAIR=()   # name -> shadow colour pair (default BCL_SHADOW_PAIR)
declare -A BCL_TPEN=()    # name -> title colour pair (default: border pair)
declare -A BCL_KEYFN=()   # name -> key handler (widgets register here)
declare -A BCL_CLICKFN=() # name -> mouse handler (widgets register here)
BCL_FOCUS=""              # area whose key handler sees keys first
BCL_CURSOR=""             # "name y x": where the visible cursor goes
# retained text (bc_text) — replayed whenever the window is rebuilt
declare -A BCL_TEXT=() BCL_TPAIR=() BCL_TATTR=() BCL_TALIGN=()
BCL_LAYOUT_DIRTY=0
BCL_STARTED=0

# Insets of an area's content inside its rectangle.
# Shadows: "1" is a solid strip one cell right and below; "mc" is Midnight
# Commander's: two columns right and one row below, see-through (tinted).
_bcl_insets() { # name -> BCL_IT BCL_IL BCL_IB BCL_IR
  local a=$1 f=$(( ${BCL_FRAME[$1]:-0} + ${BCL_MARGIN[$1]:-0} ))
  _bcl_shadow_size "$a"
  BCL_IT=$f BCL_IL=$f BCL_IB=$(( f + BCL_SH )) BCL_IR=$(( f + BCL_SW ))
}
_bcl_shadow_size() { # name -> BCL_SH BCL_SW (rows below, columns right)
  case ${BCL_SHADOW[$1]:-0} in
    mc) BCL_SH=1 BCL_SW=2 ;;
    0)  BCL_SH=0 BCL_SW=0 ;;
    *)  BCL_SH=1 BCL_SW=1 ;;
  esac
}

# Does a name get windows? Leaves always; containers only when they have
# something to show themselves (floats, borders, shadows, colours).
_bcl_bindable() { # name
  local a=$1
  [[ $a == screen ]] && return 1
  [[ -z ${BCL_TPL[$a]+set} ]] && return 0
  [[ ${BCL_KIND[$a]} == float || -n ${BCL_FRAME[$a]:-} || -n ${BCL_SHADOW[$a]:-} || -n ${BCL_PAIR[$a]:-} || -n ${BCL_ATTR[$a]:-} || -n ${BCL_TITLE[$a]:-} || -n ${BCL_MARGIN[$a]:-} ]]
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
  BCL_EA=${BCL_EA:-0}
}

_bcl_unbind() { # name
  local a=$1 p w
  [[ -n ${BCL_FWIN[$a]:-} ]] || return 0
  _bcl_forget_text "$a" "${BC_WH[${BCL_WIN[$a]}]:-0}"
  for p in ${BCL_PANS[$a]}; do del_panel "$p"; done
  for w in ${BCL_WINS[$a]}; do delwin "$w"; done
  unset "BCL_WIN[$a]" "BCL_FWIN[$a]" "BCL_PANS[$a]" "BCL_WINS[$a]" "BCL_SWINS[$a]" "BCL_WRECT[$a]"
}

# Paint the frame window (background, border, title) and the shadow strips.
_bcl_paint_frame() { # name [nobg]
  local a=$1 f=${BCL_FWIN[$1]} sw nobg=${2:-}
  _bcl_eff "$a"
  local bh=${BC_WH[$f]} bw=${BC_WW[$f]} p=${BCL_EP:-0} at=$BCL_EA
  # set the background and paint every cell once (wbkgd would repaint all
  # cells itself, and the content derwin shares these cells). With nobg the
  # background is already correct (e.g. a border-pair-only restyle): skip the
  # erase so only the border cells get dirtied.
  if [[ -z $nobg ]]; then
    wbkgdset "$f" ' ' "$at" "$p"
    werase "$f"
  fi
  local m=${BCL_MARGIN[$a]:-0}
  local y0=$m x0=$m y1=$(( bh - 1 - m )) x1=$(( bw - 1 - m ))
  if (( ${BCL_FRAME[$a]:-0} && y1 - y0 >= 1 && x1 - x0 >= 1 )); then
    local bp=${BCL_BPAIR[$a]:-$p} r line iw=$(( x1 - x0 - 1 ))
    printf -v line '%*s' "$iw" ''; line=${line// /$ACS_HLINE}
    wattrset "$f" "$at" "$bp"
    mvwaddstr "$f" "$y0" "$x0" "$ACS_ULCORNER$line$ACS_URCORNER"
    for (( r = y0 + 1; r < y1; r++ )); do
      mvwaddch "$f" "$r" "$x0" "$ACS_VLINE"; mvwaddch "$f" "$r" "$x1" "$ACS_VLINE"
    done
    mvwaddstr "$f" "$y1" "$x0" "$ACS_LLCORNER$line"
    mvwaddch "$f" "$y1" "$x1" "$ACS_LRCORNER"
    if [[ -n ${BCL_TITLE[$a]:-} ]]; then
      local t=" ${BCL_TITLE[$a]} " bw2=$(( x1 - x0 + 1 ))
      # too long: keep the end (paths read best from the right)
      (( ${#t} > bw2 - 2 )) && t=" …${t:${#t}-(bw2-5)}"
      wattrset "$f" "$at" "${BCL_TPEN[$a]:-$bp}"
      if [[ -n ${BCL_TLEFT[$a]:-} ]]; then mvwaddstr "$f" "$y0" $(( x0 + 1 )) "$t"
      else mvwaddstr "$f" "$y0" $(( x0 + (bw2 - ${#t}) / 2 )) "$t"; fi
    fi
    wattrset "$f" "$at" "$p"
  fi
  if [[ -n ${BCL_DIVIDER[$a]:-} ]] && (( bw >= 2 )); then
    local dl
    printf -v dl '%*s' $(( bw - 2 )) ''; dl=${dl// /$ACS_HLINE}
    wattrset "$f" "$at" "${BCL_BPAIR[$a]:-$p}"
    mvwaddstr "$f" 0 0 "$ACS_LTEE$dl$ACS_RTEE"
    wattrset "$f" "$at" "$p"
  fi
  local sp=${BCL_SPAIR[$a]:-${BCL_SHADOW_PAIR:-0}} sa=0
  (( sp )) || sa=$A_REVERSE
  for sw in ${BCL_SWINS[$a]:-}; do
    wbkgdset "$sw" ' ' "$sa" "$sp"; werase "$sw"
  done
}

# Build the windows for a rectangle: frame (the box), content derwin inset by
# the border (leaves only), and the shadow as two strips right and below the
# box — leaving the two outer corners uncovered so the screen shows through.
_bcl_bind() { # name y x h w
  local a=$1 y=$2 x=$3 h=$4 w=$5
  local fr=$(( ${BCL_FRAME[$a]:-0} + ${BCL_MARGIN[$a]:-0} )) st=${BCL_SHADOW[$a]:-0}
  _bcl_shadow_size "$a"
  local sh=$BCL_SH sw=$BCL_SW
  (( h <= sh || w <= sw )) && sh=0 sw=0
  local bh=$(( h - sh )) bw=$(( w - sw )) pans="" wins=""
  newwin "$bh" "$bw" "$y" "$x" || return 1
  local f=$bc_win
  new_panel "$f"; pans=$bc_panel
  BCL_FWIN[$a]=$f; BCL_WIN[$a]=$f
  if [[ -z ${BCL_TPL[$a]+set} ]] && (( fr )); then
    local ch=$(( bh - 2 * fr )) cw=$(( bw - 2 * fr ))
    if (( ch > 0 && cw > 0 )) && derwin "$f" "$ch" "$cw" "$fr" "$fr"; then
      BCL_WIN[$a]=$bc_win
      new_panel "$bc_win"; pans+=" $bc_panel"; wins="$bc_win "
    fi
  fi
  wins+=$f
  BCL_SWINS[$a]=""
  if (( sh || sw )); then
    # right strip from the 2nd row down to the box's last row, bottom strip
    # from the sw+1-th column to the right edge (outer corners stay uncovered)
    local -a strips=("$(( bh - 1 )) $sw $(( y + 1 )) $(( x + bw ))")
    if [[ $st == mc ]]; then
      strips+=("$sh $bw $(( y + bh )) $(( x + sw ))")
    else
      strips[0]="$bh $sw $(( y + 1 )) $(( x + bw ))"
      strips+=("$sh $(( bw - 1 )) $(( y + bh )) $(( x + 1 ))")
    fi
    local sdef
    for sdef in "${strips[@]}"; do
      set -- $sdef
      (( $1 > 0 && $2 > 0 )) || continue
      newwin "$1" "$2" "$3" "$4" || continue
      new_panel "$bc_win"; pans+=" $bc_panel"; wins+=" $bc_win"; BCL_SWINS[$a]+=" $bc_win"
      [[ $st == mc ]] && panel_tint "$bc_panel" 1
    done
  fi
  BCL_PANS[$a]=$pans BCL_WINS[$a]=$wins
  local c=${BCL_WIN[$a]}
  _bcl_eff "$a"
  wbkgdset "$c" ' ' "$BCL_EA" "${BCL_EP:-0}"
  wattrset "$c" "$BCL_EA" "${BCL_EP:-0}"
  _bcl_paint_frame "$a"
  BCL_WRECT[$a]="$y $x $h $w"
  _bcl_need "$a"
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
    local -a old=("${BC_PSTACK[@]}")
    BC_PSTACK=("${ns[@]}")
    if (( ${#old[@]} == ${#ns[@]} )); then
      local -A _om=()
      local p same=1
      for p in "${old[@]}"; do _om[$p]=1; done
      for p in "${ns[@]}"; do [[ -n ${_om[$p]:-} ]] || { same=0; break; }; done
      if (( same )); then _bc_stack_reorder_dirty "${old[@]}"; else _bc_stack_dirty; fi
    else
      _bc_stack_dirty
    fi
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
    [[ -n ${BCL_DIVIDER[$a]:-} ]] && key="${BCL_RY[$a]} $(( BCL_RX[$a] - 1 )) 1 $(( BCL_RW[$a] + 2 ))"
    [[ ${BCL_WRECT[$a]:-} == "$key" ]] && continue
    _bcl_unbind "$a"
    (( BCL_RH[$a] > 0 && BCL_RW[$a] > 0 )) || continue
    if [[ -n ${BCL_DIVIDER[$a]:-} ]]; then   # reaches into the border on both sides
      _bcl_bind "$a" "${BCL_RY[$a]}" $(( BCL_RX[$a] - 1 )) 1 $(( BCL_RW[$a] + 2 ))
    else
      _bcl_bind "$a" "${BCL_RY[$a]}" "${BCL_RX[$a]}" "${BCL_RH[$a]}" "${BCL_RW[$a]}"
    fi
  done
  _bcl_restack
  return 0
}

# ------------------------------------------------------------ styling
# bc_style NAME [pair=N] [attr=N] [border|border=0] [title=TEXT] [bpair=N]
#              [tpair=N] [margin=N] [shadow|shadow=mc|shadow=0] [spair=N]
#   margin: rows/columns of background between the window edge and the border
#   shadow=mc: Midnight Commander's see-through shadow (2 columns, 1 row)
#   divider: the (one-row) area is a rule ├───┤ joined to the enclosing border
#   tleft: the title sits at the left of the border instead of the middle
# "screen" styles the background (stdscr).
bc_style() {
  local a=$1 o; shift
  [[ $a == screen || -n ${BCL_KIND[$a]+set} ]] || { _bcl_err "bc_style: unknown area '$a'"; return 1; }
  local geom=0 bpen=0 content=0
  for o in "$@"; do
    case $o in
      pair=*)   nv=${o#*=}; [[ ${BCL_PAIR[$a]:-0} == "$nv" ]] || { BCL_PAIR[$a]=$nv; content=1; } ;;
      attr=*)   nv=${o#*=}; [[ ${BCL_ATTR[$a]:-0} == "$nv" ]] || { BCL_ATTR[$a]=$nv; content=1; } ;;
      bpair=*)  nv=${o#*=}; [[ ${BCL_BPAIR[$a]:-} == "$nv" ]] || { BCL_BPAIR[$a]=$nv; bpen=1; } ;;
      title=*)  nv=${o#*=}; [[ ${BCL_TITLE[$a]:-} == "$nv" ]] || { BCL_TITLE[$a]=$nv; content=1; } ;;
      border)   [[ ${BCL_FRAME[$a]:-0} == 1 ]] || { BCL_FRAME[$a]=1; geom=1; } ;;
      border=*) nv=$(( ${o#*=} ? 1 : 0 )); [[ ${BCL_FRAME[$a]:-0} == "$nv" ]] || { BCL_FRAME[$a]=$nv; geom=1; } ;;
      shadow)   [[ ${BCL_SHADOW[$a]:-0} == 1 ]] || { BCL_SHADOW[$a]=1; geom=1; } ;;
      shadow=mc) [[ ${BCL_SHADOW[$a]:-} == mc ]] || { BCL_SHADOW[$a]=mc; geom=1; } ;;
      shadow=*) nv=$(( ${o#*=} ? 1 : 0 )); [[ ${BCL_SHADOW[$a]:-0} == "$nv" ]] || { BCL_SHADOW[$a]=$nv; geom=1; } ;;
      spair=*)  nv=${o#*=}; [[ ${BCL_SPAIR[$a]:-} == "$nv" ]] || { BCL_SPAIR[$a]=$nv; bpen=1; } ;;
      tpair=*)  nv=${o#*=}; [[ ${BCL_TPEN[$a]:-} == "$nv" ]] || { BCL_TPEN[$a]=$nv; bpen=1; } ;;
      margin=*) nv=${o#*=}; [[ ${BCL_MARGIN[$a]:-0} == "$nv" ]] || { BCL_MARGIN[$a]=$nv; geom=1; }; BCL_MARGIN[$a]=$nv ;;
      divider)  [[ ${BCL_DIVIDER[$a]:-0} == 1 ]] || { BCL_DIVIDER[$a]=1; geom=1; } ;;
      tleft)    [[ ${BCL_TLEFT[$a]:-0} == 1 ]] || { BCL_TLEFT[$a]=1; content=1; } ;;
      *) _bcl_err "bc_style: unknown option '$o'"; return 1 ;;
    esac
  done
  if [[ $a == screen ]]; then
    wbkgd "$BC_STDSCR" ' ' "${BCL_ATTR[screen]:-0}" "${BCL_PAIR[screen]:-0}"
    werase "$BC_STDSCR"
    return 0
  fi
  # nothing actually changed: no repaint needed
  (( geom || bpen || content )) || return 0
  # insets changed -> rebuild the windows; otherwise just repaint in place
  if (( geom )); then
    unset "BCL_WRECT[$a]"; BCL_LAYOUT_DIRTY=1
    # content size includes the insets: re-measure retained text
    [[ -n ${BCL_TEXT[$a]+set} ]] && bc_text "$a" "${BCL_TEXT[$a]}" pair="${BCL_TPAIR[$a]}" attr="${BCL_TATTR[$a]}" align="${BCL_TALIGN[$a]}"
  else
    # a border-pair-only change touches just the frame cells: repaint the
    # frame without forgetting the area's text (which would dirty every cell).
    # A borderless area has no frame to repaint, so the change is a no-op.
    if (( bpen && !content )); then
      if [[ -n ${BCL_FWIN[$a]:-} ]]; then
        _bcl_eff "$a"
        _bcl_paint_frame "$a" nobg
      fi
      return 0
    fi
    # repaint this area and everything inheriting its colours
    _bcl_order
    local n p
    for n in "${BCL_LV[@]}"; do
      p=$n
      while [[ -n $p && $p != "$a" ]]; do p=${BCL_PARENT[$p]:-}; done
      [[ $p == "$a" && -n ${BCL_FWIN[$n]:-} ]] || continue
      _bcl_eff "$n"
      wbkgdset "${BCL_WIN[$n]}" ' ' "$BCL_EA" "${BCL_EP:-0}"
      wattrset "${BCL_WIN[$n]}" "$BCL_EA" "${BCL_EP:-0}"
      _bcl_paint_frame "$n"
      _bcl_forget_text "$n" "${BC_WH[${BCL_WIN[$n]}]}"
      _bcl_need "$n"
    done
    # a container that just became visible needs a window
    _bcl_bindable "$a" && [[ -z ${BCL_FWIN[$a]:-} ]] && BCL_LAYOUT_DIRTY=1
  fi
  return 0
}

# ------------------------------------------------------------ drawing
# bc_win NAME -> bc_win = content window handle (use any lib/bc.sh call on it).
# Returns 1 if the area is currently hidden (no window).
bc_win() {
  bc_win=${BCL_WIN[$1]:-}
  # the app may now draw cells the layer does not know about, so this area
  # falls back to a full clear before each redraw (see _bcl_draw_area)
  [[ -n $bc_win ]] && BCL_RAW[$1]=1
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

# ---- change-only drawing
# Repainting a whole area for every keystroke is what makes immediate-style
# drawing slow here: every cell written is marked dirty and doupdate pays for
# each one. So the layer only writes cells whose content actually changes, and
# instead of clearing an area before draw_NAME it remembers, per row, how far
# text may extend (BCL_EXT) and which spans the current redraw wrote
# (BCL_SPAN); after the redraw only the remembered cells that were not
# rewritten are blanked. The result equals "draw on a cleared area".
declare -A BCL_EXT=()     # "name/row" -> end column of possibly non-blank text
declare -A BCL_SPAN=()    # "name/row" -> " x0 x1 …" written in the current redraw
declare -A BCL_RAW=()     # name -> app drew with raw bc.sh calls (bc_win)
declare -A BCL_LAST=()    # "name/row" -> "x|pen|text" of the last write to that row
BCL_DRAWING=""

# Write one clipped string into an area, skipping it if the cells already hold
# exactly this text and pen, and trimming it to the part that differs.
_bcl_put() { # name y x str attr pair
  local a=$1 y=$2 x=$3 s=$4 c=${BCL_WIN[$1]:-}
  [[ -n $c ]] || return 0
  local w=${BC_WW[$c]}
  (( y < 0 || y >= BC_WH[$c] || x >= w )) && return 0
  if (( x < 0 )); then s=${s:$(( -x ))}; x=0; fi
  (( ${#s} > w - x )) && s=${s:0:w-x}
  local n=${#s}
  (( n )) || return 0
  if [[ -n $BCL_DRAWING && $BCL_DRAWING == "$a" ]]; then BCL_SPAN[$a/$y]+=" $x $(( x + n ))"; fi
  (( ${BCL_EXT[$a/$y]:-0} < x + n )) && BCL_EXT[$a/$y]=$(( x + n ))
  # rendered form of what mvwaddstr would store (see _bc_emit / _bc_render)
  local buf=${BC_WBUF[$c]} bg=${BC_WBG[$c]}
  local ra=$(( $5 | BC_WBGA[$c] )) rp=$6
  [[ -n $rp ]] || rp=${BC_WBGP[$c]}
  local want=$s
  [[ $bg != ' ' ]] && want=${s// /$bg}
  # same text, pen and column as the last write to this row: nothing to do
  # (any other change to the row's cells goes through here or forgets it)
  local sig="$x|$ra $rp|$want"
  if [[ -z ${BCL_RAW[$a]:-} && ${BCL_LAST[$a/$y]:-} == "$sig" ]]; then return 0; fi
  BCL_LAST[$a/$y]=$sig
  local ay=$(( BC_WY[$c] + y )) ax=$(( BC_WX[$c] + x )) rk
  rk="$buf $ay"
  if [[ -n ${BC_PUNI[$rk]+x} ]]; then
    # owner row cache: one string compare
    [[ ${BC_PUNI[$rk]} == "$ra $rp" && ${BC_CROW[$rk]:ax-BC_WX[$buf]:n} == "$want" ]] && return 0
  else
    local i=0 j=$(( n - 1 )) k
    while (( i < n )); do
      k="$buf/$ay $(( ax + i ))"
      [[ ${BC_C[$k]:-} == "${want:i:1}" && ${BC_A[$k]:-} == "$ra" && ${BC_P[$k]:-} == "$rp" ]] || break
      i=$(( i + 1 ))
    done
    (( i == n )) && return 0
    while (( j > i )); do
      k="$buf/$ay $(( ax + j ))"
      [[ ${BC_C[$k]:-} == "${want:j:1}" && ${BC_A[$k]:-} == "$ra" && ${BC_P[$k]:-} == "$rp" ]] || break
      j=$(( j - 1 ))
    done
    s=${s:i:j-i+1}; x=$(( x + i ))
  fi
  wattrset "$c" "$5" "$rp"
  mvwaddstr "$c" "$y" "$x" "$s"
}

# Forget what the layer knows about an area's text (fresh or erased window).
_bcl_forget_text() { # name rows
  local a=$1 r
  for (( r = 0; r < $2; r++ )); do unset "BCL_EXT[$a/$r]" "BCL_SPAN[$a/$r]" "BCL_LAST[$a/$r]"; done
}

# Redraw one area: retained text, then draw_NAME, then blank what the previous
# content left behind (or a plain full clear first for raw-drawn areas).
_bcl_draw_area() { # name
  local a=$1 c=${BCL_WIN[$1]:-}
  [[ -n $c ]] || return 0
  # only areas whose whole content is described (text / draw_NAME) are redrawn;
  # anything else keeps what was printed into it
  [[ -n ${BCL_TEXT[$a]+set} ]] || declare -F "draw_$a" >/dev/null || return 0
  local h=${BC_WH[$c]} r
  if [[ -n ${BCL_RAW[$a]:-} ]]; then
    werase "$c"; _bcl_forget_text "$a" "$h"
  fi
  local prev=$BCL_DRAWING
  BCL_DRAWING=$a BCL_PARTIAL=0
  for (( r = 0; r < h; r++ )); do BCL_SPAN[$a/$r]=""; done
  [[ -n ${BCL_TEXT[$a]+set} ]] && _bcl_draw_text "$a"
  declare -F "draw_$a" >/dev/null && "draw_$a" "$a"
  BCL_DRAWING=$prev
  # a partial redraw (BCL_PARTIAL=1, set by the draw function) only redrew
  # some rows: leave the others alone
  # blank the cells that held text before and were not written now
  _bcl_eff "$a"
  local ea=$BCL_EA ep=${BCL_EP:-0} e x0 x1 pos end blank
  local -a sp
  for (( r = 0; r < h; r++ )); do
    e=${BCL_EXT[$a/$r]:-0}
    (( e )) || continue
    (( BCL_PARTIAL )) && [[ -z ${BCL_SPAN[$a/$r]} ]] && continue
    read -r -a sp <<< "${BCL_SPAN[$a/$r]}"
    # spans in write order; sort them by start (few per row)
    local -a st=() en=()
    local i m t
    for (( i = 0; i < ${#sp[@]}; i += 2 )); do st+=("${sp[i]}"); en+=("${sp[i+1]}"); done
    for (( i = 1; i < ${#st[@]}; i++ )); do
      for (( m = i; m > 0 && st[m-1] > st[m]; m-- )); do
        t=${st[m]}; st[m]=${st[m-1]}; st[m-1]=$t
        t=${en[m]}; en[m]=${en[m-1]}; en[m-1]=$t
      done
    done
    pos=0 end=0
    for (( i = 0; i <= ${#st[@]}; i++ )); do
      if (( i < ${#st[@]} )); then x0=${st[i]} x1=${en[i]}; else x0=$e x1=$e; fi
      (( x0 > e )) && x0=$e
      if (( x0 > pos )); then
        printf -v blank '%*s' $(( x0 - pos )) ''
        BCL_DRAWING="" _bcl_put "$a" "$r" "$pos" "$blank" "$ea" "$ep"
      fi
      (( x1 > pos )) && pos=$x1
      (( x1 > end )) && end=$x1
    done
    if (( end )); then BCL_EXT[$a/$r]=$end; else unset "BCL_EXT[$a/$r]"; fi
    unset "BCL_SPAN[$a/$r]"
  done
  wattrset "$c" "$ea" "$ep"
}

# bc_print NAME Y X TEXT [pair=N] [attr=N] — clipped to the area (no wrap).
bc_print() {
  local a=$1 y=$2 x=$3 s=$4; shift 4
  local c=${BCL_WIN[$a]:-}
  [[ -n $c ]] || return 0
  _bcl_pen "$a" "$@" || return 1
  _bcl_put "$a" "$y" "$x" "$s" "$BCL_PA" "$BCL_PP"
  _bcl_eff "$a"; wattrset "$c" "$BCL_EA" "${BCL_EP:-0}"
}

# bc_clear NAME — erase the content to the area background.
bc_clear() {
  local c=${BCL_WIN[$1]:-}
  [[ -n $c ]] || return 0
  werase "$c"
  _bcl_forget_text "$1" "${BC_WH[$c]}"
}

# bc_text NAME TEXT [pair=N] [attr=N] [align=left|center|right]
# Sets the area's content: it is measured (auto tracks and auto-sized floats
# fit it) and drawn at the next update, and again whenever the window is rebuilt.
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
  _bcl_need "$a"
}

# bc_content NAME H W — tell the layout how big NAME's content is (for auto
# tracks and auto-sized floats); widgets use it.
bc_content() {
  local a=$1
  if [[ ${BCL_CH[$a]:-} != "$2" || ${BCL_CW[$a]:-} != "$3" ]]; then
    BCL_CH[$a]=$2 BCL_CW[$a]=$3
    _bcl_content_sized "$a" && BCL_LAYOUT_DIRTY=1
  fi
  return 0
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
  w=${BC_WW[$c]}
  while IFS= read -r line; do
    case ${BCL_TALIGN[$a]} in
      center) x=$(( (w - ${#line}) / 2 )) ;;
      right)  x=$(( w - ${#line} )) ;;
      *)      x=0 ;;
    esac
    (( x < 0 )) && x=0
    _bcl_put "$a" "$r" "$x" "$line" "${BCL_TATTR[$a]}" "${BCL_TPAIR[$a]}"
    r=$(( r + 1 ))
  done <<< "${BCL_TEXT[$a]}"
  _bcl_eff "$a"; wattrset "$c" "$BCL_EA" "${BCL_EP:-0}"
}

# Mark NAME for redrawing. BCL_DIRTYN counts the requests, so a widget can
# tell whether anyone but itself asked for a redraw (see bc_list).
declare -A BCL_DIRTYN=()
_bcl_need() { BCL_NEEDDRAW[$1]=1; BCL_DIRTYN[$1]=$(( ${BCL_DIRTYN[$1]:-0} + 1 )); }

# bc_dirty NAME... — ask for NAME to be redrawn (draw_NAME / on_draw) before
# the next screen update. "all" marks every bound area.
bc_dirty() {
  local a
  for a in "$@"; do
    if [[ $a == all ]]; then
      for a in "${!BCL_WIN[@]}"; do _bcl_need "$a"; done
      return 0
    fi
    _bcl_need "$a"
  done
}

# Redraw what needs it: retained text, then draw_NAME functions (which see
# the area as if freshly cleared, so they always describe its whole content),
# then on_draw (once, if anything at all was pending). Returns 1 if nothing
# was pending.
_bcl_draw_pending() {
  local a any=0 pass
  # a draw_NAME may mark other areas (e.g. bc_text on a status line): keep
  # going until nothing is pending (bounded, in case two areas mark each other)
  for (( pass = 0; pass < 4 && ${#BCL_NEEDDRAW[@]}; pass++ )); do
    for a in "${!BCL_NEEDDRAW[@]}"; do
      unset "BCL_NEEDDRAW[$a]"
      [[ -n ${BCL_WIN[$a]:-} ]] || continue
      any=1
      _bcl_draw_area "$a"
    done
  done
  (( any )) || return 1
  declare -F on_draw >/dev/null && on_draw
  return 0
}

# bc_update — relayout if needed, redraw what is pending, push to the terminal.
bc_update() {
  local t0 d e
  [[ -n ${BC_MOUSE_DEBUG:-} ]] && { e=${EPOCHREALTIME//,/}; t0=${e//./}; }
  (( BCL_LAYOUT_DIRTY )) && bc_relayout
  _bcl_draw_pending
  _bcl_place_cursor
  doupdate
  if [[ -n ${BC_MOUSE_DEBUG:-} && -n $t0 ]]; then
    e=${EPOCHREALTIME//,/}; d=$(( (${e//./} - t0) / 1000 ))
    (( d > 50 )) && _bc_mouse_log "update ${d}ms"
  fi
}

# bc_cursor NAME Y X — show the terminal cursor at Y,X of NAME's content (it
# follows the area across relayouts). bc_cursor with no arguments hides it.
bc_cursor() {
  if (( $# < 3 )); then
    [[ -n $BCL_CURSOR ]] && curs_set 0 >/dev/null
    BCL_CURSOR=""
    return 0
  fi
  [[ -z $BCL_CURSOR ]] && curs_set 1 >/dev/null
  BCL_CURSOR="$1 $2 $3"
}

# doupdate leaves the terminal cursor at stdscr's cursor: put that where the
# visible cursor belongs.
_bcl_place_cursor() {
  [[ -n $BCL_CURSOR ]] || return 0
  local a y x c
  read -r a y x <<< "$BCL_CURSOR"
  c=${BCL_WIN[$a]:-}
  [[ -n $c ]] || return 0
  BC_WAY[$BC_STDSCR]=$(( BC_WY[$c] + y )) BC_WAX[$BC_STDSCR]=$(( BC_WX[$c] + x ))
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

# bc_init [mouse] [motion] [clickms=N] — initscr + the usual terminal modes,
# colours if available, endwin on exit, and SIGWINCH -> KEY_RESIZE. motion
# accepts drag (motion) events; the 1002 wire mode is toggled per-drag with
# bc_mouse_motion, since some terminals misbehave when it is on from startup.
# clickms is the click interval.
bc_init() {
  local o mouse=0 mmask=$ALL_MOUSE_EVENTS
  for o in "$@"; do
    case $o in
      mouse)     mouse=1 ;;
      motion)    mouse=1; mmask=$(( mmask | REPORT_MOUSE_POSITION )) ;;
      clickms=*) mouseinterval "${o#*=}" >/dev/null ;;
      *) _bcl_err "bc_init: unknown option '$o'"; return 1 ;;
    esac
  done
  initscr || return 1
  cbreak; noecho; keypad "$BC_STDSCR" 1; curs_set 0
  if has_colors; then
    start_color
    if [[ -z ${BCL_SHADOW_PAIR:-} ]]; then
      BCL_SHADOW_PAIR=$BC_PAIRS
      init_pair "$BCL_SHADOW_PAIR" 0 0
    fi
  fi
  (( mouse )) && mousemask "$mmask"
  trap 'endwin' EXIT
  trap 'exit 130' INT TERM
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
declare -A BCL_FWITHIN=()  # float -> area it is clamped to ("" = its in= parent)
declare -A BCL_FNUDGE=()   # float -> "DY,DX" moved after placement, before clamping

# bc_float NAME [in=PARENT] [within=AREA] [at=PLACE] [size=HxW] [style…] [keys=FN]
#   in:     where it is placed and what N% sizes refer to (default: screen)
#   within: what it must stay inside (default: the in= parent); a float placed
#           in a small cell but kept within the whole screen can overhang it
#   PLACE:  center top bottom left right topleft topright bottomleft bottomright
#           below:X above:X right:X left:X  random  Y,X (offset in the parent)
#           (random puts the top-left corner anywhere it fits, or anywhere in
#           the parent when the float is bigger than it)
#   H, W:   N  N%  auto  A..B  A%..B% (random in range, chosen once)
#   nudge:  DY,DX added to the position before it is clamped
#   style: border title=… shadow pair=N attr=N bpair=N margin=N (see bc_style)
# Calling it again for an existing float updates it in place.
bc_float() {
  local a=$1 o; shift
  [[ $a =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ && $a != screen ]] || { _bcl_err "bc_float: bad name '$a'"; return 1; }
  if [[ -n ${BCL_KIND[$a]+set} && ${BCL_KIND[$a]} != float ]]; then
    _bcl_err "bc_float: '$a' is already a tiled area"; return 1
  fi
  local new=0 in=${BCL_FIN[$a]:-screen} at=${BCL_FAT[$a]:-center} size=${BCL_FSIZE[$a]:-autoxauto}
  local within=${BCL_FWITHIN[$a]:-}
  local -a style=()
  [[ -z ${BCL_KIND[$a]+set} ]] && new=1
  for o in "$@"; do
    case $o in
      in=*)   in=${o#*=} ;;
      within=*) within=${o#*=} ;;
      at=*)   at=${o#*=} ;;
      size=*) size=${o#*=}; size=${size// /} ;;
      keys=*) BCL_FKEYS[$a]=${o#*=} ;;
      nudge=*) BCL_FNUDGE[$a]=${o#*=} ;;
      *)      style+=("$o") ;;
    esac
  done
  [[ $in == screen || -n ${BCL_KIND[$in]+set} ]] || { _bcl_err "bc_float $a: unknown parent '$in'"; return 1; }
  [[ -z $within || $within == screen || -n ${BCL_KIND[$within]+set} ]] || { _bcl_err "bc_float $a: unknown area '$within'"; return 1; }
  [[ $at =~ ^(center|top|bottom|left|right|topleft|topright|bottomleft|bottomright|random|(below|above|right|left):[A-Za-z_][A-Za-z0-9_.-]*|[0-9]+,[0-9]+)$ ]] \
    || { _bcl_err "bc_float $a: bad at='$at'"; return 1; }
  local dim='(auto|[0-9]+%?|[0-9]+\.\.[0-9]+|[0-9]+%\.\.[0-9]+%)'
  [[ $size =~ ^${dim}x${dim}$ ]] \
    || { _bcl_err "bc_float $a: bad size='$size' (HxW, each N, N%, auto, A..B or A%..B%)"; return 1; }
  # random choices are made once so the float keeps its look across relayouts
  local rh=0 rw=0 fy=$(( RANDOM % 1001 )) fx=$(( RANDOM % 1001 )) d lo hi
  if (( ! new )) && [[ $size == "${BCL_FSIZE[$a]}" ]]; then
    read -r rh rw fy fx <<< "${BCL_FRND[$a]}"
  else
    for d in h w; do
      local spec=${size%x*}; [[ $d == w ]] && spec=${size#*x}
      if [[ $spec == *..* ]]; then
        lo=${spec%..*} hi=${spec#*..}
        local pct=""; [[ $lo == *% ]] && { pct=%; lo=${lo%\%}; hi=${hi%\%}; }
        (( hi < lo )) && hi=$lo
        local v=$(( lo + RANDOM % (hi - lo + 1) ))$pct
        if [[ $d == h ]]; then rh=$v; else rw=$v; fi
      fi
    done
  fi
  BCL_KIND[$a]=float BCL_FIN[$a]=$in BCL_FAT[$a]=$at BCL_FSIZE[$a]=$size BCL_FWITHIN[$a]=$within
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
# N / N% / A..B give the size of the box (inside any margin); margin and
# shadow are added around it.
_bcl_fdim() { # float spec parentsize axis rnd clampsize
  local a=$1 spec=$2 ps=$3 ax=$4 r=$5 s
  _bcl_shadow_size "$a"
  if (( ax == 0 )); then s=$BCL_SH; else s=$BCL_SW; fi
  s=$(( s + 2 * ${BCL_MARGIN[$a]:-0} ))
  case $spec in
    auto) _bcl_min "$a" "$ax"; BCL_D=$BCL_M ;;
    *..*) if [[ $r == *% ]]; then BCL_D=$(( ps * ${r%\%} / 100 + s )); else BCL_D=$(( r + s )); fi ;;
    *%)   BCL_D=$(( ps * ${spec%\%} / 100 + s )) ;;
    *)    BCL_D=$(( spec + s )) ;;
  esac
  (( BCL_D > ${6:-$ps} )) && BCL_D=${6:-$ps}
  (( BCL_D < 1 )) && BCL_D=1
  return 0
}

# Place every float (parents before children: float order guarantees it).
_bcl_place_floats() {
  local a py px ph pw cy cx ch cw h w y x rh rw fy fx at ref
  for a in ${BCL_FLOATS}; do
    _bcl_inner "${BCL_FWITHIN[$a]:-${BCL_FIN[$a]}}"
    cy=$BCL_Y cx=$BCL_X ch=$BCL_H cw=$BCL_W
    _bcl_inner "${BCL_FIN[$a]}"
    py=$BCL_Y px=$BCL_X ph=$BCL_H pw=$BCL_W
    read -r rh rw fy fx <<< "${BCL_FRND[$a]}"
    _bcl_fdim "$a" "${BCL_FSIZE[$a]%x*}" "$ph" 0 "$rh" "$ch"; h=$BCL_D
    _bcl_fdim "$a" "${BCL_FSIZE[$a]#*x}" "$pw" 1 "$rw" "$cw"; w=$BCL_D
    (( ch == 0 )) && h=0
    (( cw == 0 )) && w=0
    at=${BCL_FAT[$a]}
    # centring centres the box: a shadow hangs off it
    _bcl_shadow_size "$a"
    y=$(( py + (ph - h + BCL_SH) / 2 )) x=$(( px + (pw - w + BCL_SW) / 2 ))
    case $at in
      top|topleft|topright)          y=$py ;;&
      bottom|bottomleft|bottomright) y=$(( py + ph - h )) ;;&
      left|topleft|bottomleft)       x=$px ;;&
      right|topright|bottomright)    x=$(( px + pw - w )) ;;&
      random)
        if (( h <= ph )); then y=$(( py + (ph - h) * fy / 1000 )); else y=$(( py + (ph - 1) * fy / 1000 )); fi
        if (( w <= pw )); then x=$(( px + (pw - w) * fx / 1000 )); else x=$(( px + (pw - 1) * fx / 1000 )); fi ;;
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
    if [[ -n ${BCL_FNUDGE[$a]:-} ]]; then
      y=$(( y + ${BCL_FNUDGE[$a]%,*} )) x=$(( x + ${BCL_FNUDGE[$a]#*,} ))
    fi
    # keep it inside the clamp area
    (( y + h > cy + ch )) && y=$(( cy + ch - h ))
    (( x + w > cx + cw )) && x=$(( cx + cw - w ))
    (( y < cy )) && y=$cy
    (( x < cx )) && x=$cx
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

# Key handler of an area or float, if it has one -> BCL_FN: keys=FN given to
# bc_float, else a widget's handler, else a function named key_NAME.
_bcl_keyfn() { # name
  BCL_FN=${BCL_FKEYS[$1]:-${BCL_KEYFN[$1]:-}}
  [[ -z $BCL_FN ]] && declare -F "key_$1" >/dev/null && BCL_FN="key_$1"
  [[ -n $BCL_FN ]]
}

# bc_pass — called by a key or click handler: "not mine", so the event goes on
# to the next handler (focus -> floats top-down -> on_key / on_click).
bc_pass() { BCL_PASSED=1; }

# Call a handler; status 0 if it took the event (did not bc_pass).
_bcl_handle() { # fn args...
  BCL_PASSED=0
  "$@"
  (( ! BCL_PASSED ))
}

# bc_focus NAME — the area whose key handler sees keys first ("" for none).
bc_focus() { BCL_FOCUS=${1:-}; }

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
    _bc_mouse_log "dispatch KEY_MOUSE x=$BC_ME_X y=$BC_ME_Y bstate=$BC_ME_BSTATE"
    while getmouse; do
      if ! bc_hit "$BC_ME_Y" "$BC_ME_X" || { [[ -n $m ]] && ! _bcl_inside "$BCL_AREA" "$m"; }; then
        [[ -n $m ]] && declare -F "outclick_$m" >/dev/null && "outclick_$m" "$BC_ME_Y" "$BC_ME_X" "$BC_ME_BSTATE"
        continue
      fi
      BCL_MB=$BC_ME_BSTATE
      declare -F on_mouse >/dev/null && on_mouse "$BC_ME_Y" "$BC_ME_X" "$BC_ME_BSTATE" "$BCL_AREA"
      _bcl_click "$BCL_AREA" "$BCL_MY" "$BCL_MX" "$BCL_MB" "$m"
    done
    return 0
  fi
  # the focused area first, then floats top-down, then on_key
  if [[ -n $BCL_FOCUS && -n ${BCL_WIN[$BCL_FOCUS]:-} ]] && { [[ -z $m ]] || _bcl_inside "$BCL_FOCUS" "$m"; }; then
    _bcl_keyfn "$BCL_FOCUS" && _bcl_handle "$BCL_FN" "$k" && return 0
  fi
  local -a fl
  read -r -a fl <<< "$BCL_FLOATS"
  for (( i = ${#fl[@]} - 1; i >= 0; i-- )); do
    [[ -n $m ]] && ! _bcl_inside "${fl[i]}" "$m" && continue
    [[ ${fl[i]} == "$BCL_FOCUS" ]] && continue
    _bcl_keyfn "${fl[i]}" && _bcl_handle "$BCL_FN" "$k" && return 0
  done
  [[ -n $m ]] && return 0
  declare -F on_key >/dev/null && on_key "$k"
  return 0
}

# A click goes to the area's widget handler, then click_NAME, then on_click
# (each may bc_pass it on).
_bcl_click() { # area y x bstate modal
  local a=$1
  if [[ -n ${BCL_CLICKFN[$a]:-} ]]; then
    _bcl_handle "${BCL_CLICKFN[$a]}" "$a" "$2" "$3" "$4" && return 0
  fi
  if declare -F "click_$a" >/dev/null; then
    _bcl_handle "click_$a" "$2" "$3" "$4" && return 0
  fi
  declare -F on_click >/dev/null && on_click "$a" "$2" "$3" "$4"
  return 0
}

_bcl_loop() { # modal-float or ""
  local m=$1 frame=0 last next wait
  [[ -n $BCL_FPS ]] && frame=$(( 1000 / BCL_FPS ))
  (( frame < 1 && ${BCL_FPS:-0} > 0 )) && frame=1
  _bcl_now_ms; last=$BCL_NOW
  while (( ! BCL_QUIT )); do
    [[ -n $m ]] && { (( BCL_MODAL_END )) || [[ -z ${BCL_KIND[$m]:-} ]]; } && break
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

# bc_modal NAME — only NAME (and what is inside it: its grid, floats placed in
# it) sees keys and clicks until NAME is closed (bc_close NAME [RESULT], for a
# float) or bc_modal_done [RESULT] is called (any area). A click outside goes
# to outclick_NAME Y X BSTATE (screen coordinates) if defined, else nowhere.
# Returns 0 if it ended with a result, which is left in BCL_RESULT.
BCL_MODAL_END=0
bc_modal() {
  local a=$1 prev=$BCL_MODAL
  [[ -n ${BCL_KIND[$a]:-} ]] || { _bcl_err "bc_modal: unknown area '$a'"; return 1; }
  local pfocus=$BCL_FOCUS
  BCL_RESULT=""
  BCL_MODAL=$a BCL_MODAL_END=0
  _bcl_loop "$a"
  BCL_MODAL=$prev BCL_MODAL_END=0
  BCL_FOCUS=$pfocus
  [[ -n $BCL_RESULT ]]
}

# bc_modal_done [RESULT] — end the innermost bc_modal.
bc_modal_done() { BCL_RESULT=${1:-} BCL_MODAL_END=1; }

# bc_quit — leave bc_run (and any bc_modal inside it).
bc_quit() { BCL_QUIT=1; }
