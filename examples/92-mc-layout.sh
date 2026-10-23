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

# menus: "LABEL|SHORTCUT|HOTKEY" (HOTKEY "x:N" highlights label position N)
MENU_Left=(
  "File listing||g" "Quick view|C-x q|Q" "Info|C-x i|I" "Tree||T"
  "---"
  "Listing format...||L" "Sort order...||S" "Filter...||F" "Encoding...|M-e|E"
  "---"
  "FTP link...||P" "Shell link...||h" "SFTP link...||n" "Panelize||z"
  "---"
  "Rescan|C-r|R"
)
MENU_Right=("${MENU_Left[@]}")
MENU_File=(
  "View|F3|V" "View file...||w" "Filtered view|M-!|F" "Edit|F4|E" "Copy|F5|C"
  "Chmod|C-x c|h" "Link|C-x l|L" "Symlink|C-x s|S" "Relative symlink|C-x v|k"
  "Edit symlink|C-x C-s|y" "Chown|C-x o|o" "Advanced chown||A" "Chattr|C-x e|t"
  "Rename/Move|F6|R" "Mkdir|F7|M" "Delete|F8|D" "Quick cd|M-c|Q"
  "---"
  "Select group|+|g" "Unselect group|-|n" "Invert selection|*|I"
  "---"
  "Exit|F10|x"
)
MENU_Command=(
  "User menu|F2|U" "Directory tree||D" "Find file|M-?|F" "Swap panels|C-u|w"
  "Switch panels on/off|C-o|p" "Compare directories|C-x d|C" "Compare files|C-x C-d|o"
  "External panelize|C-x !|x" "Show directory sizes|C-Space|i:16"
  "---"
  "Command history|M-h|h" "Viewed/edited files history|M-E|s:22" 'Directory hotlist|C-\|r'
  "Active VFS list|C-x a|A" "Background jobs|C-x j|B" 'Screen list|M-`|t'
  "---"
  "Undelete files (ext2fs only)||U"
  "---"
  "Edit extension file||e:5" "Edit menu file||m" "Edit highlighting group file||g"
)
MENU_Options=(
  "Configuration...||C" "Layout...||L" "Panel options...||P" "Confirmation...||o"
  "Appearance...||A" "Display bits...||D" "Learn keys...||k" "Virtual FS...||V"
  "---"
  "Save setup||S"
)
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
  # mc.sh gives each panel COLS/2 columns, so an odd width leaves the last
  # column blank; a "* *" grid would round the extra cell into the left panel.
  local pw=$(( COLS / 2 )) spare=$(( COLS - 2 * (COLS / 2) ))
  bc_screen "
    menu  menu  menu
    left  right .
    hint  hint  hint
    cmd   cmd   cmd
    keys  keys  keys
  " rows="1 * $HINTBAR 1 1" cols="$pw $pw $spare"
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
  bc_menubar menu "Left:2 File:11 Command:20 Options:32 Right:44" pairs="22 16 17 18 19" reserve=3
  bc_style cmd pair=40
  bc_list left.list NAMES_0
  bc_list right.list NAMES_1
}

# the panel split is computed from COLS, so the screen template is rebuilt
# whenever the terminal changes size
on_resize() { layout_screen; }

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
  bc_dirty left.top right.top cmd
  bc_list_redraw_sel left.list; bc_list_redraw_sel right.list
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

