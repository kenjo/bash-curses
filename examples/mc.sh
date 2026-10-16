# A Midnight Commander-style dual-panel file manager built on lib/bc.sh.
#
# Layout (for a 100x30 terminal):
#   row 0   : menu bar (Left <menus> Right)
#   rows 1- : two file panels (Name / Size / Modify-time), color by type
#   bottom  : hint line, command line, F-key button bar
#
# Keys:
#   arrows      move selection        Tab / Left / Right : switch panel
#   PgUp/PgDn   scroll                Home/End           : top/bottom
#   Enter       open dir / view file  r                  : refresh
#   F1 help     F2 menu               F3 view            F4 edit
#   F5 copy     F6 rename/move        F7 mkdir           F8 delete
#   F9 pull down F10 quit             printable chars    : command line
#   Esc         focus command line
source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"
ESCDELAY=100

_repeat() { # var char n
  local __var=$1 __ch=$2 __n=$3 __s=""
  if (( __n > 0 )); then
    printf -v __s '%*s' "$__n" ''
    __s=${__s// /$__ch}
  fi
  printf -v "$__var" '%s' "$__s"
}

# ---- per-panel state (suffix 0=left, 1=right) ----
NAMES_0=(); TYPES_0=(); SIZES_0=(); TIMES_0=(); REALS_0=(); EXEC_0=()
NAMES_1=(); TYPES_1=(); SIZES_1=(); TIMES_1=(); REALS_1=(); EXEC_1=()
DIR=("$PWD" "$PWD")
FREE=("" "")
POS_0=0; POS_1=0; OFF_0=0; OFF_1=0
SORT=(name name)
REV=(0 0)
HIDE=(0 0)
SHOWEXT=(1 1)
FILTERS=("" "")
declare -A SELSET_0=() SELSET_1=()
WIN=()
PANEL=()

CUR=0                 # active panel (0 left, 1 right)
CMD_LINE=""
CMD_CARET=0
HINT_TEXT=""
STOP=0
DLG_RESULT=""
DIRHIST=()            # directory history, most-recent-first (for the completer)
HIST_RESULT=""
CMDHIST=()            # executed command history, most-recent-first
FILEHIST=()           # viewed/edited file history, most-recent-first
LIST_RESULT=""

# column widths
SIZEW=7
TIMEW=12

MO=(jan feb mars apr maj juni juli aug sep okt nov dec)

# menus and their items (top-level bar: Left, File, Command, Options, Right).
# Each entry is "LABEL|SHORTCUT" (shortcut may be empty); "---" is a group
# separator. Bar items sit at MENU_X, and the dropdown opens 2 cols to the
# left of the bar item (matching mc).
MENUNAMES=(Left File Command Options Right)
MENU_X=(2 11 20 32 44)
MENU_Left=(
  "File listing||g" "Quick view|C-x q|Q" "Info|C-x i|I" "Tree||T"
  "---"
  "Listing format...||L" "Sort order...||S" "Filter...||F" "Encoding...|M-e|E"
  "---"
  "FTP link...||P" "Shell link...||h" "SFTP link...||n" "Panelize||z"
  "---"
  "Rescan|C-r|R"
)
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
MENU_Right=(
  "File listing||g" "Quick view|C-x q|Q" "Info|C-x i|I" "Tree||T"
  "---"
  "Listing format...||L" "Sort order...||S" "Filter...||F" "Encoding...|M-e|E"
  "---"
  "FTP link...||P" "Shell link...||h" "SFTP link...||n" "Panelize||z"
  "---"
  "Rescan|C-r|R"
)
menu_open=0      # menu bar visible
menu_bar_sel=0   # highlighted bar item
menu_dd=0        # dropdown open
menu_sel=0       # selected item (index over real, non-separator items)
MC_MOUSE_IDX=-1  # panel entry hit by the last mouse event
MC_MOUSE_MENU=-1 # menu bar item hit by the last mouse event
MC_MOUSE_CHOOSE=0
MC_MOUSE_DRAG=0

# ------------------------------------------------------------------ helpers
hum_bytes() { # bytes -> human
  local b=$1
  if (( b >= 1024 )); then printf '%dK' "$(( (b + 1023) / 1024 ))"
  else printf '%d B' "$b"; fi
}

selection_summary() { # p -> SEL_SUMMARY
  local p=$1
  local -n RR=REALS_$p SS=SIZES_$p SELARR=SELSET_$p
  local i cnt=0 bytes=0
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    if [[ -n ${SELARR[${RR[$i]}]:-} ]]; then
      cnt=$(( cnt + 1 ))
      bytes=$(( bytes + ${SS[$i]:-0} ))
    fi
  done
  if (( cnt == 0 )); then
    SEL_SUMMARY=""
  else
    local files="files"; (( cnt == 1 )) && files="file"
    SEL_SUMMARY="$(hum_bytes "$bytes") in $cnt $files"
  fi
}

hum() { # kb -> human
  local kb=$1
  if (( kb >= 10240 * 1024 )); then printf '%dG' "$(( (kb + 524288) / 1048576 ))"
  elif (( kb >= 1024 )); then printf '%dM' "$(( (kb + 512) / 1024 ))"
  else printf '%dK' "$kb"; fi
}

# MC time column: "MON  DD  YYYY" for files older than ~6 months, else
# "MON  DD HH:MM". NOW_Y/NOW_MO are set by list_dir before use.
fmt_mtime() { # y mo dd h mi
  local y=$1 mo=$2 dd=$3 h=$4 mi=$5
  local age=$(( (NOW_Y - 10#$y) * 12 + (NOW_MO - 10#$mo) ))
  if (( age >= 6 )); then
    printf '%s %2d  %s' "${MO[$((10#$mo - 1))]}" "$((10#$dd))" "$((10#$y))"
  else
    printf '%s %2d %s:%s' "${MO[$((10#$mo - 1))]}" "$((10#$dd))" "$h" "$mi"
  fi
}

update_free() { # p
  local p=$1
  local total_kb avail_kb fstr="no info"
  read -r _ total_kb _ avail_kb _ _ <<< "$(df -P -k "${DIR[$p]}" 2>/dev/null | tail -1)"
  if [[ -n ${total_kb:-} ]]; then
    fstr="$(hum "$avail_kb") / $(hum "$total_kb") ($(( avail_kb * 100 / total_kb ))%)"
  fi
  FREE[$p]=$fstr
}

# list a directory into the panel's arrays; ".." is always entry 0
list_dir() {
  local p=$1
  local -n NN=NAMES_$p TT=TYPES_$p SS=SIZES_$p TM=TIMES_$p RR=REALS_$p XX=EXEC_$p
  local d=${DIR[$p]}
  d=$(cd "$d" 2>/dev/null && pwd) || d="$HOME"
  # record the directory in the history (most-recent-first, deduped, capped).
  # Always run: list_dir is the choke point every directory change flows
  # through, and DIR[$p] is already the new path by the time we get here.
  local -a nh=("$d") e
  for e in "${DIRHIST[@]}"; do [[ $e != "$d" ]] && nh+=("$e"); done
  (( ${#nh[@]} > 50 )) && nh=("${nh[@]:0:50}")
  DIRHIST=("${nh[@]}")
  DIR[$p]=$d
  update_free "$p"
  local now; now=$(date +%Y%-m); NOW_Y=${now:0:4}; NOW_MO=$((10#${now:4}))

  local SEP=$'\037'
  local -a find_args=(. -mindepth 1 -maxdepth 1)
  (( HIDE[$p] )) && find_args+=(! -name '.*')
  if [[ -n ${FILTERS[$p]} ]]; then find_args+=(-name "${FILTERS[$p]}"); fi
  local fmt='%y'"$SEP"'%s'"$SEP"'%m'"$SEP"'%TY'"$SEP"'%Tm'"$SEP"'%Td'"$SEP"'%TH'"$SEP"'%TM'"$SEP"'%f\n'
  local out sorted
  out=$( (cd "$d" 2>/dev/null && find "${find_args[@]}" -printf "$fmt") 2>/dev/null )

  sorted=""
  if [[ -n $out ]]; then
    sorted=$(
      awk -F"$SEP" -v OFS="$SEP" \
        -v now_y="$NOW_Y" -v now_mo="$NOW_MO" \
        -v sort_mode="${SORT[$p]}" \
        -v months='jan,feb,mars,apr,maj,juni,juli,aug,sep,okt,nov,dec' '
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
          tm=fmt_time(y, mo, dd, h, mi)
          tk=sprintf("%04d%02d%02d%02d%02d", y, mo, dd, h+0, mi+0)
          group=(t == "d") ? "0" : "1"
          if (sort_mode == "size") key=sprintf("%020s", s)
          else if (sort_mode == "date") key=tk
          else key=name
          print group, key, disp, t, s, tm, name, ex
        }
      ' <<< "$out" | LC_ALL=C sort -t"$SEP" -k1,1 $( (( REV[$p] )) && echo "-k2,2r" || echo "-k2,2" )
    )
  fi

  # ".." parent entry, always first
  local pd parent_time="-"
  pd=$( (cd "$(dirname "$d")" 2>/dev/null && find . -maxdepth 0 -printf '%TY|%Tm|%Td|%TH|%TM') 2>/dev/null )
  if [[ -n $pd ]]; then
    local y mo dd h mi
    IFS='|' read -r y mo dd h mi <<< "$pd"
    parent_time=$(fmt_mtime "$y" "$mo" "$dd" "$h" "$mi")
  fi

  local -a f_nn=() f_tt=() f_ss=() f_tm=() f_rr=() f_xx=()
  f_nn+=("/.."); f_tt+=(d); f_ss+=("UP--DIR"); f_tm+=("$parent_time"); f_rr+=(".."); f_xx+=(0)
  if [[ -n $sorted ]]; then
    local group key disp t s tm name ex
    while IFS="$SEP" read -r group key disp t s tm name ex; do
      f_nn+=("$disp"); f_tt+=("$t"); f_ss+=("$s")
      f_tm+=("$tm"); f_rr+=("$name"); f_xx+=("$ex")
    done <<< "$sorted"
  fi
  local i
  for (( i = 1; i < ${#f_nn[@]}; i++ )); do
    if [[ ${f_tt[$i]} == l && ! -e "$d/${f_rr[$i]}" ]]; then
      f_nn[$i]="!${f_rr[$i]}"
    fi
  done
  NN=("${f_nn[@]}"); TT=("${f_tt[@]}"); SS=("${f_ss[@]}")
  TM=("${f_tm[@]}"); RR=("${f_rr[@]}"); XX=("${f_xx[@]}")
  case $p in
    0) SELSET_0=() ;;
    1) SELSET_1=() ;;
  esac
  POS[$p]=0; OFF[$p]=0
}

# Refresh panel p without throwing away its selection/current entry. If
# new_real is supplied, move the cursor to that entry afterwards.
refresh_panel_keep() { # p [new_real]
  local p=$1 new=${2:-}
  local -n RR=REALS_$p SELARR=SELSET_$p
  local cur=${RR[${POS[$p]}]:-}
  local -a oldsel=("${!SELARR[@]}")
  list_dir "$p"
  local k i
  for k in "${oldsel[@]}"; do
    for i in "${!RR[@]}"; do
      if [[ ${RR[$i]} == "$k" ]]; then SELARR[$k]=1; break; fi
    done
  done
  local target=$new
  [[ -z $target ]] && target=$cur
  if [[ -n $target ]]; then
    for i in "${!RR[@]}"; do
      if [[ ${RR[$i]} == "$target" ]]; then POS[$p]=$i; break; fi
    done
  fi
}

# Swap the two panels' contents (mc "Swap panels", C-u). The active panel
# follows its content to the other side, so CUR is toggled as well. The
# position-bound windows (WIN/PANEL) are left in place.
_swap_panel_arr() { # base name of NAMES_/TYPES_/SIZES_/TIMES_/REALS_/EXEC_
  local -n _sp0="${1}_0" _sp1="${1}_1"
  local -a _sp=("${_sp0[@]}")
  _sp0=("${_sp1[@]}"); _sp1=("${_sp[@]}")
}
_swap_panel_assoc() { # base name of SELSET_
  local -n _sa0="${1}_0" _sa1="${1}_1"
  local -A _sa=()
  local k
  for k in "${!_sa0[@]}"; do _sa[$k]=${_sa0[$k]}; done
  _sa0=()
  for k in "${!_sa1[@]}"; do _sa0[$k]=${_sa1[$k]}; done
  _sa1=()
  for k in "${!_sa[@]}"; do _sa1[$k]=${_sa[$k]}; done
}
_swap_panel_idx() { # assoc array indexed [0]/[1]
  local -n _si="$1"
  local _t=${_si[0]}; _si[0]=${_si[1]}; _si[1]=$_t
}
do_swap_panels() {
  local f
  for f in NAMES TYPES SIZES TIMES REALS EXEC; do _swap_panel_arr "$f"; done
  _swap_panel_assoc SELSET
  for f in DIR POS OFF SORT REV HIDE FILTERS FREE; do _swap_panel_idx "$f"; done
  CUR=$(( 1 - CUR ))
}

type_color() { # p idx -> pair (assumes not the current/highlighted row)
  # Colour the whole entry by type, like mc: directory bright white, regular
  # file yellow, executable bright green (symlinks/specials bright white).
  local p=$1 i=$2
  local -n TT=TYPES_$p XX=EXEC_$p NN=NAMES_$p
  local t=${TT[$i]}
  case $t in
    d) echo 2 ;;
    l) if [[ ${NN[$i]} == '!'* ]]; then echo 35; else echo 4; fi ;;
    c|b|p|s) echo 5 ;;
    *)  if (( XX[$i] )); then echo 3; else echo 11; fi ;;
  esac
}

# ------------------------------------------------------------------ drawing
name_width() { # w -> name column width
  local w=$1
  local nw=$(( w - SIZEW - TIMEW - 4 ))
  (( nw < 4 )) && nw=4
  echo "$nw"
}

draw_panel() {
  local p=$1
  local -n NN=NAMES_$p SS=SIZES_$p TM=TIMES_$p TT=TYPES_$p RR=REALS_$p SELARR=SELSET_$p
  local win=${WIN[$p]}
  local w h
  getmaxyx "$win"; h=$BC_GMY; w=$BC_GMX
  local off=${OFF[$p]} pos=${POS[$p]} cnt=${#NN[@]}
  local rows=$(( h - 5 ))
  if (( pos < off )); then off=$pos; fi
  if (( pos >= off + rows )); then off=$(( pos - rows + 1 )); fi
  (( off < 0 )) && off=0
  OFF[$p]=$off

  local active=0; (( p == CUR )) && active=1
  local bp; (( active )) && bp=7 || bp=8

  wbkgd "$win" ' ' 0 7
  werase "$win"
  wattrset "$win" 0 "$bp"
  box "$win"

  # top border: <- path ---- . >
  local path=${DIR[$p]}
  local dp=$path
  if [[ $path == "$HOME" ]]; then dp="~"
  elif [[ $path == "$HOME"/* ]]; then dp="~${path#"$HOME"}"
  fi
  local maxpath=$(( w - 12 ))
  if (( maxpath < 6 )); then maxpath=6; fi
  if (( ${#dp} > maxpath )); then
    dp="...${dp: -$(( maxpath - 3 ))}"
  fi
  local top="<─ ${dp:0:$maxpath} "
  local fill=$(( w - 2 - ${#top} - 5 ))
  (( fill < 0 )) && fill=0
  _repeat dstr '─' "$fill"
  top+="$dstr.[^]>"
  top=${top:0:$(( w - 2 ))}
  mvwaddstr "$win" 0 1 "$top"
  # path highlight (pair 13, black-on-white) covers the path plus one space on
  # each side; only the active panel gets it (the inactive path stays border
  # color), matching real MC
  if (( active && ! menu_open )); then
    wattrset "$win" 0 13
    mvwaddstr "$win" 0 3 " ${dp:0:$maxpath} "
  fi

  # header row: blue bg like the panel; column titles in bright yellow (pair 12),
  # inner dividers and the left border in white (pair 7 / border color).
  local NAMEW
  NAMEW=$(name_width "$w")
  local SD=$(( 1 + NAMEW ))
  local skey ind
  case ${SORT[$p]} in size) skey=s ;; date) skey=d ;; *) skey=n ;; esac
  if (( REV[$p] )); then ind="^$skey"; else ind=".$skey"; fi
  local hname hsize htime
  hname=$(printf '%-12sName%*s' "$ind" "$(( NAMEW - 16 ))" "")
  hsize=$(printf ' Size%*s' "$(( SIZEW - 5 ))" "")
  htime=$(printf 'Modify time%*s' "$(( TIMEW - 11 ))" "")
  wattrset "$win" 0 "$bp"
  mvwaddch "$win" 1 0 "│"
  wattrset "$win" 0 12
  mvwaddstr "$win" 1 1 "$hname"
  wattrset "$win" 0 7
  mvwaddch "$win" 1 "$SD" "│"
  wattrset "$win" 0 12
  mvwaddstr "$win" 1 $(( SD + 1 )) "$hsize"
  wattrset "$win" 0 7
  mvwaddch "$win" 1 $(( SD + SIZEW + 1 )) "│"
  wattrset "$win" 0 12
  mvwaddstr "$win" 1 $(( SD + SIZEW + 2 )) "$htime"
  wattrset "$win" 0 7
  mvwaddch "$win" 1 $(( SD + SIZEW + TIMEW + 2 )) "│"

  # entry rows: │ dividers keep the border color, entry text uses its type color;
  # the selected row (active panel only) is a full cyan strip in black.
  local y idx cpair row
  for (( y = 0; y < rows; y++ )); do
    idx=$(( off + y ))
    (( idx >= cnt )) && break
    row=$(( y + 2 ))
    if (( idx == pos && active && ! menu_open )); then
      # interior (cols 1..w-2) is a cyan strip; selected entries keep their
      # bright-yellow text, unselected entries use black text.
      local apair=6
      [[ -n ${SELARR[${RR[$idx]}]:-} ]] && apair=34
      wmove "$win" "$row" 1
      wchgat "$win" $(( w - 2 )) 0 "$apair"
      wattrset "$win" 0 "$apair"
      mvwaddstr "$win" "$row" 1 "$(printf '%-*s' "$NAMEW" "${NN[$idx]}")"
      wattrset "$win" 0 6
      mvwaddch "$win" "$row" "$SD" "│"
      wattrset "$win" 0 "$apair"
      mvwaddstr "$win" "$row" $(( SD + 1 )) "$(printf '%*s' "$SIZEW" "${SS[$idx]}")"
      wattrset "$win" 0 6
      mvwaddch "$win" "$row" $(( SD + SIZEW + 1 )) "│"
      wattrset "$win" 0 "$apair"
      mvwaddstr "$win" "$row" $(( SD + SIZEW + 2 )) "$(printf '%-*s' "$TIMEW" "${TM[$idx]}")"
    else
      cpair=$(type_color "$p" "$idx")
      if [[ -n ${SELARR[${RR[$idx]}]:-} ]]; then cpair=31; fi
      wattrset "$win" 0 "$cpair"
      mvwaddstr "$win" "$row" 1 "$(printf '%-*s' "$NAMEW" "${NN[$idx]}")"
      wattrset "$win" 0 7
      mvwaddch "$win" "$row" "$SD" "│"
      wattrset "$win" 0 "$cpair"
      mvwaddstr "$win" "$row" $(( SD + 1 )) "$(printf '%*s' "$SIZEW" "${SS[$idx]}")"
      wattrset "$win" 0 7
      mvwaddch "$win" "$row" $(( SD + SIZEW + 1 )) "│"
      wattrset "$win" 0 "$cpair"
      mvwaddstr "$win" "$row" $(( SD + SIZEW + 2 )) "$(printf '%-*s' "$TIMEW" "${TM[$idx]}")"
      wattrset "$win" 0 7
      mvwaddch "$win" "$row" $(( SD + SIZEW + TIMEW + 2 )) "│"
    fi
  done

  # inner column dividers on the empty rows below the listing (MC draws them)
  local ey
  for (( ey = 0; ey < rows; ey++ )); do
    if (( off + ey >= cnt )); then
      row=$(( ey + 2 ))
      wattrset "$win" 0 7
      mvwaddch "$win" "$row" "$SD" "│"
      mvwaddch "$win" "$row" $(( SD + SIZEW + 1 )) "│"
    fi
  done

  # separator, status, bottom
  local sy=$(( h - 3 ))
  wattrset "$win" 0 "$bp"
  mvwaddch "$win" "$sy" 0 "$ACS_LTEE"
  selection_summary "$p"
  local inside=$(( w - 2 ))
  if [[ -n $SEL_SUMMARY ]]; then
    local slen=${#SEL_SUMMARY}
    if (( slen + 2 <= inside )); then
      local lft=$(( (inside - slen - 2) / 2 ))
      local rgt=$(( inside - 2 - lft - slen ))
      (( lft < 0 )) && lft=0
      (( rgt < 0 )) && rgt=0
      _repeat ld '─' "$lft"
      _repeat rd '─' "$rgt"
      wattrset "$win" 0 "$bp"
      mvwaddstr "$win" "$sy" 1 "$ld"
      wattrset "$win" 0 12
      mvwaddstr "$win" "$sy" $(( 1 + lft )) " ${SEL_SUMMARY} "
      wattrset "$win" 0 "$bp"
      mvwaddstr "$win" "$sy" $(( 1 + lft + slen + 2 )) "$rd"
    else
      mvwhline "$win" "$sy" 1 "$ACS_HLINE" "$inside"
    fi
  else
    mvwhline "$win" "$sy" 1 "$ACS_HLINE" "$inside"
  fi
  mvwaddch "$win" "$sy" "$(( w - 1 ))" "$ACS_RTEE"

  # status row names the selected entry (its listing name, with type prefix),
  # or UP--DIR for the parent entry.
  local status
  if (( pos == 0 )); then
    status="UP--DIR"
  else
    status=${NN[$pos]}
  fi
  wattrset "$win" 0 7
  mvwprintw "$win" "$(( h - 2 ))" 1 '%s' "${status:0:$(( w - 2 ))}"

  local fstr=${FREE[$p]}
  [[ -z $fstr ]] && fstr="no info"
  local blen=${#fstr} rd=1 left
  left=$(( w - 5 - blen ))
  (( left < 0 )) && left=0
  _repeat ld '─' "$left"
  _repeat rdstr '─' "$rd"
  wattrset "$win" 0 7
  mvwaddstr "$win" "$(( h - 1 ))" 1 "$ld $fstr $rdstr"
}

  draw_menu() {
   local i full
  _repeat full ' ' "$COLS"
  if (( menu_open )); then
    # Open state: bright-white-on-cyan (16); mnemonic bright-yellow (17); the
    # selected item inverted to white-on-black (18), mnemonic (19).
    wattrset 0 0 16
    mvwaddstr 0 0 0 "$full"
    for (( i = 0; i < ${#MENUNAMES[@]}; i++ )); do
      local name=${MENUNAMES[$i]} x=${MENU_X[$i]}
      local mn=${name:0:1} rest=${name:1}
      if (( i == menu_bar_sel )); then
        wattrset 0 0 18; mvwaddstr 0 0 "$(( x - 1 ))" " "
        wattrset 0 0 19; mvwaddstr 0 0 "$x" "$mn"
        wattrset 0 0 18; mvwaddstr 0 0 "$(( x + 1 ))" "$rest"
        wattrset 0 0 18; mvwaddstr 0 0 "$(( x + ${#name} ))" " "
      else
        wattrset 0 0 17; mvwaddstr 0 0 "$x" "$mn"
        wattrset 0 0 16; mvwaddstr 0 0 "$(( x + 1 ))" "$rest"
      fi
    done
  else
    # Closed state: the whole bar is uniform black-on-cyan (22).
    wattrset 0 0 22
    mvwaddstr 0 0 0 "$full"
    for (( i = 0; i < ${#MENUNAMES[@]}; i++ )); do
      mvwaddstr 0 0 "${MENU_X[$i]}" "${MENUNAMES[$i]}"
    done
  fi
}

# The dropdown is its own top panel window so it composites over the file
# panels (stdscr is below them). Geometry + per-row data are cached so only the
# changed rows need redrawing during navigation.
MENU_WIN=0; MENU_PANEL=0; MENU_GX=0; MENU_GY=0; MENU_GW=0; MENU_GH=0
MENU_INNER=0; MENU_MAXSC=0; MENU_BW=0; MENU_TOP=0; MENU_VIS=0
MENU_NROWS=0; MENU_SELROW=0

# Build the dropdown row list (each "SEP" or an item string) + geometry for
# the current bar entry, and the row index of the selected item.
menu_dd_prep() { # bar_sel
  local name=${MENUNAMES[$1]}
  local -n MI="MENU_${name}"
  local maxlen=0 maxsc=0 lab sc e
  for e in "${MI[@]}"; do
    if [[ $e == --- ]]; then continue; fi
    lab=${e%%|*}; sc=${e#*|}; sc=${sc%|*}
    (( ${#lab} > maxlen )) && maxlen=${#lab}
    (( ${#sc} > maxsc )) && maxsc=${#sc}
  done
  MENU_INNER=$(( 1 + maxlen + 2 + maxsc ))
  MENU_MAXSC=$maxsc
  MENU_BW=$(( MENU_INNER + 2 ))
  MENU_GX=$(( MENU_X[$1] - 2 )); (( MENU_GX < 0 )) && MENU_GX=0
  (( MENU_GX + MENU_BW > COLS )) && MENU_GX=$(( COLS - MENU_BW ))
  MENU_GY=1
  MENU_VIS=$(( ${CMY:-$(( ${HINTY:-0} + 1 ))} - 4 )); (( MENU_VIS < 1 )) && MENU_VIS=1
  local -a rows=()
  local r=0 ri=0 selrow=-1
  for e in "${MI[@]}"; do
    if [[ $e == --- ]]; then
      rows+=("SEP")
    else
      rows+=("$e")
      (( ri == menu_sel )) && selrow=$r
      (( ri++ ))
    fi
    (( r++ ))
  done
  MENU_ROWS=("${rows[@]}")
  MENU_NROWS=${#rows[@]}
  MENU_SELROW=$selrow
}

# Draw one dropdown item at window row $1, selected (1) / not ($2).
menu_dd_row() { # displayrow sel item
  local row=$1 sel=$2 e=$3
  local lab=${e%%|*} mnem=${e##*|}
  local sc=${e#*|}; sc=${sc%|*}
  local tp tp2 sp mpos=-1 i lc letter
  tp=$(( sel ? 18 : 16 )); tp2=$(( sel ? 19 : 17 ))
  if [[ $mnem == *:* ]]; then
    letter=${mnem%%:*}
    mpos=${mnem##*:}
  else
    letter=$mnem
    for (( i = 0; i < ${#lab}; i++ )); do
      lc=${lab:i:1}
      [[ -n $letter && $lc == "$letter" ]] && { mpos=$i; break; }
    done
  fi
  (( mpos < 0 )) && mpos=0
  _repeat sp ' ' "$MENU_INNER"
  wattrset "$MENU_WIN" 0 16;      mvwaddstr "$MENU_WIN" "$row" 0 "│"
  wattrset "$MENU_WIN" 0 "$tp";   mvwaddstr "$MENU_WIN" "$row" 1 "$sp"
  wattrset "$MENU_WIN" 0 "$tp";   mvwaddstr "$MENU_WIN" "$row" 2 "${lab:0:mpos}"
  wattrset "$MENU_WIN" 0 "$tp2";  mvwaddstr "$MENU_WIN" "$row" $(( 2 + mpos )) "${lab:mpos:1}"
  wattrset "$MENU_WIN" 0 "$tp";   mvwaddstr "$MENU_WIN" "$row" $(( 3 + mpos )) "${lab:mpos+1}"
  [[ -n $sc ]] && { wattrset "$MENU_WIN" 0 "$tp"; mvwaddstr "$MENU_WIN" "$row" $(( MENU_INNER - MENU_MAXSC + 1 )) "$sc"; }
  wattrset "$MENU_WIN" 0 16; mvwaddstr "$MENU_WIN" "$row" $(( MENU_INNER + 1 )) "│"
}

# Draw a separator line at window row $1.
menu_dd_sep() { # displayrow
  local row=$1 mid
  _repeat mid '─' "$(( MENU_BW - 2 ))"; mid="├${mid}┤"
  wattrset "$MENU_WIN" 0 16
  mvwaddstr "$MENU_WIN" "$row" 0 "$mid"
}

# Repaint the MC-style black shadow around the dropdown without changing the
# underlying panel characters.
menu_dd_shadow() {
  local pair=32 p win px wx wy x y

  local r0=$(( MENU_GY + 1 )) r1=$(( MENU_GY + MENU_GH - 1 ))
  local c0=$(( MENU_GX + MENU_BW ))
  local c1=$(( c0 + 1 ))
  local br=$(( MENU_GY + MENU_GH ))
  local bc0=$(( MENU_GX + 2 ))
  local bc1=$(( MENU_GX + MENU_BW + 1 ))
  for p in 0 1; do
    win=${WIN[$p]}
    (( win == 0 )) && continue
    px=$(( p == 0 ? 0 : PW ))
    for (( y = r0; y <= r1; y++ )); do
      wy=$(( y - 1 ))
      (( wy < 0 || wy >= PH )) && continue
      for (( x = c0; x <= c1; x++ )); do
        wx=$(( x - px ))
        (( wx < 0 || wx >= PW )) && continue
        wmove "$win" "$wy" "$wx" && wchgat "$win" 1 0 "$pair"
      done
    done
    wy=$(( br - 1 ))
    (( wy >= 0 && wy < PH )) || continue
    for (( x = bc0; x <= bc1; x++ )); do
      wx=$(( x - px ))
      (( wx < 0 || wx >= PW )) && continue
      wmove "$win" "$wy" "$wx" && wchgat "$win" 1 0 "$pair"
    done
  done
}

# Open (fully draw) the dropdown, scrolling so the selected item is visible.
menu_dd_open() {
  menu_dd_prep "$menu_bar_sel"
  local nshow=$(( MENU_NROWS < MENU_VIS ? MENU_NROWS : MENU_VIS ))
  local top=$MENU_TOP
  (( top < 0 )) && top=0
  (( top > MENU_NROWS - nshow )) && top=$(( MENU_NROWS - nshow ))
  (( MENU_SELROW >= 0 )) && {
    (( MENU_SELROW < top )) && top=$MENU_SELROW
    (( MENU_SELROW >= top + nshow )) && top=$(( MENU_SELROW - nshow + 1 ))
  }
  (( top < 0 )) && top=0
  MENU_TOP=$top
  local gh=$(( nshow + 2 ))
  MENU_GH=$gh
  if (( MENU_WIN > 0 )); then
    del_panel "$MENU_PANEL" 2>/dev/null; delwin "$MENU_WIN"
    MENU_WIN=0; MENU_PANEL=0
  fi
  newwin "$gh" "$MENU_BW" "$MENU_GY" "$MENU_GX"; MENU_WIN=$bc_win
  new_panel "$MENU_WIN"; MENU_PANEL=$bc_panel
  wattrset "$MENU_WIN" 0 16
  werase "$MENU_WIN"
  local topb botb
  _repeat topb '─' "$(( MENU_BW - 2 ))"; topb="┌${topb}┐"
  _repeat botb '─' "$(( MENU_BW - 2 ))"; botb="└${botb}┘"
  mvwaddstr "$MENU_WIN" 0 0 "$topb"
  local i drow e
  for (( i = top; i < top + nshow; i++ )); do
    e=${MENU_ROWS[$i]}
    drow=$(( i - top + 1 ))
    if [[ $e == SEP ]]; then menu_dd_sep "$drow"
    else menu_dd_row "$drow" $(( i == MENU_SELROW ? 1 : 0 )) "$e"; fi
  done
  mvwaddstr "$MENU_WIN" "$(( gh - 1 ))" 0 "$botb"
  menu_dd_shadow
}

menu_dd_close() {
  (( MENU_WIN > 0 )) && { del_panel "$MENU_PANEL" 2>/dev/null; delwin "$MENU_WIN"; }
  MENU_WIN=0; MENU_PANEL=0
}

redraw_hint() { # bottom hint line, context-dependent like real MC
  [[ ${HINTBAR:-1} == 0 ]] && return
  local clear hint
  _repeat clear ' ' "$COLS"
  clear=${clear:1}
  if [[ -n $CMD_LINE ]]; then
    hint="To change directory halfway through typing a command, use M-c."
  elif [[ -n $HINT_TEXT ]]; then
    hint=$HINT_TEXT
  else
    hint="Tab changes your current panel."
  fi
  wattrset 0 0 0
  mvwaddstr 0 "$HINTY" 0 "$clear"
  mvwaddstr 0 "$HINTY" 0 "Hint: $hint"
}

draw_buttonbar() { # 10 button labels (empty allowed); number always, label if set
  local -a bl=("$@")
  local clear x=0 num last=$(( ${#bl[@]} - 1 )) n
  _repeat clear ' ' "$COLS"
  clear=${clear:1}
  # bright-white numbers on black, black labels on cyan
  wattrset 0 0 0
  mvwaddstr 0 "$BTNY" 0 "$clear"
  for num in "${!bl[@]}"; do
    printf -v n '%2d' "$(( num + 1 ))"
    wattrset 0 0 15
    mvwaddstr 0 "$BTNY" "$x" "$n"
    wattrset 0 0 6
    if (( num == last )); then
      mvwaddstr 0 "$BTNY" "$(( x + 2 ))" "${bl[$num]}"
    else
      mvwaddstr 0 "$BTNY" "$(( x + 2 ))" "$(printf '%-8s' "${bl[$num]}")"
    fi
    x=$(( x + 10 ))
  done
}

draw_bottom() {
  local clear
  _repeat clear ' ' "$COLS"
  clear=${clear:1}
  # hint: default colors (context-dependent)
  redraw_hint
  # command line: default colors, ~ abbreviated path
  wattrset 0 0 40
  mvwaddstr 0 "$CMY" 0 "$clear"
  local cwd=${DIR[$CUR]}
  local scwd=$cwd
  if [[ $cwd == "$HOME" ]]; then scwd="~"
  elif [[ $cwd == "$HOME"/* ]]; then scwd="~${cwd#"$HOME"}"
  fi
  local prompt="${USER:-$(whoami)}@${HOSTNAME%%.*}:${scwd}\$ "
  mvwaddstr 0 "$CMY" 0 "$prompt"
  mvwaddstr 0 "$CMY" "${#prompt}" "$CMD_LINE"
  # MC draws a fixed [^] cursor marker at the far right of the command line
  wattrset 0 0 7
  mvwaddstr 0 "$CMY" "$(( COLS - 3 ))" "[^]"
  draw_buttonbar Help Menu View Edit Copy RenMov Mkdir Delete PullDn Quit
}

draw_all() {
  draw_panel 0
  draw_panel 1
  draw_bottom
  draw_menu
}

# redraw one list row of panel p (list index idx) in place; hl highlights it.
# Mirrors the per-row body of draw_panel so a single row can be patched without
# re-rendering the whole panel.
draw_entry_row() { # p idx hl
  local p=$1 idx=$2 hl=$3
  local -n NN=NAMES_$p SS=SIZES_$p TM=TIMES_$p
  local win=${WIN[$p]} off=${OFF[$p]}
  local w h row
  getmaxyx "$win"; h=$BC_GMY; w=$BC_GMX
  row=$(( idx - off + 2 ))
  (( row < 2 )) && return
  local NAMEW SD cpair
  NAMEW=$(name_width "$w")
  SD=$(( 1 + NAMEW ))
  if (( hl )); then
    # interior only; border columns keep the border color drawn by box()
    wmove "$win" "$row" 1
    wchgat "$win" $(( w - 2 )) 0 6
    wattrset "$win" 0 6
    mvwaddstr "$win" "$row" 1 "$(printf '%-*s' "$NAMEW" "${NN[$idx]}")"
    mvwaddch "$win" "$row" "$SD" "│"
    mvwaddstr "$win" "$row" $(( SD + 1 )) "$(printf '%*s' "$SIZEW" "${SS[$idx]}")"
    mvwaddch "$win" "$row" $(( SD + SIZEW + 1 )) "│"
    mvwaddstr "$win" "$row" $(( SD + SIZEW + 2 )) "$(printf '%-*s' "$TIMEW" "${TM[$idx]}")"
  else
    wmove "$win" "$row" 1
    wchgat "$win" $(( w - 2 )) 0 7
    cpair=$(type_color "$p" "$idx")
    wattrset "$win" 0 "$cpair"
    mvwaddstr "$win" "$row" 1 "$(printf '%-*s' "$NAMEW" "${NN[$idx]}")"
    wattrset "$win" 0 7
    mvwaddch "$win" "$row" "$SD" "│"
    wattrset "$win" 0 "$cpair"
    mvwaddstr "$win" "$row" $(( SD + 1 )) "$(printf '%*s' "$SIZEW" "${SS[$idx]}")"
    wattrset "$win" 0 7
    mvwaddch "$win" "$row" $(( SD + SIZEW + 1 )) "│"
    wattrset "$win" 0 "$cpair"
    mvwaddstr "$win" "$row" $(( SD + SIZEW + 2 )) "$(printf '%-*s' "$TIMEW" "${TM[$idx]}")"
  fi
}

# Cheap in-place update after a selection move that did not scroll the window:
# patch the old and new selection rows plus the panel status row, then wrefresh
# only that panel. Returns 0 on success, 1 when a full redraw is required.
update_selection() { # p oldpos
  local p=$1 oldpos=$2
  local win=${WIN[$p]}
  local off=${OFF[$p]}
  local w h rows newpos
  getmaxyx "$win"; h=$BC_GMY; w=$BC_GMX
  rows=$(( h - 5 ))
  newpos=${POS[$p]}
  (( oldpos < off || oldpos >= off + rows )) && return 1
  (( newpos < off || newpos >= off + rows )) && return 1
  (( oldpos != newpos )) && draw_entry_row "$p" "$oldpos" 0
  draw_entry_row "$p" "$newpos" 1
  local -n NN=NAMES_$p
  local status statusline
  # status row names the selected entry (its listing name, with type prefix),
  # or UP--DIR for the parent entry -- same as draw_panel.
  if (( newpos == 0 )); then
    status="UP--DIR"
  else
    status=${NN[$newpos]}
  fi
  wattrset "$win" 0 7
  printf -v statusline '%-*s' "$(( w - 2 ))" "$status"
  mvwaddstr "$win" "$(( h - 2 ))" 1 "$statusline"
  wrefresh "$win"
  return 0
}

# redraw just the top border row (path + active path-highlight) of panel p.
# The rest of the frame -- box, header, separator -- uses pairs 7/8, which render
# identically, so it never changes when the active panel switches and is left alone.
draw_panel_top() { # p
  local p=$1
  local win=${WIN[$p]} w active=0 bp path dp top fill dstr
  getmaxyx "$win"; w=$BC_GMX
  (( p == CUR )) && active=1
  (( active )) && bp=7 || bp=8
  path=${DIR[$p]}; dp=$path
  if [[ $path == "$HOME" ]]; then dp="~"
  elif [[ $path == "$HOME"/* ]]; then dp="~${path#"$HOME"}"
  fi
  top="<─ ${dp:0:$(( w - 8 ))} "
  fill=$(( w - 2 - ${#top} - 5 )); (( fill < 0 )) && fill=0
  _repeat dstr '─' "$fill"
  top+="$dstr.[^]>"; top=${top:0:$(( w - 2 ))}
  wattrset "$win" 0 "$bp"
  mvwaddstr "$win" 0 1 "$top"
  (( active )) && { wattrset "$win" 0 13; mvwaddstr "$win" 0 3 " ${dp:0:$(( w - 8 ))} "; }
}

# Tab / left / right switch the active panel. Only three things change: the two
# top-border path highlights, the two selection strips, and the command-line
# prompt. Redraw just those and refresh -- no df fork, no full-panel row loops.
switch_panel() { # old_cur : CUR is already the newly-active panel
  local old_cur=$1
  draw_panel_top 0
  draw_panel_top 1
  draw_entry_row "$old_cur" "${POS[$old_cur]}" 0
  draw_entry_row "$CUR" "${POS[$CUR]}" 1
  draw_cmdline
  # Refresh only the windows that changed (cmdline on stdscr + the two panels).
  # Using wrefresh/refresh keeps it to the dirty cells; doupdate would re-flush
  # stdscr over the whole panel region and force a full-screen redraw.
  refresh
  wrefresh "${WIN[0]}"
  wrefresh "${WIN[1]}"
}

# fold any navigation keys already buffered (e.g. a held-down arrow) into a
# single POS step so one keypress batch triggers exactly one redraw.
drain_panel_nav() {
  local cur=$CUR
  local -n _NN=NAMES_$cur
  local max=$(( ${#_NN[@]} - 1 )); (( max < 0 )) && max=0
  local pg; pg=$(page_rows "$cur")
  local old=${BC_WDELAY[$BC_STDSCR]:-0}
  BC_WDELAY[$BC_STDSCR]=1
  local k
  while :; do
    wgetch "$BC_STDSCR" || break
    k=$key
    case $k in
      $KEY_UP)    (( POS[$cur] > 0 )) && POS[$cur]=$(( POS[$cur] - 1 )) ;;
      $KEY_DOWN)  (( POS[$cur] < max )) && POS[$cur]=$(( POS[$cur] + 1 )) ;;
      $KEY_HOME)  POS[$cur]=0 ;;
      $KEY_END)   POS[$cur]=$max ;;
      $KEY_PPAGE) POS[$cur]=$(( POS[$cur] - pg )); clamp_pos "$cur" ;;
      $KEY_NPAGE) POS[$cur]=$(( POS[$cur] + pg )); clamp_pos "$cur" ;;
      *)          ungetch "$key"; break ;;
    esac
  done
  BC_WDELAY[$BC_STDSCR]=$old
  clamp_pos "$cur"
  return 0
}

cmdline_prompt() {
  local cwd=${DIR[$CUR]}
  local scwd=$cwd
  if [[ $cwd == "$HOME" ]]; then scwd="~"
  elif [[ $cwd == "$HOME"/* ]]; then scwd="~${cwd#"$HOME"}"
  fi
  CMD_PROMPT="${USER:-$(whoami)}@${HOSTNAME%%.*}:${scwd}\$ "
}

draw_cmdline() {
  redraw_hint
  local clear
  _repeat clear ' ' "$COLS"
  clear=${clear:1}
  wattrset 0 0 40
  mvwaddstr 0 "$CMY" 0 "$clear"
  cmdline_prompt
  local prompt=$CMD_PROMPT
  (( CMD_CARET > ${#CMD_LINE} )) && CMD_CARET=${#CMD_LINE}
  (( CMD_CARET < 0 )) && CMD_CARET=0
  mvwaddstr 0 "$CMY" 0 "$prompt"
  mvwaddstr 0 "$CMY" "${#prompt}" "$CMD_LINE"
  wattrset 0 0 7
  mvwaddstr 0 "$CMY" "$(( COLS - 3 ))" "[^]"
  move "$CMY" "$(( ${#prompt} + CMD_CARET ))"
}

# ------------------------------------------------------------------ dialogs
dialog_box() { # w h title -> creates centered window, returns bc_win in $dw
  local w=$1 h=$2 title=$3
  local y=$(( (LINES - h) / 2 )) x=$(( (COLS - w) / 2 ))
  (( y < 1 )) && y=1; (( x < 1 )) && x=1
  newwin "$h" "$w" "$y" "$x"
  dw=$bc_win
  werase "$dw"; box "$dw"
  # title bar
  local tlen=${#title} tx
  tx=$(( (w - tlen) / 2 ))
  (( tx < 2 )) && tx=2
  wattrset "$dw" 1 9
  mvwhline "$dw" 0 1 "$ACS_HLINE" "$(( w - 2 ))"
  mvwaddstr "$dw" 0 "$tx" "$title"
  wattrset "$dw" 0 1
}

# ------------------------------------------------------------------ mc-style dialogs
# Paint a dialog shadow/highlight cell on whichever window covers the absolute
# screen cell, preserving the character that is already there.
mc_shadow_put() { # ay ax pair [ch]
  local ay=$1 ax=$2 pair=$3 ch=$4 w ry rx found=0
  for w in "${WIN[0]}" "${WIN[1]}"; do
    [[ -n ${BC_WY[$w]:-} ]] || continue
    if (( ay >= BC_WY[$w] && ay < BC_WY[$w] + BC_WH[$w] &&
          ax >= BC_WX[$w] && ax < BC_WX[$w] + BC_WW[$w] )); then
      ry=$(( ay - BC_WY[$w] )); rx=$(( ax - BC_WX[$w] ))
      mvwinch "$w" "$ry" "$rx"
      _bc_cell "$w" "$ay" "$ax" "$wch" "$wcha" "$wchp"
      [[ -z $ch ]] && ch=$wch
      found=1
      break
    fi
  done
  if (( ! found )); then
    mvwinch 0 "$ay" "$ax"
    [[ -z $ch ]] && ch=$wch
  fi
  mvwaddch 0 "$ay" "$ax" "$ch" 0 "$pair"
}

# A centered window with a colored frame and a centered title bar, matching
# Midnight Commander's modal dialogs. danger=1 uses the red (destructive)
# frame. Content is drawn on top afterwards. Sets the window id in $dw.
  mc_dialog() { # w h title danger [y] [fp] [tp]
    local w=$1 h=$2 title=$3 danger=${4:-0} yov=${5:-}
    (( w > COLS - 4 )) && w=$(( COLS - 4 ))
    (( h > LINES - 4 )) && h=$(( LINES - 4 ))
    # center in the panel listing area (below the menu bar, above the
    # separator/status/hint rows), matching mc rather than the whole screen
    local area=$(( LINES - 6 )); (( area < 1 )) && area=1
    local y=$(( 1 + (area - h) / 2 )) x=$(( (COLS - w) / 2 ))
    [[ -n $yov ]] && y=$yov
    (( y < 1 )) && y=1; (( x < 1 )) && x=1
   local fp tp
   (( danger )) && { fp=26; tp=27; } || { fp=23; tp=24; }
   [[ -n ${6:-} ]] && fp=$6
   [[ -n ${7:-} ]] && tp=$7
  newwin "$h" "$w" "$y" "$x"; dw=$bc_win
  local sy sx
  if (( y > 0 )); then
    for (( sx = x - 1; sx <= x + w && sx < COLS; sx++ )); do
      (( sx >= 0 )) && mc_shadow_put "$(( y - 1 ))" "$sx" "$fp" ' '
    done
  fi
  for (( sy = y - 1; sy <= y + h - 1; sy++ )); do
    (( sy >= 0 && x - 1 >= 0 )) && mc_shadow_put "$sy" "$(( x - 1 ))" "$fp" ' '
  done
  for (( sy = y; sy <= y + h; sy++ )); do
    (( sy < LINES && x + w < COLS )) && mc_shadow_put "$sy" "$(( x + w ))" "$fp" ' '
  done
  if (( y + h < LINES )); then
    for (( sx = x - 1; sx <= x + w && sx < COLS; sx++ )); do
      (( sx >= 0 )) && mc_shadow_put "$(( y + h ))" "$sx" "$fp" ' '
    done
  fi
  for (( sy = y; sy <= y + h; sy++ )); do
    (( sy < LINES )) && {
      (( x + w + 1 < COLS )) && mc_shadow_put "$sy" "$(( x + w + 1 ))" 32
      (( x + w + 2 < COLS )) && mc_shadow_put "$sy" "$(( x + w + 2 ))" 32
    }
  done
  if (( y + h + 1 < LINES )); then
    for (( sx = x + 1; sx <= x + w + 2 && sx < COLS; sx++ )); do
      mc_shadow_put "$(( y + h + 1 ))" "$sx" 32
    done
  fi
  wrefresh 0
  wattrset "$dw" 0 "$fp"
  wbkgdset "$dw" ' ' 0 "$fp"
  werase "$dw"; box "$dw"
  local tstr=" $title "
  local tlen=${#tstr}
  local tx=$(( (w - tlen) / 2 )); (( tx < 1 )) && tx=1
  wattrset "$dw" 0 "$tp"
  mvwaddstr "$dw" 0 "$tx" "$tstr"
  wattrset "$dw" 0 "$fp"
}

# Horizontal divider inside a dialog (pair 23 by default): row [pair].
dlg_divider() { # row [pair]
  local row=$1 pair=${2:-23} w; getmaxyx "$dw"; w=$BC_GMX
  wattrset "$dw" 0 "$pair"
  mvwhline "$dw" "$row" 1 "$ACS_HLINE" "$(( w - 2 ))"
  mvwaddch "$dw" "$row" 0 "$ACS_LTEE"
  mvwaddch "$dw" "$row" $(( w - 1 )) "$ACS_RTEE"
}

# Input field: cyan background (pair 25), bright-black text, and a completer
# Some fields (notably the Select pattern field) draw a completer button "[^]"
# (bright-white on blue, pair 28) at the right end. The focused field parks the
# hardware cursor at the caret position.
dlg_field() { # row col width text caret focused [button]
  local row=$1 col=$2 width=$3 text=$4 caret=$5 focused=$6 button=${7:-0}
  (( caret > ${#text} )) && caret=${#text}; (( caret < 0 )) && caret=0
  wattrset "$dw" 0 25
  mvwhline "$dw" "$row" "$col" ' ' "$width"
  if (( button )); then
    mvwaddnstr "$dw" "$row" "$col" "$text" "$(( width - 3 ))"
    wattrset "$dw" 0 28
    mvwaddstr "$dw" "$row" $(( col + width - 3 )) "[^]"
    wattrset "$dw" 0 25
    (( caret > width - 4 )) && caret=$(( width - 4 ))
  else
    mvwaddnstr "$dw" "$row" "$col" "$text" "$width"
    (( caret > width - 1 )) && caret=$(( width - 1 ))
  fi
  (( caret < 0 )) && caret=0
  if (( focused )); then
    wmove "$dw" "$row" $(( col + caret ))
  fi
}

# Checkbox "[x]"/"[ ]" with a mnemonic letter (index mnemidx into label).
# focused draws the whole box+label on a cyan highlight (mc behavior).
dlg_checkbox() { # row col on label mnemidx [fp [tp [focused]]]
  local row=$1 col=$2 on=$3 label=$4 mcol=${5:-0} fp=${6:-23} tp=${7:-24} focused=${8:-0}
  local bp mp
  if (( focused )); then bp=29; mp=30; else bp=$fp; mp=$tp; fi
  wattrset "$dw" 0 "$bp"
  if (( on )); then mvwaddstr "$dw" "$row" "$col" "[x] "
  else mvwaddstr "$dw" "$row" "$col" "[ ] "; fi
  mvwaddstr "$dw" "$row" $(( col + 4 )) "${label:0:mcol}"
  wattrset "$dw" 0 "$mp"
  mvwaddstr "$dw" "$row" $(( col + 4 + mcol )) "${label:mcol:1}"
  wattrset "$dw" 0 "$bp"
  mvwaddstr "$dw" "$row" $(( col + 4 + mcol + 1 )) "${label:mcol+1}"
}

# Button "[< label >]" (style ok) or "[ label ]" with a mnemonic letter.
# focused draws the whole button on a cyan highlight (mc behavior).
dlg_button() { # row col label style mnemidx [fp [tp [focused]]]
  local row=$1 col=$2 label=$3 style=$4 mcol=${5:-0} fp=${6:-23} tp=${7:-24} focused=${8:-0}
  local pad tcol bp mp
  if (( focused )); then bp=29; mp=30; else bp=$fp; mp=$tp; fi
  wattrset "$dw" 0 "$bp"
  if [[ $style == ok ]]; then mvwaddstr "$dw" "$row" "$col" "[< "; pad=3
  else mvwaddstr "$dw" "$row" "$col" "[ "; pad=2; fi
  tcol=$(( col + pad ))
  mvwaddstr "$dw" "$row" "$tcol" "${label:0:mcol}"
  wattrset "$dw" 0 "$mp"
  mvwaddstr "$dw" "$row" $(( tcol + mcol )) "${label:mcol:1}"
  wattrset "$dw" 0 "$bp"
  mvwaddstr "$dw" "$row" $(( tcol + mcol + 1 )) "${label:mcol+1}"
  if [[ $style == ok ]]; then mvwaddstr "$dw" "$row" $(( tcol + ${#label} )) " >]"
  else mvwaddstr "$dw" "$row" $(( tcol + ${#label} )) " ]"; fi
}

dlg_button_width() { # label style
  local label=$1 style=$2 pad=2 suffix=2
  [[ $style == ok ]] && { pad=3; suffix=3; }
  echo $(( pad + ${#label} + suffix ))
}

dlg_hit_button() { # win y x row col label style
  local win=$1 y=$2 x=$3 row=$4 col=$5 label=$6 style=$7
  wmouse_trafo "$win" "$y" "$x" 0 || return 1
  local wy=$BC_MT_Y wx=$BC_MT_X w
  w=$(dlg_button_width "$label" "$style")
  (( wy == row && wx >= col && wx < col + w ))
}

dlg_hit_checkbox() { # win y x row col label
  local win=$1 y=$2 x=$3 row=$4 col=$5 label=$6
  wmouse_trafo "$win" "$y" "$x" 0 || return 1
  local wy=$BC_MT_Y wx=$BC_MT_X w=$(( 4 + ${#label} ))
  (( wy == row && wx >= col && wx < col + w ))
}

dlg_hit_field() { # win y x row col width -> DLG_FIELD_X
  local win=$1 y=$2 x=$3 row=$4 col=$5 width=$6
  wmouse_trafo "$win" "$y" "$x" 0 || return 1
  local wy=$BC_MT_Y wx=$BC_MT_X
  (( wy == row && wx >= col && wx < col + width - 3 )) || return 1
  DLG_FIELD_X=$(( wx - col ))
  return 0
}

# generic modal dialogs ---------------------------------------------
message_dialog() { # title line1 [line2 ...]
  local title=$1; shift
  local -a lines=("$@")
  local w=50 h=$(( ${#lines[@]} + 4 ))
  (( w < 40 )) && w=40; (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  (( h > LINES - 4 )) && h=$(( LINES - 4 ))
  mc_dialog "$w" "$h" "$title" 0
  local i
  for (( i = 0; i < ${#lines[@]}; i++ )); do
    wattrset "$dw" 0 23
    mvwaddstr "$dw" "$(( i + 1 ))" 2 "${lines[$i]:0:$(( w - 4 ))}"
  done
  dlg_button "$(( h - 2 ))" $(( (w - 9) / 2 )) "OK" ok 0
  wrefresh "$dw"
  while :; do
    wgetch "$dw" || break
    case $key in
      $'\r'|$'q'|$'Q'|$'\x1b') break ;;
      $KEY_MOUSE)
        while getmouse; do
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" "$(( h - 2 ))" $(( (w - 9) / 2 )) "OK" ok; then
            break 2
          fi
        done
        ;;
    esac
  done
  delwin "$dw"
}

input_dialog() { # title prompt default -> DLG_RESULT; 0 ok / 1 cancel
  local title=$1 prompt=$2 def=$3
  local buf="$def"
  local w=50
  (( ${#prompt} + 8 > w )) && w=$(( ${#prompt} + 8 ))
  (( w < 40 )) && w=40; (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  local h=9
  dialog_box "$w" "$h" "$title"
  mvwaddstr "$dw" 2 2 "${prompt:0:$(( w - 4 ))}"
  local row=4
  wrefresh "$dw"
  local redraw=1
  while :; do
    if (( redraw )); then
      wmove "$dw" "$row" 2
      wclrtoeol "$dw"
      waddstr "$dw" "$buf"
      wrefresh "$dw"
      redraw=0
    fi
    wgetch "$dw" || break
    case $key in
      $'\r') DLG_RESULT="$buf"; delwin "$dw"; return 0 ;;
      $'\x1b') delwin "$dw"; return 1 ;;
      $'\x7f'|$'\x08') buf=${buf:0:-1}; redraw=1 ;;
      *)
        if [[ ${#key} == 1 && ${key:0:1} == [[:print:]] ]]; then
          buf+=$key; redraw=1
        fi
        ;;
    esac
  done
  delwin "$dw"
  return 1
}

confirm_dialog() { # title prompt -> DLG_RESULT y/n; 0 yes / 1 no
  local title=$1 prompt=$2
  local w=46 h=8
  (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  dialog_box "$w" "$h" "$title"
  mvwaddstr "$dw" 2 2 "${prompt:0:$(( w - 4 ))}"
  mvwaddstr "$dw" 4 2 "Are you sure? [y]es or [n]o:"
  wrefresh "$dw"
  while :; do
    wgetch "$dw" || break
    case $key in
      y|Y) DLG_RESULT=y; delwin "$dw"; return 0 ;;
      n|N|$'\x1b'|$'\r') DLG_RESULT=n; delwin "$dw"; return 1 ;;
    esac
  done
  delwin "$dw"
  return 1
}

# populate MITEMS[] / MN from the mi-th top-level menu
# set REALN to the number of real (non-separator) items in the menu bar_sel
menu_real_n() { # bar_sel
  local name=${MENUNAMES[$1]}
  local -n MI="MENU_${name}"
  local c=0 e
  for e in "${MI[@]}"; do [[ $e != --- ]] && (( c++ )); done
  REALN=$c
}

# set ENTRY to the "LABEL|SHORTCUT" of the ri-th real item (0-based)
menu_entry_at() { # bar_sel realidx
  local name=${MENUNAMES[$1]}
  local -n MI="MENU_${name}"
  local ri=$2 c=0 e
  for e in "${MI[@]}"; do
    if [[ $e != --- ]]; then
      if (( c == ri )); then ENTRY="$e"; return 0; fi
      (( c++ ))
    fi
  done
  ENTRY=""
}

# (the interactive menu is driven by run_menu; draw_menu renders it)

# ------------------------------------------------------------------ actions
cur_real() { # real name of current entry in active panel
  local -n RR=REALS_$CUR
  echo "${RR[${POS[$CUR]}]}"
}
do_open() {
  local real child="" old
  real=$(cur_real)
  if [[ $real == ".." ]]; then
    old="${DIR[$CUR]}"
    [[ $old != "/" ]] && child=$(basename "$old")
    DIR[$CUR]=$(dirname "$old")
  elif [[ -d "${DIR[$CUR]}/$real" ]]; then
    DIR[$CUR]="${DIR[$CUR]}/$real"
  elif [[ -f "${DIR[$CUR]}/$real" ]]; then
    view_file "$real"
    return
  else
    return
  fi
  list_dir "$CUR"
  HINT_TEXT="VFS coolness: tap enter on a tar file to examine its contents."
  # MC: when entering the parent, highlight the directory we came from
  if [[ -n $child ]]; then
    local -n RR=REALS_$CUR
    local i
    for (( i = 0; i < ${#RR[@]}; i++ )); do
      [[ ${RR[$i]} == "$child" ]] && { POS[$CUR]=$i; break; }
    done
  fi
}

# ------------------------------------------------------------------ file viewer (F3)
# Full-screen scrollable quick view, matching Midnight Commander's F3.
# Globals: V_WIN V_N V_OFF V_PATH V_LINES. Color pairs reused from the main
# palette: 6 (black-on-cyan), 7 (white-on-blue), 15 (bright-white-on-black).
view_metrics() { # compute viewer content height and maximum line offset
  V_ROWS=$(( LINES - 2 )); (( V_ROWS < 1 )) && V_ROWS=1
  V_MAXOFF=$(( V_N - V_ROWS )); (( V_MAXOFF < 0 )) && V_MAXOFF=0
}

view_title() { # win : redraw only the title bar
  local win=$1
  local total=${V_TOTAL:-0}; (( total < 0 )) && total=0

  # byte offset of first visible line; MC clamps to total (100%) at the bottom
  local off=${V_BTOFF[$V_OFF]:-0}
  if (( V_MAXOFF == 0 )); then
    off=$total
  else
    (( V_OFF >= V_MAXOFF )) && off=$total
  fi
  (( off < 0 )) && off=0
  (( off > total )) && off=$total
  local pct=0
  (( total > 0 )) && pct=$(( (off * 100) / total ))

  wattrset "$win" 0 6
  local offsettotal="${off}/${total}" pctpart="${pct}%" pctfield left_raw gap left title
  pctfield=$(printf '%21s' "$pctpart")
  gap=$(( COLS - 21 - ${#V_PATH} - ${#offsettotal} ))
  (( gap < 0 )) && gap=0
  left_raw="${V_PATH}$(printf '%*s' "$gap" '')${offsettotal}"
  left=$(printf '%-*s' "$((COLS - 21))" "$left_raw")
  title="${left}${pctfield}"
  mvwaddnstr "$win" 0 0 "$title" "$COLS"
}

view_content_line() { # win row : draw one full-width content row
  local win=$1 r=$2
  local idx=$(( V_OFF + r - 1 )) line len
  line=""; (( idx < V_N )) && line="${V_LINES[$idx]}"
  line="${line:0:$COLS}"
  wattrset "$win" 0 7
  mvwaddnstr "$win" "$r" 0 "$line" "$COLS"
  len=${#line}
  (( len < COLS )) && mvwhline "$win" "$r" "$len" ' ' "$(( COLS - len ))"
}

view_draw() { # paint the full-screen viewer window and refresh it
  local win=$V_WIN
  view_metrics
  (( V_OFF < 0 )) && V_OFF=0
  (( V_OFF > V_MAXOFF )) && V_OFF=$V_MAXOFF

  wattrset "$win" 0 7
  werase "$win"
  view_title "$win"

  local i
  for (( i = 1; i < LINES - 1; i++ )); do
    view_content_line "$win" "$i"
  done

  view_fnbar "$win"
  doupdate
}

view_scroll_to() { # new_off : scroll the content region when possible
  local new=$1
  view_metrics
  (( new < 0 )) && new=0
  (( new > V_MAXOFF )) && new=$V_MAXOFF
  local d=$(( new - V_OFF ))
  (( d == 0 )) && return 0
  local ad=$d
  (( ad < 0 )) && ad=$(( -ad ))

  if (( ad < V_ROWS )) && wscrl "$V_WIN" "$d"; then
    V_OFF=$new
    local r
    if (( d > 0 )); then
      for (( r = LINES - 1 - d; r < LINES - 1; r++ )); do
        view_content_line "$V_WIN" "$r"
      done
    else
      for (( r = 1; r < 1 - d; r++ )); do
        view_content_line "$V_WIN" "$r"
      done
    fi
    view_title "$V_WIN"
    doupdate
  else
    V_OFF=$new
    view_draw
  fi
}

view_fnbar() { # win : MC-style function-key hints (10 slots; #6 has a blank label)
  local win=$1
  local -a label=("" "Help" "UnWrap" "Quit" "Hex" "Goto" "" "Search" "Raw" "Format" "Quit")
  local i n numstr x
  wattrset "$win" 0 6
  mvwhline "$win" $(( LINES - 1 )) 0 ' ' "$COLS"
  for (( i = 0; i < 10; i++ )); do
    n=$(( i + 1 ))
    x=$(( i * 10 ))
    (( x >= COLS )) && break
    printf -v numstr '%2d' "$n"
    wattrset "$win" 0 15
    mvwaddnstr "$win" $(( LINES - 1 )) "$x" "$numstr" 2
    wattrset "$win" 0 6
    mvwaddnstr "$win" $(( LINES - 1 )) $(( x + 2 )) "$(printf '%-8s' "${label[$n]}")" 8
  done
}

view_apply_nav_key() { # key : update V_TARGET from one navigation key
  local k=$1
  case $k in
    $KEY_UP)    (( V_TARGET > 0 )) && V_TARGET=$(( V_TARGET - 1 )) ;;
    $KEY_DOWN)  (( V_TARGET < V_MAXOFF )) && V_TARGET=$(( V_TARGET + 1 )) ;;
    $KEY_HOME)  V_TARGET=0 ;;
    $KEY_END)   V_TARGET=$V_MAXOFF ;;
    $KEY_PPAGE) (( V_TARGET >= V_ROWS )) && V_TARGET=$(( V_TARGET - V_ROWS )) || V_TARGET=0 ;;
    $KEY_NPAGE) (( V_TARGET + V_ROWS <= V_MAXOFF )) && V_TARGET=$(( V_TARGET + V_ROWS )) || V_TARGET=$V_MAXOFF ;;
  esac
  (( V_TARGET < 0 )) && V_TARGET=0
  (( V_TARGET > V_MAXOFF )) && V_TARGET=$V_MAXOFF
}

drain_view_nav() { # fold any queued navigation keys into V_TARGET
  local win=$V_WIN
  local old=${BC_WDELAY[$win]:-0}
  BC_WDELAY[$win]=1
  local k
  while :; do
    wgetch "$win" || break
    k=$key
    case $k in
      $KEY_UP|$KEY_DOWN|$KEY_HOME|$KEY_END|$KEY_PPAGE|$KEY_NPAGE)
        view_apply_nav_key "$k"
        ;;
      *) ungetch "$key"; break ;;
    esac
  done
  BC_WDELAY[$win]=$old
}

view_loop() { # modal key loop; returns 0 to close the viewer
  local win=$V_WIN
  local k
  while :; do
    wgetch "$win" || return 0
    k=$key
    case $k in
      $KEY_UP|$KEY_DOWN|$KEY_HOME|$KEY_END|$KEY_PPAGE|$KEY_NPAGE)
        V_TARGET=$V_OFF
        view_apply_nav_key "$k"
        drain_view_nav
        view_scroll_to "$V_TARGET"
        ;;
      "q"|"Q"|$'\x1b'|"$KEY_F3"|"$KEY_F10") return 0 ;;
      $KEY_RESIZE) BC_WINCH=1; return 0 ;;
      $KEY_MOUSE)
        while getmouse; do
          if (( BC_ME_BSTATE & (BUTTON4_PRESSED | BUTTON4_CLICKED) )); then
            V_TARGET=$V_OFF
            (( V_TARGET > 0 )) && V_TARGET=$(( V_TARGET - 1 ))
            view_scroll_to "$V_TARGET"
          elif (( BC_ME_BSTATE & (BUTTON5_PRESSED | BUTTON5_CLICKED) )); then
            V_TARGET=$V_OFF
            (( V_TARGET < V_MAXOFF )) && V_TARGET=$(( V_TARGET + 1 ))
            view_scroll_to "$V_TARGET"
          elif (( BC_ME_Y == LINES - 1 && (BC_ME_BSTATE & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED)) )); then
            case $(( BC_ME_X / 10 )) in
              2|9) return 0 ;;
            esac
          fi
        done
        ;;
      *) continue ;;
    esac
  done
  return 0
}

view_load_text() { # title [total] ; reads lines from stdin into V_*
  local title=$1 total=${2:-}
  local -a lines=() bto=()
  local ln off=0
  while IFS= read -r ln || [[ -n $ln ]]; do
    bto+=("$off"); lines+=("$ln"); off=$(( off + ${#ln} + 1 ))
  done
  (( ${#lines[@]} == 0 )) && { lines+=(""); bto+=(0); }
  V_LINES=("${lines[@]}")
  V_N=${#lines[@]}
  V_OFF=0
  V_PATH="$title"
  V_BTOFF=("${bto[@]}")
  V_TOTAL=${total:-$off}
}

view_show() { # open the viewer from the current V_* globals
  local saved_esc=$ESCDELAY
  ESCDELAY=80

  newwin "$LINES" "$COLS" 0 0
  V_WIN=$bc_win
  new_panel "$V_WIN"; V_PANEL=$bc_panel
  scrollok "$V_WIN" 1
  if (( LINES > 2 )); then
    wsetscrreg "$V_WIN" 1 $(( LINES - 2 ))
  fi
  view_draw
  view_loop
  del_panel "$V_PANEL" 2>/dev/null
  delwin "$V_WIN"
  ESCDELAY=$saved_esc
  doupdate
}

view_path() { # absolute or relative path
  local f=$1
  if [[ ! -r $f ]]; then
    message_dialog "View" "Cannot read $f"
    return
  fi
  local -a nh=("$f") e
  for e in "${FILEHIST[@]}"; do [[ $e != "$f" ]] && nh+=("$e"); done
  (( ${#nh[@]} > 50 )) && nh=("${nh[@]:0:50}")
  FILEHIST=("${nh[@]}")
  view_load_text "$f" "$(wc -c < "$f" 2>/dev/null | tr -d ' \t')" < "$f"
  view_show
}

view_file() { # real name
  local real=$1
  view_path "${DIR[$CUR]}/$real"
}

do_view() {
  local real
  real=$(cur_real)
  [[ $real == ".." ]] && return
  if [[ -d "${DIR[$CUR]}/$real" ]]; then
    DIR[$CUR]="${DIR[$CUR]}/$real"; list_dir "$CUR"
  else
    view_file "$real"
  fi
}

do_view_file() {
  text_field_dialog "View file" "File name:" "" || return
  local f=$TF_TEXT
  [[ -z $f ]] && return
  f=${f/#~/$HOME}
  [[ $f != /* ]] && f="${DIR[$CUR]}/$f"
  if [[ -d $f ]]; then
    DIR[$CUR]="$f"; list_dir "$CUR"
  else
    view_path "$f"
  fi
}

do_filtered_view() {
  text_field_dialog "Filtered view" "Command:" "" || return
  local cmd=$TF_TEXT
  [[ -z $cmd ]] && return
  local out
  out=$( (cd "${DIR[$CUR]}" 2>/dev/null && eval "$cmd") 2>&1 )
  view_load_text "Filtered view: $cmd" <<< "$out"
  view_show
}

do_edit_path() { # path
  local f=$1
  local ed=${EDITOR:-${VISUAL:-}}
  if [[ -z $ed ]]; then
    message_dialog "Edit" "No editor configured."
    return
  fi
  if [[ ! -e $f ]]; then
    message_dialog "Edit" "File does not exist: $f"
    return
  fi
  local -a nh=("$f") e
  for e in "${FILEHIST[@]}"; do [[ $e != "$f" ]] && nh+=("$e"); done
  (( ${#nh[@]} > 50 )) && nh=("${nh[@]:0:50}")
  FILEHIST=("${nh[@]}")
  def_prog_mode
  endwin
  eval "$ed $(printf '%q' "$f")"
  reset_prog_mode
  BC_FORCEFULL=1
  refresh_panel_keep "$CUR"
  draw_all
  doupdate
}

do_edit() { # real name
  local real=${1:-}
  [[ -z $real ]] && real=$(cur_real)
  [[ $real == ".." ]] && return
  do_edit_path "${DIR[$CUR]}/$real"
}

# Directory-history popup (the completer behind a field's "[^]" button). Shows
# the recently-used directories most-recent-first; up/down/page/home/end to
# browse, Enter to choose (result in HIST_RESULT), Esc/F10 to cancel. Returns
# 0 if an entry was chosen, 1 otherwise. $1 is the row the box starts on.
field_history_popup() { # anchor_row
  local anchor=${1:-19}
  local -a items=() e
  for e in "${DIRHIST[@]}"; do [[ -n $e ]] && items+=("$e"); done
  (( ${#items[@]} )) || items=("$PWD")
  local n=${#items[@]} sel=0 top=0 maxl=0
  for e in "${items[@]}"; do (( ${#e} > maxl )) && maxl=${#e}; done
  local w=$(( maxl + 6 )); (( w < 40 )) && w=40; (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  local maxh=$(( LINES - anchor )); (( maxh < 4 )) && maxh=4
  local h=$(( n + 2 )); (( h > maxh )) && h=$maxh
  local visible=$(( h - 2 ))
  local y=$anchor x=$(( (COLS - w) / 2 )); (( x < 1 )) && x=1
  newwin "$h" "$w" "$y" "$x"; local hw=$bc_win
  hist_draw() {
    wattrset "$hw" 0 23; werase "$hw"; box "$hw"
    local tstr=" History " tx=$(( (w - ${#tstr}) / 2 )); (( tx < 1 )) && tx=1
    wattrset "$hw" 0 24; mvwaddstr "$hw" 0 "$tx" "$tstr"
    local i row idx e2
    for (( i = 0; i < visible; i++ )); do
      row=$(( i + 1 )); idx=$(( top + i ))
      (( idx >= n )) && continue
      e2=${items[idx]}
      if (( idx == sel )); then
        wattrset "$hw" 0 22
        mvwaddnstr "$hw" "$row" 1 "$e2" "$(( w - 2 ))"
        mvwhline "$hw" "$row" $(( 1 + ${#e2} )) ' ' "$(( w - 2 - ${#e2} ))"
      else
        wattrset "$hw" 0 23
        mvwaddnstr "$hw" "$row" 1 "$e2" "$(( w - 2 ))"
      fi
    done
    wrefresh "$hw"
  }
  hist_draw
  while :; do
    wgetch "$hw" || break
    case $key in
      $KEY_UP)    (( sel > 0 )) && { sel=$(( sel - 1 )); (( sel < top )) && top=$sel; } ;;
      $KEY_DOWN)  (( sel < n - 1 )) && { sel=$(( sel + 1 )); (( sel > top + visible - 1 )) && top=$(( sel - visible + 1 )); } ;;
      $KEY_HOME)  sel=0; top=0 ;;
      $KEY_END)   sel=$(( n - 1 )); if (( n > visible )); then top=$(( n - visible )); else top=0; fi ;;
      $KEY_PPAGE) sel=$(( sel - visible )); (( sel < 0 )) && sel=0; (( sel < top )) && top=$sel ;;
      $KEY_NPAGE) sel=$(( sel + visible )); (( sel > n - 1 )) && sel=$(( n - 1 )); (( sel > top + visible - 1 )) && top=$(( sel - visible + 1 )) ;;
      $'\r')      HIST_RESULT=${items[sel]}; delwin "$hw"; return 0 ;;
      $'\x1b'|$KEY_F10) delwin "$hw"; return 1 ;;
    esac
    hist_draw
  done
  delwin "$hw"
  return 1
}

# Generic centered list popup. Sets LIST_RESULT. 0 chosen / 1 cancel.
list_dialog() { # title item...
  local title=$1; shift
  local -a items=("$@")
  (( ${#items[@]} )) || { message_dialog "$title" "No entries."; return 1; }
  local n=${#items[@]} sel=0 top=0 maxl=0 e wy wx idx
  for e in "${items[@]}"; do (( ${#e} > maxl )) && maxl=${#e}; done
  local w=$(( maxl + 6 )); (( w < 40 )) && w=40; (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  local maxh=$(( LINES - 4 )); (( maxh < 4 )) && maxh=4
  local h=$(( n + 2 )); (( h > maxh )) && h=$maxh
  local visible=$(( h - 2 )); (( visible < 1 )) && visible=1
  local y=$(( (LINES - h) / 2 )); (( y < 1 )) && y=1
  local x=$(( (COLS - w) / 2 )); (( x < 1 )) && x=1
  newwin "$h" "$w" "$y" "$x"; local lw=$bc_win
  ld_draw() {
    wattrset "$lw" 0 23; werase "$lw"; box "$lw"
    local tstr=" $title " tx=$(( (w - ${#tstr}) / 2 )); (( tx < 1 )) && tx=1
    wattrset "$lw" 0 24; mvwaddstr "$lw" 0 "$tx" "$tstr"
    local i row idx e2
    for (( i = 0; i < visible; i++ )); do
      row=$(( i + 1 )); idx=$(( top + i ))
      (( idx >= n )) && continue
      e2=${items[idx]}
      if (( idx == sel )); then
        wattrset "$lw" 0 22
        mvwaddnstr "$lw" "$row" 1 "$e2" "$(( w - 2 ))"
        mvwhline "$lw" "$row" $(( 1 + ${#e2} )) ' ' "$(( w - 2 - ${#e2} ))"
      else
        wattrset "$lw" 0 23
        mvwaddnstr "$lw" "$row" 1 "$e2" "$(( w - 2 ))"
      fi
    done
    wrefresh "$lw"
  }
  ld_draw
  while :; do
    wgetch "$lw" || break
    case $key in
      $KEY_UP)    (( sel > 0 )) && { sel=$(( sel - 1 )); (( sel < top )) && top=$sel; } ;;
      $KEY_DOWN)  (( sel < n - 1 )) && { sel=$(( sel + 1 )); (( sel > top + visible - 1 )) && top=$(( sel - visible + 1 )); } ;;
      $KEY_HOME)  sel=0; top=0 ;;
      $KEY_END)   sel=$(( n - 1 )); if (( n > visible )); then top=$(( n - visible )); else top=0; fi ;;
      $KEY_PPAGE) sel=$(( sel - visible )); (( sel < 0 )) && sel=0; (( sel < top )) && top=$sel ;;
      $KEY_NPAGE) sel=$(( sel + visible )); (( sel > n - 1 )) && sel=$(( n - 1 )); (( sel > top + visible - 1 )) && top=$(( sel - visible + 1 )) ;;
      $KEY_MOUSE)
        while getmouse; do
          if (( BC_ME_BSTATE & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
            if wmouse_trafo "$lw" "$BC_ME_Y" "$BC_ME_X" 0; then
              wy=$BC_MT_Y; wx=$BC_MT_X
              if (( wy >= 1 && wy < h - 1 && wx >= 1 && wx < w - 1 )); then
                idx=$(( top + wy - 1 ))
                if (( idx < n )); then
                  sel=$idx
                  if (( BC_ME_BSTATE & (BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
                    LIST_RESULT=${items[sel]}; delwin "$lw"; return 0
                  fi
                fi
              fi
            fi
          fi
        done
        ;;
      $'\r')      LIST_RESULT=${items[sel]}; delwin "$lw"; return 0 ;;
      $'\x1b'|$KEY_F10|q|Q) delwin "$lw"; return 1 ;;
    esac
    ld_draw
  done
  delwin "$lw"
  return 1
}

# MC-style Copy/Move dialog: source-mask field, five checkboxes, destination
# field, and OK/Background/Cancel. Returns 0 (OK) / 1 (cancel); results in
# CM_SRC / CM_DST / CM_SHELL / CM_FOLLOW / CM_DIVE / CM_PRESERVE / CM_STABLE.
copy_move_dialog() { # verb
  local verb=$1
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return 1
  local kind; [[ -d "${DIR[$CUR]}/$real" ]] && kind="directory" || kind="file"
  local src='*' dst="${DIR[$(( 1 - CUR ))]}/"
  local sc=${#src} dc=${#dst}
  local c_shell=1 c_follow=0 c_dive=0 c_preserve=1 c_stable=0
  # focus order matches mc: fields top-to-bottom, then the checkboxes
  # column-major (left column, then right column), then the buttons.
  local -a ET=(src shell dst follow preserve dive stable ok bg cancel)
  local fi=2 cancelled=0          # mc starts with the destination field focused
  local w=66 h=12
  (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  mc_dialog "$w" "$h" "$verb" 0
  # the history popup opens just below the dialog
  local anchor=$(( (PH - h) / 2 + h ))

  cm_draw() {
    wattrset "$dw" 0 23
    mvwaddstr "$dw" 1 2 "$verb $kind \"$real\" with source mask:"
    dlg_field 2 2 62 "$src" "$sc" $(( fi == 0 ))
    dlg_checkbox 3 33 "$c_shell" "Using shell patterns" 0 23 24 $(( fi == 1 ))
    wattrset "$dw" 0 23
    mvwaddstr "$dw" 4 2 "to:"
    dlg_field 5 2 62 "$dst" "$dc" $(( fi == 2 ))
    dlg_divider 6
    dlg_checkbox 7 2  "$c_follow"   "Follow links" 7 23 24 $(( fi == 3 ))
    dlg_checkbox 7 33 "$c_dive"     "Dive into subdir if exists" 2 23 24 $(( fi == 5 ))
    dlg_checkbox 8 2  "$c_preserve" "Preserve attributes" 9 23 24 $(( fi == 4 ))
    dlg_checkbox 8 33 "$c_stable"   "Stable symlinks" 0 23 24 $(( fi == 6 ))
    dlg_divider 9
    dlg_button 10 16 "OK" ok 0 23 24 $(( fi == 7 ))
    dlg_button 10 25 "Background" plain 0 23 24 $(( fi == 8 ))
    dlg_button 10 40 "Cancel" plain 0 23 24 $(( fi == 9 ))
    wrefresh "$dw"
  }

  # full redraw of the whole dialog (frame + title + contents); used to restore
  # it after the history popup has painted over part of the screen.
  cm_redraw_full() {
    werase "$dw"; box "$dw"
    local tstr=" $verb " tx=$(( (w - ${#tstr}) / 2 )); (( tx < 1 )) && tx=1
    wattrset "$dw" 0 24; mvwaddstr "$dw" 0 "$tx" "$tstr"; wattrset "$dw" 0 23
    cm_draw
  }

  cm_draw
  while :; do
    wgetch "$dw" || break
    case $key in
      $KEY_RESIZE) BC_WINCH=1; break ;;
      $'\x1b') cancelled=1; break ;;
      $'\t') (( fi < 9 )) && fi=$(( fi + 1 )); cm_draw ;;
      $KEY_UP)   (( fi > 0 )) && fi=$(( fi - 1 )); cm_draw ;;
      $KEY_DOWN) (( fi < 9 )) && fi=$(( fi + 1 )); cm_draw ;;
      $'\r') [[ ${ET[$fi]} == cancel ]] && cancelled=1; break ;;
      $KEY_LEFT)
        case ${ET[$fi]} in
          src) (( sc > 0 )) && sc=$(( sc - 1 ));;
          dst) (( dc > 0 )) && dc=$(( dc - 1 ));;
          shell)    c_shell=$(( 1 - c_shell ));;
          follow)   c_follow=$(( 1 - c_follow ));;
          dive)     c_dive=$(( 1 - c_dive ));;
          preserve) c_preserve=$(( 1 - c_preserve ));;
          stable)   c_stable=$(( 1 - c_stable ));;
        esac; cm_draw ;;
      $KEY_RIGHT)
        case ${ET[$fi]} in
          src) (( sc < ${#src} )) && sc=$(( sc + 1 ));;
          dst) (( dc < ${#dst} )) && dc=$(( dc + 1 ));;
          shell)    c_shell=$(( 1 - c_shell ));;
          follow)   c_follow=$(( 1 - c_follow ));;
          dive)     c_dive=$(( 1 - c_dive ));;
          preserve) c_preserve=$(( 1 - c_preserve ));;
          stable)   c_stable=$(( 1 - c_stable ));;
        esac; cm_draw ;;
      $KEY_HOME) case ${ET[$fi]} in src) sc=0;; dst) dc=0;; esac; cm_draw ;;
      $KEY_END)  case ${ET[$fi]} in src) sc=${#src};; dst) dc=${#dst};; esac; cm_draw ;;
      $KEY_ALT_SH)
        case ${ET[$fi]} in
          src) field_history_popup "$anchor" && { src="$HIST_RESULT"; sc=${#src}; } ;;
          dst) field_history_popup "$anchor" && { dst="$HIST_RESULT"; dc=${#dst}; } ;;
        esac
        draw_all; doupdate; cm_redraw_full ;;
      $KEY_MOUSE)
        while getmouse; do
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 10 16 "OK" ok; then break 2; fi
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 10 25 "Background" plain; then break 2; fi
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 10 40 "Cancel" plain; then cancelled=1; break 2; fi
          if dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 3 33 "Using shell patterns"; then
            c_shell=$(( 1 - c_shell )); fi=1
          elif dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 7 2 "Follow links"; then
            c_follow=$(( 1 - c_follow )); fi=3
          elif dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 7 33 "Dive into subdir if exists"; then
            c_dive=$(( 1 - c_dive )); fi=5
          elif dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 8 2 "Preserve attributes"; then
            c_preserve=$(( 1 - c_preserve )); fi=4
          elif dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 8 33 "Stable symlinks"; then
            c_stable=$(( 1 - c_stable )); fi=6
          elif dlg_hit_field "$dw" "$BC_ME_Y" "$BC_ME_X" 2 2 62; then
            fi=0; sc=$DLG_FIELD_X; (( sc > ${#src} )) && sc=${#src}
          elif dlg_hit_field "$dw" "$BC_ME_Y" "$BC_ME_X" 5 2 62; then
            fi=2; dc=$DLG_FIELD_X; (( dc > ${#dst} )) && dc=${#dst}
          fi
        done
        cm_draw ;;
      $'\x7f'|$'\x08')
        case ${ET[$fi]} in
          src) if (( sc > 0 )); then src="${src:0:sc-1}${src:sc}"; sc=$(( sc - 1 )); fi ;;
          dst) if (( dc > 0 )); then dst="${dst:0:dc-1}${dst:dc}"; dc=$(( dc - 1 )); fi ;;
        esac; cm_draw ;;
      *)
        case ${ET[$fi]} in
          shell)    [[ $key == " " ]] && c_shell=$(( 1 - c_shell )) ;;
          follow)   [[ $key == " " ]] && c_follow=$(( 1 - c_follow )) ;;
          dive)     [[ $key == " " ]] && c_dive=$(( 1 - c_dive )) ;;
          preserve) [[ $key == " " ]] && c_preserve=$(( 1 - c_preserve )) ;;
          stable)   [[ $key == " " ]] && c_stable=$(( 1 - c_stable )) ;;
          ok)       [[ $key == " " ]] && break ;;
          bg)       [[ $key == " " ]] && break ;;
          cancel)   [[ $key == " " ]] && { cancelled=1; break; } ;;
        esac
        if [[ ${#key} == 1 && ${key:0:1} == [[:print:]] ]]; then
          case ${ET[$fi]} in
            src) src="${src:0:sc}$key${src:sc}"; sc=$(( sc + 1 )) ;;
            dst) dst="${dst:0:dc}$key${dst:dc}"; dc=$(( dc + 1 )) ;;
          esac
        fi
        cm_draw ;;
    esac
  done
  delwin "$dw"
  CM_SRC=$src; CM_DST=$dst
  CM_SHELL=$c_shell; CM_FOLLOW=$c_follow; CM_DIVE=$c_dive
  CM_PRESERVE=$c_preserve; CM_STABLE=$c_stable
  (( cancelled )) && return 1
  return 0
}

# Generic single-line input dialog (mc white frame). Sets TF_TEXT. 0 ok / 1 cancel.
text_field_dialog() { # title prompt default
  local title=$1 prompt=$2 def=$3
  local name="$def" caret=${#def} cancelled=0
  local w=40 h=6
  (( ${#prompt} + 8 > w )) && w=$(( ${#prompt} + 8 ))
  (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  mc_dialog "$w" "$h" "$title" 0
  tf_draw() {
    wattrset "$dw" 0 23
    mvwaddstr "$dw" 1 2 "$prompt"
    dlg_field 2 2 $(( w - 4 )) "$name" "$caret" 1
    dlg_divider 3
    dlg_button 4 9 "OK" ok 0
    dlg_button 4 18 "Cancel" plain 0
    wrefresh "$dw"
  }
  tf_draw
  while :; do
    wgetch "$dw" || break
    case $key in
      $KEY_RESIZE) BC_WINCH=1; break ;;
      $'\x1b') cancelled=1; break ;;
      $'\r') break ;;
      $KEY_LEFT)  (( caret > 0 )) && caret=$(( caret - 1 )) ;;
      $KEY_RIGHT) (( caret < ${#name} )) && caret=$(( caret + 1 )) ;;
      $KEY_HOME) caret=0 ;;
      $KEY_END) caret=${#name} ;;
      $'\x7f'|$'\x08') if (( caret > 0 )); then name="${name:0:caret-1}${name:caret}"; caret=$(( caret - 1 )); fi ;;
      $KEY_MOUSE)
        while getmouse; do
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 4 9 "OK" ok; then break 2; fi
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 4 18 "Cancel" plain; then cancelled=1; break 2; fi
          if dlg_hit_field "$dw" "$BC_ME_Y" "$BC_ME_X" 2 2 $(( w - 4 )); then
            caret=$DLG_FIELD_X
            (( caret > ${#name} )) && caret=${#name}
          fi
        done
        ;;
      *) if [[ ${#key} == 1 && ${key:0:1} == [[:print:]] ]]; then name="${name:0:caret}$key${name:caret}"; caret=$(( caret + 1 )); fi ;;
    esac
    tf_draw
  done
  delwin "$dw"
  TF_TEXT=$name
  (( cancelled )) && return 1
  return 0
}

# MC-style Delete confirmation (red frame). kind = directory|file. 0 yes / 1 no.
delete_dialog() { # kind real
  local kind=$1 real=$2
  local prompt; [[ $kind == directory ]] && prompt="Delete directory" || prompt="Delete file"
  local name="\"$real\"?"
  local w=21
  (( ${#prompt} + 4 > w )) && w=$(( ${#prompt} + 4 ))
  (( ${#name} + 6 > w )) && w=$(( ${#name} + 6 ))
  (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  mc_dialog "$w" 6 "Delete" 1
  local c=$(( (w - 14) / 2 ))
  dd_draw() {
    wattrset "$dw" 0 26
    mvwaddstr "$dw" 1 2 "$prompt"
    mvwaddstr "$dw" 2 $(( (w - ${#name}) / 2 )) "$name"
    dlg_divider 3 26
    dlg_button 4 "$c"     "Yes" plain 0 26 27
    dlg_button 4 "$(( c + 8 ))" "No" plain 0 26 27
    wrefresh "$dw"
  }
  dd_draw
  local yes=0
  while :; do
    wgetch "$dw" || yes=1
    case $key in
      $KEY_RESIZE) yes=0; break ;;
      $'\r'|y|Y) yes=1; break ;;
      n|N|$'\x1b') yes=0; break ;;
      $KEY_MOUSE)
        while getmouse; do
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 4 "$c" "Yes" plain; then yes=1; break 2; fi
          if dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 4 "$(( c + 8 ))" "No" plain; then yes=0; break 2; fi
        done
        ;;
    esac
  done
  delwin "$dw"
  (( yes )) && return 0
  return 1
}

do_mkdir() {
  text_field_dialog "Create a new Directory" "Enter directory name:" "" || return
  local name=$TF_TEXT
  [[ -z $name ]] && return
  if mkdir "${DIR[$CUR]}/$name" 2>/dev/null; then
    refresh_panel_keep "$CUR" "$name"
    local other=$(( 1 - CUR ))
    [[ ${DIR[$other]} == "${DIR[$CUR]}" ]] && refresh_panel_keep "$other"
  fi
}

do_delete() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  local kind; [[ -d "${DIR[$CUR]}/$real" ]] && kind="directory" || kind="file"
  delete_dialog "$kind" "$real" || return
  if rm -rf -- "${DIR[$CUR]}/$real" 2>/dev/null; then
    local -n RR=REALS_$CUR
    local pos=${POS[$CUR]}
    local next=${RR[$(( pos + 1 ))]:-}
    [[ -z $next ]] && next=${RR[$(( pos - 1 ))]:-}
    refresh_panel_keep "$CUR" "$next"
    local other=$(( 1 - CUR ))
    [[ ${DIR[$other]} == "${DIR[$CUR]}" ]] && refresh_panel_keep "$other"
  fi
}

do_copy() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  copy_move_dialog "Copy" || return
  local d=${CM_DST/#~/$HOME}
  [[ -z $d ]] && return
  [[ -d $d ]] || { message_dialog "Copy" "Not a directory: $d"; return; }
  local flags=" -r"
  (( CM_PRESERVE )) && flags+=" -p"
  (( CM_FOLLOW )) && flags+=" -L"
  local target="$d"
  (( CM_DIVE )) && [[ -d "$d/$real" ]] && target="$d/$real/"
  if [[ $CM_SRC == '*' ]]; then cp $flags -- "${DIR[$CUR]}/$real" "$target" 2>/dev/null
  else cp $flags -- ${DIR[$CUR]}/${CM_SRC} "$target" 2>/dev/null; fi
  list_dir 0; list_dir 1
}

do_move() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  copy_move_dialog "Move" || return
  local d=${CM_DST/#~/$HOME}
  [[ -z $d ]] && return
  [[ -d $d ]] || { message_dialog "Move" "Not a directory: $d"; return; }
  local target="$d"
  (( CM_DIVE )) && [[ -d "$d/$real" ]] && target="$d/$real/"
  if [[ $CM_SRC == '*' ]]; then mv -- "${DIR[$CUR]}/$real" "$target" 2>/dev/null
  else mv -- ${DIR[$CUR]}/${CM_SRC} "$target" 2>/dev/null; fi
  list_dir 0; list_dir 1
}

# File "Info" (C-x i): a quick stat dialog for the current entry.
do_info() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  local f="${DIR[$CUR]}/$real" size="" mtime type
  if [[ -d $f ]]; then type="directory"
  elif [[ -L $f ]]; then type="symlink"
  else type="regular file"; size=$(wc -c < "$f" 2>/dev/null | tr -d ' '); fi
  mtime=$(stat -c '%y' "$f" 2>/dev/null)
  local -a lines=("$real", "Type: $type")
  [[ -n $size ]] && lines+=("Size: $size bytes")
  [[ -n $mtime ]] && lines+=("Modified: ${mtime:0:19}")
  message_dialog "Info" "${lines[@]}"
}

do_chmod() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  text_field_dialog "Chmod" "Mode (octal):" "0644" || return
  local mode=$TF_TEXT
  [[ $mode =~ ^[0-7]{3,4}$ ]] || { message_dialog "Chmod" "Invalid mode: $mode"; return; }
  chmod "$mode" "${DIR[$CUR]}/$real" 2>/dev/null && list_dir "$CUR"
}

do_link() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  text_field_dialog "Link" "Name of the new link:" "" || return
  local name=$TF_TEXT
  [[ -z $name ]] && return
  ln "$real" "${DIR[$CUR]}/$name" 2>/dev/null && list_dir "$CUR"
}

do_symlink() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  text_field_dialog "Symlink" "Name of the new symlink:" "" || return
  local name=$TF_TEXT
  [[ -z $name ]] && return
  ln -s "$real" "${DIR[$CUR]}/$name" 2>/dev/null && list_dir "$CUR"
}

do_relative_symlink() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  text_field_dialog "Relative symlink" "Name of the new symlink:" "" || return
  local name=$TF_TEXT
  [[ -z $name ]] && return
  local target="${DIR[$CUR]}/$real"
  local link="${DIR[$CUR]}/$name"
  local rel
  rel=$(realpath --relative-to="$(dirname "$link")" "$target" 2>/dev/null)
  [[ -z $rel ]] && rel=$real
  ln -s "$rel" "$link" 2>/dev/null && list_dir "$CUR"
}

do_edit_symlink() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  local f="${DIR[$CUR]}/$real"
  if [[ ! -L $f ]]; then
    message_dialog "Edit symlink" "Not a symlink: $real"
    return
  fi
  local target
  target=$(readlink "$f" 2>/dev/null)
  text_field_dialog "Edit symlink" "New target:" "$target" || return
  [[ -z $TF_TEXT ]] && return
  ln -sf "$TF_TEXT" "$f" 2>/dev/null && list_dir "$CUR"
}

do_chown() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  text_field_dialog "Chown" "Owner[:group]:" "" || return
  local spec=$TF_TEXT
  [[ -z $spec ]] && return
  if ! chown "$spec" "${DIR[$CUR]}/$real" 2>/dev/null; then
    message_dialog "Chown" "Cannot chown $real to $spec"
  fi
  list_dir "$CUR"
}

do_advanced_chown() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  text_field_dialog "Advanced chown" "Owner:" "" || return
  local owner=$TF_TEXT
  text_field_dialog "Advanced chown" "Group:" "" || return
  local group=$TF_TEXT
  local spec=$owner
  [[ -n $group ]] && spec+=":$group"
  [[ -z $spec ]] && return
  if ! chown "$spec" "${DIR[$CUR]}/$real" 2>/dev/null; then
    message_dialog "Advanced chown" "Cannot chown $real to $spec"
  fi
  list_dir "$CUR"
}

do_chattr() {
  local real; real=$(cur_real)
  [[ $real == ".." ]] && return
  if ! command -v chattr >/dev/null 2>&1; then
    message_dialog "Chattr" "chattr is not available."
    return
  fi
  text_field_dialog "Chattr" "Attributes (+/- flags):" "" || return
  local attrs=$TF_TEXT
  [[ -z $attrs ]] && return
  if ! chattr "$attrs" "${DIR[$CUR]}/$real" 2>/dev/null; then
    message_dialog "Chattr" "Cannot set attributes on $real"
  fi
  list_dir "$CUR"
}

select_group_dialog() {
  local w=53 h=5
  local pat="" caret=0 focus=0
  local files_only=0 case_sens=1 shell_pat=1
  local cancelled=0
  mc_dialog "$w" "$h" "Select" 0
  sg_draw() {
    dlg_field 1 2 49 "$pat" "$caret" $(( focus == 0 )) 1
    dlg_checkbox 2 2  "$files_only" "Files only"           0 23 24 $(( focus == 1 ))
    dlg_checkbox 2 27 "$case_sens"  "Case sensitive"       0 23 24 $(( focus == 2 ))
    dlg_checkbox 3 2  "$shell_pat"  "Using shell patterns" 0 23 24 $(( focus == 3 ))
    wrefresh "$dw"
  }
  sg_draw
  while :; do
    wgetch "$dw" || break
    case $key in
      $KEY_RESIZE) BC_WINCH=1; break ;;
      $'\x1b') cancelled=1; break ;;
      $'\r') break ;;
      $'\t') focus=$(( (focus + 1) % 4 )) ;;
      $' ')
        case $focus in
          1) files_only=$(( 1 - files_only )) ;;
          2) case_sens=$(( 1 - case_sens )) ;;
          3) shell_pat=$(( 1 - shell_pat )) ;;
        esac
        ;;
      $KEY_LEFT)  (( caret > 0 )) && caret=$(( caret - 1 )) ;;
      $KEY_RIGHT) (( caret < ${#pat} )) && caret=$(( caret + 1 )) ;;
      $KEY_HOME) caret=0 ;;
      $KEY_END) caret=${#pat} ;;
      $KEY_MOUSE)
        while getmouse; do
          if dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 2 2 "Files only"; then
            files_only=$(( 1 - files_only )); focus=1
          elif dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 2 27 "Case sensitive"; then
            case_sens=$(( 1 - case_sens )); focus=2
          elif dlg_hit_checkbox "$dw" "$BC_ME_Y" "$BC_ME_X" 3 2 "Using shell patterns"; then
            shell_pat=$(( 1 - shell_pat )); focus=3
          elif dlg_hit_field "$dw" "$BC_ME_Y" "$BC_ME_X" 1 2 49; then
            focus=0; caret=$DLG_FIELD_X; (( caret > ${#pat} )) && caret=${#pat}
          fi
        done
        ;;
      $'\x7f'|$'\x08')
        if (( caret > 0 )); then
          pat="${pat:0:caret-1}${pat:caret}"
          caret=$(( caret - 1 ))
        fi
        ;;
      *)
        if (( focus == 0 )) && [[ ${#key} == 1 && ${key:0:1} == [[:print:]] ]]; then
          pat="${pat:0:caret}$key${pat:caret}"
          caret=$(( caret + 1 ))
        fi
        ;;
    esac
    sg_draw
  done
  delwin "$dw"
  SG_PATTERN=$pat
  SG_FILES_ONLY=$files_only
  SG_CASE_SENS=$case_sens
  SG_SHELL_PAT=$shell_pat
  (( cancelled )) && return 1
  return 0
}

do_select_group() {
  select_group_dialog || { draw_all; doupdate; return; }
  local pat=$SG_PATTERN
  [[ -z $pat ]] && { draw_all; doupdate; return; }
  local -n RR=REALS_$CUR TT=TYPES_$CUR SELARR=SELSET_$CUR
  local i real match
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    real=${RR[$i]}
    [[ $real == ".." ]] && continue
    if (( SG_FILES_ONLY )) && [[ ${TT[$i]} == d ]]; then continue; fi
    match=0
    if (( SG_SHELL_PAT )); then
      if (( SG_CASE_SENS )); then
        [[ $real == $pat ]] && match=1
      else
        [[ ${real,,} == ${pat,,} ]] && match=1
      fi
    else
      if (( SG_CASE_SENS )); then
        [[ $real == "$pat" ]] && match=1
      else
        [[ ${real,,} == "${pat,,}" ]] && match=1
      fi
    fi
    (( match )) && SELARR[$real]=1
  done
  HINT_TEXT=""
  draw_all
  doupdate
}

do_unselect_group() {
  text_field_dialog "Unselect group" "File name pattern:" "*" || return
  local pat=$TF_TEXT
  [[ -z $pat ]] && return
  local -n RR=REALS_$CUR
  local i real
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    real=${RR[$i]}
    [[ $real == ".." ]] && continue
    if [[ $real == $pat ]]; then
      local -n SELARR=SELSET_$CUR
      unset 'SELARR[$real]'
    fi
  done
  draw_panel "$CUR"
  doupdate
}

do_insert_select() {
  local -n NN=NAMES_$CUR RR=REALS_$CUR SELARR=SELSET_$CUR
  local pos=${POS[$CUR]}
  if (( pos > 0 )); then
    local real=${RR[$pos]}
    if [[ -n ${SELARR[$real]:-} ]]; then
      unset 'SELARR[$real]'
    else
      SELARR[$real]=1
    fi
  fi
  (( pos < ${#NN[@]} - 1 )) && POS[$CUR]=$(( pos + 1 ))
  HINT_TEXT=""
  draw_panel "$CUR"
  doupdate
}

do_star_select() {
  local -n RR=REALS_$CUR TT=TYPES_$CUR SELARR=SELSET_$CUR
  local i
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    [[ ${RR[$i]} == ".." ]] && continue
    [[ ${TT[$i]} == d ]] && continue
    SELARR[${RR[$i]}]=1
  done
  HINT_TEXT=""
  draw_panel "$CUR"
  doupdate
}

do_invert_selection() {
  local -n RR=REALS_$CUR
  local i real
  for (( i = 1; i < ${#RR[@]}; i++ )); do
    real=${RR[$i]}
    [[ $real == ".." ]] && continue
    local -n SELARR=SELSET_$CUR
    if [[ -n ${SELARR[$real]:-} ]]; then
      unset 'SELARR[$real]'
    else
      SELARR[$real]=1
    fi
  done
  HINT_TEXT=""
  draw_panel "$CUR"
  doupdate
}

do_rescan() {
  list_dir "$CUR"
  draw_all
  doupdate
}

do_filter() {
  text_field_dialog "Filter" "Panel filter (shell pattern):" "${FILTERS[$CUR]}" || return
  FILTERS[$CUR]=$TF_TEXT
  list_dir "$CUR"
}

do_tree() {
  local -a dirs=() d
  while IFS= read -r d; do
    [[ -n $d ]] && dirs+=("$d")
  done < <(find "${DIR[$CUR]}" -maxdepth 3 -type d -print 2>/dev/null | head -200)
  list_dialog "Directory tree" "${dirs[@]}" || return
  DIR[$CUR]="$LIST_RESULT"
  list_dir "$CUR"
}

do_find_file() {
  text_field_dialog "Find file" "File name pattern:" "" || return
  local pat=$TF_TEXT
  [[ -z $pat ]] && return
  local -a found=() f
  while IFS= read -r f; do
    [[ -n $f ]] && found+=("$f")
  done < <(find "${DIR[$CUR]}" -name "$pat" -print 2>/dev/null | head -200)
  if (( ${#found[@]} == 0 )); then
    message_dialog "Find file" "No files found matching: $pat"
    return
  fi
  list_dialog "Find file" "${found[@]}" || return
  f=$LIST_RESULT
  if [[ -d $f ]]; then
    DIR[$CUR]="$f"; list_dir "$CUR"
  else
    view_path "$f"
  fi
}

cur_real_p() { # p
  local p=$1
  local -n RR=REALS_$p
  echo "${RR[${POS[$p]}]}"
}

do_compare_files() {
  local l="${DIR[0]}/$(cur_real_p 0)"
  local r="${DIR[1]}/$(cur_real_p 1)"
  if cmp -s "$l" "$r"; then
    message_dialog "Compare files" "Files are identical:" "$l" "$r"
  else
    message_dialog "Compare files" "Files differ:" "$l" "$r"
  fi
}

quick_cd_dialog() {
  local w=48 h=3 x=1 y=$(( LINES - 7 ))
  (( y < 1 )) && y=1
  local r c
  for (( r = y - 1; r <= y + h; r++ )); do
    for (( c = x - 1; c <= x + w; c++ )); do
      (( r >= 0 && c >= 0 && r < LINES && c < COLS )) && mc_shadow_put "$r" "$c" 23 ' '
    done
  done
  for (( r = y; r <= y + h; r++ )); do
    for (( c = x + w + 1; c <= x + w + 2; c++ )); do
      (( r >= 0 && c >= 0 && r < LINES && c < COLS )) && mc_shadow_put "$r" "$c" 36
    done
  done
  wrefresh 0
  newwin "$h" "$w" "$y" "$x"; local qw=$bc_win
  wbkgdset "$qw" ' ' 0 23
  local buf="" caret=0 redraw=1
  qc_draw() {
    wattrset "$qw" 0 23; werase "$qw"; box "$qw"
    local tstr=" Quick cd "
    local tx=$(( (w - ${#tstr}) / 2 )); (( tx < 1 )) && tx=1
    wattrset "$qw" 0 24; mvwaddstr "$qw" 0 "$tx" "$tstr"
    wattrset "$qw" 0 23; mvwaddstr "$qw" 1 2 "cd "
    wattrset "$qw" 0 25; mvwhline "$qw" 1 5 ' ' "$(( w - 7 ))"
    (( caret > ${#buf} )) && caret=${#buf}; (( caret < 0 )) && caret=0
    wmove "$qw" 1 $(( 5 + caret ))
    wrefresh "$qw"
  }
  qc_draw
  while :; do
    wgetch "$qw" || break
    case $key in
      $'\r')
        local target="$buf"
        target="${target//\"/}"
        target="${target/#~/$HOME}"
        target="${target## }"
        [[ -z $target ]] && target="$HOME"
        if [[ -d $target ]]; then
          DIR[$CUR]="$target"; list_dir "$CUR"
        else
          message_dialog "cd" "Not a directory: $target"
        fi
        delwin "$qw"; return 0
        ;;
      $'\x1b'|$KEY_F10) delwin "$qw"; return 1 ;;
      $'\x7f'|$'\x08')
        if (( caret > 0 )); then
          buf="${buf:0:caret-1}${buf:caret}"
          caret=$(( caret - 1 ))
        fi
        redraw=1 ;;
      $KEY_LEFT) (( caret > 0 )) && caret=$(( caret - 1 )); redraw=1 ;;
      $KEY_RIGHT) (( caret < ${#buf} )) && caret=$(( caret + 1 )); redraw=1 ;;
      *)
        if [[ ${#key} == 1 && ${key:0:1} == [[:print:]] ]]; then
          buf="${buf:0:caret}${key}${buf:caret}"
          caret=$(( caret + 1 ))
          redraw=1
        fi
        ;;
    esac
    (( redraw )) && qc_draw
  done
  delwin "$qw"
  return 1
}

cmd_history_popup() {
  local -a items=("$@")
  local n=${#items[@]} sel=0 maxl=0 e
  for e in "${items[@]}"; do (( ${#e} > maxl )) && maxl=${#e}; done
  local w=$(( maxl + 6 )); (( w < 13 )) && w=13; (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  local h=$(( n + 3 )); (( h < 4 )) && h=4
  local maxh=$(( LINES - 4 )); (( h > maxh )) && h=$maxh
  local visible=$(( h - 2 )); (( visible < 1 )) && visible=1
  local top=$(( n < visible ? n - visible : 0 ))
  local y=$(( LINES - 6 )); (( y < 1 )) && y=1
  local x=$(( (COLS - w) / 2 + 5 )); (( x < 1 )) && x=1
  local r c
  for (( r = y + 1; r <= y + h - 2; r++ )); do
    for (( c = x + w; c <= x + w + 1; c++ )); do
      (( r >= 0 && c >= 0 && r < LINES && c < COLS )) && mc_shadow_put "$r" "$c" 36
    done
  done
  cmdline_prompt
  local cl=${#CMD_PROMPT}
  for (( c = cl; c < cl + w && c < COLS; c++ )); do
    mvwinch 0 "$CMY" "$c"
    [[ $wch == ' ' ]] && mc_shadow_put "$CMY" "$c" 36
  done
  wrefresh 0
  newwin "$h" "$w" "$y" "$x"; local hw=$bc_win
  wbkgdset "$hw" ' ' 0 23
  ch_draw() {
    wattrset "$hw" 0 23; werase "$hw"; box "$hw"
    local tstr=" History "
    local tx=$(( (w - ${#tstr}) / 2 )); (( tx < 1 )) && tx=1
    wattrset "$hw" 0 24; mvwaddstr "$hw" 0 "$tx" "$tstr"
    local i row idx e2
    for (( i = 0; i < visible; i++ )); do
      row=$(( i + 1 )); idx=$(( top + i ))
      (( idx < 0 || idx >= n )) && continue
      e2=${items[idx]}
      if (( idx == sel )); then
        wattrset "$hw" 0 30
        mvwaddnstr "$hw" "$row" 2 "$e2" "$(( w - 4 ))"
        mvwhline "$hw" "$row" $(( 2 + ${#e2} )) ' ' "$(( w - 4 - ${#e2} ))"
      else
        wattrset "$hw" 0 23
        mvwaddnstr "$hw" "$row" 2 "$e2" "$(( w - 4 ))"
      fi
    done
    wrefresh "$hw"
  }
  ch_draw
  while :; do
    wgetch "$hw" || break
    case $key in
      $KEY_UP)    (( sel > 0 )) && { sel=$(( sel - 1 )); (( sel < top )) && top=$sel; } ;;
      $KEY_DOWN)  (( sel < n - 1 )) && { sel=$(( sel + 1 )); (( sel > top + visible - 1 )) && top=$(( sel - visible + 1 )); } ;;
      $KEY_HOME)  sel=0; top=0 ;;
      $KEY_END)   sel=$(( n - 1 )); if (( n > visible )); then top=$(( n - visible )); else top=0; fi ;;
      $KEY_PPAGE) sel=$(( sel - visible )); (( sel < 0 )) && sel=0; (( sel < top )) && top=$sel ;;
      $KEY_NPAGE) sel=$(( sel + visible )); (( sel > n - 1 )) && sel=$(( n - 1 )); (( sel > top + visible - 1 )) && top=$(( sel - visible + 1 )) ;;
      $'\r')      HIST_RESULT=${items[sel]}; delwin "$hw"; return 0 ;;
      $'\x1b'|$KEY_F10) delwin "$hw"; return 1 ;;
    esac
    if (( n < visible )); then
      top=$(( n - visible ))
    else
      (( top < 0 )) && top=0
      (( top > n - visible )) && top=$(( n - visible ))
    fi
    ch_draw
  done
  delwin "$hw"
  return 1
}

do_command_history() {
  (( ${#CMDHIST[@]} )) || { message_dialog "Command history" "No commands yet."; return; }
  cmd_history_popup "${CMDHIST[@]}" || return
  CMD_LINE="$HIST_RESULT"
  CMD_CARET=${#CMD_LINE}
  draw_cmdline
  doupdate
}

do_file_history() {
  (( ${#FILEHIST[@]} )) || { message_dialog "Viewed/edited files history" "No files yet."; return; }
  list_dialog "Viewed/edited files history" "${FILEHIST[@]}" || return
  view_path "$LIST_RESULT"
}

do_hotlist() {
  (( ${#DIRHIST[@]} )) || { message_dialog "Directory hotlist" "No directories yet."; return; }
  list_dialog "Directory hotlist" "${DIRHIST[@]}" || return
  DIR[$CUR]="$LIST_RESULT"
  list_dir "$CUR"
}

do_vfs_list() {
  message_dialog "Active VFS list" "No active VFS mounts."
}

do_background_jobs() {
  # mc "Background jobs" (C-x j): empty job list + Stop/Resume/Kill/OK.
  local w=58 h=13
  mc_dialog "$w" "$h" "Background jobs" 0 8
  # mc highlights the (empty) list-cursor row black-on-cyan, leaving a 3-col
  # scrollbar gutter on the right.
  wattrset "$dw" 0 29
  mvwaddstr "$dw" 1 2 "$(printf '%*s' 52 '')"
  dlg_divider 10
  dlg_button 11 10 "Stop"   norm 0 23 24 0
  dlg_button 11 19 "Resume" norm 0 23 24 0
  dlg_button 11 30 "Kill"   norm 0 23 24 0
  dlg_button 11 39 "OK"     ok   0 23 24 1
  wrefresh "$dw"
  while :; do
    wgetch "$dw" || break
    case $key in
      $'\r'|$'\x1b'|q|Q) break ;;
    esac
  done
  delwin "$dw"
}

do_screen_list() {
  # mc "Screens" (M-`): a cyan info box (frame pair 16, title pair 17) listing
  # the virtual screens. Only the panel screen exists, shown as a highlighted
  # (bright-yellow on black, pair 19) "Panels: [user@host]:dir" line.
  local w=68 h=3
  mc_dialog "$w" "$h" "Screens" 0 "" 16 17
  local host line pad
  host=$(printf '%s@%s' "$(id -un)" "$(hostname)")
  line="Panels: [$host]:$PWD"
  wattrset "$dw" 0 19
  mvwaddstr "$dw" 1 2 "$line"
  pad=$(( w - 4 - ${#line} ))
  (( pad > 0 )) && mvwaddstr "$dw" 1 $(( 2 + ${#line} )) "$(printf '%*s' "$pad" '')"
  wrefresh "$dw"
  while :; do
    wgetch "$dw" || break
    case $key in $'\x1b'|$'\r') break ;; esac
  done
  delwin "$dw"
}

do_undelete() {
  message_dialog "Undelete files" "Undelete is only available on ext2fs filesystems."
}

do_edit_file_kind() { # title filename
  local title=$1 file=$2
  local ed=${EDITOR:-${VISUAL:-}}
  if [[ -z $ed ]]; then
    message_dialog "$title" "No editor configured."
    return
  fi
  local path="${HOME}/.config/mc/$file"
  if [[ ! -e $path ]]; then
    message_dialog "$title" "File not found: $path"
    return
  fi
  do_edit_path "$path"
}

do_panel_options() {
  local w=44 h=10
  (( w > COLS - 4 )) && w=$(( COLS - 4 ))
  mc_dialog "$w" "$h" "Panel options" 0
  local -a ET=(hidden ext reverse sort ok cancel)
  local fi=0 cancelled=0
  local hidden=${HIDE[$CUR]} ext=${SHOWEXT[$CUR]} rev=${REV[$CUR]} sort=${SORT[$CUR]}
  po_draw() {
    wattrset "$dw" 0 23
    dlg_checkbox 1 2 "$hidden" "Show hidden files" 0 23 24 $(( fi == 0 ))
    dlg_checkbox 2 2 "$ext" "Show extension" 0 23 24 $(( fi == 1 ))
    dlg_checkbox 3 2 "$rev" "Reverse sort" 0 23 24 $(( fi == 2 ))
    wattrset "$dw" 0 23
    mvwaddstr "$dw" 4 2 "Sort order: $sort"
    dlg_button 6 9 "OK" ok 0 23 24 $(( fi == 4 ))
    dlg_button 6 20 "Cancel" plain 0 23 24 $(( fi == 5 ))
    wrefresh "$dw"
  }
  po_draw
  while :; do
    wgetch "$dw" || break
    case $key in
      $KEY_RESIZE) BC_WINCH=1; cancelled=1; break ;;
      $'\x1b') cancelled=1; break ;;
      $'\t'|$KEY_DOWN) fi=$(( (fi + 1) % ${#ET[@]} )) ;;
      $KEY_UP) fi=$(( (fi + ${#ET[@]} - 1) % ${#ET[@]} )) ;;
      $'\r')
        case ${ET[$fi]} in
          ok) break ;;
          cancel) cancelled=1; break ;;
          hidden) hidden=$(( 1 - hidden )) ;;
          ext) ext=$(( 1 - ext )) ;;
          reverse) rev=$(( 1 - rev )) ;;
          sort)
            case $sort in
              name) sort=size ;;
              size) sort=date ;;
              date) sort=name ;;
              *) sort=name ;;
            esac ;;
        esac ;;
      $' ')
        case ${ET[$fi]} in
          ok) break ;;
          cancel) cancelled=1; break ;;
          hidden) hidden=$(( 1 - hidden )) ;;
          ext) ext=$(( 1 - ext )) ;;
          reverse) rev=$(( 1 - rev )) ;;
          sort)
            case $sort in
              name) sort=size ;;
              size) sort=date ;;
              date) sort=name ;;
              *) sort=name ;;
            esac ;;
        esac ;;
      $KEY_LEFT|$KEY_RIGHT)
        case ${ET[$fi]} in
          hidden) hidden=$(( 1 - hidden )) ;;
          ext) ext=$(( 1 - ext )) ;;
          reverse) rev=$(( 1 - rev )) ;;
          sort)
            case $sort in
              name) sort=size ;;
              size) sort=date ;;
              date) sort=name ;;
              *) sort=name ;;
            esac ;;
        esac ;;
    esac
    po_draw
  done
  delwin "$dw"
  (( cancelled )) && return
  HIDE[$CUR]=$hidden
  SHOWEXT[$CUR]=$ext
  REV[$CUR]=$rev
  SORT[$CUR]=$sort
  list_dir "$CUR"
}

do_configuration() {
  message_dialog "Configuration" \
    "Sort order: ${SORT[$CUR]}" \
    "Reverse sort: $(( REV[$CUR] ))" \
    "Show hidden files: $(( HIDE[$CUR] ))" \
    "Show extension: $(( SHOWEXT[$CUR] ))" \
    "Panel filter: ${FILTERS[$CUR]:-none}"
}

do_layout() {
  message_dialog "Layout" "Layout changes are not implemented."
}

do_confirmation() {
  message_dialog "Confirmation" "Confirmation settings are not implemented."
}

do_appearance() {
  message_dialog "Appearance" "Appearance settings are not implemented."
}

do_display_bits() {
  message_dialog "Display bits" "Display bits settings are not implemented."
}

do_learn_keys() {
  message_dialog "Learn keys" "Key learning is not implemented."
}

do_virtual_fs() {
  message_dialog "Virtual FS" "Virtual FS settings are not implemented."
}

do_save_setup() {
  message_dialog "Save setup" "Saving setup is not implemented."
}

do_switch_panels() {
  message_dialog "Switch panels on/off" "Panel visibility is not implemented."
}

do_external_panelize() {
  message_dialog "External panelize" "External panelize is not implemented."
}

do_sort_cycle() { # Left/Right "Sort order...": cycle name -> size -> date
  local cur=${SORT[$CUR]:-name}
  case $cur in
    name) SORT[$CUR]=size ;;
    size) SORT[$CUR]=date ;;
    date) SORT[$CUR]=name ;;
    *)    SORT[$CUR]=name ;;
  esac
  list_dir "$CUR"
}

do_show_sizes() {
  local kb
  kb=$(du -sk "${DIR[$CUR]}" 2>/dev/null | awk '{print $1}')
  message_dialog "Directory size" "${DIR[$CUR]}" "Total: $(hum "${kb:-0}")"
}

do_compare_dirs() {
  # mc "Compare directories" (C-x d): a method-choice dialog.
  local w=56 h=5
  mc_dialog "$w" "$h" "Compare directories" 0 9
  wattrset "$dw" 0 23
  local msg="Select compare method:"
  mvwaddstr "$dw" 1 $(( (w - ${#msg}) / 2 )) "$msg"
  dlg_divider 2
  dlg_button 3 3  "Quick"     norm 0 23 24 1
  dlg_button 3 14 "Size only" norm 0 23 24 0
  dlg_button 3 29 "Thorough"  norm 0 23 24 0
  dlg_button 3 43 "Cancel"    norm 0 23 24 0
  wrefresh "$dw"
  local method=""
  while [[ -z $method ]]; do
    wgetch "$dw" || break
    case $key in
      $'\x1b'|q|Q) method="cancel" ;;
      $'\r')       method="quick" ;;
      $KEY_MOUSE)
        while getmouse; do
          if   dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 3 3  "Quick"     norm; then method="quick"
          elif dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 3 14 "Size only" norm; then method="size"
          elif dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 3 29 "Thorough"  norm; then method="thorough"
          elif dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 3 43 "Cancel"    norm; then method="cancel"
          fi
        done
        ;;
    esac
  done
  delwin "$dw"
  [[ $method == cancel || -z $method ]] && return
  compare_dirs_mark "$method"
}

# Mark entries that differ between the two panels. mc colors differing entries;
# we approximate by re-listing both panels (the visual marking is a follow-up).
compare_dirs_mark() { # method
  list_dir 0; list_dir 1
}

do_filtered_view() {
  # mc "Filtered view" (M-!): a filter-command input dialog.
  local w=48 h=6
  mc_dialog "$w" "$h" "Filtered view" 0
  wattrset "$dw" 0 23
  mvwaddstr "$dw" 1 2 "Filter command and arguments:"
  dlg_divider 3
  dlg_button 4 14 "OK"     ok   0 23 24 0
  dlg_button 4 23 "Cancel" norm 0 23 24 0
  local buf=".." caret=2 res=""
  while [[ -z $res ]]; do
    dlg_field 2 2 44 "$buf" "$caret" 1 1
    wrefresh "$dw"
    wgetch "$dw" || break
    case $key in
      $'\r') res="ok" ;;
      $'\x1b') res="cancel" ;;
      $'\x7f'|$'\x08') (( caret > 0 )) && { buf="${buf:0:caret-1}${buf:caret}"; (( caret-- )); } ;;
      $KEY_LEFT)  (( caret > 0 )) && (( caret-- )) ;;
      $KEY_RIGHT) (( caret < ${#buf} )) && (( caret++ )) ;;
      $KEY_MOUSE)
        while getmouse; do
          if   dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 4 14 "OK"     ok;   then res="ok"
          elif dlg_hit_button "$dw" "$BC_ME_Y" "$BC_ME_X" 4 23 "Cancel" norm; then res="cancel"
          fi
        done
        ;;
      *) if [[ ${#key} == 1 && $key == [[:print:]] ]]; then buf="${buf:0:caret}$key${buf:caret}"; (( caret++ )); fi ;;
    esac
  done
  delwin "$dw"
  # Applying the filter to produce a filtered listing is a follow-up feature.
}

do_encoding() {
  # mc "Choose codepage" (M-e): a cyan listbox (like the F2 user menu), not a
  # white dialog. Frame/interior pair 16 (white on cyan), title pair 17 (bright
  # yellow on cyan), the current codepage highlighted pair 19 (bright yellow on
  # black), other rows pair 16. mc_dialog draws the cyan halo + offset shadow.
  local w=34 h=16
  mc_dialog "$w" "$h" "Choose codepage" 0 "" 16 17
  local -a keys=('-' 0 1 2 3 4 5 6 7 8 9 a b c)
  local -a names=("< No translation >" "7-bit ASCII" "ISO 8859-1" "ISO 8859-2" \
    "ISO 8859-5" "Windows 1250" "Windows 1251" "CP 437" "CP 850" "CP 852" \
    "CP 866" "KOI8-R" "KOI8-U" "UTF-8")
  local i line
  for i in "${!keys[@]}"; do
    if (( i == 0 )); then
      wattrset "$dw" 0 19
      line="${keys[i]}  ${names[i]}"
      while (( ${#line} < w - 4 )); do line+=" "; done
      mvwaddstr "$dw" $(( i + 1 )) 2 "$line"
    else
      wattrset "$dw" 0 16
      mvwaddstr "$dw" $(( i + 1 )) 2 "${keys[i]}"
      mvwaddstr "$dw" $(( i + 1 )) 5 "${names[i]}"
    fi
  done
  wrefresh "$dw"
  while :; do
    wgetch "$dw" || break
    case $key in $'\x1b'|$'\r') break ;; esac
  done
  delwin "$dw"
}

do_exchange() {
  local t=${DIR[0]}
  DIR[0]=${DIR[1]}; DIR[1]=$t
  list_dir 0; list_dir 1
}

do_sort() { # key
  SORT[$CUR]=$1
  list_dir "$CUR"
}

do_reverse() {
  REV[$CUR]=$(( 1 - REV[$CUR] ))
  list_dir "$CUR"
}

dialog_margin_shadow() { # x y w h margin_pair
  local x=$1 y=$2 w=$3 h=$4 mp=$5 pad r p lr px lc0 lc1 sr sc
  printf -v pad '%*s' "$(( w + 2 ))" ''
  for (( r = y - 1; r <= y + h; r++ )); do
    for p in 0 1; do
      lr=$(( r - 1 ))
      (( lr < 0 || lr >= PH )) && continue
      px=$(( p * PW ))
      lc0=$(( x - 1 - px )); lc1=$(( x + w - px ))
      (( lc0 < 0 )) && lc0=0
      (( lc1 >= PW )) && lc1=$(( PW - 1 ))
      (( lc0 <= lc1 )) || continue
      wattrset "${WIN[$p]}" 0 "$mp"
      mvwaddstr "${WIN[$p]}" "$lr" "$lc0" "${pad:0:$(( lc1 - lc0 + 1 ))}"
    done
  done
  for p in 0 1; do
    px=$(( p * PW ))
    for (( sr = y; sr <= y + h + 1; sr++ )); do
      lr=$(( sr - 1 ))
      (( lr < 0 || lr >= PH )) && continue
      for sc in $(( x + w + 1 )) $(( x + w + 2 )); do
        lc0=$(( sc - px ))
        (( lc0 < 0 || lc0 >= PW )) && continue
        wmove "${WIN[$p]}" "$lr" "$lc0" && wchgat "${WIN[$p]}" 1 0 36
      done
    done
    lr=$(( y + h ))
    (( lr >= 0 && lr < PH )) || continue
    lc0=$(( x + 1 - px )); lc1=$(( x + w + 2 - px ))
    (( lc0 < 0 )) && lc0=0
    (( lc1 >= PW )) && lc1=$(( PW - 1 ))
    (( lc0 <= lc1 )) || continue
    wmove "${WIN[$p]}" "$lr" "$lc0" && wchgat "${WIN[$p]}" $(( lc1 - lc0 + 1 )) 0 36
  done
  wrefresh "${WIN[0]}"
  wrefresh "${WIN[1]}"
}

fkey_help() {
  # MC "Help" dialog: the MC logo + version + intro text, centered over the panels.
  # (MC's interactive help browser opened by Enter is out of scope for this port.)
  local -a c=(
" ┌─┬─┐     ┐           ┐                                                        "
" │ │ │ .   │     .     │                                                        "
" │ │ │ ┐ ┌─┤ ┬─┐ ┐ ┌─┬ ├─┐ ┼                                                    "
" │ │ │ │ │ │ │ │ │ │ │ │ │ │                                                    "
" ┴   ┴ ┴ └─┴ ┴ ┴ ┴ └─┤ ┴ ┴ └┘                                                   "
"     ──────Commander─┘ 4.8.33                                                   "
"                                                                                "
"This is the main help screen for GNU Midnight Commander.                        "
"                                                                                "
"To learn more on how to use the interactive help facility just press Enter.     "
"You may want to go directly to the help contents.                               "
"                                                                                "
"GNU Midnight Commander is written by its authors.                               "
"                                                                                "
"GNU Midnight Commander comes with ABSOLUTELY NO WARRANTY. This is free          "
"software, and you are welcome to redistribute it under terms of GNU General     "
"Public License.                                                                 "
"                                                                                "
"                                                                                "
"                                                                                "
  )
  local h=$(( ${#c[@]} + 2 )) w=82 x y hw i
  x=$(( (COLS - w) / 2 )); y=$(( 1 + (PH - h) / 2 ))
  (( x < 1 )) && x=1; (( y < 1 )) && y=1
  (( w > COLS - 2 )) && w=$(( COLS - 2 ))
  (( h > 1 + PH )) && h=$(( 1 + PH ))
  dialog_margin_shadow "$x" "$y" "$w" "$h" 13
  # button bar switches to the Help context while the dialog is up
  draw_buttonbar Help Index Prev "" "" "" "" "" "" Quit
  wrefresh 0
  newwin "$h" "$w" "$y" "$x"; hw=$bc_win
  # MC draws the whole Help dialog on a white background: black border/text,
  # blue title and the "Commander" word in the logo.
  wattrset "$hw" 0 13
  werase "$hw"; box "$hw"
  wattrset "$hw" 0 20
  mvwaddstr "$hw" 0 "$(( (w - 6) / 2 ))" " Help "
  wattrset "$hw" 0 13
  for (( i = 0; i < ${#c[@]}; i++ )); do
    mvwaddstr "$hw" "$(( i + 1 ))" 1 "${c[$i]:0:$(( w - 2 ))}"
  done
  # the "Commander" word in the logo is blue (logo bottom row is content index 5)
  local prefix=${c[5]%%Commander*}
  wattrset "$hw" 0 20
  mvwaddstr "$hw" 6 "$(( 1 + ${#prefix} ))" "Commander"
  # the first "GNU Midnight Commander" (intro line, content index 7) is blue
  local p7=${c[7]%%GNU Midnight Commander*}
  mvwaddstr "$hw" 8 "$(( 1 + ${#p7} ))" "GNU Midnight Commander"
  # Emphasized words in the help body, matching mc's help-text colours:
  # the "Enter" key is bright-cyan/blue (pair 21); the other highlighted
  # words are black-on-cyan (pair 6).
  local _li _pre
  _hl() { _li=$1 _pre=${c[$1]%%"$2"*}; wattrset "$hw" 0 "$3"; mvwaddstr "$hw" "$((_li + 1))" "$(( 1 + ${#_pre} ))" "$2"; }
  _hl 9  "Enter"          21
  _hl 10 "contents"       6
  _hl 12 "authors"        6
  _hl 14 "WARRANTY"       6
  _hl 15 "GNU General "   6
  _hl 16 "Public License" 6
  wattrset "$hw" 0 13
  wrefresh "$hw"
  wgetch "$hw" || :
  delwin "$hw"
}

user_menu() {
  # MC "User menu" dialog (F2): a centered list of user-defined commands.
  # Border is bright-white/cyan (pair 16), title bright-cyan/cyan (pair 17),
  # the cursor item bright-cyan/black (pair 19), other items pair 16.
  # MC opens the cursor on the 4th item (index 3). Button bar/hint unchanged.
  local -a items=(
    "@ Do something on the current file"
    "0 Edit a bug report and send it to root"
    "2 Call the info hypertext browser"
    "3 Compress the current subdirectory (tar.gz)"
    "4 Compress the current subdirectory (tar.bz2)"
    "5 Compress the current subdirectory (tar.7z)"
    "6 Compress the current subdirectory (tar.xz)"
    "7 Compress the current subdirectory (tar.zst)"
    "8 Compress the current subdirectory (tar.lzo)"
    "m View manual page"
    "n Inspect gzip'ed newsbatch file"
    "h Strip headers from current newsarticle"
    "r Copy file to remote host"
    "y Gzip or gunzip current file"
    "b Bzip2 or bunzip2 current file"
    "o Open next a free console"
  )
  local n=${#items[@]} w=64 x y hw cur=3 i mk desc line
  local h=$(( n + 2 ))
  x=$(( (COLS - w) / 2 )); y=$(( (LINES - 3 - h) / 2 ))
  (( x < 1 )) && x=1; (( y < 1 )) && y=1
  (( w > COLS - 2 )) && w=$(( COLS - 2 ))
  (( h > 1 + PH )) && h=$(( 1 + PH ))
  dialog_margin_shadow "$x" "$y" "$w" "$h" 16
  newwin "$h" "$w" "$y" "$x"; hw=$bc_win
  wbkgdset "$hw" ' ' 0 16
  while :; do
    wattrset "$hw" 0 16
    werase "$hw"; box "$hw"
    wattrset "$hw" 0 17
    mvwaddstr "$hw" 0 "$(( (w - 11) / 2 ))" " User menu "
    for (( i = 0; i < n; i++ )); do
      mk=${items[i]%% *}; desc=${items[i]#* }
      # Leading margin space always in the normal item colour.
      wattrset "$hw" 0 16
      mvwaddch "$hw" "$(( i + 1 ))" 1 " "
      if (( i == cur )); then
        # Selected item: mnemonic + description, padded to the right border,
        # in the highlight colour (pair 19).
        wattrset "$hw" 0 19
        line="${mk}       ${desc}"
        while (( ${#line} < w - 4 )); do line+=" "; done
        mvwaddstr "$hw" "$(( i + 1 ))" 2 "$line"
      else
        wattrset "$hw" 0 16
        mvwaddstr "$hw" "$(( i + 1 ))" 2 "${mk}       ${desc}"
      fi
    done
    wrefresh "$hw"
    wgetch "$hw" || break
    case $key in
      $KEY_UP)      (( cur > 0 )) && cur=$(( cur - 1 )) ;;
      $KEY_DOWN)    (( cur < n - 1 )) && cur=$(( cur + 1 )) ;;
      $'\r'|$'\x1b'|"q"|"Q") break ;;
      $KEY_RESIZE) BC_WINCH=1; break ;;
      $KEY_MOUSE)
        while getmouse; do
          if (( BC_ME_BSTATE & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
            local row=$(( BC_ME_Y - y - 1 ))
            if (( row >= 0 && row < n && BC_ME_X >= x && BC_ME_X < x + w )); then
              cur=$row
              break 2
            fi
          fi
        done
        ;;
      *) : ;;
    esac
  done
  delwin "$hw"
}

about_mc() {
  message_dialog "About mc (bash port)" \
    "A Midnight Commander-style file manager" \
    "written in bash on lib/bc.sh." \
    "Dual panels, command line, F-key actions."
}

# ------------------------------------------------------------------ mouse input
mouse_panel_entry() { # p y x -> MC_MOUSE_IDX
  local p=$1 y=$2 x=$3
  local win=${WIN[$p]} wy wx h w rows idx
  wmouse_trafo "${WIN[$p]}" "$y" "$x" 0 || { MC_MOUSE_IDX=-1; return 1; }
  wy=$BC_MT_Y; wx=$BC_MT_X
  getmaxyx "$win"; h=$BC_GMY; w=$BC_GMX
  rows=$(( h - 5 ))
  if (( wy >= 2 && wy < 2 + rows && wx >= 1 && wx < w - 1 )); then
    idx=$(( OFF[$p] + wy - 2 ))
    local -n NN=NAMES_$p
    if (( idx >= 0 && idx < ${#NN[@]} )); then
      MC_MOUSE_IDX=$idx
      return 0
    fi
  fi
  MC_MOUSE_IDX=-1
  return 1
}

handle_panel_mouse() { # y x bstate
  local y=$1 x=$2 b=$3 p=-1 q idx old_cur prev_pos
  for q in 0 1; do
    if wenclose "${WIN[$q]}" "$y" "$x"; then
      p=$q
      break
    fi
  done
  (( p < 0 )) && return 1

  if (( b & (BUTTON4_PRESSED | BUTTON4_CLICKED | BUTTON5_PRESSED | BUTTON5_CLICKED) )); then
    local -n NN=NAMES_$p
    local n=${#NN[@]} oldpos
    if (( n == 0 )); then
      if (( p != CUR )); then
        old_cur=$CUR
        CUR=$p
        switch_panel "$old_cur"
      fi
      return 0
    fi
    clamp_pos "$p"
    oldpos=${POS[$p]}
    if (( b & (BUTTON4_PRESSED | BUTTON4_CLICKED) )); then
      (( POS[$p] > 0 )) && POS[$p]=$(( POS[$p] - 1 ))
    else
      (( POS[$p] < n - 1 )) && POS[$p]=$(( POS[$p] + 1 ))
    fi
    if (( p != CUR )); then
      old_cur=$CUR
      CUR=$p
      switch_panel "$old_cur"
    fi
    if (( POS[$p] != oldpos )); then
      update_selection "$p" "$oldpos" || { draw_panel "$p"; wrefresh "${WIN[$p]}"; }
    fi
    return 0
  fi

  if (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
    if mouse_panel_entry "$p" "$y" "$x"; then
      idx=$MC_MOUSE_IDX
    else
      idx=-1
    fi
    if (( p != CUR )); then
      old_cur=$CUR
      prev_pos=${POS[$p]}
      CUR=$p
      switch_panel "$old_cur"
      if (( idx >= 0 && POS[$p] != idx )); then
        POS[$p]=$idx
        update_selection "$p" "$prev_pos" || { draw_panel "$p"; wrefresh "${WIN[$p]}"; }
      fi
    else
      prev_pos=${POS[$p]}
      if (( idx >= 0 && POS[$p] != idx )); then
        POS[$p]=$idx
        update_selection "$p" "$prev_pos" || { draw_panel "$p"; wrefresh "${WIN[$p]}"; }
      fi
    fi
    if (( idx >= 0 && (b & (BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED)) )); then
      do_open
    fi
    return 0
  fi

  if (( b & BUTTON1_PRESSED )); then
    MC_MOUSE_DRAG=1
  fi
  if (( b & BUTTON1_RELEASED )); then
    MC_MOUSE_DRAG=0
    return 0
  fi
  if (( b & REPORT_MOUSE_POSITION )) && (( MC_MOUSE_DRAG )); then
    if mouse_panel_entry "$p" "$y" "$x"; then
      idx=$MC_MOUSE_IDX
    else
      idx=-1
    fi
    if (( idx >= 0 )); then
      if (( p != CUR )); then
        old_cur=$CUR
        prev_pos=${POS[$p]}
        CUR=$p
        switch_panel "$old_cur"
        if (( POS[$p] != idx )); then
          POS[$p]=$idx
          update_selection "$p" "$prev_pos" || { draw_panel "$p"; wrefresh "${WIN[$p]}"; }
        fi
      else
        prev_pos=${POS[$p]}
        if (( POS[$p] != idx )); then
          POS[$p]=$idx
          update_selection "$p" "$prev_pos" || { draw_panel "$p"; wrefresh "${WIN[$p]}"; }
        fi
      fi
    fi
    return 0
  fi

  return 1
}

handle_buttonbar_mouse() { # y x bstate
  local y=$1 x=$2 b=$3 num
  (( y != BTNY )) && return 1
  (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 1
  num=$(( x / 10 ))
  (( num < 0 || num > 9 )) && return 1
  case $num in
    0) fkey_help ;;
    1) user_menu ;;
    2) do_view ;;
    3) do_edit ;;
    4) do_copy ;;
    5) do_move ;;
    6) do_mkdir ;;
    7) do_delete ;;
    8) run_menu 0 1 ;;
    9) STOP=1 ;;
    *) return 1 ;;
  esac
  return 0
}

handle_cmdline_mouse() { # y x bstate
  local y=$1 x=$2 b=$3 col
  (( y != CMY )) && return 1
  (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 1
  cmdline_prompt
  col=$(( x - ${#CMD_PROMPT} ))
  (( col < 0 )) && col=0
  (( col > ${#CMD_LINE} )) && col=${#CMD_LINE}
  CMD_CARET=$col
  draw_cmdline
  doupdate
  return 0
}

menu_bar_hit() { # y x -> MC_MOUSE_MENU
  local y=$1 x=$2 i name len
  MC_MOUSE_MENU=-1
  (( y != 0 )) && return 1
  for i in "${!MENUNAMES[@]}"; do
    name=${MENUNAMES[$i]}
    len=${#name}
    if (( x >= MENU_X[i] && x < MENU_X[i] + len )); then
      MC_MOUSE_MENU=$i
      return 0
    fi
  done
  return 1
}

menu_mouse_handle() { # y x bstate
  local y=$1 x=$2 b=$3 i row ridx e ri k
  MC_MOUSE_CHOOSE=0
  (( b & (BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 1

  if menu_bar_hit "$y" "$x"; then
    menu_bar_sel=$MC_MOUSE_MENU
    menu_sel=0
    MENU_TOP=0
    menu_dd=1
    menu_real_n "$menu_bar_sel"
    draw_menu
    draw_panel 0
    draw_panel 1
    menu_dd_open
    return 0
  fi

  if (( menu_dd && MENU_WIN > 0 )); then
    if (( y >= MENU_GY && y < MENU_GY + MENU_GH && x >= MENU_GX && x < MENU_GX + MENU_BW )); then
      row=$(( y - MENU_GY ))
      (( row <= 0 || row >= MENU_GH - 1 )) && return 0
      ridx=$(( MENU_TOP + row - 1 ))
      (( ridx < 0 || ridx >= MENU_NROWS )) && return 0
      e=${MENU_ROWS[$ridx]}
      [[ $e == SEP ]] && return 0
      ri=0
      for (( k = 0; k <= ridx; k++ )); do
        [[ ${MENU_ROWS[$k]} != SEP ]] && (( ri++ ))
      done
      menu_sel=$(( ri - 1 ))
      MC_MOUSE_CHOOSE=1
      return 0
    fi
  fi

  return 1
}

run_menu() {
  menu_open=1; menu_bar_sel=${1:-0}; menu_dd=${2:-0}; menu_sel=0
  local nmb=${#MENUNAMES[@]} chosen=""
  menu_real_n "$menu_bar_sel"
  draw_menu
  draw_panel 0; draw_panel 1
  (( menu_dd )) && menu_dd_open
  doupdate
  while :; do
    wgetch 0 || break
    case $key in
      $KEY_LEFT)
        menu_bar_sel=$(( (menu_bar_sel + nmb - 1) % nmb )); menu_sel=0; MENU_TOP=0
        menu_real_n "$menu_bar_sel"
        draw_menu
        (( menu_dd )) && { menu_dd_close; menu_dd_open; }
        ;;
       $KEY_RIGHT)
         menu_bar_sel=$(( (menu_bar_sel + 1) % nmb )); menu_sel=0; MENU_TOP=0
         menu_real_n "$menu_bar_sel"
         draw_menu
         (( menu_dd )) && { menu_dd_close; menu_dd_open; }
         ;;
        $KEY_RESIZE) do_resize ;;
        $KEY_MOUSE)
          while getmouse; do
            if menu_mouse_handle "$BC_ME_Y" "$BC_ME_X" "$BC_ME_BSTATE"; then
              if (( MC_MOUSE_CHOOSE )); then
                menu_entry_at "$menu_bar_sel" "$menu_sel"; chosen="$ENTRY"
                menu_open=0; menu_dd=0; draw_menu; menu_dd_close; break 2
              fi
            else
              menu_open=0; menu_dd=0; draw_menu; menu_dd_close; break 2
            fi
          done
          ;;
        $KEY_DOWN)
          if (( menu_dd == 0 )); then
            MENU_TOP=0; menu_dd=1; menu_sel=0
            draw_panel 0; draw_panel 1
            menu_dd_open
          else
           menu_sel=$(( (menu_sel + 1) % REALN ))
           menu_dd_open
         fi
         ;;
       $KEY_UP)
         if (( menu_dd == 1 )); then
            if (( menu_sel == 0 )); then
              menu_dd=0; menu_dd_close
              draw_panel 0; draw_panel 1
            else
              menu_sel=$(( menu_sel - 1 ))
              menu_dd_open
            fi
          else
            MENU_TOP=0; menu_dd=1; menu_sel=0
            draw_panel 0; draw_panel 1
            menu_dd_open
          fi
         ;;
       $'\r')
          if (( menu_dd == 0 )); then
            MENU_TOP=0; menu_dd=1; menu_sel=0
            draw_panel 0; draw_panel 1
            menu_dd_open
          else
           menu_entry_at "$menu_bar_sel" "$menu_sel"; chosen="$ENTRY"
           menu_open=0; menu_dd=0; draw_menu; menu_dd_close; break
         fi
         ;;
       $'\x1b') menu_open=0; menu_dd=0; draw_menu; menu_dd_close; break ;;
       [a-zA-Z])
         local ch=${key,,} ri lf
         if (( menu_dd == 1 )); then
           local old=$menu_sel
           for (( ri = 0; ri < REALN; ri++ )); do
              menu_entry_at "$menu_bar_sel" "$ri"; lf=${ENTRY##*|}; lf=${lf%%:*}; lf=${lf,,}
             [[ $lf == "$ch" ]] && { menu_sel=$ri; break; }
           done
           (( old != menu_sel )) && menu_dd_open
         else
           for (( ri = 0; ri < nmb; ri++ )); do
             lf=${MENUNAMES[ri]:0:1}; lf=${lf,,}
             [[ $lf == "$ch" ]] && { menu_bar_sel=$ri; menu_sel=0; MENU_TOP=0; break; }
           done
           menu_real_n "$menu_bar_sel"
           draw_menu
         fi
         ;;
    esac
    doupdate
  done
  menu_open=0; menu_dd=0
  menu_dd_close
  draw_all
  doupdate
  [[ -z $chosen ]] && return
  local label=${chosen%%|*} name=${MENUNAMES[$menu_bar_sel]}
  case $name in
    Left|Right)
      case $label in
        "Quick view")    do_view ;;
        "Info")          do_info ;;
        "Tree")          do_tree ;;
        "Sort order...") do_sort_cycle ;;
        "Filter...")     do_filter ;;
        "Rescan")        do_rescan ;;
        *)               message_dialog "$name" "Not implemented: $label" ;;
      esac ;;
    File)
      case $label in
        "View")          do_view ;;
        "View file...")  do_view_file ;;
        "Filtered view") do_filtered_view ;;
        "Edit")          do_edit ;;
        "Copy")          do_copy ;;
        "Chmod")         do_chmod ;;
        "Link")          do_link ;;
        "Symlink")       do_symlink ;;
        "Relative symlink") do_relative_symlink ;;
        "Edit symlink")  do_edit_symlink ;;
        "Chown")         do_chown ;;
        "Advanced chown") do_advanced_chown ;;
        "Chattr")        do_chattr ;;
        "Rename/Move")   do_move ;;
        "Mkdir")         do_mkdir ;;
        "Delete")        do_delete ;;
        "Quick cd")      focus_cmdline ;;
        "Select group")  do_select_group ;;
        "Unselect group") do_unselect_group ;;
        "Invert selection") do_invert_selection ;;
        "Exit")          STOP=1 ;;
        *)              message_dialog "File" "Not implemented: $label" ;;
      esac ;;
    Command)
      case $label in
        "User menu")            user_menu ;;
        "Directory tree")       do_tree ;;
        "Find file")            do_find_file ;;
        "Swap panels")          do_swap_panels; draw_all; doupdate ;;
        "Switch panels on/off") do_switch_panels ;;
        "Compare directories")  do_compare_dirs ;;
        "Compare files")        do_compare_files ;;
        "External panelize")    do_external_panelize ;;
        "Show directory sizes") do_show_sizes ;;
        "Command history")      do_command_history ;;
        "Viewed/edited files history") do_file_history ;;
        "Directory hotlist")    do_hotlist ;;
        "Active VFS list")      do_vfs_list ;;
        "Background jobs")      do_background_jobs ;;
        "Screen list")          do_screen_list ;;
        "Undelete files (ext2fs only)") do_undelete ;;
        "Edit extension file")  do_edit_file_kind "Edit extension file" "mc.ext" ;;
        "Edit menu file")       do_edit_file_kind "Edit menu file" "mc.menu" ;;
        "Edit highlighting group file") do_edit_file_kind "Edit highlighting group file" "mc.hint" ;;
        *)                     message_dialog "Command" "Not implemented: $label" ;;
      esac ;;
    Options)
      case $label in
        "Configuration...") do_configuration ;;
        "Layout...")        do_layout ;;
        "Panel options...") do_panel_options ;;
        "Confirmation...")  do_confirmation ;;
        "Appearance...")    do_appearance ;;
        "Display bits...")  do_display_bits ;;
        "Learn keys...")    do_learn_keys ;;
        "Virtual FS...")    do_virtual_fs ;;
        "Save setup")       do_save_setup ;;
        *)                  message_dialog "Options" "Not implemented: $label" ;;
      esac ;;
   esac
 }

 focus_cmdline() { # F9: focus the command line (fresh line to type a command)
  CMD_LINE=""
  CMD_CARET=0
}

execute_cmd() {
  [[ -z $CMD_LINE ]] && return
  local cmd=$CMD_LINE
  CMD_LINE=""
  CMD_CARET=0
  local -a nh=("$cmd") e
  for e in "${CMDHIST[@]}"; do [[ $e != "$cmd" ]] && nh+=("$e"); done
  (( ${#nh[@]} > 50 )) && nh=("${nh[@]:0:50}")
  CMDHIST=("${nh[@]}")
  if [[ $cmd =~ ^cd[[:space:]]*(.*)$ ]]; then
    local target="${BASH_REMATCH[1]//\"/}"
    target=${target/#~/$HOME}
    if [[ -z $target ]]; then target="$HOME"; fi
    if [[ -d $target ]]; then
      DIR[$CUR]=$target; list_dir "$CUR"
    else
      draw_cmdline
      doupdate
      message_dialog "cd" "Not a directory: $target"
    fi
    return
  fi
  case $cmd in
    exit|quit) STOP=1; return ;;
  esac
  draw_cmdline
  doupdate
  (cd "${DIR[$CUR]}" 2>/dev/null && eval "$cmd") >/dev/null 2>&1
}

# visible entry-row count for panel p (window height minus border/header/footer)
page_rows() { # p -> rows
  local win=${WIN[$1]}
  getmaxyx "$win"; echo $(( BC_GMY - 5 ))
}

# clamp POS[p] into [0, entry count - 1]
clamp_pos() { # p
  local p=$1
  local -n _NN=NAMES_$p
  local n=${#_NN[@]}
  (( POS[$p] < 0 )) && POS[$p]=0
  (( POS[$p] > n - 1 )) && POS[$p]=$(( n - 1 ))
  return 0
}

# Handle a terminal resize (SIGWINCH -> KEY_RESIZE): re-read the size, tear
# down and rebuild both panels at the new geometry, and force a full repaint.
do_resize() {
  local p vis
  (( LINES < 5 || COLS < 20 )) && return 0
  (( MENU_WIN > 0 )) && menu_dd_close
  del_panel "${PANEL[0]}" 2>/dev/null; delwin "${WIN[0]}"
  del_panel "${PANEL[1]}" 2>/dev/null; delwin "${WIN[1]}"
  resizeterm
  BC_DELRECTS=""
  layout_bottom
  PW=$(( COLS / 2 )); (( PW < 10 )) && PW=10
  newwin "$PH" "$PW" 1 0; WIN[0]=$bc_win; new_panel "${WIN[0]}"; PANEL[0]=$bc_panel
  newwin "$PH" "$PW" 1 "$PW"; WIN[1]=$bc_win; new_panel "${WIN[1]}"; PANEL[1]=$bc_panel
  for p in 0 1; do
    clamp_pos "$p"
    vis=$(page_rows "$p"); (( vis < 1 )) && vis=1
    (( POS[$p] < OFF[$p] )) && OFF[$p]=$(( POS[$p] ))
    (( POS[$p] >= OFF[$p] + vis )) && OFF[$p]=$(( POS[$p] - vis + 1 ))
    (( OFF[$p] < 0 )) && OFF[$p]=0
  done
  draw_all
  BC_FORCEFULL=1
  doupdate
}

# ------------------------------------------------------------------ main
layout_bottom() {
  HINTBAR=${MC_HINTBAR:-1}
  case $HINTBAR in
    0|false|no)
      HINTBAR=0
      PH=$(( LINES - 3 )); (( PH < 2 )) && PH=2
      HINTY=-1
      CMY=$(( 1 + PH ))
      BTNY=$(( 1 + PH + 1 ))
      ;;
    *)
      HINTBAR=1
      PH=$(( LINES - 4 )); (( PH < 2 )) && PH=2
      HINTY=$(( 1 + PH ))
      CMY=$(( 1 + PH + 1 ))
      BTNY=$(( 1 + PH + 2 ))
      ;;
  esac
}

init_ui() {
  (( LINES < 12 || COLS < 60 )) && { echo "Terminal too small" >&2; return 1; }
  layout_bottom
  PW=$(( COLS / 2 ))
  newwin "$PH" "$PW" 1 0; WIN[0]=$bc_win; new_panel "${WIN[0]}"; PANEL[0]=$bc_panel
  newwin "$PH" "$PW" 1 "$PW"; WIN[1]=$bc_win; new_panel "${WIN[1]}"; PANEL[1]=$bc_panel
  list_dir 0; list_dir 1
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  mousemask "$(( ALL_MOUSE_EVENTS | REPORT_MOUSE_POSITION ))"
  mouseinterval 200
  start_color
  trap 'endwin' EXIT INT TERM
  trap 'BC_WINCH=1' WINCH
  # Pairs 1,9,10 are the menu bar / dropdown (left unchanged).  The rest are the
  # main-window palette, matching real Midnight Commander's colors.
  init_pair 1 "$COLOR_WHITE"   "$COLOR_BLACK"   # menu bar, hint/cmdline/buttons
  init_pair 2 15 "$COLOR_BLUE"               # directories (bright white)
  init_pair 3 10 "$COLOR_BLUE"               # executables (bright green)
  init_pair 4 "$COLOR_WHITE" "$COLOR_BLUE"   # symlinks
  init_pair 5 15 "$COLOR_BLUE"               # special files
  init_pair 6 "$COLOR_BLACK"   "$COLOR_CYAN"  # selected entry: full row (active panel)
  init_pair 7 "$COLOR_WHITE"   "$COLOR_BLUE"  # active border, dividers, status+size text
  init_pair 8 "$COLOR_WHITE"   "$COLOR_BLUE"  # inactive border
  init_pair 9 "$COLOR_BLACK"   "$COLOR_YELLOW" # active menu item / selected menu entry
  init_pair 10 "$COLOR_BLACK"  "$COLOR_CYAN"  # dropdown bg/text
  init_pair 11 "$COLOR_YELLOW" "$COLOR_BLUE"  # regular files (yellow)
  init_pair 12 11 "$COLOR_BLUE"               # column header text (bright yellow on blue)
  init_pair 13 "$COLOR_BLACK"  "$COLOR_WHITE"  # directory path in top border
  init_pair 14 "$COLOR_CYAN"   "$COLOR_BLUE"   # scripts (.sh)
  init_pair 15 15 "$COLOR_BLACK"               # button-bar numbers (bright white on black)
  # dedicated menu pairs (match mc: bright-white-on-cyan, yellow mnemonics,
  # highlighted item inverted to white-on-black)
  init_pair 16 15 "$COLOR_CYAN"               # menu bar + dropdown text/border
  init_pair 17 11 "$COLOR_CYAN"               # mnemonic letter (unselected)
  init_pair 18 15 "$COLOR_BLACK"              # highlighted item text
  init_pair 19 11 "$COLOR_BLACK"              # highlighted item mnemonic
  init_pair 20 "$COLOR_BLUE"  "$COLOR_WHITE"  # F1 Help dialog: blue title/"Commander" on white
  init_pair 21 11 "$COLOR_BLUE"               # F1 Help: "Enter" key word (bright cyan on blue)
  init_pair 22 "$COLOR_BLACK" "$COLOR_CYAN"   # menu bar, closed (black-on-cyan)
  # mc-style modal dialogs: white frame / blue title / cyan input fields, and a
  # red-framed variant for destructive (Delete) dialogs.
  init_pair 23 0 7                            # dialog frame + body + button text (black on white)
  init_pair 24 4 7                            # dialog title + mnemonics (blue on white)
  init_pair 25 8 6                            # dialog input fields (bright-black on cyan)
  init_pair 26 15 1                           # destructive dialog frame/body (bright-white on red)
  init_pair 27 11 1                           # destructive dialog title (bright-yellow on red)
  init_pair 28 7 "$COLOR_BLUE"               # input-field completer button (white on blue)
  init_pair 29 0 6                           # focused dialog checkbox/button (black on cyan)
  init_pair 30 4 6                           # focused dialog mnemonic (blue on cyan)
  init_pair 31 11 "$COLOR_BLUE"              # selected panel entry, inactive (bright yellow on blue)
  init_pair 34 11 6                           # selected panel entry, active (bright yellow on cyan)
  init_pair 32 8 0                           # dropdown shadow (bright black on black)
  init_pair 35 9 "$COLOR_BLUE"               # broken symlinks (bright red on blue)
  init_pair 36 8 "$COLOR_BLACK"              # dialog shadow (gray on black)
  init_pair 40 -1 -1                         # command line: terminal default colors (matches mc)

  init_ui || { endwin; exit 1; }

  draw_all
  doupdate

  local k nav switched prev_cur
  while :; do
    local -n _CN=NAMES_$CUR
    local prev_pos=${POS[$CUR]}
    prev_cur=$CUR
    nav=0
    switched=0
    getch || break
    k=$key
    if [[ $k == $'\x1b' && -n $BC_PENDING_IN ]]; then
      mk=${BC_PENDING_IN:0:1}
      BC_PENDING_IN=${BC_PENDING_IN:1}
      case $mk in
        c) quick_cd_dialog; continue ;;
        h) do_command_history; continue ;;
        '!') do_filtered_view; continue ;;
        e) do_encoding; continue ;;
        '`') do_screen_list; continue ;;
        *) ungetch "$mk"; continue ;;
      esac
    fi
    if [[ $k == $'\x18' ]]; then
      getch || break
      case $key in
        d) do_compare_dirs ;;
        j) do_background_jobs ;;
        *) : ;;
      esac
      continue
    fi
    case $k in
      $KEY_UP)     (( POS[$CUR] > 0 )) && POS[$CUR]=$(( POS[$CUR]-1 )); nav=1 ;;
      $KEY_DOWN)   (( POS[$CUR] < ${#_CN[@]}-1 )) && POS[$CUR]=$(( POS[$CUR]+1 )); nav=1 ;;
      $KEY_HOME)   POS[$CUR]=0; nav=1 ;;
      $KEY_END)   POS[$CUR]=$(( ${#_CN[@]} - 1 )); nav=1 ;;
      $KEY_PPAGE) POS[$CUR]=$(( POS[$CUR] - $(page_rows "$CUR") )); clamp_pos "$CUR"; nav=1 ;;
      $KEY_NPAGE) POS[$CUR]=$(( POS[$CUR] + $(page_rows "$CUR") )); clamp_pos "$CUR"; nav=1 ;;
       $KEY_LEFT)
         if [[ -n $CMD_LINE ]]; then
           (( CMD_CARET > 0 )) && CMD_CARET=$(( CMD_CARET - 1 ))
           draw_cmdline
           doupdate
           continue
         fi
         ;;
       $KEY_RIGHT)
         if [[ -n $CMD_LINE ]]; then
           (( CMD_CARET < ${#CMD_LINE} )) && CMD_CARET=$(( CMD_CARET + 1 ))
           draw_cmdline
           doupdate
           continue
         fi
         ;;
       $KEY_RESIZE) do_resize ;;
        $KEY_MOUSE)
          while getmouse; do
            if (( BC_ME_BSTATE & BUTTON1_RELEASED )); then
              MC_MOUSE_DRAG=0
            fi
            if handle_panel_mouse "$BC_ME_Y" "$BC_ME_X" "$BC_ME_BSTATE"; then
              :
            elif handle_buttonbar_mouse "$BC_ME_Y" "$BC_ME_X" "$BC_ME_BSTATE"; then
              :
            elif handle_cmdline_mouse "$BC_ME_Y" "$BC_ME_X" "$BC_ME_BSTATE"; then
              :
            elif menu_bar_hit "$BC_ME_Y" "$BC_ME_X"; then
              run_menu "$MC_MOUSE_MENU" 1
            fi
          done
          ;;
       $'\t')       CUR=$(( 1 - CUR )); switched=1 ;;
       $'\x15')     do_swap_panels ;;
      $'\r')       if [[ -n $CMD_LINE ]]; then execute_cmd; else do_open; fi ;;
      "r")         list_dir "$CUR" ;;
      $KEY_F1)    fkey_help ;;
      $KEY_F2)    user_menu ;;
      $KEY_F3)    do_view ;;
      $KEY_F4)    do_edit ;;
      $KEY_F5)    do_copy ;;
      $KEY_F6)    do_move ;;
      $KEY_F7)    do_mkdir ;;
      $KEY_F8)    do_delete ;;
       $KEY_F9)    run_menu ;;
       $KEY_F10)   STOP=1 ;;
       $KEY_IC)    do_insert_select ;;
       '+')        do_select_group ;;
       '-')        do_unselect_group ;;
       '*')         do_star_select ;;
        $' ')
          if [[ -n $CMD_LINE ]]; then
            CMD_LINE="${CMD_LINE:0:CMD_CARET} ${CMD_LINE:CMD_CARET}"
            CMD_CARET=$(( CMD_CARET + 1 ))
            draw_cmdline
            doupdate
            continue
          fi
          ;;
       $'\x1b')    if [[ -n $CMD_LINE ]]; then CMD_LINE=""; CMD_CARET=0; draw_cmdline; doupdate; fi ;;
       $'\x7f' | $'\x08')
         if (( CMD_CARET > 0 )); then
           CMD_LINE="${CMD_LINE:0:CMD_CARET-1}${CMD_LINE:CMD_CARET}"
           CMD_CARET=$(( CMD_CARET - 1 ))
         elif [[ -n $CMD_LINE ]]; then
           CMD_LINE=${CMD_LINE:0:-1}
           CMD_CARET=${#CMD_LINE}
         fi
         draw_cmdline
         doupdate
         continue
         ;;
      *)
        if [[ ${#k} == 1 && ${k:0:1} == [[:print:]] ]]; then
          CMD_LINE="${CMD_LINE:0:CMD_CARET}${k}${CMD_LINE:CMD_CARET}"
          CMD_CARET=$(( CMD_CARET + 1 ))
          draw_cmdline
          doupdate
          continue
        fi
        ;;
    esac
    if (( switched )); then
      switch_panel "$prev_cur"
    elif (( nav )); then
      drain_panel_nav
      if (( POS[$CUR] != prev_pos )); then
        update_selection "$CUR" "$prev_pos" || { draw_panel "$CUR"; wrefresh "${WIN[$CUR]}"; }
      fi
    else
      draw_all
      doupdate
    fi
    (( STOP )) && break
  done
  endwin
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
