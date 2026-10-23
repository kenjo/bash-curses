# 92-mc-layout: the Midnight Commander clone (examples/mc.sh) rewritten on
# lib/layout.sh + lib/widgets.sh. Same palette, same positions, same
# features; the layout layer does the geometry, resizing and redrawing, and
# widgets do the lists, menus and dialog controls.
#
#   bash examples/92-mc-layout.sh
#   MC_HINTBAR=0 hides the hint line.

source "${BASH_SOURCE[0]%/*}/../lib/widgets.sh"
ESCDELAY=100

# ------------------------------------------------------------------ state
# per panel p (0 = left, 1 = right); the entry arrays are NAMES_p TYPES_p
# SIZES_p TIMES_p REALS_p EXEC_p, the marked entries SELSET_p
SIDE=(left right)
NAMES_0=(); TYPES_0=(); SIZES_0=(); TIMES_0=(); REALS_0=(); EXEC_0=()
NAMES_1=(); TYPES_1=(); SIZES_1=(); TIMES_1=(); REALS_1=(); EXEC_1=()
declare -A SELSET_0=() SELSET_1=()
DIR=("$PWD" "$PWD") FREE=("" "") SORT=(name name) REV=(0 0) HIDE=(0 0)
SHOWEXT=(1 1) FILTERS=("" "")
CUR=0                 # active panel
CMD_LINE="" CMD_CARET=0
HINT_TEXT=""
MENU_OPEN=0           # menu bar active: panel highlights are hidden
DIRHIST=() CMDHIST=() FILEHIST=()
SIZEW=7 TIMEW=12
MO=(jan feb mars apr maj juni juli aug sep okt nov dec)
BUTTONS=(Help Menu View Edit Copy RenMov Mkdir Delete PullDn Quit)
PREFIX=""             # pending C-x prefix

# ------------------------------------------------------------------ data
# (the directory model is mc.sh's, unchanged)
hum_bytes() { # bytes -> human
  local b=$1
  if (( b >= 1024 )); then printf '%dK' "$(( (b + 1023) / 1024 ))"
  else printf '%d B' "$b"; fi
}

selection_summary() { # p -> SEL_SUMMARY
  local -n RR=REALS_$1 SS=SIZES_$1 SELARR=SELSET_$1
  local i cnt=0 bytes=0
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    [[ -n ${SELARR[${RR[$i]}]:-} ]] || continue
    cnt=$(( cnt + 1 )) bytes=$(( bytes + ${SS[$i]:-0} ))
  done
  SEL_SUMMARY=""
  (( cnt )) || return 0
  local files="files"; (( cnt == 1 )) && files="file"
  SEL_SUMMARY="$(hum_bytes "$bytes") in $cnt $files"
}

hum() { # kb -> human
  local kb=$1
  if (( kb >= 10240 * 1024 )); then printf '%dG' "$(( (kb + 524288) / 1048576 ))"
  elif (( kb >= 1024 )); then printf '%dM' "$(( (kb + 512) / 1024 ))"
  else printf '%dK' "$kb"; fi
}

