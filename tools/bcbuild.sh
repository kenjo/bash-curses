#!/usr/bin/env bash
# bcbuild — interactive layout designer for the bash_curses layout layer.
#
# Design a bc_screen/bc_grid/bc_float/bc_style layout visually: click to
# select, keys (or menus) to split, style and tag areas, drag track
# boundaries and floats. Designs save as replayable bash, and export as a
# runnable skeleton app. See docs/builder.md.
#
#   tools/bcbuild.sh [project.bcl]
#
set -uo pipefail

BCB_SELF_DIR=${BASH_SOURCE[0]%/*}
source "$BCB_SELF_DIR/../lib/widgets.sh"

# ------------------------------------------------------------------ options
BCB_MIN_COLS=110 BCB_MIN_LINES=32
BCB_E='c.'           # engine-name prefix for every design area
BCB_ROOT='@'         # model key of the root grid
BCB_ERR=""
BCB_MSG=""
BCB_SEL=""
BCB_FILE=""
BCB_DIRTY=0
BCB_DRAG=""          # active drag: "bnd|move|size ..." fields
BCB_UNDO=() BCB_REDO=()

# design colour pairs: fixed numbers so exports reproduce them; the builder
# allocates its own UI pairs above these.
BCB_NPAL=8
_bb_pal() { # idx -> "fg bg"
  case $1 in
    1) echo "7 0" ;; 2) echo "7 4" ;; 3) echo "7 1" ;; 4) echo "7 2" ;;
    5) echo "7 6" ;; 6) echo "0 7" ;; 7) echo "1 7" ;; 8) echo "5 7" ;;
  esac
}

# ------------------------------------------------------------------- model
declare -A BB_TPL BB_ROWSPEC BB_COLSPEC BB_GAP BB_BORDER BB_KIDS
declare -A BB_PARENT BB_KIND                 # area -> grid ; area -> area|float
declare -A BB_FIN BB_FAT BB_FSIZE BB_FWITHIN # floats
declare -A BB_PAIR BB_ATTR BB_FRAME BB_TITLE BB_SHADOW BB_BPAIR BB_TPAIR
declare -A BB_TLEFT BB_MARGIN BB_DIVIDER BB_SPAIR
declare -A BB_TAG                            # area -> widget tag
declare -A BB_R0 BB_R1 BB_C0 BB_C1           # parsed template spans
BB_FLOATS=""                                 # float names, bottom -> top

bb_reset() {
  local k
  for k in TPL ROWSPEC COLSPEC GAP BORDER KIDS PARENT KIND FIN FAT FSIZE FWITHIN \
           PAIR ATTR FRAME TITLE SHADOW BPAIR TPAIR TLEFT MARGIN DIVIDER SPAIR \
           TAG R0 R1 C0 C1; do
    unset "BB_$k"; declare -gA "BB_$k"
  done
  BB_FLOATS="" BCB_SEL="" BCB_ERR=""
}

bb_new() {
  bb_reset
  BB_TPL[$BCB_ROOT]="main"
  BB_ROWSPEC[$BCB_ROOT]="*" BB_COLSPEC[$BCB_ROOT]="*"
  BB_GAP[$BCB_ROOT]=0 BB_BORDER[$BCB_ROOT]=0
  _bb_parse_grid "$BCB_ROOT" || return 1
  BCB_SEL=main
  return 0
}

_bb_name_ok() { # name
  [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]] && [[ $1 != "$BCB_ROOT" ]]
}

_bb_taken() { # name
  [[ -n ${BB_KIND[$1]+set} ]]
}

_bb_uname() { # base -> BCB_NAME
  local base=$1 n=$1 i=0
  while _bb_taken "$n"; do i=$(( i + 1 )); n="$base$i"; done
  BCB_NAME=$n
}

# Parse BB_TPL[g] ("row1|row2", tokens by space) into spans/kids/parents.
_bb_parse_grid() { # g
  local g=$1
  local -a rows=() toks=()
  IFS='|' read -r -a rows <<< "${BB_TPL[$g]}"
  local -A r0=() r1=() c0=() c1=() cnt=()
  local -a order=()
  local r c name nc=-1 line ri=0
  for line in "${rows[@]}"; do
    read -r -a toks <<< "$line"
    if (( nc < 0 )); then nc=${#toks[@]}
    elif (( ${#toks[@]} != nc )); then
      BCB_ERR="template row has ${#toks[@]} cells, expected $nc"; return 1
    fi
  done
  for line in "${rows[@]}"; do
    read -r -a toks <<< "$line"
    for (( c = 0; c < nc; c++ )); do
      name=${toks[c]}
      [[ $name == . ]] && continue
      _bb_name_ok "$name" || { BCB_ERR="bad area name '$name'"; return 1; }
      if [[ -z ${cnt[$name]+set} ]]; then
        [[ -n ${BB_KIND[$name]+set} && ${BB_PARENT[$name]:-} != "$g" ]] && \
          { BCB_ERR="area '$name' defined elsewhere"; return 1; }
        order+=("$name"); cnt[$name]=0
        r0[$name]=$ri; r1[$name]=$ri; c0[$name]=$c; c1[$name]=$c
      fi
      cnt[$name]=$(( cnt[$name] + 1 ))
      (( c < c0[$name] )) && c0[$name]=$c
      (( c > c1[$name] )) && c1[$name]=$c
    done
    ri=$(( ri + 1 ))
  done
  for name in "${order[@]}"; do
    if (( cnt[$name] != (r1[$name] - r0[$name] + 1) * (c1[$name] - c0[$name] + 1) )); then
      BCB_ERR="area '$name' is not a rectangle"; return 1
    fi
  done
  BB_KIDS[$g]="${order[*]}"
  for name in "${order[@]}"; do
    BB_KIND[$name]=area BB_PARENT[$name]=$g
    BB_R0[$name]=${r0[$name]} BB_R1[$name]=${r1[$name]}
    BB_C0[$name]=${c0[$name]} BB_C1[$name]=${c1[$name]}
  done
  return 0
}

# ------------------------------------------------------------- model edits
_bb_push() { # snapshot for undo
  BCB_UNDO+=("$(bb_serialize)")
  (( ${#BCB_UNDO[@]} > 60 )) && unset 'BCB_UNDO[0]'
  BCB_REDO=()
  BCB_DIRTY=1
}

bb_split() { # h|v
  local a=$BCB_SEL dir=$1
  [[ -n $a && -n ${BB_KIND[$a]+set} ]] || { BCB_ERR="select an area first"; return 1; }
  [[ -z ${BB_TPL[$a]+set} ]] || { BCB_ERR="'$a' is already split"; return 1; }
  _bb_push
  local n0 n1
  _bb_uname "$a.0"; n0=$BCB_NAME
  _bb_uname "$a.1"; n1=$BCB_NAME
  if [[ $dir == h ]]; then
    BB_TPL[$a]="$n0 $n1"
    BB_ROWSPEC[$a]="*" BB_COLSPEC[$a]="* *"
  else
    BB_TPL[$a]="$n0|$n1"
    BB_ROWSPEC[$a]="* *" BB_COLSPEC[$a]="*"
  fi
  BB_GAP[$a]=0 BB_BORDER[$a]=0
  _bb_parse_grid "$a" || return 1
  BCB_SEL=$n0
  return 0
}

# Replace one token with another in a grid template.
_bb_tpl_replace() { # g old new
  local g=$1 old=$2 new=$3
  local -a rows; IFS='|' read -r -a rows <<< "${BB_TPL[$g]}"
  local line n out=()
  for line in "${rows[@]}"; do
    local -a toks; read -r -a toks <<< "$line"
    for n in "${!toks[@]}"; do [[ ${toks[n]} == "$old" ]] && toks[n]=$new; done
    out+=("${toks[*]}")
  done
  local IFS='|'
  BB_TPL[$g]="${out[*]}"
}

bb_delete() {
  local a=$BCB_SEL g s
  [[ -n $a && ${BB_KIND[$a]:-} == area ]] || { BCB_ERR="select an area to delete"; return 1; }
  [[ -z ${BB_TPL[$a]+set} ]] || { BCB_ERR="delete the children of '$a' first"; return 1; }
  g=${BB_PARENT[$a]}
  _bb_push
  _bb_tpl_replace "$g" "$a" .
  _bb_forget "$a"
  _bb_parse_grid "$g" || return 1
  local -a kk; read -r -a kk <<< "${BB_KIDS[$g]:-}"
  if [[ $g != "$BCB_ROOT" ]] && (( ${#kk[@]} == 1 )); then
    s=${kk[0]}
    local gp=${BB_PARENT[$g]}
    _bb_tpl_replace "$gp" "$g" "$s"
    _bb_forget "$g"
    _bb_parse_grid "$gp" || return 1
    BCB_SEL=$s
  else
    BCB_SEL=${BB_KIDS[$g]:-}
  fi
  return 0
}

_bb_forget() { # name — drop a name and its subtree from the model
  local a=$1 k c
  for c in ${BB_KIDS[$a]:-}; do _bb_forget "$c"; done
  for k in TPL ROWSPEC COLSPEC GAP BORDER KIDS PARENT KIND FIN FAT FSIZE FWITHIN \
           PAIR ATTR FRAME TITLE SHADOW BPAIR TPAIR TLEFT MARGIN DIVIDER SPAIR \
           TAG R0 R1 C0 C1; do
    unset "BB_$k[$a]"
  done
  local fl=() f
  for f in $BB_FLOATS; do [[ $f == "$a" ]] || fl+=("$f"); done
  BB_FLOATS="${fl[*]:-}"
  [[ $BCB_SEL == "$a" ]] && BCB_SEL=""
}

bb_rename() { # old new
  local old=$1 new=$2
  _bb_name_ok "$new" || { BCB_ERR="bad name '$new'"; return 1; }
  _bb_taken "$new" && { BCB_ERR="'$new' already used"; return 1; }
  [[ -n ${BB_KIND[$old]+set} ]] || { BCB_ERR="no such area '$old'"; return 1; }
  _bb_push
  local g k f
  for g in "${!BB_TPL[@]}"; do _bb_tpl_replace "$g" "$old" "$new"; done
  for k in TPL ROWSPEC COLSPEC GAP BORDER KIDS PARENT KIND FIN FAT FSIZE FWITHIN \
           PAIR ATTR FRAME TITLE SHADOW BPAIR TPAIR TLEFT MARGIN DIVIDER SPAIR \
           TAG R0 R1 C0 C1; do
    local -n src=BB_$k
    [[ -n ${src[$old]+set} ]] || continue
    declare -g "BB_$k[$new]=${src[$old]}"
    unset "BB_$k[$old]"
  done
  for g in "${!BB_PARENT[@]}"; do [[ ${BB_PARENT[$g]} == "$old" ]] && BB_PARENT[$g]=$new; done
  for g in "${!BB_FIN[@]}"; do [[ ${BB_FIN[$g]} == "$old" ]] && BB_FIN[$g]=$new; done
  local fl=()
  for f in $BB_FLOATS; do [[ $f == "$old" ]] && fl+=("$new") || fl+=("$f"); done
  BB_FLOATS="${fl[*]:-}"
  [[ $BCB_SEL == "$old" ]] && BCB_SEL=$new
  [[ -n ${BB_PARENT[$new]+set} ]] && _bb_parse_grid "${BB_PARENT[$new]}"
  return 0
}

bb_set_style() { # key value — set/clear a style option on BCB_SEL
  local key=$1 val=$2 a=$BCB_SEL
  [[ -n $a && -n ${BB_KIND[$a]+set} ]] || { BCB_ERR="select an area first"; return 1; }
  _bb_push
  case $key in
    border) [[ -n $val ]] && BB_FRAME[$a]=1 || unset "BB_FRAME[$a]" ;;
    shadow) [[ -n $val ]] && BB_SHADOW[$a]=$val || unset "BB_SHADOW[$a]" ;;
    tleft) [[ -n $val ]] && BB_TLEFT[$a]=1 || unset "BB_TLEFT[$a]" ;;
    divider) [[ -n $val ]] && BB_DIVIDER[$a]=1 || unset "BB_DIVIDER[$a]" ;;
    title) [[ -n $val ]] && BB_TITLE[$a]=$val || unset "BB_TITLE[$a]" ;;
    *) [[ -n $val ]] && declare -g "BB_${key^^}[$a]=$val" || unset "BB_${key^^}[$a]" ;;
  esac
  return 0
}

bb_cycle_pair() { # which=PAIR|BPAIR|TPAIR
  local which=$1 a=$BCB_SEL cur
  [[ -n $a && -n ${BB_KIND[$a]+set} ]] || { BCB_ERR="select an area first"; return 1; }
  _bb_push
  local -n arr=BB_$which
  cur=${arr[$a]:-0}
  arr[$a]=$(( cur % BCB_NPAL + 1 ))
  return 0
}

bb_cycle_tag() {
  local a=$BCB_SEL
  [[ -n $a && ${BB_KIND[$a]:-} == area ]] || { BCB_ERR="select an area to tag"; return 1; }
  _bb_push
  local -a tags=("" label list input button check cycle menubar)
  local cur=${BB_TAG[$a]:-} i next=0
  for i in "${!tags[@]}"; do [[ ${tags[i]} == "$cur" ]] && next=$(( (i + 1) % ${#tags[@]} )); done
  local t=${tags[next]}
  [[ -n $t ]] && BB_TAG[$a]=$t || unset "BB_TAG[$a]"
  return 0
}

bb_gap() { # delta
  local a=$BCB_SEL g cur
  [[ -n $a && -n ${BB_KIND[$a]+set} ]] || { BCB_ERR="select an area first"; return 1; }
  g=${BB_PARENT[$a]}
  _bb_push
  cur=${BB_GAP[$g]:-0}
  cur=$(( cur + $1 )); (( cur < 0 )) && cur=0; (( cur > 3 )) && cur=3
  BB_GAP[$g]=$cur
  return 0
}

_bb_track_idx() { # axis -> BCB_TI (single track index of BCB_SEL in its grid)
  local ax=$1 a=$BCB_SEL g
  g=${BB_PARENT[$a]}
  if (( ax == 0 )); then
    (( BB_R0[$a] == BB_R1[$a] )) || { BCB_ERR="'$a' spans several row tracks"; return 1; }
    BCB_TI=${BB_R0[$a]}
  else
    (( BB_C0[$a] == BB_C1[$a] )) || { BCB_ERR="'$a' spans several column tracks"; return 1; }
    BCB_TI=${BB_C0[$a]}
  fi
  BCB_TG=$g
  return 0
}

_bb_measured() { # axis -> BCB_MV (current size of BCB_SEL)
  local ax=$1 e=$BCB_E$BCB_SEL
  if [[ -n ${BCL_RY[$e]+set} ]]; then
    (( ax == 0 )) && BCB_MV=${BCL_RH[$e]} || BCB_MV=${BCL_RW[$e]}
  else
    BCB_MV=8
  fi
}

bb_grow() { # axis 0=row 1=col, delta
  local ax=$1 d=$2
  [[ -n $BCB_SEL && ${BB_KIND[$BCB_SEL]:-} == area ]] || { BCB_ERR="select an area first"; return 1; }
  _bb_track_idx "$ax" || return 1
  _bb_measured "$ax"
  local cur=$BCB_MV
  local new=$(( cur + d ))
  (( new < 1 )) && new=1
  _bb_push
  local -a trk
  if (( ax == 0 )); then read -r -a trk <<< "${BB_ROWSPEC[$BCB_TG]}"; else read -r -a trk <<< "${BB_COLSPEC[$BCB_TG]}"; fi
  trk[BCB_TI]=$new
  if (( ax == 0 )); then BB_ROWSPEC[$BCB_TG]="${trk[*]}"; else BB_COLSPEC[$BCB_TG]="${trk[*]}"; fi
  return 0
}

bb_toggle_auto() { # axis
  local ax=$1
  [[ -n $BCB_SEL && ${BB_KIND[$BCB_SEL]:-} == area ]] || { BCB_ERR="select an area first"; return 1; }
  _bb_track_idx "$ax" || return 1
  _bb_push
  local -a trk
  if (( ax == 0 )); then read -r -a trk <<< "${BB_ROWSPEC[$BCB_TG]}"; else read -r -a trk <<< "${BB_COLSPEC[$BCB_TG]}"; fi
  if [[ ${trk[BCB_TI]} == auto ]]; then
    _bb_measured "$ax"
    trk[BCB_TI]=$BCB_MV
  else
    trk[BCB_TI]=auto
  fi
  if (( ax == 0 )); then BB_ROWSPEC[$BCB_TG]="${trk[*]}"; else BB_COLSPEC[$BCB_TG]="${trk[*]}"; fi
  return 0
}

bb_add_float() {
  _bb_push
  local f
  _bb_uname dlg; f=$BCB_NAME
  BB_KIND[$f]=float BB_FIN[$f]=$BCB_ROOT BB_FAT[$f]=center BB_FSIZE[$f]=autoxauto
  BB_FRAME[$f]=1 BB_TITLE[$f]=$f
  BB_FLOATS+=" $f"
  BCB_SEL=$f
  return 0
}

# ------------------------------------------------------------- serialise
# All model names, sorted, so serialise output is stable.
_bb_sorted() { printf '%s\n' "${!BB_KIND[@]}" | sort; }

bb_serialize() {
  local out="# bcbuild layout"
  local n k
  local -a q=("$BCB_ROOT")
  while (( ${#q[@]} )); do
    n=${q[0]}; q=("${q[@]:1}")
    if [[ $n == "$BCB_ROOT" ]]; then
      out+=$'\n'"bc_screen \"$(_bb_tpl_nl "$n")\" rows=\"${BB_ROWSPEC[$n]}\" cols=\"${BB_COLSPEC[$n]}\" gap=${BB_GAP[$n]:-0} border=${BB_BORDER[$n]:-0}"
    else
      out+=$'\n'"bc_grid $n \"$(_bb_tpl_nl "$n")\" rows=\"${BB_ROWSPEC[$n]}\" cols=\"${BB_COLSPEC[$n]}\" gap=${BB_GAP[$n]:-0} border=${BB_BORDER[$n]:-0}"
    fi
    for k in ${BB_KIDS[$n]:-}; do [[ -n ${BB_TPL[$k]+set} ]] && q+=("$k"); done
  done
  for n in $BB_FLOATS; do
    out+=$'\n'"bc_float $n in=${BB_FIN[$n]} at=${BB_FAT[$n]} size=${BB_FSIZE[$n]}"
    [[ -n ${BB_FWITHIN[$n]:-} ]] && out+=" within=${BB_FWITHIN[$n]}"
    [[ -n ${BB_TPL[$n]+set} ]] && out+=$'\n'"bc_grid $n \"$(_bb_tpl_nl "$n")\" rows=\"${BB_ROWSPEC[$n]}\" cols=\"${BB_COLSPEC[$n]}\" gap=${BB_GAP[$n]:-0} border=${BB_BORDER[$n]:-0}"
  done
  for n in $(_bb_sorted); do
    local opts=""
    [[ -n ${BB_FRAME[$n]:-} ]] && opts+=" border"
    [[ -n ${BB_PAIR[$n]:-} ]] && opts+=" pair=${BB_PAIR[$n]}"
    [[ -n ${BB_ATTR[$n]:-} ]] && opts+=" attr=${BB_ATTR[$n]}"
    [[ -n ${BB_BPAIR[$n]:-} ]] && opts+=" bpair=${BB_BPAIR[$n]}"
    [[ -n ${BB_TPAIR[$n]:-} ]] && opts+=" tpair=${BB_TPAIR[$n]}"
    [[ -n ${BB_TITLE[$n]:-} ]] && opts+=" title=\"${BB_TITLE[$n]}\""
    [[ -n ${BB_TLEFT[$n]:-} ]] && opts+=" tleft"
    [[ -n ${BB_SHADOW[$n]:-} ]] && opts+=" shadow=${BB_SHADOW[$n]}"
    [[ -n ${BB_SPAIR[$n]:-} ]] && opts+=" spair=${BB_SPAIR[$n]}"
    [[ -n ${BB_MARGIN[$n]:-} ]] && opts+=" margin=${BB_MARGIN[$n]}"
    [[ -n ${BB_DIVIDER[$n]:-} ]] && opts+=" divider"
    [[ -n $opts ]] && out+=$'\n'"bc_style $n$opts"
    [[ -n ${BB_TAG[$n]:-} ]] && out+=$'\n'"BB_TAG[$n]=${BB_TAG[$n]}"
  done
  out+=$'\n'"BB_SEL_X=\"$BCB_SEL\""
  printf '%s\n' "$out"
}

_bb_tpl_nl() { # grid -> template with rows on separate lines
  local -a rows; IFS='|' read -r -a rows <<< "${BB_TPL[$1]}"
  local r out=""
  for r in "${rows[@]}"; do out+="  $r"$'\n'; done
  printf '%s' "${out%$'\n'}"
}

# Load: replay a project file through recording stubs (renamed so the real
# library functions are never shadowed).
bb_load_text() { # text
  bb_reset
  local line out=""
  while IFS= read -r line; do
    case $line in
      bc_screen\ *) line="_bcb_screen ${line#bc_screen }" ;;
      bc_grid\ *)   line="_bcb_grid ${line#bc_grid }" ;;
      bc_float\ *)  line="_bcb_float ${line#bc_float }" ;;
      bc_style\ *)  line="_bcb_style ${line#bc_style }" ;;
    esac
    out+="$line"$'\n'
  done <<< "$1"
  eval "$out"
  local g
  for g in "${!BB_TPL[@]}"; do _bb_parse_grid "$g" || return 1; done
  BCB_SEL=${BB_SEL_X:-}
  unset 'BB_SEL_X'
  if [[ -z $BCB_SEL ]]; then
    local k
    for k in "${!BB_KIND[@]}"; do
      [[ ${BB_KIND[$k]} == area && -z ${BB_TPL[$k]+set} ]] && { BCB_SEL=$k; break; }
    done
  fi
  return 0
}

_bcb_screen() { _bcb_grid "$BCB_ROOT" "$1" "${@:2}"; }

_bcb_grid() { # grid tpl opts...
  local g=$1 tpl=$2; shift 2
  local rows="" cols="" gap=0 border=0 o line
  for o in "$@"; do
    case $o in
      rows=*) rows=${o#*=} ;; cols=*) cols=${o#*=} ;;
      gap=*) gap=${o#*=} ;; border=*) border=${o#*=} ;;
    esac
  done
  local -a lines=() t
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*$ ]] && continue
    read -r -a t <<< "$line"
    lines+=("${t[*]}")
  done <<< "$tpl"
  local IFS='|'
  BB_TPL[$g]="${lines[*]}"
  IFS=' '
  BB_ROWSPEC[$g]=$rows BB_COLSPEC[$g]=$cols BB_GAP[$g]=$gap BB_BORDER[$g]=$border
}

_bcb_float() { # name opts...
  local a=$1 o in=$BCB_ROOT at=center size=autoxauto within=""
  for o in "$@"; do
    case $o in
      in=*) in=${o#*=} ;; at=*) at=${o#*=} ;; size=*) size=${o#*=} ;;
      within=*) within=${o#*=} ;;
    esac
  done
  BB_KIND[$a]=float BB_FIN[$a]=$in BB_FAT[$a]=$at BB_FSIZE[$a]=$size BB_FWITHIN[$a]=$within
  BB_FLOATS+=" $a"
  _bcb_style "$a" "${@:2}"
}

_bcb_style() { # name opts...
  local a=$1 o
  for o in "${@:2}"; do
    case $o in
      border) BB_FRAME[$a]=1 ;;
      shadow) BB_SHADOW[$a]=1 ;;
      shadow=*) BB_SHADOW[$a]=${o#*=} ;;
      tleft) BB_TLEFT[$a]=1 ;;
      divider) BB_DIVIDER[$a]=1 ;;
      pair=*) BB_PAIR[$a]=${o#*=} ;;
      attr=*) BB_ATTR[$a]=${o#*=} ;;
      bpair=*) BB_BPAIR[$a]=${o#*=} ;;
      tpair=*) BB_TPAIR[$a]=${o#*=} ;;
      title=*) local v=${o#title=}; v=${v#\"}; v=${v%\"}; BB_TITLE[$a]=$v ;;
      margin=*) BB_MARGIN[$a]=${o#*=} ;;
      spair=*) BB_SPAIR[$a]=${o#*=} ;;
    esac
  done
}

bb_load_file() { # path
  local text
  text=$(<"$1") || { BCB_ERR="cannot read $1"; return 1; }
  bb_load_text "$text" || return 1
  BCB_FILE=$1 BCB_DIRTY=0
  return 0
}

bb_save() { # path
  local path=${1:-$BCB_FILE}
  [[ -n $path ]] || { BCB_ERR="no filename"; return 1; }
  bb_serialize > "$path" || { BCB_ERR="cannot write $path"; return 1; }
  BCB_FILE=$path BCB_DIRTY=0
  BCB_MSG="saved $path"
  return 0
}

bb_undo() {
  (( ${#BCB_UNDO[@]} )) || { BCB_ERR="nothing to undo"; return 1; }
  BCB_REDO+=("$(bb_serialize)")
  bb_load_text "${BCB_UNDO[-1]}"
  unset 'BCB_UNDO[-1]'
  BCB_DIRTY=1
  return 0
}

bb_redo() {
  (( ${#BCB_REDO[@]} )) || { BCB_ERR="nothing to redo"; return 1; }
  BCB_UNDO+=("$(bb_serialize)")
  bb_load_text "${BCB_REDO[-1]}"
  unset 'BCB_REDO[-1]'
  BCB_DIRTY=1
  return 0
}

# ------------------------------------------------------------- export
bb_export() { # path
  local path=${1:-} tags=0 n t fb
  [[ -n $path ]] || { BCB_ERR="no filename"; return 1; }
  for n in "${!BB_TAG[@]}"; do tags=1; done
  {
    printf '#!/usr/bin/env bash\n# generated by bcbuild\n'
    if (( tags )); then
      printf 'source "${BC_LIB_DIR:-%s/..}/lib/widgets.sh"\n' "$BCB_SELF_DIR"
    else
      printf 'source "${BC_LIB_DIR:-%s/..}/lib/layout.sh"\n' "$BCB_SELF_DIR"
    fi
    local -A used=()
    for n in "${!BB_PAIR[@]}"; do used[${BB_PAIR[$n]}]=1; done
    for n in "${!BB_BPAIR[@]}"; do used[${BB_BPAIR[$n]}]=1; done
    for n in "${!BB_TPAIR[@]}"; do used[${BB_TPAIR[$n]}]=1; done
    for n in "${!used[@]}"; do
      fb=$(_bb_pal "$n")
      printf 'init_pair %s %s\n' "$n" $fb
    done
    bb_serialize | grep -v '^BB_TAG\|^BB_SEL_X'
    for n in $(_bb_sorted); do
      [[ ${BB_KIND[$n]} == area ]] || continue
      [[ -n ${BB_TPL[$n]+set} ]] && continue
      t=${BB_TAG[$n]:-}
      local v=${n//./_}
      case $t in
        label) printf 'bc_label %s "%s"\n' "$n" "$n" ;;
        list)
          printf '%s_items=("one" "two" "three")\nbc_list %s %s_items\n' "$v" "$n" "$v"
          printf 'row_%s() { local s=" ${%s_items[$1]} "; if (( $3 )); then bc_print %s "$2" 0 "$s" pair=4; else bc_print %s "$2" 0 "$s"; fi; }\n' "$n" "$v" "$n" "$n" ;;
        input) printf '%s_val=""\nbc_input %s %s_val\n' "$v" "$n" "$v" ;;
        button) printf 'bc_button %s "%s"\n' "$n" "$n" ;;
        check) printf '%s_on=0\nbc_check %s %s_on "%s"\n' "$v" "$n" "$v" "$n" ;;
        cycle) printf '%s_i=0\nbc_cycle %s %s_i "%s:" a b c\n' "$v" "$n" "$v" "$n" ;;
        menubar) printf 'MENU_File=("Open||O" "---" "Quit||Q")\nbc_menubar %s "File:2"\n' "$n" ;;
        *) printf 'draw_%s() { bc_print %s 0 0 "%s"; }\n' "$n" "$n" "$n" ;;
      esac
    done
    printf '\nbc_init mouse\nbc_run\n'
  } > "$path" || { BCB_ERR="cannot write $path"; return 1; }
  chmod +x "$path"
  BCB_MSG="exported $path"
  return 0
}

# ---------------------------------------------------------------- render
_bb_tpl_e() { # grid -> template with engine-prefixed tokens
  local -a rows; IFS='|' read -r -a rows <<< "${BB_TPL[$1]}"
  local r n out=()
  for r in "${rows[@]}"; do
    local -a toks; read -r -a toks <<< "$r"
    for n in "${!toks[@]}"; do [[ ${toks[n]} != . ]] && toks[n]=$BCB_E${toks[n]}; done
    out+=("${toks[*]}")
  done
  local IFS=$'\n'
  printf '%s' "${out[*]}"
}

bb_render() {
  [[ -z ${BCB_TEST:-} ]] || return 0
  local e n
  for e in ${BCL_FLOATS:-}; do
    [[ $e == "$BCB_E"* ]] || continue
    n=${e#"$BCB_E"}
    [[ ${BB_KIND[$n]:-} == float ]] || bc_close "$e"
  done
  bc_grid cvs "$(_bb_tpl_e "$BCB_ROOT")" rows="${BB_ROWSPEC[$BCB_ROOT]}" \
    cols="${BB_COLSPEC[$BCB_ROOT]}" gap="${BB_GAP[$BCB_ROOT]:-0}" \
    border="${BB_BORDER[$BCB_ROOT]:-0}" || { BCB_ERR=$BCL_ERR; return 1; }
  for n in $BB_FLOATS; do
    bc_float "$BCB_E$n" "in=$(_bb_e_parent "$n")" "at=${BB_FAT[$n]}" "size=${BB_FSIZE[$n]}" || \
      { BCB_ERR=$BCL_ERR; return 1; }
  done
  for n in "${!BB_TPL[@]}"; do
    [[ $n == "$BCB_ROOT" ]] && continue
    bc_grid "$BCB_E$n" "$(_bb_tpl_e "$n")" rows="${BB_ROWSPEC[$n]}" \
      cols="${BB_COLSPEC[$n]}" gap="${BB_GAP[$n]:-0}" border="${BB_BORDER[$n]:-0}" || \
      { BCB_ERR=$BCL_ERR; return 1; }
  done
  for n in "${!BB_KIND[@]}"; do _bb_style_e "$n"; done
  _bb_sel_style
  bc_dirty all
  return 0
}

_bb_e_parent() { # float -> engine parent name
  local p=${BB_FIN[$1]}
  [[ $p == "$BCB_ROOT" ]] && printf cvs || printf '%s%s' "$BCB_E" "$p"
}

_bb_style_e() { # model name -> mirror BB_* into BCL_*
  local n=$1 e k v
  [[ $n == "$BCB_ROOT" ]] && return 0
  e=$BCB_E$n
  [[ -n ${BCL_KIND[$e]+set} ]] || return 0
  for k in PAIR ATTR FRAME TITLE SHADOW BPAIR TPAIR TLEFT DIVIDER SPAIR; do
    local -n arr=BB_$k
    if [[ -n ${arr[$n]+set} ]]; then
      v=${arr[$n]}
      case $k in
        FRAME) bc_style "$e" border ;;
        SHADOW) bc_style "$e" "shadow=$v" ;;
        TLEFT) bc_style "$e" tleft ;;
        DIVIDER) bc_style "$e" divider ;;
        *) bc_style "$e" "$(printf '%s' "$k" | tr 'A-Z' 'a-z')=$v" ;;
      esac
    else
      case $k in
        FRAME) bc_style "$e" border=0 ;;
        SHADOW) bc_style "$e" shadow=0 ;;
        TPAIR) unset 'BCL_TPEN[$e]' ;;
        *) unset "BCL_$k[$e]" ;;
      esac
    fi
  done
  # a margin (even 0) keeps tiled grids bindable, so gap clicks reach on_click
  [[ ${BB_KIND[$n]} == area ]] && bc_style "$e" "margin=${BB_MARGIN[$n]:-0}"
}

_bb_sel_style() {
  [[ -n $BCB_SEL ]] || return 0
  local e=$BCB_E$BCB_SEL
  [[ -n ${BCL_KIND[$e]+set} ]] || return 0
  bc_style "$e" "bpair=$BCB_SELP"
  [[ -z ${BCL_FRAME[$e]:-} ]] && bc_style "$e" border
}

# ------------------------------------------------------------------- UI
BB_TREE=()
_bb_tree() {
  BB_TREE=()
  _bb_tree_walk "$BCB_ROOT" 0
  local f
  for f in $BB_FLOATS; do BB_TREE+=("0 $f"); done
}
_bb_tree_walk() { # grid depth
  local g=$1 d=$2 k
  for k in ${BB_KIDS[$g]}; do
    BB_TREE+=("$d $k")
    [[ -n ${BB_TPL[$k]+set} ]] && _bb_tree_walk "$k" $(( d + 1 ))
  done
}

_bb_tree_idx() { # name -> index or -1
  local i
  for i in "${!BB_TREE[@]}"; do
    [[ ${BB_TREE[i]#* } == "$1" ]] && { printf '%s' "$i"; return 0; }
  done
  printf -- '-1'
  return 1
}

bb_select() { # name
  BCB_SEL=$1
  [[ -n ${BCB_TEST:-} ]] && return 0
  local i
  i=$(_bb_tree_idx "$1") || i=-1
  (( i >= 0 )) && bc_list_sel pal "$i"
  bb_render
  bc_dirty prop st
}

row_pal() { # idx y sel
  [[ -n ${BB_TREE[$1]:-} ]] || return 0
  local d=${BB_TREE[$1]%% *} name=${BB_TREE[$1]#* }
  local tag=${BB_TAG[$name]:-} kind=${BB_KIND[$name]:-}
  local t
  if [[ $kind == float ]]; then t="$(printf '%*s* %s' $(( d * 2 )) '' "$name")"
  else t="$(printf '%*s  %s%s' $(( d * 2 )) '' "$name" "${tag:+ [$tag]}")"; fi
  if (( $3 )); then bc_print pal "$2" 0 "$t" pair=$BCB_SELP
  else bc_print pal "$2" 0 "$t"; fi
}

select_pal() { # idx
  [[ -n ${BB_TREE[$1]:-} ]] || return 0
  BCB_SEL=${BB_TREE[$1]#* }
  bb_render
  bc_dirty prop st
}

declare -A BCB_PROW=()  # prop content row -> click action
declare -A BCB_PBTN=()  # prop content row -> "x1 x2 act1 x3 x4 act2"

_bb_prop_row() { # y text action
  bc_print prop "$1" 1 "$2"
  [[ -n $3 ]] && BCB_PROW[$1]=$3
}

_bb_prop_btn() { # y text act-minus act-plus
  bc_print prop "$1" 1 "$2"
  bc_print prop "$1" 21 "[-] [+]"
  BCB_PBTN[$1]="21 23 $3 25 27 $4"
}

draw_prop() {
  local a=$BCB_SEL y=0 g e
  BCB_PROW=() BCB_PBTN=()
  if [[ -z $a ]]; then
    bc_print prop 0 1 "no selection"
    return
  fi
  bc_print prop $(( y++ )) 1 "name:    $a"
  bc_print prop $(( y++ )) 1 "kind:    ${BB_KIND[$a]}"
  g=${BB_PARENT[$a]:-}
  [[ -n $g ]] && bc_print prop $(( y++ )) 1 "in:      ${g/$BCB_ROOT/root}"
  e=$BCB_E$a
  if [[ -n ${BCL_RY[$e]+set} ]]; then
    bc_print prop $(( y++ )) 1 "rect:    ${BCL_RH[$e]}x${BCL_RW[$e]} @ ${BCL_RY[$e]},${BCL_RX[$e]}"
  fi
  if [[ -n ${BB_TPL[$a]+set} ]]; then
    bc_print prop $(( y++ )) 1 "rows:    ${BB_ROWSPEC[$a]}"
    bc_print prop $(( y++ )) 1 "cols:    ${BB_COLSPEC[$a]}"
    _bb_prop_btn $(( y++ )) "gap:     ${BB_GAP[$a]:-0}" "gap-" "gap+"
  elif [[ -n $g ]]; then
    local -a rs cs
    read -r -a rs <<< "${BB_ROWSPEC[$g]}"; read -r -a cs <<< "${BB_COLSPEC[$g]}"
    _bb_prop_btn $(( y++ )) "row trk: ${rs[${BB_R0[$a]}]}" "trk-" "trk+"
    _bb_prop_btn $(( y++ )) "col trk: ${cs[${BB_C0[$a]}]}" "ctrk-" "ctrk+"
  fi
  if [[ ${BB_KIND[$a]} == float ]]; then
    bc_print prop $(( y++ )) 1 "at:      ${BB_FAT[$a]}"
    bc_print prop $(( y++ )) 1 "size:    ${BB_FSIZE[$a]}"
  fi
  _bb_prop_row $(( y++ )) "border:  $([[ -n ${BB_FRAME[$a]:-} ]] && echo on || echo off)" "tog border"
  _bb_prop_row $(( y++ )) "title:   ${BB_TITLE[$a]:-}" "prompt title"
  _bb_prop_row $(( y++ )) "pair:    ${BB_PAIR[$a]:-0}" "cyc pair"
  _bb_prop_row $(( y++ )) "shadow:  ${BB_SHADOW[$a]:-off}" "cyc shadow"
  _bb_prop_row $(( y++ )) "margin:  ${BB_MARGIN[$a]:-0}" "cyc margin"
  _bb_prop_row $(( y++ )) "divider: $([[ -n ${BB_DIVIDER[$a]:-} ]] && echo on || echo off)" "tog divider"
  _bb_prop_row $(( y++ )) "t-left:  $([[ -n ${BB_TLEFT[$a]:-} ]] && echo on || echo off)" "tog tleft"
  _bb_prop_row $(( y++ )) "tag:     ${BB_TAG[$a]:-none}" "cyc tag"
}

click_prop() { # y x bstate
  local y=$1 x=$2 b=$3 act
  (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED) )) || return 0
  [[ -n $BCB_SEL ]] || return 0
  if [[ -n ${BCB_PBTN[$y]:-} ]]; then
    local -a z
    read -r -a z <<< "${BCB_PBTN[$y]}"
    if (( x >= z[0] && x <= z[1] )); then _bb_prop_act "${z[2]}"; return 0; fi
    if (( x >= z[3] && x <= z[4] )); then _bb_prop_act "${z[5]}"; return 0; fi
  fi
  act=${BCB_PROW[$y]:-}
  [[ -n $act ]] && _bb_prop_act "$act"
  return 0
}

_bb_prop_act() { # action
  local a=$BCB_SEL
  case $1 in
    'tog border')  bb_set_style border "$([[ -n ${BB_FRAME[$a]:-} ]] && echo '' || echo 1)" ;;
    'tog divider') bb_set_style divider "$([[ -n ${BB_DIVIDER[$a]:-} ]] && echo '' || echo 1)" ;;
    'tog tleft')   bb_set_style tleft "$([[ -n ${BB_TLEFT[$a]:-} ]] && echo '' || echo 1)" ;;
    'cyc pair')    bb_cycle_pair PAIR ;;
    'cyc shadow')  bb_cycle_shadow ;;
    'cyc margin')  bb_cycle_margin ;;
    'cyc tag')     bb_cycle_tag ;;
    'prompt title') if bb_prompt "Title" "title text" "${BB_TITLE[$a]:-}"; then bb_set_style title "$REPLY"; fi ;;
    'trk-')  bb_grow 0 -1 ;;
    'trk+')  bb_grow 0 1 ;;
    'ctrk-') bb_grow 1 -1 ;;
    'ctrk+') bb_grow 1 1 ;;
    'gap-')  bb_gap -1 ;;
    'gap+')  bb_gap 1 ;;
    *) return 0 ;;
  esac
  bb_after
}

draw_st() {
  local msg=${BCB_MSG:-}
  if [[ -n $msg ]]; then
    bc_print st 0 1 "$msg"
    return
  fi
  if [[ -n $BCB_ERR ]]; then
    bc_print st 0 1 "! $BCB_ERR" pair=$BCB_MSGP
    return
  fi
  bc_print st 0 1 "click: select · toolbar buttons · prop rows/[-][+] · drag edges & floats"
  bc_print st 1 1 "h/v split  d del  r rename  t title  b border  p pair  s shadow  w tag  f float"
  bc_print st 2 1 "+/- < > size  a auto  [] gap  u undo  ? help  q quit  ^S save  ^O open  ^E export"
}

# ------------------------------------------------------- modal prompts
BB_PROMPT_VAL=""

bb_prompt() { # title label default -> REPLY
  local title=$1 label=$2 def=$3
  BB_PROMPT_VAL=$def
  bc_dialog bcprompt "$title" 7x44 margin=1 shadow=mc
  bc_grid bcprompt "
    bcprompt.lbl  bcprompt.fld
    bcprompt.ok   bcprompt.cancel
  " rows="auto auto" cols="auto *" gap=1
  bc_label bcprompt.lbl "$label"
  bc_input bcprompt.fld BB_PROMPT_VAL
  bc_button bcprompt.ok "OK" ok
  bc_button bcprompt.cancel "Cancel" cancel
  if bc_dialog_run bcprompt focus=bcprompt.fld; then
    REPLY=$BB_PROMPT_VAL
    return 0
  fi
  REPLY=""
  return 1
}

bb_yes() { # title text -> 0 yes
  bc_dialog bcq "$1" 7x44 margin=1 shadow=mc
  bc_grid bcq "
    bcq.txt
    bcq.yes  bcq.no
  " rows="auto auto" cols="* *"
  bc_text bcq.txt "$2"
  bc_button bcq.yes "Yes" ok
  bc_button bcq.no "No" cancel
  bc_dialog_run bcq focus=bcq.yes
}

_bchelp_key() { bc_close bchelp; }

bb_help() {
  bc_float bchelp in=screen at=center size=autox74 border title="bcbuild — keys" \
    shadow=mc keys=_bchelp_key pair=6
  bc_text bchelp "
Click an area (or a tree row) to select it.

  h / v        split the selected area horizontally / vertically
  d            delete the selected area (collapses its parent)
  r            rename the selected area
  t            set the border title
  b            toggle border        p  cycle colour pair
  s            cycle shadow         l  toggle title-left
  D            toggle divider       m  cycle margin (0-2)
  w            cycle widget tag (label list input button ...)
  f            add a float          Tab  next area
  + / -        grow / shrink rows   < / >  grow / shrink cols
  a / A        toggle auto on the row / column track
  [ / ]        gap - / + in the parent grid
  drag a track boundary; drag a float (corner resizes)
  u / Ctrl-Y   undo / redo
  Ctrl-S save  Ctrl-O open  Ctrl-E export  ?  this help  q  quit
" align=left
  bc_modal bchelp
  bc_dirty all
}

# ----------------------------------------------------------------- mouse
_bb_hit_grid() { # y x -> BCB_HG (engine grid name) or 1
  local y=$1 x=$2 best="" bestd=-1 n e d p
  local -a cands=("$BCB_ROOT")
  for n in "${!BB_TPL[@]}"; do [[ $n != "$BCB_ROOT" ]] && cands+=("$n"); done
  for n in "${cands[@]}"; do
    if [[ $n == "$BCB_ROOT" ]]; then e=cvs; else e=$BCB_E$n; fi
    [[ -n ${BCL_RY[$e]+set} ]] || continue
    (( y >= BCL_RY[$e] && y < BCL_RY[$e] + BCL_RH[$e] )) || continue
    (( x >= BCL_RX[$e] && x < BCL_RX[$e] + BCL_RW[$e] )) || continue
    d=0; p=$n
    while [[ -n $p && $p != "$BCB_ROOT" ]]; do p=${BB_PARENT[$p]:-}; d=$(( d + 1 )); done
    (( d > bestd )) && { bestd=$d; best=$e; }
  done
  [[ -n $best ]] || return 1
  BCB_HG=$best
  return 0
}

_bb_hit_bnd() { # y x e -> 0 if on a boundary; BCB_BND="v|h e a b pos"
  local y=$1 x=$2 e=$3 k
  local g=$BCB_ROOT
  [[ $e != cvs ]] && g=${e#"$BCB_E"}
  local -a kids=()
  for k in ${BB_KIDS[$g]}; do kids+=("$BCB_E$k"); done
  local i j a b
  for (( i = 0; i < ${#kids[@]}; i++ )); do
    for (( j = i + 1; j < ${#kids[@]}; j++ )); do
      a=${kids[i]}; b=${kids[j]}
      [[ -n ${BCL_RY[$a]+set} && -n ${BCL_RY[$b]+set} ]] || continue
      if (( BCL_RX[$a] < BCL_RX[$b] &&
            BCL_RX[$b] - (BCL_RX[$a] + BCL_RW[$a]) <= 1 &&
            x >= BCL_RX[$a] + BCL_RW[$a] - 1 && x <= BCL_RX[$b] &&
            y >= BCL_RY[$a] && y < BCL_RY[$a] + BCL_RH[$a] &&
            y >= BCL_RY[$b] && y < BCL_RY[$b] + BCL_RH[$b] )); then
        BCB_BND="v $e $a $b $x"; return 0
      fi
      if (( BCL_RY[$a] < BCL_RY[$b] &&
            BCL_RY[$b] - (BCL_RY[$a] + BCL_RH[$a]) <= 1 &&
            y >= BCL_RY[$a] + BCL_RH[$a] - 1 && y <= BCL_RY[$b] &&
            x >= BCL_RX[$a] && x < BCL_RX[$a] + BCL_RW[$a] &&
            x >= BCL_RX[$b] && x < BCL_RX[$b] + BCL_RW[$b] )); then
        BCB_BND="h $e $a $b $y"; return 0
      fi
    done
  done
  return 1
}

# Enclosing float of a model area (itself included) -> BCB_FOF.
_bb_float_of() { # name
  local p=$1
  while [[ -n $p ]]; do
    [[ ${BB_KIND[$p]:-} == float ]] && { BCB_FOF=$p; return 0; }
    p=${BB_FIN[$p]:-${BB_PARENT[$p]:-}}
  done
  return 1
}

on_click() { # NAME Y X BSTATE — NAME is an engine area name
  local a=$1 b=$4 sy=$BC_ME_Y sx=$BC_ME_X
  case $a in
    tb|bar|bar.*|prop|st|pal) return 0 ;;
  esac
  local n=${a#"$BCB_E"}

  if (( b & BUTTON1_PRESSED )); then
    if _bb_float_of "$n"; then
      local f=$BCB_FOF ef=$BCB_E$f
      bb_select "$f"
      bc_raise "$ef"
      _bb_push
      if (( sy == BCL_RY[$ef] + BCL_RH[$ef] - 1 && sx == BCL_RX[$ef] + BCL_RW[$ef] - 1 )); then
        BCB_DRAG="size $f $sy $sx ${BCL_RH[$ef]} ${BCL_RW[$ef]}"
      else
        BCB_DRAG="move $f $(( sy - BCL_RY[$ef] )) $(( sx - BCL_RX[$ef] ))"
      fi
      return 0
    fi
    if _bb_hit_grid "$sy" "$sx" && _bb_hit_bnd "$sy" "$sx" "$BCB_HG"; then
      local -a bd; read -r -a bd <<< "$BCB_BND"
      local ka=${bd[2]} kb=${bd[3]}
      _bb_push
      BCB_DRAG="bnd ${bd[0]} $ka $kb $sy $sx ${BCL_RH[$ka]} ${BCL_RW[$ka]} ${BCL_RH[$kb]} ${BCL_RW[$kb]}"
      return 0
    fi
    [[ $a != cvs && -n ${BB_KIND[$n]+set} ]] && bb_select "$n"
    return 0
  fi

  if (( b & REPORT_MOUSE_POSITION )) && [[ -n $BCB_DRAG ]]; then
    local -a dr; read -r -a dr <<< "$BCB_DRAG"
    case ${dr[0]} in
      move)
        local f=${dr[1]} ef=$BCB_E${dr[1]}
        local ny=$(( sy - dr[2] )) nx=$(( sx - dr[3] ))
        _bcl_inner "${BCL_FIN[$ef]}"
        BB_FAT[$f]="$(( ny - BCL_Y )),$(( nx - BCL_X ))"
        bb_render ;;
      size)
        local f=${dr[1]} h=$(( dr[4] + sy - dr[2] )) w=$(( dr[5] + sx - dr[3] ))
        (( h < 3 )) && h=3; (( w < 3 )) && w=3
        BB_FSIZE[$f]="${h}x${w}"
        bb_render ;;
      bnd)
        local ax=${dr[1]} ka=${dr[2]} kb=${dr[3]}
        local ga=${ka#"$BCB_E"} gb=${kb#"$BCB_E"}
        local g=${BB_PARENT[$ga]}
        local -a trk
        local i1 i2 s1 s2 d
        if [[ $ax == v ]]; then
          read -r -a trk <<< "${BB_COLSPEC[$g]}"
          i1=${BB_C0[$ga]}; i2=${BB_C0[$gb]}
          d=$(( sx - dr[5] ))
          s1=$(( dr[7] + d )); s2=$(( dr[9] - d ))
        else
          read -r -a trk <<< "${BB_ROWSPEC[$g]}"
          i1=${BB_R0[$ga]}; i2=${BB_R0[$gb]}
          d=$(( sy - dr[4] ))
          s1=$(( dr[6] + d )); s2=$(( dr[8] - d ))
        fi
        (( s1 < 1 )) && s1=1; (( s2 < 1 )) && s2=1
        trk[i1]=$s1; trk[i2]=$s2
        if [[ $ax == v ]]; then BB_COLSPEC[$g]="${trk[*]}"; else BB_ROWSPEC[$g]="${trk[*]}"; fi
        bb_render ;;
    esac
    return 0
  fi

  if (( b & BUTTON1_RELEASED )); then
    BCB_DRAG=""
    return 0
  fi
  return 0
}

# ------------------------------------------------------------------ keys
on_key() {
  local k=$1
  case $k in
    h) bb_split h; bb_after ;;
    v) bb_split v; bb_after ;;
    d) bb_delete; bb_after ;;
    r) if bb_prompt "Rename" "new name" "$BCB_SEL"; then bb_rename "$BCB_SEL" "$REPLY"; fi; bb_after ;;
    t) if bb_prompt "Title" "title text" "${BB_TITLE[$BCB_SEL]:-}"; then bb_set_style title "$REPLY"; fi; bb_after ;;
    b) bb_set_style border "$([[ -n ${BB_FRAME[$BCB_SEL]:-} ]] && echo '' || echo 1)"; bb_after ;;
    p) bb_cycle_pair PAIR; bb_after ;;
    s) bb_cycle_shadow; bb_after ;;
    l) bb_set_style tleft "$([[ -n ${BB_TLEFT[$BCB_SEL]:-} ]] && echo '' || echo 1)"; bb_after ;;
    D) bb_set_style divider "$([[ -n ${BB_DIVIDER[$BCB_SEL]:-} ]] && echo '' || echo 1)"; bb_after ;;
    m) bb_cycle_margin; bb_after ;;
    w) bb_cycle_tag; bb_after ;;
    f) bb_add_float; bb_after ;;
    $'\t') bb_cycle_sel 1; bb_after ;;
    $KEY_BTAB) bb_cycle_sel -1; bb_after ;;
    '+'|'=') bb_grow 0 1; bb_after ;;
    '-') bb_grow 0 -1; bb_after ;;
    '<') bb_grow 1 -1; bb_after ;;
    '>') bb_grow 1 1; bb_after ;;
    a) bb_toggle_auto 0; bb_after ;;
    A) bb_toggle_auto 1; bb_after ;;
    '[') bb_gap -1; bb_after ;;
    ']') bb_gap 1; bb_after ;;
    u) bb_undo; bb_after ;;
    $'\x1a') bb_undo; bb_after ;;
    $'\x19') bb_redo; bb_after ;;
    $'\x13') if [[ -n $BCB_FILE ]]; then bb_save; else bb_saveas; fi; bc_dirty st ;;
    $'\x0f') bb_open ;;
    $'\x05') bb_exportas; bc_dirty st ;;
    '?') bb_help ;;
    "$KEY_F9") bc_menubar_run tb ;;
    $'\e') BCB_DRAG=""; BCB_ERR="" ;;
    q|Q) bb_quit ;;
    *) BCB_ERR=""; bc_dirty st ;;
  esac
}

bb_after() {
  _bb_tree
  bb_render
  local i
  i=$(_bb_tree_idx "$BCB_SEL") || i=-1
  (( i >= 0 )) && bc_list_sel pal "$i"
  bc_dirty pal prop st
}

bb_cycle_sel() { # delta
  _bb_tree
  local n=${#BB_TREE[@]} i cur=-1
  (( n == 0 )) && return 0
  for i in "${!BB_TREE[@]}"; do [[ ${BB_TREE[i]#* } == "$BCB_SEL" ]] && cur=$i; done
  i=$(( (cur + $1 + n) % n ))
  bb_select "${BB_TREE[i]#* }"
}

bb_cycle_shadow() {
  local a=$BCB_SEL cur=${BB_SHADOW[$a]:-0}
  case $cur in
    0|'') bb_set_style shadow 1 ;;
    1) bb_set_style shadow mc ;;
    *) bb_set_style shadow '' ;;
  esac
}

bb_cycle_margin() {
  local a=$BCB_SEL cur=${BB_MARGIN[$a]:-0}
  cur=$(( (cur + 1) % 3 ))
  bb_set_style margin "$([[ $cur == 0 ]] && echo '' || echo "$cur")"
}

bb_saveas() {
  local def=${BCB_FILE:-layout.bcl}
  if bb_prompt "Save as" "file" "$def"; then bb_save "$REPLY"; fi
}

bb_open() {
  local def=${BCB_FILE:-layout.bcl}
  if bb_prompt "Open" "file" "$def"; then
    if bb_load_file "$REPLY"; then
      BCB_MSG="opened $REPLY"
      bb_after
    else
      BCB_ERR="open: $BCB_ERR"
    fi
    bc_dirty st
  fi
}

bb_exportas() {
  local def=${BCB_FILE:-app}
  def=${def%.bcl}.sh
  if bb_prompt "Export" "file" "$def"; then bb_export "$REPLY"; fi
}

bb_quit() {
  if (( BCB_DIRTY )); then
    bb_yes "Quit" "Discard unsaved changes?" || return 0
  fi
  bc_quit
}

pick_tb() { # TITLE LABEL
  case $1/$2 in
    File/New) bb_new; bb_after ;;
    File/Open) bb_open ;;
    File/Save) if [[ -n $BCB_FILE ]]; then bb_save; else bb_saveas; fi; bc_dirty st ;;
    File/"Save as...") bb_saveas; bc_dirty st ;;
    File/Export) bb_exportas; bc_dirty st ;;
    File/Quit) bb_quit ;;
    Edit/Undo) bb_undo; bb_after ;;
    Edit/Redo) bb_redo; bb_after ;;
    Edit/Rename) on_key r ;;
    Edit/Title) on_key t ;;
    Edit/Delete) bb_delete; bb_after ;;
    Insert/"Split horiz") bb_split h; bb_after ;;
    Insert/"Split vert") bb_split v; bb_after ;;
    Insert/Float) bb_add_float; bb_after ;;
    Insert/"Cycle tag") bb_cycle_tag; bb_after ;;
    Style/Border) on_key b ;;
    Style/Pair) bb_cycle_pair PAIR; bb_after ;;
    Style/Shadow) bb_cycle_shadow; bb_after ;;
    Style/"Title left") on_key l ;;
    Style/Divider) on_key D ;;
    Style/Margin) bb_cycle_margin; bb_after ;;
    Style/"Gap +") bb_gap 1; bb_after ;;
    Style/"Gap -") bb_gap -1; bb_after ;;
    Help/Keys) bb_help ;;
  esac
}

# toolbar buttons (clicks land here via bc_button's press_NAME)
press_bar.sh()  { bb_split h; bb_after; }
press_bar.sv()  { bb_split v; bb_after; }
press_bar.del() { bb_delete; bb_after; }
press_bar.fl()  { bb_add_float; bb_after; }
press_bar.un()  { bb_undo; bb_after; }
press_bar.rd()  { bb_redo; bb_after; }
press_bar.sav() { if [[ -n $BCB_FILE ]]; then bb_save; else bb_saveas; fi; bc_dirty st; }
press_bar.exp() { bb_exportas; bc_dirty st; }

on_resize() { bb_render; bc_dirty pal prop st; }

# ------------------------------------------------------------------ main
_bb_colors() {
  local i fb
  for (( i = 1; i <= BCB_NPAL; i++ )); do
    fb=$(_bb_pal "$i")
    init_pair "$i" $fb
  done
  alloc_pair 7 4; BCB_SELP=$bc_pair
  alloc_pair 3 0; BCB_MSGP=$bc_pair
  alloc_pair 0 6; BCB_TBP=$bc_pair
  alloc_pair 0 7; BCB_PROPB=$bc_pair
}

main() {
  bb_new || { printf 'bcbuild: %s\n' "$BCB_ERR" >&2; exit 1; }
  if [[ -n ${1:-} ]]; then
    bb_load_file "$1" || { printf 'bcbuild: %s\n' "$BCB_ERR" >&2; exit 1; }
  fi
  bc_init mouse motion
  if (( BC_LINES < BCB_MIN_LINES || BC_COLS < BCB_MIN_COLS )); then
    endwin
    printf 'bcbuild needs a terminal of at least %dx%d (got %dx%d).\n' \
      "$BCB_MIN_COLS" "$BCB_MIN_LINES" "$BC_COLS" "$BC_LINES" >&2
    exit 1
  fi
  _bb_colors

  bc_screen "
    tb   tb   tb
    bar  bar  bar
    pal  cvs  prop
    st   st   st
  " rows="1 1 * 3" cols="24 * 30"

  bc_style tb pair=$BCB_TBP
  bc_style bar pair=$BCB_TBP
  bc_style pal border title="Areas" tleft
  bc_style cvs border title="canvas"
  bc_style prop border title="Properties" tleft
  bc_style st pair=$BCB_PROPB

  _bb_tree
  bc_list pal BB_TREE
  bc_focus pal

  MENU_File=("New||N" "Open...||O" "Save||S" "Save as...||A" "Export...||E" "---" "Quit||Q")
  MENU_Edit=("Undo|^U|U" "Redo|^R|R" "---" "Rename...||r" "Title...||t" "Delete||d")
  MENU_Insert=("Split horiz||h" "Split vert||v" "Float||f" "---" "Cycle tag||w")
  MENU_Style=("Border||b" "Pair||p" "Shadow||s" "Title left||l" "Divider||D" "Margin||m" "Gap +||+" "Gap -||-")
  MENU_Help=("Keys||?")
  bc_menubar tb "File:1 Edit:6 Insert:12 Style:19 Help:25" pairs="$BCB_TBP $BCB_SELP 1 $BCB_SELP 1"

  bc_grid bar "
    bar.sh bar.sv bar.del bar.fl bar.un bar.rd bar.sav bar.exp bar.fill
  " rows="1" cols="auto auto auto auto auto auto auto auto *"
  bc_button bar.sh "Split-H"
  bc_button bar.sv "Split-V"
  bc_button bar.del "Delete"
  bc_button bar.fl "Float"
  bc_button bar.un "Undo"
  bc_button bar.rd "Redo"
  bc_button bar.sav "Save"
  bc_button bar.exp "Export"
  bc_content bar.fill 1 1

  bb_render
  bc_dirty pal prop st
  bc_run
}

[[ -n ${BCB_TEST:-} ]] || main "$@"