# ------------------------------------------------------------------ dialogs
# mc's dialog: a box centred over the listing area with a one-cell margin in
# the frame colour and mc's shadow. danger = the red Delete style.
mc_dialog() { # name title h w [danger | fp tp]
  local n=$1 t=$2 h=$3 w=$4 fp=23 tp=24
  if [[ ${5:-} == danger ]]; then fp=26 tp=27; elif [[ -n ${6:-} ]]; then fp=$5 tp=$6; fi
  (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  (( h > LINES - 4 )) && h=$(( LINES - 4 ))
  DW=$w DH=$h
  bc_dialog "$n" "$t" "${h}x$w" margin=1 shadow=mc spair=32 pair=$fp tpair=$tp nudge=-2,0
}

# A row of buttons starting at content column X (gap 1 between them).
button_row() { # area x name…
  local a=$1 x=$2 tpl="." n; shift 2
  local cols=$(( x < 0 ? 1 : x + 1 ))
  for n in "$@"; do tpl+=" $n ."; cols+=" auto 1"; done
  bc_grid "$a" "$tpl" cols="${cols% 1} *"
}

# lines of text, OK
message_dialog() { # title line…
  local t=$1 i tpl="" rows="" w=50; shift
  (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  mc_dialog d "$t" $(( $# + 4 )) "$w"
  for (( i = 1; i <= $#; i++ )); do tpl+=". d.l$i ."$'\n'; rows+="1 "; done
  bc_grid d "$tpl. . .
. d.b ." rows="${rows}1 1" cols="1 * 1"
  for (( i = 1; i <= $#; i++ )); do bc_label "d.l$i" "${!i}"; done
  button_row d.b $(( (DW - 9) / 2 - 3 )) d.ok
  bc_button d.ok "OK" ok
  bc_dialog_run d keys=quit_keys
}
quit_keys() { case $1 in q|Q) bc_close d ok ;; *) _bcw_dialog_key "$1" ;; esac; }

# prompt + one field, OK / Cancel -> TF_TEXT; status 0 = OK
text_field_dialog() { # title prompt default
  TF_TEXT=$3
  local w=40
  (( ${#2} + 8 > w )) && w=$(( ${#2} + 8 ))
  mc_dialog d "$1" 6 "$w"
  bc_grid d "
    .   d.p   d.p   d.p   d.p  d.p .
    .   d.f   d.f   d.f   d.f  d.f .
    d.s d.s   d.s   d.s   d.s  d.s d.s
    .   .     d.ok  .     d.no .   .
  " rows="1 1 1 1" cols="1 7 auto 1 auto * 1"
  bc_label d.p "$2"
  bc_input d.f TF_TEXT
  bc_style d.s divider
  bc_button d.ok "OK" ok
  bc_button d.no "Cancel" cancel
  bc_dialog_run d focus=d.f
}

delete_dialog() { # kind real -> status 0 = Yes
  local prompt="Delete file" name="\"$2\"?" w=21
  [[ $1 == directory ]] && prompt="Delete directory"
  (( ${#prompt} + 4 > w )) && w=$(( ${#prompt} + 4 ))
  (( ${#name} + 6 > w )) && w=$(( ${#name} + 6 ))
  mc_dialog d "Delete" 6 "$w" danger
  bc_grid d "
    .   d.p .
    .   d.n .
    d.s d.s d.s
    .   d.b .
  " rows="1 1 1 1" cols="1 * 1"
  bc_label d.p "$prompt"
  bc_label d.n "$name" align=center
  bc_style d.s divider
  button_row d.b $(( (DW - 14) / 2 - 3 )) d.yes d.no
  bc_button d.yes "Yes"
  bc_button d.no "No" cancel
  bc_dialog_run d focus=- keys=delete_keys
}
delete_keys() {
  case $1 in
    $'\r'|y|Y) bc_close d yes ;;
    n|N|$'\e') bc_close d ;;
  esac
}

# mc's Copy/Move dialog -> CM_SRC CM_DST CM_SHELL CM_FOLLOW CM_DIVE CM_PRESERVE CM_STABLE
copy_move_dialog() { # verb
  local verb=$1 kind=file
  cur_real; [[ $REAL == ".." ]] && return 1
  [[ -d ${DIR[$CUR]}/$REAL ]] && kind=directory
  CM_SRC='*' CM_DST="${DIR[$(( 1 - CUR ))]}/"
  CM_SHELL=1 CM_FOLLOW=0 CM_DIVE=0 CM_PRESERVE=1 CM_STABLE=0
  mc_dialog d "$verb" 12 66
  bc_grid d "
    .    d.msg d.msg   .
    .    d.src d.src   .
    .    .     d.shell .
    .    d.to  d.to    .
    .    d.dst d.dst   .
    d.s1 d.s1  d.s1    d.s1
    .    d.fol d.dive  .
    .    d.pre d.stab  .
    d.s2 d.s2  d.s2    d.s2
    .    d.b   d.b     .
  " rows="1 1 1 1 1 1 1 1 1 1" cols="1 31 * 1"
  bc_label d.msg "$verb $kind \"$REAL\" with source mask:"
  bc_label d.to "to:"
  bc_input d.src CM_SRC
  bc_input d.dst CM_DST
  bc_check d.shell CM_SHELL "Using shell patterns" hot=0
  bc_check d.fol CM_FOLLOW "Follow links" hot=7
  bc_check d.dive CM_DIVE "Dive into subdir if exists" hot=2
  bc_check d.pre CM_PRESERVE "Preserve attributes" hot=9
  bc_check d.stab CM_STABLE "Stable symlinks" hot=0
  bc_style d.s1 divider; bc_style d.s2 divider
  bc_grid d.b ". d.ok d.bg d.no ." cols="* auto auto auto *" gap=1
  bc_button d.ok "OK" ok
  bc_button d.bg "Background"
  bc_button d.no "Cancel" cancel
  bc_dialog_run d focus=d.dst order="d.src d.shell d.dst d.fol d.pre d.dive d.stab d.ok d.bg d.no"
}
history_d.src() { dir_history && CM_SRC=$HIST_RESULT BCW_CARET[d.src]=${#HIST_RESULT} && bc_dirty d.src; }
history_d.dst() { dir_history && CM_DST=$HIST_RESULT BCW_CARET[d.dst]=${#HIST_RESULT} && bc_dirty d.dst; }

# + : pattern, three options -> SG_*
select_group_dialog() {
  SG_PATTERN="" SG_FILES_ONLY=0 SG_CASE_SENS=1 SG_SHELL_PAT=1
  mc_dialog d "Select" 5 53
  bc_grid d "
    . d.pat d.pat .
    . d.fo  d.cs  .
    . d.sp  .     .
  " rows="1 1 1" cols="1 25 * 1"
  bc_input d.pat SG_PATTERN button
  bc_check d.fo SG_FILES_ONLY "Files only" hot=0
  bc_check d.cs SG_CASE_SENS "Case sensitive" hot=0
  bc_check d.sp SG_SHELL_PAT "Using shell patterns" hot=0
  bc_dialog_run d focus=d.pat
}

do_panel_options() {
  local hidden=${HIDE[$CUR]} ext=${SHOWEXT[$CUR]} rev=${REV[$CUR]} sort=${SORT[$CUR]}
  mc_dialog d "Panel options" 10 44
  bc_grid d "
    . d.hid .
    . d.ext .
    . d.rev .
    . d.srt .
    . .     .
    . d.b   .
  " rows="1 1 1 1 1 1" cols="1 * 1"
  bc_check d.hid hidden "Show hidden files" hot=0
  bc_check d.ext ext "Show extension" hot=0
  bc_check d.rev rev "Reverse sort" hot=0
  bc_cycle d.srt sort "Sort order: " name size date
  bc_grid d.b ". d.ok . d.no ." cols="7 auto 3 auto *"
  bc_button d.ok "OK" ok
  bc_button d.no "Cancel" cancel
  bc_dialog_run d || return
  HIDE[$CUR]=$hidden SHOWEXT[$CUR]=$ext REV[$CUR]=$rev SORT[$CUR]=$sort
  list_dir "$CUR"
}

do_compare_dirs() {
  mc_dialog d "Compare directories" 5 56
  bc_grid d "
    .   d.m .
    d.s d.s d.s
    .   d.b .
  " rows="1 1 1" cols="1 * 1"
  bc_label d.m "Select compare method:" align=center
  bc_style d.s divider
  bc_grid d.b ". d.q . d.z . d.t . d.no ." cols="1 auto 2 auto 2 auto 2 auto *"
  bc_button d.q "Quick"; bc_button d.z "Size only"; bc_button d.t "Thorough"; bc_button d.no "Cancel" cancel
  bc_dialog_run d focus=d.q keys=quit_keys || return
  list_dir 0; list_dir 1      # marking the differences is not implemented
}

do_background_jobs() {
  mc_dialog d "Background jobs" 13 58
  bc_float d nudge=0,0 at="7,$(( (COLS - DW) / 2 - 1 ))"
  bc_grid d "
    .   d.l .
    .   .   .
    d.s d.s d.s
    .   d.b .
  " rows="1 * 1 1" cols="1 * 1"
  local s; printf -v s '%*s' 52 ''
  bc_label d.l "$s" pair=29
  bc_style d.s divider
  bc_grid d.b ". d.st . d.re . d.ki . d.ok ." cols="8 auto 1 auto 1 auto 1 auto *"
  bc_button d.st "Stop"; bc_button d.re "Resume"; bc_button d.ki "Kill"; bc_button d.ok "OK" ok
  bc_dialog_run d focus=d.ok keys=quit_keys
}

do_screen_list() {
  local line
  line="Panels: [$(id -un)@$(hostname)]:$PWD"
  mc_dialog d "Screens" 3 68 16 17
  bc_grid d ". d.l ." cols="1 * 1"
  printf -v line '%-*s' $(( DW - 4 )) "$line"
  bc_label d.l "$line" pair=19
  bc_dialog_run d focus=-
}

do_encoding() {
  local -a keys=('-' 0 1 2 3 4 5 6 7 8 9 a b c)
  local -a names=("< No translation >" "7-bit ASCII" "ISO 8859-1" "ISO 8859-2" "ISO 8859-5" \
    "Windows 1250" "Windows 1251" "CP 437" "CP 850" "CP 852" "CP 866" "KOI8-R" "KOI8-U" "UTF-8")
  local i tpl="" line
  mc_dialog d "Choose codepage" 16 34 16 17
  for i in "${!keys[@]}"; do tpl+=". d.e$i ."$'\n'; done
  bc_grid d "$tpl" cols="1 * 1"
  for i in "${!keys[@]}"; do
    if (( i == 0 )); then printf -v line '%-*s' $(( DW - 4 )) "${keys[i]}  ${names[i]}"; bc_label "d.e$i" "$line" pair=19
    else bc_label "d.e$i" "${keys[i]}  ${names[i]}"; fi
  done
  bc_dialog_run d focus=-
}

do_vfs_list() {
  bc_dialog d "Active VFS directories" 26x92 at=2,4 pair=23 tpair=24
  bc_grid d "
    .  d.g1 .
    .  d.g2 .
    d.s d.s d.s
    .  d.b  .
  " rows="19 3 1 1" cols="1 88 *"
  bc_grid d.g1 ". d.h ." cols="1 * 1" rows="1"
  bc_style d.g1 border title="Top level group" tleft
  bc_grid d.g2 ". d.p ." cols="1 * 1"
  bc_style d.g2 border title="Directory path" tleft
  local home; printf -v home '%-84s' "$HOME"
  bc_label d.h "$home" pair=30
  bc_label d.p "$HOME"
  bc_style d.s divider
  bc_grid d.b "d.ch . d.fr . d.rf . d.no" cols="auto 1 auto 1 auto * auto"
  bc_button d.ch "Change to" ok hot=7; bc_button d.fr "Free VFSs now" hot=2
  bc_button d.rf "Refresh" hot=2;      bc_button d.no "Cancel" cancel hot=2
  bc_dialog_run d focus=- keys=quit_keys
}

do_filtered_view() {
  local cmd=".."
  mc_dialog d "Filtered view" 6 48
  bc_grid d "
    .   d.p d.p   d.p .
    .   d.f d.f   d.f .
    d.s d.s d.s   d.s d.s
    .   d.b d.b   d.b .
  " rows="1 1 1 1" cols="1 * * * 1"
  bc_label d.p "Filter command and arguments:"
  bc_input d.f cmd button
  bc_style d.s divider
  bc_grid d.b ". d.ok d.no ." cols="11 auto auto *" gap=1
  bc_button d.ok "OK" ok; bc_button d.no "Cancel" cancel
  bc_dialog_run d focus=d.f    # applying the filter is not implemented
}

# M-c: "cd" + field, at the bottom left
quick_cd_dialog() {
  local target=""
  bc_dialog d "Quick cd" 3x48 at=bottomleft nudge=-2,0 margin=1 shadow=mc spair=36 pair=23 tpair=24
  bc_grid d ". d.cd d.f ." cols="1 3 * 1"
  bc_label d.cd "cd "
  bc_input d.f target
  bc_dialog_run d focus=d.f keys=qcd_keys || return
  target=${target//\"/}; target=${target/#~/$HOME}; target=${target## }
  [[ -z $target ]] && target=$HOME
  if [[ -d $target ]]; then DIR[$CUR]=$target; list_dir "$CUR"; cmd_changed
  else message_dialog "cd" "Not a directory: $target"; fi
}
qcd_keys() { case $1 in "$KEY_F10") bc_close d ;; *) _bcw_dialog_key "$1" ;; esac; }

# ---- list popups
# A framed float with a scrolling list of ITEMS; Enter / double click picks.
# -> LIST_RESULT (status 0) or cancelled.
POP_ITEMS=() POP_SELPAIR=22 POP_PAD=0
list_popup() { # name title h w at=… [style…]
  local n=$1 t=$2 h=$3 w=$4; shift 4
  bc_dialog "$n" "$t" "${h}x$w" pair=23 tpair=24 keys=pop_keys "$@"
  bc_grid "$n" "$n.l" rows="*"
  bc_list "$n.l" POP_ITEMS
  bc_list_sel "$n.l" "$POP_PAD"
  eval "row_$n.l() { pop_row $n.l \"\$@\"; }"
  eval "enter_$n.l() { pop_pick $n; }"
  eval "select_$n.l() { (( \$1 < POP_PAD )) && bc_list_sel $n.l \$POP_PAD; }"
  local pf=$BCL_FOCUS
  bc_focus "$n.l"
  bc_modal "$n"; local rc=$?
  bc_focus "$pf"
  return "$rc"
}
pop_row() { # list idx y sel   (POP_INDENT: one blank column on each side)
  local a=$1 i=$2 y=$3 s="" in=$POP_INDENT
  (( i < ${#POP_ITEMS[@]} )) && s=${POP_ITEMS[i]}
  bc_size "$a"
  printf -v s '%*s%-*s%*s' "$in" '' $(( BCL_W - 2 * in )) "${s:0:BCL_W-2*in}" "$in" ''
  bc_print "$a" "$y" 0 "$s"
  (( $4 )) && bc_print "$a" "$y" "$in" "${s:in:BCL_W-2*in}" pair="$POP_SELPAIR"
}
pop_pick() { bc_list_sel "$1.l"; LIST_RESULT=${POP_ITEMS[BCL_SEL]}; bc_close "$1" picked; }
pop_keys() { case $1 in $'\e'|"$KEY_F10"|q|Q) bc_close "$BCL_MODAL" ;; esac; }

pop_size() { # items… -> PW (width) PH (height)
  local e maxl=0
  for e in "$@"; do (( ${#e} > maxl )) && maxl=${#e}; done
  PW=$(( maxl + 6 )); (( PW < 40 )) && PW=40; (( PW > COLS - 4 )) && PW=$(( COLS - 4 ))
  PH=$(( $# + 2 ))
}

list_dialog() { # title item…
  local t=$1; shift
  (( $# )) || { message_dialog "$t" "No entries."; return 1; }
  POP_ITEMS=("$@") POP_SELPAIR=22 POP_PAD=0 POP_INDENT=0
  pop_size "$@"
  (( PH > LINES - 4 )) && PH=$(( LINES - 4 ))
  list_popup p "$t" "$PH" "$PW" at=center
}

# the directory history behind a field's [^] / M-H -> HIST_RESULT
dir_history() {
  local -a items=() e
  for e in "${DIRHIST[@]}"; do [[ -n $e ]] && items+=("$e"); done
  (( ${#items[@]} )) || items=("$PWD")
  POP_ITEMS=("${items[@]}") POP_SELPAIR=22 POP_PAD=0 POP_INDENT=0
  pop_size "${items[@]}"
  local y=$(( (LINES - 6) / 2 + 6 ))       # just below the Copy dialog
  (( PH > LINES - y )) && PH=$(( LINES - y )); (( PH < 4 )) && PH=4
  list_popup h "History" "$PH" "$PW" at="$y,$(( (COLS - PW) / 2 ))" || return 1
  HIST_RESULT=$LIST_RESULT
}

# M-h: command history above the command line, newest at the bottom
do_command_history() {
  (( ${#CMDHIST[@]} )) || { message_dialog "Command history" "No commands yet."; return; }
  local e maxl=0 n=${#CMDHIST[@]} w h vis
  for e in "${CMDHIST[@]}"; do (( ${#e} > maxl )) && maxl=${#e}; done
  w=$(( maxl + 6 )); (( w < 13 )) && w=13; (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  h=$(( n + 3 )); (( h > LINES - 4 )) && h=$(( LINES - 4 ))
  vis=$(( h - 2 ))
  POP_ITEMS=() POP_PAD=0 POP_SELPAIR=30 POP_INDENT=1
  while (( POP_PAD + n < vis )); do POP_ITEMS+=(""); POP_PAD=$(( POP_PAD + 1 )); done
  POP_ITEMS+=("${CMDHIST[@]}")
  list_popup p "History" "$h" "$w" at="$(( LINES - 6 )),$(( (COLS - w) / 2 + 5 ))" \
    shadow=mc spair=36 || return
  CMD_LINE=$LIST_RESULT CMD_CARET=${#LIST_RESULT}
  cmd_changed
}

do_file_history() {
  (( ${#FILEHIST[@]} )) || { message_dialog "Viewed/edited files history" "No files yet."; return; }
  list_dialog "Viewed/edited files history" "${FILEHIST[@]}" && view_path "$LIST_RESULT"
}

do_hotlist() {
  (( ${#DIRHIST[@]} )) || { message_dialog "Directory hotlist" "No directories yet."; return; }
  list_dialog "Directory hotlist" "${DIRHIST[@]}" && { DIR[$CUR]=$LIST_RESULT; list_dir "$CUR"; cmd_changed; }
}

do_tree() {
  local -a dirs=()
  mapfile -t dirs < <(find "${DIR[$CUR]}" -maxdepth 3 -type d -print 2>/dev/null | head -200)
  list_dialog "Directory tree" "${dirs[@]}" || return
  DIR[$CUR]=$LIST_RESULT; list_dir "$CUR"; cmd_changed
}

do_find_file() {
  text_field_dialog "Find file" "File name pattern:" "" || return
  local pat=$TF_TEXT f
  [[ -z $pat ]] && return
  local -a found=()
  mapfile -t found < <(find "${DIR[$CUR]}" -name "$pat" -print 2>/dev/null | head -200)
  (( ${#found[@]} )) || { message_dialog "Find file" "No files found matching: $pat"; return; }
  list_dialog "Find file" "${found[@]}" || return
  f=$LIST_RESULT
  if [[ -d $f ]]; then DIR[$CUR]=$f; list_dir "$CUR"; cmd_changed; else view_path "$f"; fi
}

# ---- F1 help and F2 user menu (fixed-size boxes centred over the panels)
HELP_TEXT=(
" ┌─┬─┐     ┐           ┐"
" │ │ │ .   │     .     │"
" │ │ │ ┐ ┌─┤ ┬─┐ ┐ ┌─┬ ├─┐ ┼"
" │ │ │ │ │ │ │ │ │ │ │ │ │ │"
" ┴   ┴ ┴ └─┴ ┴ ┴ ┴ └─┤ ┴ ┴ └┘"
"     ──────Commander─┘ 4.8.33"
""
"This is the main help screen for GNU Midnight Commander."
""
"To learn more on how to use the interactive help facility just press Enter."
"You may want to go directly to the help contents."
""
"GNU Midnight Commander is written by its authors."
""
"GNU Midnight Commander comes with ABSOLUTELY NO WARRANTY. This is free"
"software, and you are welcome to redistribute it under terms of GNU General"
"Public License."
"" "" ""
)
# highlighted words: "line|word|pair"
HELP_HL=("5|Commander|20" "7|GNU Midnight Commander|20" "9|Enter|21" "10|contents|6"
         "12|authors|6" "14|WARRANTY|6" "15|GNU General |6" "16|Public License|6")

panel_rows() { PH=$(( LINES - 3 - HINTBAR )); }

fkey_help() {
  local h=$(( ${#HELP_TEXT[@]} + 2 )) w=82 x y
  panel_rows
  (( w > COLS - 2 )) && w=$(( COLS - 2 )); (( h > 1 + PH )) && h=$(( 1 + PH ))
  x=$(( (COLS - w) / 2 )) y=$(( 1 + (PH - h) / 2 ))
  (( x < 1 )) && x=1; (( y < 1 )) && y=1
  bc_dialog d "Help" "$(( h ))x$w" at="$(( y - 1 )),$(( x - 1 ))" margin=1 shadow=mc spair=36 \
    pair=13 tpair=20 keys=any_key_closes
  bc_grid d "d.t" rows="*"
  draw_d.t() {
    local i e w p
    local -a t=()
    for i in "${!HELP_TEXT[@]}"; do printf -v t[i] '%-80s' "${HELP_TEXT[i]}"; bc_print d.t "$i" 0 "${t[i]}"; done
    for e in "${HELP_HL[@]}"; do
      IFS='|' read -r i w p <<< "$e"
      local pre=${t[i]%%"$w"*}
      bc_print d.t "$i" "${#pre}" "$w" pair="$p"
    done
  }
  local -a saved=("${BUTTONS[@]}")
  BUTTONS=(Help Index Prev "" "" "" "" "" "" Quit); bc_dirty keys
  bc_dialog_run d focus=-
  BUTTONS=("${saved[@]}"); bc_dirty keys
}
any_key_closes() { bc_close d; }
click_d.t() { bc_close d; }

USER_MENU=(
  "@ Do something on the current file" "0 Edit a bug report and send it to root"
  "2 Call the info hypertext browser" "3 Compress the current subdirectory (tar.gz)"
  "4 Compress the current subdirectory (tar.bz2)" "5 Compress the current subdirectory (tar.7z)"
  "6 Compress the current subdirectory (tar.xz)" "7 Compress the current subdirectory (tar.zst)"
  "8 Compress the current subdirectory (tar.lzo)" "m View manual page"
  "n Inspect gzip'ed newsbatch file" "h Strip headers from current newsarticle"
  "r Copy file to remote host" "y Gzip or gunzip current file"
  "b Bzip2 or bunzip2 current file" "o Open next a free console"
)
user_menu() {
  local n=${#USER_MENU[@]} w=64 h x y e
  h=$(( n + 2 )); panel_rows
  x=$(( (COLS - w) / 2 )) y=$(( (LINES - 3 - h) / 2 ))
  (( x < 1 )) && x=1; (( y < 1 )) && y=1
  (( w > COLS - 2 )) && w=$(( COLS - 2 )); (( h > 1 + PH )) && h=$(( 1 + PH ))
  POP_ITEMS=()
  for e in "${USER_MENU[@]}"; do POP_ITEMS+=("${e%% *}       ${e#* }"); done
  POP_SELPAIR=19 POP_PAD=0 POP_INDENT=1
  bc_dialog u "User menu" "${h}x$w" at="$(( y - 1 )),$(( x - 1 ))" margin=1 shadow=mc spair=36 \
    pair=16 tpair=17 keys=pop_keys
  bc_grid u "u.l" rows="*"
  bc_list u.l POP_ITEMS
  bc_list_sel u.l 3
  local pf=$BCL_FOCUS
  bc_focus u.l
  bc_modal u
  bc_focus "$pf"
}
row_u.l() { POP_INDENT=1 POP_SELPAIR=19; pop_row u.l "$@"; }
enter_u.l() { bc_close u; }
click_u.l() { (( $3 & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED) )) && bc_close u; }

# ------------------------------------------------------------------ file actions
do_mkdir() {
  text_field_dialog "Create a new Directory" "Enter directory name:" "" || return
  local name=$TF_TEXT
  [[ -z $name ]] && return
  mkdir "${DIR[$CUR]}/$name" 2>/dev/null || return
  refresh_panel_keep "$CUR" "$name"
  [[ ${DIR[1 - CUR]} == "${DIR[$CUR]}" ]] && refresh_panel_keep $(( 1 - CUR ))
}

do_delete() {
  cur_real; local real=$REAL kind=file
  [[ $real == ".." ]] && return
  [[ -d ${DIR[$CUR]}/$real ]] && kind=directory
  delete_dialog "$kind" "$real" || return
  rm -rf -- "${DIR[$CUR]}/$real" 2>/dev/null || return
  local -n RR=REALS_$CUR
  pos_get "$CUR"
  local next=${RR[POS + 1]:-}
  [[ -z $next ]] && next=${RR[POS - 1]:-}
  refresh_panel_keep "$CUR" "$next"
  [[ ${DIR[1 - CUR]} == "${DIR[$CUR]}" ]] && refresh_panel_keep $(( 1 - CUR ))
}

copy_or_move() { # Copy|Move
  cur_real; local real=$REAL
  [[ $real == ".." ]] && return
  copy_move_dialog "$1" || return
  local d=${CM_DST/#~/$HOME} target flags=""
  [[ -z $d ]] && return
  [[ -d $d ]] || { message_dialog "$1" "Not a directory: $d"; return; }
  target=$d
  (( CM_DIVE )) && [[ -d $d/$real ]] && target="$d/$real/"
  if [[ $1 == Copy ]]; then
    flags="-r"; (( CM_PRESERVE )) && flags+=" -p"; (( CM_FOLLOW )) && flags+=" -L"
    if [[ $CM_SRC == '*' ]]; then cp $flags -- "${DIR[$CUR]}/$real" "$target" 2>/dev/null
    else cp $flags -- ${DIR[$CUR]}/${CM_SRC} "$target" 2>/dev/null; fi
  else
    if [[ $CM_SRC == '*' ]]; then mv -- "${DIR[$CUR]}/$real" "$target" 2>/dev/null
    else mv -- ${DIR[$CUR]}/${CM_SRC} "$target" 2>/dev/null; fi
  fi
  list_dir 0; list_dir 1
}
do_copy() { copy_or_move Copy; }
do_move() { copy_or_move Move; }

do_info() {
  cur_real; local real=$REAL
  [[ $real == ".." ]] && return
  local f="${DIR[$CUR]}/$real" size="" mtime type="regular file"
  if [[ -d $f ]]; then type=directory
  elif [[ -L $f ]]; then type=symlink
  else size=$(wc -c < "$f" 2>/dev/null | tr -d ' '); fi
  mtime=$(stat -c '%y' "$f" 2>/dev/null)
  local -a lines=("$real," "Type: $type")
  [[ -n $size ]] && lines+=("Size: $size bytes")
  [[ -n $mtime ]] && lines+=("Modified: ${mtime:0:19}")
  message_dialog "Info" "${lines[@]}"
}

# a text_field_dialog, then a command on the current entry; re-list on success
entry_op() { # title prompt default -> runs: OP_CMD with $REAL / $TF_TEXT
  cur_real
  [[ $REAL == ".." ]] && return 1
  text_field_dialog "$1" "$2" "$3" || return 1
  return 0
}
do_chmod() {
  entry_op "Chmod" "Mode (octal):" "0644" || return
  [[ $TF_TEXT =~ ^[0-7]{3,4}$ ]] || { message_dialog "Chmod" "Invalid mode: $TF_TEXT"; return; }
  chmod "$TF_TEXT" "${DIR[$CUR]}/$REAL" 2>/dev/null && refresh_panel_keep "$CUR"
}
do_link() {
  entry_op "Link" "Name of the new link:" "" && [[ -n $TF_TEXT ]] || return
  ln "${DIR[$CUR]}/$REAL" "${DIR[$CUR]}/$TF_TEXT" 2>/dev/null && refresh_panel_keep "$CUR"
}
do_symlink() {
  entry_op "Symlink" "Name of the new symlink:" "" && [[ -n $TF_TEXT ]] || return
  ln -s "$REAL" "${DIR[$CUR]}/$TF_TEXT" 2>/dev/null && refresh_panel_keep "$CUR"
}
do_relative_symlink() {
  entry_op "Relative symlink" "Name of the new symlink:" "" && [[ -n $TF_TEXT ]] || return
  local link="${DIR[$CUR]}/$TF_TEXT" rel
  rel=$(realpath --relative-to="$(dirname "$link")" "${DIR[$CUR]}/$REAL" 2>/dev/null)
  ln -s "${rel:-$REAL}" "$link" 2>/dev/null && refresh_panel_keep "$CUR"
}
do_edit_symlink() {
  cur_real; [[ $REAL == ".." ]] && return
  local f="${DIR[$CUR]}/$REAL"
  [[ -L $f ]] || { message_dialog "Edit symlink" "Not a symlink: $REAL"; return; }
  text_field_dialog "Edit symlink" "New target:" "$(readlink "$f" 2>/dev/null)" && [[ -n $TF_TEXT ]] || return
  ln -sf "$TF_TEXT" "$f" 2>/dev/null && refresh_panel_keep "$CUR"
}
do_chown() {
  entry_op "Chown" "Owner[:group]:" "" && [[ -n $TF_TEXT ]] || return
  chown "$TF_TEXT" "${DIR[$CUR]}/$REAL" 2>/dev/null || message_dialog "Chown" "Cannot chown $REAL to $TF_TEXT"
  refresh_panel_keep "$CUR"
}
do_advanced_chown() {
  entry_op "Advanced chown" "Owner:" "" || return
  local spec=$TF_TEXT
  text_field_dialog "Advanced chown" "Group:" "" || return
  [[ -n $TF_TEXT ]] && spec+=":$TF_TEXT"
  [[ -z $spec ]] && return
  chown "$spec" "${DIR[$CUR]}/$REAL" 2>/dev/null || message_dialog "Advanced chown" "Cannot chown $REAL to $spec"
  refresh_panel_keep "$CUR"
}
do_chattr() {
  cur_real; [[ $REAL == ".." ]] && return
  command -v chattr >/dev/null 2>&1 || { message_dialog "Chattr" "chattr is not available."; return; }
  entry_op "Chattr" "Attributes (+/- flags):" "" && [[ -n $TF_TEXT ]] || return
  chattr "$TF_TEXT" "${DIR[$CUR]}/$REAL" 2>/dev/null || message_dialog "Chattr" "Cannot set attributes on $REAL"
  refresh_panel_keep "$CUR"
}

do_filter() {
  text_field_dialog "Filter" "Panel filter (shell pattern):" "${FILTERS[$CUR]}" || return
  FILTERS[$CUR]=$TF_TEXT
  list_dir "$CUR"
}

do_select_group() {
  select_group_dialog || return
  local pat=$SG_PATTERN i r m
  [[ -z $pat ]] && return
  local -n RR=REALS_$CUR TT=TYPES_$CUR SELARR=SELSET_$CUR
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    r=${RR[$i]}
    (( SG_FILES_ONLY )) && [[ ${TT[$i]} == d ]] && continue
    m=0
    if (( SG_SHELL_PAT )); then
      if (( SG_CASE_SENS )); then [[ $r == $pat ]] && m=1; else [[ ${r,,} == ${pat,,} ]] && m=1; fi
    else
      if (( SG_CASE_SENS )); then [[ $r == "$pat" ]] && m=1; else [[ ${r,,} == "${pat,,}" ]] && m=1; fi
    fi
    (( m )) && SELARR[$r]=1
  done
  mark_changed
}

do_unselect_group() {
  text_field_dialog "Unselect group" "File name pattern:" "*" || return
  local pat=$TF_TEXT i
  [[ -z $pat ]] && return
  local -n RR=REALS_$CUR SELARR=SELSET_$CUR
  for (( i = 1; i < ${#RR[@]}; i++ )); do [[ ${RR[$i]} == $pat ]] && unset "SELARR[${RR[$i]}]"; done
  mark_changed
}

do_compare_files() {
  local l r
  local -n RL=REALS_0 RRt=REALS_1
  pos_get 0; l="${DIR[0]}/${RL[POS]}"
  pos_get 1; r="${DIR[1]}/${RRt[POS]}"
  if cmp -s "$l" "$r"; then message_dialog "Compare files" "Files are identical:" "$l" "$r"
  else message_dialog "Compare files" "Files differ:" "$l" "$r"; fi
}

do_show_sizes() {
  local kb
  kb=$(du -sk "${DIR[$CUR]}" 2>/dev/null | awk '{print $1}')
  message_dialog "Directory size" "${DIR[$CUR]}" "Total: $(hum "${kb:-0}")"
}

do_edit_path() { # path
  local f=$1 ed=${EDITOR:-${VISUAL:-}}
  [[ -n $ed ]] || { message_dialog "Edit" "No editor configured."; return; }
  [[ -e $f ]] || { message_dialog "Edit" "File does not exist: $f"; return; }
  push_hist FILEHIST "$f"
  def_prog_mode; endwin
  eval "$ed $(printf '%q' "$f")"
  reset_prog_mode
  BC_FORCEFULL=1
  refresh_panel_keep "$CUR"
  redraw_all
}
do_edit() { cur_real; [[ $REAL == ".." ]] || do_edit_path "${DIR[$CUR]}/$REAL"; }
do_edit_file_kind() { # title file
  [[ -n ${EDITOR:-${VISUAL:-}} ]] || { message_dialog "$1" "No editor configured."; return; }
  local path="$HOME/.config/mc/$2"
  [[ -e $path ]] || { message_dialog "$1" "File not found: $path"; return; }
  do_edit_path "$path"
}

# ------------------------------------------------------------------ viewer
# F3: a full-screen float — title bar, text, F-key bar.
V_LINES=() V_BTOFF=() V_PATH="" V_TOTAL=0 V_OFF=0
view_load_text() { # title [total] < text
  local l off=0
  mapfile -t V_LINES
  V_BTOFF=()
  if (( ${#V_LINES[@]} == 0 )); then V_LINES=(""); V_BTOFF=(0)
  else for l in "${V_LINES[@]}"; do V_BTOFF+=("$off"); off=$(( off + ${#l} + 1 )); done; fi
  V_PATH=$1 V_TOTAL=${2:-$off} V_OFF=0
}

view_path() { # file
  local f=$1
  [[ -r $f ]] || { message_dialog "View" "Cannot read $f"; return; }
  push_hist FILEHIST "$f"
  view_load_text "$f" "$(wc -c < "$f" 2>/dev/null | tr -d ' \t')" < "$f"
  view_show
}
view_file() { view_path "${DIR[$CUR]}/$1"; }
do_view() {
  cur_real; local real=$REAL
  [[ $real == ".." ]] && return
  if [[ -d ${DIR[$CUR]}/$real ]]; then DIR[$CUR]="${DIR[$CUR]}/$real"; list_dir "$CUR"; cmd_changed
  else view_file "$real"; fi
}
do_view_file() {
  text_field_dialog "View file" "File name:" "" || return
  local f=${TF_TEXT/#~/$HOME}
  [[ -z $f ]] && return
  [[ $f != /* ]] && f="${DIR[$CUR]}/$f"
  if [[ -d $f ]]; then DIR[$CUR]=$f; list_dir "$CUR"; cmd_changed; else view_path "$f"; fi
}

view_show() {
  local saved=$ESCDELAY
  ESCDELAY=80
  bc_float v at=0,0 size=100%x100% keys=view_keys
  bc_grid v "
    v.t
    v.b
    v.f
  " rows="1 * 1"
  bc_style v.b pair=7
  local pf=$BCL_FOCUS
  bc_focus ""; bc_cursor
  bc_modal v
  bc_focus "$pf"
  ESCDELAY=$saved
  cmd_changed
}

view_maxoff() { bc_size v.b; V_ROWS=$BCL_H; V_MAXOFF=$(( ${#V_LINES[@]} - V_ROWS )); (( V_MAXOFF < 0 )) && V_MAXOFF=0; }

draw_v.t() {
  view_maxoff
  local off=${V_BTOFF[V_OFF]:-0} total=$V_TOTAL pct=0 ot left gap
  (( V_MAXOFF == 0 || V_OFF >= V_MAXOFF )) && off=$total
  (( off > total )) && off=$total
  (( total > 0 )) && pct=$(( off * 100 / total ))
  ot="$off/$total"
  gap=$(( COLS - 21 - ${#V_PATH} - ${#ot} )); (( gap < 0 )) && gap=0
  printf -v left '%s%*s%s' "$V_PATH" "$gap" '' "$ot"
  printf -v left '%-*s%21s' $(( COLS - 21 )) "$left" "$pct%"
  bc_print v.t 0 0 "${left:0:COLS}" pair=6
}

draw_v.b() {
  view_maxoff
  local r line exp part sp pad col
  for (( r = 0; r < V_ROWS; r++ )); do
    line=${V_LINES[V_OFF + r]:-}
    if [[ $line == *$'\t'* ]]; then      # tabs to 8-column stops
      exp="" col=0
      while [[ $line == *$'\t'* ]]; do
        part=${line%%$'\t'*}; line=${line#*$'\t'}
        exp+=$part; col=$(( col + ${#part} ))
        pad=$(( 8 - col % 8 )); printf -v sp '%*s' "$pad" ''; exp+=$sp; col=$(( col + pad ))
      done
      line=$exp$line
    fi
    printf -v line '%-*s' "$COLS" "${line:0:COLS}"
    bc_print v.b "$r" 0 "$line"
  done
}

draw_v.f() {
  local -a label=(Help UnWrap Quit Hex Goto "" Search Raw Format Quit)
  local i x n l
  for (( i = 0; i < 10 && i * 10 < COLS; i++ )); do
    x=$(( i * 10 )); printf -v n '%2d' $(( i + 1 )); printf -v l '%-8s' "${label[i]}"
    bc_print v.f 0 "$x" "$n" pair=15
    bc_print v.f 0 $(( x + 2 )) "$l" pair=6
  done
}

view_scroll() { # new offset
  view_maxoff
  local o=$1
  (( o > V_MAXOFF )) && o=$V_MAXOFF; (( o < 0 )) && o=0
  (( o == V_OFF )) && return
  V_OFF=$o
  bc_dirty v.t v.b
}

view_keys() {
  view_maxoff
  case $1 in
    "$KEY_UP")    view_scroll $(( V_OFF - 1 )) ;;
    "$KEY_DOWN")  view_scroll $(( V_OFF + 1 )) ;;
    "$KEY_HOME")  view_scroll 0 ;;
    "$KEY_END")   view_scroll "$V_MAXOFF" ;;
    "$KEY_PPAGE") view_scroll $(( V_OFF - V_ROWS )) ;;
    "$KEY_NPAGE") view_scroll $(( V_OFF + V_ROWS )) ;;
    q|Q|$'\e'|"$KEY_F3"|"$KEY_F10") bc_close v ;;
  esac
}
click_v.b() { # wheel scrolls
  (( $3 & (BUTTON4_PRESSED | BUTTON4_CLICKED) )) && view_scroll $(( V_OFF - 1 ))
  (( $3 & (BUTTON5_PRESSED | BUTTON5_CLICKED) )) && view_scroll $(( V_OFF + 1 ))
  return 0
}
click_v.f() { # Quit buttons
  (( $3 & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  case $(( $2 / 10 )) in 2|9) bc_close v ;; esac
}

# ------------------------------------------------------------------ menus
# while the menu bar is open the panels hide their highlights (as mc does)
open_menu()  { MENU_OPEN=1; menu_dims; }
close_menu() { MENU_OPEN=0; menu_dims; }
menu_dims() { bc_dirty left.top right.top; bc_list_redraw_sel left.list; bc_list_redraw_sel right.list; }
run_menu() { bc_menubar_run menu "${1:-0}" "${2:-0}"; }
not_impl() { message_dialog "$1" "Not implemented: $2"; }

pick_menu() { # title label
  local m=$1 l=$2
  case $m in
    Left|Right)
      case $l in
        "File listing") : ;;
        "Quick view")    do_view ;;
        "Info")          do_info ;;
        "Tree")          do_tree ;;
        "Sort order...") do_sort_cycle ;;
        "Filter...")     do_filter ;;
        "Rescan")        do_rescan ;;
        *)               not_impl "$m" "$l" ;;
      esac ;;
    File)
      case $l in
        "View")             do_view ;;
        "View file...")     do_view_file ;;
        "Filtered view")    do_filtered_view ;;
        "Edit")             do_edit ;;
        "Copy")             do_copy ;;
        "Chmod")            do_chmod ;;
        "Link")             do_link ;;
        "Symlink")          do_symlink ;;
        "Relative symlink") do_relative_symlink ;;
        "Edit symlink")     do_edit_symlink ;;
        "Chown")            do_chown ;;
        "Advanced chown")   do_advanced_chown ;;
        "Chattr")           do_chattr ;;
        "Rename/Move")      do_move ;;
        "Mkdir")            do_mkdir ;;
        "Delete")           do_delete ;;
        "Quick cd")         focus_cmdline ;;
        "Select group")     do_select_group ;;
        "Unselect group")   do_unselect_group ;;
        "Invert selection") do_invert_selection ;;
        "Exit")             bc_quit ;;
      esac ;;
    Command)
      case $l in
        "User menu")            user_menu ;;
        "Directory tree")       do_tree ;;
        "Find file")            do_find_file ;;
        "Swap panels")          do_swap_panels ;;
        "Switch panels on/off") message_dialog "$l" "Panel visibility is not implemented." ;;
        "Compare directories")  do_compare_dirs ;;
        "Compare files")        do_compare_files ;;
        "External panelize")    message_dialog "$l" "External panelize is not implemented." ;;
        "Show directory sizes") do_show_sizes ;;
        "Command history")      do_command_history ;;
        "Viewed/edited files history") do_file_history ;;
        "Directory hotlist")    do_hotlist ;;
        "Active VFS list")      do_vfs_list ;;
        "Background jobs")      do_background_jobs ;;
        "Screen list")          do_screen_list ;;
        "Undelete files (ext2fs only)") message_dialog "Undelete files" "Undelete is only available on ext2fs filesystems." ;;
        "Edit extension file")  do_edit_file_kind "$l" mc.ext ;;
        "Edit menu file")       do_edit_file_kind "$l" mc.menu ;;
        "Edit highlighting group file") do_edit_file_kind "$l" mc.hint ;;
      esac ;;
    Options)
      case $l in
        "Configuration...")
          message_dialog Configuration "Sort order: ${SORT[$CUR]}" "Reverse sort: $(( REV[$CUR] ))" \
            "Show hidden files: $(( HIDE[$CUR] ))" "Show extension: $(( SHOWEXT[$CUR] ))" \
            "Panel filter: ${FILTERS[$CUR]:-none}" ;;
        "Layout...")        message_dialog Layout "Layout changes are not implemented." ;;
        "Panel options...") do_panel_options ;;
        "Confirmation...")  message_dialog Confirmation "Confirmation settings are not implemented." ;;
        "Appearance...")    message_dialog Appearance "Appearance settings are not implemented." ;;
        "Display bits...")  message_dialog "Display bits" "Display bits settings are not implemented." ;;
        "Learn keys...")    message_dialog "Learn keys" "Key learning is not implemented." ;;
        "Virtual FS...")    message_dialog "Virtual FS" "Virtual FS settings are not implemented." ;;
        "Save setup")       message_dialog "Save setup" "Saving setup is not implemented." ;;
      esac ;;
  esac
}

focus_cmdline() { CMD_LINE="" CMD_CARET=0; cmd_changed; }

do_sort_cycle() {
  case ${SORT[$CUR]} in name) SORT[$CUR]=size ;; size) SORT[$CUR]=date ;; *) SORT[$CUR]=name ;; esac
  list_dir "$CUR"
}

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
  BCW_PENS="29 30 25 28"      # focused control, its hotkey, input field, [^]
  if (( LINES < 12 || COLS < 60 )); then endwin; echo "Terminal too small" >&2; exit 1; fi
  layout_screen
  list_dir 0; list_dir 1
  activate 0
  bc_run
}

[[ ${BASH_SOURCE[0]} == "$0" ]] && main "$@"