fmt_mtime() { # y mo dd h mi ("MON DD  YYYY" when older than ~6 months)
  local y=$1 mo=$2 dd=$3 h=$4 mi=$5
  if (( (NOW_Y - 10#$y) * 12 + (NOW_MO - 10#$mo) >= 6 )); then
    printf '%s %2d  %s' "${MO[$((10#$mo - 1))]}" "$((10#$dd))" "$((10#$y))"
  else
    printf '%s %2d %s:%s' "${MO[$((10#$mo - 1))]}" "$((10#$dd))" "$h" "$mi"
  fi
}

update_free() { # p
  local p=$1 total_kb avail_kb fstr="no info"
  read -r _ total_kb _ avail_kb _ _ <<< "$(df -P -k "${DIR[$p]}" 2>/dev/null | tail -1)"
  [[ -n ${total_kb:-} ]] && fstr="$(hum "$avail_kb") / $(hum "$total_kb") ($(( avail_kb * 100 / total_kb ))%)"
  FREE[$p]=$fstr
}

push_hist() { # array value — most recent first, deduped, max 50
  local -n _h=$1
  local -a nh=("$2")
  local e
  for e in "${_h[@]}"; do [[ $e != "$2" ]] && nh+=("$e"); done
  _h=("${nh[@]:0:50}")
}

# List a directory into panel p; ".." is always entry 0.
list_dir() { # p
  local p=$1
  local -n NN=NAMES_$p TT=TYPES_$p SS=SIZES_$p TM=TIMES_$p RR=REALS_$p XX=EXEC_$p
  local d=${DIR[$p]}
  d=$(cd "$d" 2>/dev/null && pwd) || d="$HOME"
  push_hist DIRHIST "$d"
  DIR[$p]=$d
  update_free "$p"
  local now; now=$(date +%Y%-m); NOW_Y=${now:0:4}; NOW_MO=$((10#${now:4}))
  local SEP=$'\037'
  local -a find_args=(. -mindepth 1 -maxdepth 1)
  (( HIDE[$p] )) && find_args+=(! -name '.*')
  [[ -n ${FILTERS[$p]} ]] && find_args+=(-name "${FILTERS[$p]}")
  local fmt='%y'"$SEP"'%s'"$SEP"'%m'"$SEP"'%TY'"$SEP"'%Tm'"$SEP"'%Td'"$SEP"'%TH'"$SEP"'%TM'"$SEP"'%f\n'
  local out sorted=""
  out=$( (cd "$d" 2>/dev/null && find "${find_args[@]}" -printf "$fmt") 2>/dev/null )
  if [[ -n $out ]]; then
    sorted=$(
      awk -F"$SEP" -v OFS="$SEP" -v now_y="$NOW_Y" -v now_mo="$NOW_MO" \
        -v sort_mode="${SORT[$p]}" -v months='jan,feb,mars,apr,maj,juni,juli,aug,sep,okt,nov,dec' '
        BEGIN { split(months, mon, ",") }
        function fmt_time(y, mo, dd, h, mi,   age) {
          age = (now_y - y) * 12 + (now_mo - mo)
          if (age >= 6) return sprintf("%s %2d  %d", mon[mo], dd, y)
          return sprintf("%s %2d %s:%s", mon[mo], dd, h, mi)
        }
        {
          t=$1; s=$2; mode=$3; y=$4+0; mo=$5+0; dd=$6+0; h=$7; mi=$8; name=$9
          ex=0
          if (t != "d" && t != "l" && mode ~ /^[0-7]+$/) {
            m=0
            for (i=1; i<=length(mode); i++) m = m*8 + substr(mode, i, 1)
            if (m % 2 || int(m/8) % 2 || int(m/64) % 2) ex=1
          }
          if (t == "d") disp="/" name
          else if (t == "l") disp="@" name
          else if (ex) disp="*" name
          else disp=" " name
          tk=sprintf("%04d%02d%02d%02d%02d", y, mo, dd, h+0, mi+0)
          if (sort_mode == "size") key=sprintf("%020s", s)
          else if (sort_mode == "date") key=tk
          else key=name
          print (t == "d") ? "0" : "1", key, disp, t, s, fmt_time(y, mo, dd, h, mi), name, ex
        }' <<< "$out" | LC_ALL=C sort -t"$SEP" -k1,1 $( (( REV[$p] )) && echo "-k2,2r" || echo "-k2,2" )
    )
  fi
  local pd parent_time="-" y mo dd h mi
  pd=$( (cd "$(dirname "$d")" 2>/dev/null && find . -maxdepth 0 -printf '%TY|%Tm|%Td|%TH|%TM') 2>/dev/null )
  if [[ -n $pd ]]; then
    IFS='|' read -r y mo dd h mi <<< "$pd"
    parent_time=$(fmt_mtime "$y" "$mo" "$dd" "$h" "$mi")
  fi
  NN=("/..") TT=(d) SS=("UP--DIR") TM=("$parent_time") RR=("..") XX=(0)
  if [[ -n $sorted ]]; then
    local group key disp t s tm name ex
    while IFS="$SEP" read -r group key disp t s tm name ex; do
      [[ $t == l && ! -e "$d/$name" ]] && disp="!$name"
      NN+=("$disp") TT+=("$t") SS+=("$s") TM+=("$tm") RR+=("$name") XX+=("$ex")
    done <<< "$sorted"
  fi
  local -n SELARR=SELSET_$p
  SELARR=()
  bc_list_sel "${SIDE[$p]}.list" 0
  redraw_panel "$p"
}

# Re-list panel p keeping its marks and current entry (or moving to new_real).
refresh_panel_keep() { # p [new_real]
  local p=$1 new=${2:-}
  local -n RR=REALS_$p SELARR=SELSET_$p
  pos_get "$p"
  local cur=${RR[$POS]:-} k i
  local -a oldsel=("${!SELARR[@]}")
  list_dir "$p"
  for k in "${oldsel[@]}"; do
    for i in "${!RR[@]}"; do [[ ${RR[$i]} == "$k" ]] && { SELARR[$k]=1; break; }; done
  done
  local target=${new:-$cur}
  for i in "${!RR[@]}"; do [[ ${RR[$i]} == "$target" ]] && { pos_set "$p" "$i"; break; }; done
}

pos_get() { bc_list_sel "${SIDE[$1]}.list"; POS=$BCL_SEL; }      # p -> POS
pos_set() { bc_list_sel "${SIDE[$1]}.list" "$2"; }              # p idx
cur_real() { local -n RR=REALS_$CUR; pos_get "$CUR"; REAL=${RR[$POS]}; }  # -> REAL

# Swap the two panels' contents (C-u); the active panel follows its content.
do_swap_panels() {
  local f t
  for f in NAMES TYPES SIZES TIMES REALS EXEC; do
    local -n _a0=${f}_0 _a1=${f}_1
    local -a _t=("${_a0[@]}"); _a0=("${_a1[@]}"); _a1=("${_t[@]}")
    unset -n _a0 _a1
  done
  local -A _s=()
  for f in "${!SELSET_0[@]}"; do _s[$f]=1; done
  SELSET_0=(); for f in "${!SELSET_1[@]}"; do SELSET_0[$f]=1; done
  SELSET_1=(); for f in "${!_s[@]}"; do SELSET_1[$f]=1; done
  for f in DIR SORT REV HIDE FILTERS FREE; do
    local -n _i=$f; t=${_i[0]}; _i[0]=${_i[1]}; _i[1]=$t; unset -n _i
  done
  for f in BCW_SEL BCW_TOP; do
    local -n _i=$f; t=${_i[left.list]}; _i[left.list]=${_i[right.list]}; _i[right.list]=$t; unset -n _i
  done
  activate $(( 1 - CUR ))
  redraw_panel 0; redraw_panel 1
}

# ------------------------------------------------------------------ screen
layout_screen() {
  HINTBAR=${MC_HINTBAR:-1}
  case $HINTBAR in 0|false|no) HINTBAR=0 ;; *) HINTBAR=1 ;; esac
  bc_screen "
    menu  menu
    left  right
    hint  hint
    cmd   cmd
    keys  keys
  " rows="1 * $HINTBAR 1 1" cols="* *"
  local s a
  for s in left right; do
    # a panel: frame top (path), column header, the list, separator (marked
    # summary), status line, frame bottom (free space)
    bc_grid "$s" "
      $s.top
      $s.head
      $s.list
      $s.sep
      $s.stat
      $s.free
    " rows="1 1 * 1 1 1"
    for a in top head list sep stat free; do bc_style "$s.$a" pair=7; done
  done
  bc_style menu pair=22
  bc_style cmd pair=40
  bc_list left.list NAMES_0
  bc_list right.list NAMES_1
}

redraw_panel() { local s=${SIDE[$1]}; bc_dirty "$s.top" "$s.head" "$s.list" "$s.sep" "$s.stat" "$s.free"; }
redraw_all() { bc_dirty all; }

panel_of() { # area -> P (0/1), status 1 if not a panel area
  case $1 in left|left.*) P=0 ;; right|right.*) P=1 ;; *) return 1 ;; esac
}

# Make panel p the active one (keys go to its list).
activate() { # p
  local old=$CUR
  CUR=$1
  bc_focus "${SIDE[$CUR]}.list"
  (( old == CUR )) && return 0
  bc_dirty left.top right.top left.list right.list cmd
}

# column geometry of a panel of width w -> NAMEW SD (name width, 1st divider)
panel_cols() { NAMEW=$(( $1 - SIZEW - TIMEW - 4 )); (( NAMEW < 4 )) && NAMEW=4; SD=$(( 1 + NAMEW )); }

repeat() { # var char n
  local -n _r=$1
  printf -v _r '%*s' "$3" ''
  _r=${_r// /$2}
}

# ---- panel parts (area = SIDE.part, P = its panel)
draw_panel_top() { # area
  panel_of "$1"
  local a=$1 p=$P bp=8 w path dp top fill line
  (( p == CUR )) && bp=7
  bc_size "$a"; w=$BCL_W
  path=${DIR[$p]}; dp=$path
  if [[ $path == "$HOME" ]]; then dp="~"; elif [[ $path == "$HOME"/* ]]; then dp="~${path#"$HOME"}"; fi
  local maxpath=$(( w - 12 )); (( maxpath < 6 )) && maxpath=6
  (( ${#dp} > maxpath )) && dp="...${dp: -$(( maxpath - 3 ))}"
  top="<─ ${dp:0:$maxpath} "
  fill=$(( w - 2 - ${#top} - 5 )); (( fill < 0 )) && fill=0
  repeat line '─' "$fill"
  top+="$line.[^]>"
  bc_print "$a" 0 0 "┌${top:0:w-2}┐" pair=$bp
  (( p == CUR && ! MENU_OPEN )) && bc_print "$a" 0 3 " ${dp:0:$maxpath} " pair=13
}

draw_panel_head() { # area
  panel_of "$1"
  local a=$1 p=$P bp=8 ind skey hname hsize htime
  (( p == CUR )) && bp=7
  bc_size "$a"; panel_cols "$BCL_W"
  case ${SORT[$p]} in size) skey=s ;; date) skey=d ;; *) skey=n ;; esac
  if (( REV[$p] )); then ind="^$skey"; else ind=".$skey"; fi
  printf -v hname '%-12sName%*s' "$ind" "$(( NAMEW - 16 ))" ""
  printf -v hsize ' Size%*s' "$(( SIZEW - 5 ))" ""
  printf -v htime 'Modify time%*s' "$(( TIMEW - 11 ))" ""
  bc_print "$a" 0 0 "│" pair=$bp
  bc_print "$a" 0 1 "$hname" pair=12
  bc_print "$a" 0 "$SD" "│"
  bc_print "$a" 0 $(( SD + 1 )) "$hsize" pair=12
  bc_print "$a" 0 $(( SD + SIZEW + 1 )) "│"
  bc_print "$a" 0 $(( SD + SIZEW + 2 )) "$htime" pair=12
  bc_print "$a" 0 $(( SD + SIZEW + TIMEW + 2 )) "│"
}

type_color() { # p idx -> TC_PAIR
  local -n TT=TYPES_$1 XX=EXEC_$1 NN=NAMES_$1
  case ${TT[$2]} in
    d) TC_PAIR=2 ;;
    l) if [[ ${NN[$2]} == '!'* ]]; then TC_PAIR=35; else TC_PAIR=4; fi ;;
    c|b|p|s) TC_PAIR=5 ;;
    *) if (( XX[$2] )); then TC_PAIR=3; else TC_PAIR=11; fi ;;
  esac
}

# One list row (called by the list widget).
panel_row() { # p idx y sel
  local p=$1 i=$2 y=$3 a="${SIDE[$1]}.list" bp=8 cp dp=7 nm sz tm
  local -n NN=NAMES_$p SS=SIZES_$p TM=TIMES_$p RR=REALS_$p SELARR=SELSET_$p
  (( p == CUR )) && bp=7
  bc_size "$a"; panel_cols "$BCL_W"
  if (( i >= ${#NN[@]} )); then
    printf -v nm '%*s' "$NAMEW" ''; printf -v sz '%*s' "$SIZEW" ''; printf -v tm '%*s' "$TIMEW" ''
    cp=7
  else
    printf -v nm '%-*s' "$NAMEW" "${NN[$i]}"
    printf -v sz '%*s' "$SIZEW" "${SS[$i]}"
    printf -v tm '%-*s' "$TIMEW" "${TM[$i]}"
    if (( $4 && p == CUR && ! MENU_OPEN )); then
      cp=6 dp=6; [[ -n ${SELARR[${RR[$i]}]:-} ]] && cp=34
    else
      type_color "$p" "$i"; cp=$TC_PAIR
      [[ -n ${SELARR[${RR[$i]}]:-} ]] && cp=31
    fi
  fi
  bc_print "$a" "$y" 0 "│" pair=$bp
  bc_print "$a" "$y" 1 "$nm" pair=$cp
  bc_print "$a" "$y" "$SD" "│" pair=$dp
  bc_print "$a" "$y" $(( SD + 1 )) "$sz" pair=$cp
  bc_print "$a" "$y" $(( SD + SIZEW + 1 )) "│" pair=$dp
  bc_print "$a" "$y" $(( SD + SIZEW + 2 )) "$tm" pair=$cp
  bc_print "$a" "$y" $(( SD + SIZEW + TIMEW + 2 )) "│" pair=$bp
}
row_left.list()  { panel_row 0 "$@"; }
row_right.list() { panel_row 1 "$@"; }

draw_panel_sep() { # area
  panel_of "$1"
  local a=$1 p=$P bp=8 w inside line ld rd
  (( p == CUR )) && bp=7
  bc_size "$a"; w=$BCL_W; inside=$(( w - 2 ))
  selection_summary "$p"
  local slen=${#SEL_SUMMARY}
  if [[ -n $SEL_SUMMARY ]] && (( slen + 2 <= inside )); then
    local lft=$(( (inside - slen - 2) / 2 ))
    repeat ld '─' "$lft"; repeat rd '─' $(( inside - 2 - lft - slen ))
    bc_print "$a" 0 0 "├$ld" pair=$bp
    bc_print "$a" 0 $(( 1 + lft )) " $SEL_SUMMARY " pair=12
    bc_print "$a" 0 $(( 1 + lft + slen + 2 )) "$rd┤" pair=$bp
  else
    repeat line '─' "$inside"
    bc_print "$a" 0 0 "├$line┤" pair=$bp
  fi
}

draw_panel_stat() { # area
  panel_of "$1"
  local a=$1 p=$P bp=8 w status s
  local -n NN=NAMES_$p
  (( p == CUR )) && bp=7
  bc_size "$a"; w=$BCL_W
  pos_get "$p"
  if (( POS == 0 )); then status="UP--DIR"; else status=${NN[$POS]}; fi
  printf -v s '%-*s' $(( w - 2 )) "${status:0:w-2}"
  bc_print "$a" 0 0 "│" pair=$bp
  bc_print "$a" 0 1 "$s"
  bc_print "$a" 0 $(( w - 1 )) "│" pair=$bp
}

draw_panel_free() { # area
  panel_of "$1"
  local a=$1 p=$P bp=8 w fstr ld left
  (( p == CUR )) && bp=7
  bc_size "$a"; w=$BCL_W
  fstr=${FREE[$p]:-no info}
  left=$(( w - 5 - ${#fstr} )); (( left < 0 )) && left=0
  repeat ld '─' "$left"
  bc_print "$a" 0 0 "└" pair=$bp
  bc_print "$a" 0 1 "$ld $fstr ─"
  bc_print "$a" 0 $(( w - 1 )) "┘" pair=$bp
}
for _s in left right; do
  for _p in top head sep stat free; do eval "draw_$_s.$_p() { draw_panel_$_p \"\$1\"; }"; done
done
unset _s _p

# list callbacks: the status line follows the selection; Enter opens
select_left.list()  { bc_dirty left.stat; }
select_right.list() { bc_dirty right.stat; }
enter_left.list()   { list_enter 0; }
enter_right.list()  { list_enter 1; }
list_enter() { # p
  [[ -n $CMD_LINE ]] && { bc_pass; return; }   # Enter runs the command line
  activate "$1"
  do_open
}

# ---- bottom rows
draw_menu() { # closed menu bar (the menu widget draws the open one)
  local i x=(2 11 20 32 44) names=(Left File Command Options Right) s
  printf -v s '%*s' "$COLS" ''
  bc_print menu 0 0 "$s"
  for i in "${!names[@]}"; do bc_print menu 0 "${x[i]}" "${names[i]}"; done
}

draw_hint() {
  local hint s
  if [[ -n $CMD_LINE ]]; then hint="To change directory halfway through typing a command, use M-c."
  elif [[ -n $HINT_TEXT ]]; then hint=$HINT_TEXT
  else hint="Tab changes your current panel."; fi
  printf -v s '%-*s' $(( COLS - 1 )) "Hint: $hint"
  bc_print hint 0 0 "$s"
}

cmdline_prompt() {
  local cwd=${DIR[$CUR]} scwd
  scwd=$cwd
  if [[ $cwd == "$HOME" ]]; then scwd="~"; elif [[ $cwd == "$HOME"/* ]]; then scwd="~${cwd#"$HOME"}"; fi
  CMD_PROMPT="${USER:-$(whoami)}@${HOSTNAME%%.*}:${scwd}\$ "
}

draw_cmd() {
  local s
  cmdline_prompt
  (( CMD_CARET > ${#CMD_LINE} )) && CMD_CARET=${#CMD_LINE}
  (( CMD_CARET < 0 )) && CMD_CARET=0
  printf -v s '%-*s' $(( COLS - 3 )) "$CMD_PROMPT$CMD_LINE"
  bc_print cmd 0 0 "$s"
  bc_print cmd 0 $(( COLS - 3 )) "[^]" pair=7
  bc_cursor cmd 0 $(( ${#CMD_PROMPT} + CMD_CARET ))
}
cmd_changed() { bc_dirty cmd; [[ $HINTBAR == 1 ]] && bc_dirty hint; }

draw_keys() { # F-key bar: bright numbers on black, labels on cyan
  local i n x=0 last=$(( ${#BUTTONS[@]} - 1 )) l s
  for i in "${!BUTTONS[@]}"; do
    printf -v n '%2d' $(( i + 1 ))
    bc_print keys 0 "$x" "$n" pair=15
    l=${BUTTONS[i]}; (( i < last )) && printf -v l '%-8s' "$l"
    bc_print keys 0 $(( x + 2 )) "$l" pair=6
    x=$(( x + 10 ))
  done
  x=$(( x - 8 + ${#BUTTONS[last]} ))
  (( x < COLS - 1 )) && { printf -v s '%*s' $(( COLS - 1 - x )) ''; bc_print keys 0 "$x" "$s" pair=0; }
}

# ------------------------------------------------------------------ actions
do_open() {
  cur_real
  local real=$REAL child="" old
  if [[ $real == ".." ]]; then
    old=${DIR[$CUR]}
    [[ $old != "/" ]] && child=${old##*/}
    DIR[$CUR]=$(dirname "$old")
  elif [[ -d ${DIR[$CUR]}/$real ]]; then
    DIR[$CUR]="${DIR[$CUR]}/$real"
  elif [[ -f ${DIR[$CUR]}/$real ]]; then
    view_file "$real"; return
  else
    return
  fi
  list_dir "$CUR"
  HINT_TEXT="VFS coolness: tap enter on a tar file to examine its contents."
  cmd_changed
  if [[ -n $child ]]; then   # back in the parent: highlight where we came from
    local -n RR=REALS_$CUR
    local i
    for i in "${!RR[@]}"; do [[ ${RR[$i]} == "$child" ]] && { pos_set "$CUR" "$i"; break; }; done
  fi
}

mark_changed() { HINT_TEXT=""; redraw_panel "$CUR"; cmd_changed; }

do_insert_select() {
  local -n NN=NAMES_$CUR RR=REALS_$CUR SELARR=SELSET_$CUR
  pos_get "$CUR"
  if (( POS > 0 )); then
    if [[ -n ${SELARR[${RR[$POS]}]:-} ]]; then unset "SELARR[${RR[$POS]}]"; else SELARR[${RR[$POS]}]=1; fi
  fi
  (( POS < ${#NN[@]} - 1 )) && pos_set "$CUR" $(( POS + 1 ))
  mark_changed
}

do_star_select() {
  local -n RR=REALS_$CUR TT=TYPES_$CUR SELARR=SELSET_$CUR
  local i
  for (( i = 1; i < ${#RR[@]}; i++ )); do [[ ${TT[$i]} == d ]] || SELARR[${RR[$i]}]=1; done
  mark_changed
}

do_invert_selection() {
  local -n RR=REALS_$CUR SELARR=SELSET_$CUR
  local i r
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    r=${RR[$i]}
    if [[ -n ${SELARR[$r]:-} ]]; then unset "SELARR[$r]"; else SELARR[$r]=1; fi
  done
  mark_changed
}

do_rescan() { refresh_panel_keep "$CUR"; }

execute_cmd() {
  local cmd=$CMD_LINE
  [[ -z $cmd ]] && return
  CMD_LINE="" CMD_CARET=0
  cmd_changed
  push_hist CMDHIST "$cmd"
  if [[ $cmd =~ ^cd[[:space:]]*(.*)$ ]]; then
    local target="${BASH_REMATCH[1]//\"/}"
    target=${target/#~/$HOME}
    [[ -z $target ]] && target=$HOME
    if [[ -d $target ]]; then DIR[$CUR]=$target; list_dir "$CUR"
    else message_dialog "cd" "Not a directory: $target"; fi
    return
  fi
  case $cmd in exit|quit) bc_quit; return ;; esac
  (cd "${DIR[$CUR]}" 2>/dev/null && eval "$cmd") >/dev/null 2>&1
}

cmd_edit() { # key -> 0 if it was a command-line edit
  local k=$1
  case $k in
    "$KEY_LEFT")  [[ -n $CMD_LINE ]] || return 1; (( CMD_CARET > 0 )) && CMD_CARET=$(( CMD_CARET - 1 )) ;;
    "$KEY_RIGHT") [[ -n $CMD_LINE ]] || return 1; (( CMD_CARET < ${#CMD_LINE} )) && CMD_CARET=$(( CMD_CARET + 1 )) ;;
    $'\x7f'|$'\b'|"$KEY_BACKSPACE")
      if (( CMD_CARET > 0 )); then
        CMD_LINE="${CMD_LINE:0:CMD_CARET-1}${CMD_LINE:CMD_CARET}"; CMD_CARET=$(( CMD_CARET - 1 ))
      elif [[ -n $CMD_LINE ]]; then
        CMD_LINE=${CMD_LINE:0:-1}; CMD_CARET=${#CMD_LINE}
      fi ;;
    ' ') [[ -n $CMD_LINE ]] || return 0      # Space on an empty line: ignored
         CMD_LINE="${CMD_LINE:0:CMD_CARET} ${CMD_LINE:CMD_CARET}"; CMD_CARET=$(( CMD_CARET + 1 )) ;;
    *) [[ ${#k} == 1 && $k == [[:print:]] ]] || return 1
       CMD_LINE="${CMD_LINE:0:CMD_CARET}$k${CMD_LINE:CMD_CARET}"; CMD_CARET=$(( CMD_CARET + 1 )) ;;
  esac
  cmd_changed
  return 0
}

# ------------------------------------------------------------------ not yet
for _f in message_dialog view_file do_compare_dirs do_background_jobs do_vfs_list \
  quick_cd_dialog do_command_history do_filtered_view do_encoding do_screen_list \
  fkey_help user_menu do_view do_edit do_copy do_move do_mkdir do_delete run_menu \
  do_select_group do_unselect_group menu_click; do
  eval "$_f() { :; }"
done; unset _f

# ------------------------------------------------------------------ input
on_key() {
  local k=$1
  if [[ -n $PREFIX ]]; then          # C-x <key>
    PREFIX=""
    case $k in
      d) do_compare_dirs ;; j) do_background_jobs ;; a) do_vfs_list ;;
    esac
    return
  fi
  if [[ $k == $'\e' && -n $BC_PENDING_IN ]]; then   # M-<key>
    local mk=${BC_PENDING_IN:0:1}
    BC_PENDING_IN=${BC_PENDING_IN:1}
    case $mk in
      c) quick_cd_dialog ;; h) do_command_history ;; '!') do_filtered_view ;;
      e) do_encoding ;; '`') do_screen_list ;;
    esac
    return
  fi
  case $k in
    $'\t')        activate $(( 1 - CUR )) ;;
    $'\x15')      do_swap_panels ;;
    $'\x18')      PREFIX=x ;;
    $'\r'|$'\n')  if [[ -n $CMD_LINE ]]; then execute_cmd; else do_open; fi ;;
    $'\e')        [[ -n $CMD_LINE ]] && { CMD_LINE="" CMD_CARET=0; cmd_changed; } ;;
    "$KEY_F1")    fkey_help ;;
    "$KEY_F2")    user_menu ;;
    "$KEY_F3")    do_view ;;
    "$KEY_F4")    do_edit ;;
    "$KEY_F5")    do_copy ;;
    "$KEY_F6")    do_move ;;
    "$KEY_F7")    do_mkdir ;;
    "$KEY_F8")    do_delete ;;
    "$KEY_F9")    run_menu ;;
    "$KEY_F10")   bc_quit ;;
    "$KEY_IC")    do_insert_select ;;
    r)            if [[ -z $CMD_LINE ]]; then do_rescan; else cmd_edit r; fi ;;
    +)            do_select_group ;;
    -)            do_unselect_group ;;
    \*)           do_star_select ;;
    *)            cmd_edit "$k" ;;
  esac
}

on_click() { # area y x bstate
  local a=$1 y=$2 x=$3 b=$4
  if panel_of "$a"; then
    (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED | BUTTON1_PRESSED | BUTTON4_PRESSED | BUTTON5_PRESSED) )) && activate "$P"
    return
  fi
  (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return
  case $a in
    keys)
      case $(( x / 10 )) in
        0) fkey_help ;; 1) user_menu ;; 2) do_view ;; 3) do_edit ;; 4) do_copy ;;
        5) do_move ;; 6) do_mkdir ;; 7) do_delete ;; 8) run_menu 0 1 ;; 9) bc_quit ;;
      esac ;;
    cmd)
      cmdline_prompt
      CMD_CARET=$(( x - ${#CMD_PROMPT} ))
      (( CMD_CARET < 0 )) && CMD_CARET=0
      (( CMD_CARET > ${#CMD_LINE} )) && CMD_CARET=${#CMD_LINE}
      bc_dirty cmd ;;
    menu) menu_click "$x" ;;
  esac
}

# ------------------------------------------------------------------ main
main() {
  bc_init motion clickms=200 || exit 1
  curs_set 0
  init_pair 2 15 4;  init_pair 3 10 4;  init_pair 4 7 4;  init_pair 5 15 4
  init_pair 6 0 6;   init_pair 7 7 4;   init_pair 8 7 4;  init_pair 11 3 4
  init_pair 12 11 4; init_pair 13 0 7;  init_pair 15 15 0
  init_pair 16 15 6; init_pair 17 11 6; init_pair 18 15 0; init_pair 19 11 0
  init_pair 20 4 7;  init_pair 21 11 4; init_pair 22 0 6
  init_pair 23 0 7;  init_pair 24 4 7;  init_pair 25 8 6;  init_pair 26 15 1
  init_pair 27 11 1; init_pair 28 7 4;  init_pair 29 0 6;  init_pair 30 4 6
  init_pair 31 11 4; init_pair 34 11 6; init_pair 32 8 0;  init_pair 35 9 4
  init_pair 36 8 0;  init_pair 40 -1 -1
  BCL_SHADOW_PAIR=32
  if (( LINES < 12 || COLS < 60 )); then endwin; echo "Terminal too small" >&2; exit 1; fi
  layout_screen
  list_dir 0; list_dir 1
  activate 0
  bc_run
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
