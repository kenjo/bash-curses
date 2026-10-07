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

# ---- per-panel state (suffix 0=left, 1=right) ----
NAMES_0=(); TYPES_0=(); SIZES_0=(); TIMES_0=(); REALS_0=(); EXEC_0=()
NAMES_1=(); TYPES_1=(); SIZES_1=(); TIMES_1=(); REALS_1=(); EXEC_1=()
DIR=("$PWD" "$PWD")
POS_0=0; POS_1=0; OFF_0=0; OFF_1=0
SORT=(name name)
REV=(0 0)
WIN=()

CUR=0                 # active panel (0 left, 1 right)
CMD_LINE=""
STOP=0
DLG_RESULT=""

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
  "External panelize|C-x !|x" "Show directory sizes|C-Space|i"
  "---"
  "Command history|M-h|h" "Viewed/edited files history|M-E|s" 'Directory hotlist|C-\|r'
  "Active VFS list|C-x a|A" "Background jobs|C-x j|B" 'Screen list|M-`|t'
  "---"
  "Undelete files (ext2fs only)||U"
  "---"
  "Edit extension file||e" "Edit menu file||m" "Edit highlighting group file||g"
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

# ------------------------------------------------------------------ helpers
hum() { # kb -> human
  local kb=$1
  if (( kb >= 1048576 )); then printf '%dG' "$(( kb / 1048576 ))"
  elif (( kb >= 1024 )); then printf '%dM' "$(( kb / 1024 ))"
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

# list a directory into the panel's arrays; ".." is always entry 0
list_dir() {
  local p=$1
  local -n NN=NAMES_$p TT=TYPES_$p SS=SIZES_$p TM=TIMES_$p RR=REALS_$p XX=EXEC_$p
  local d=${DIR[$p]}
  d=$(cd "$d" 2>/dev/null && pwd) || d="$HOME"
  DIR[$p]=$d
  local now; now=$(date +%Y%-m); NOW_Y=${now:0:4}; NOW_MO=$((10#${now:4}))

  local -a nm=() ty=() sz=() tk=() tm=() rk=() xx=()
  local out t s mode y mo dd h mi name disp ex
  out=$( (cd "$d" 2>/dev/null && find . -mindepth 1 -maxdepth 1 \
        -printf '%y|%s|%m|%TY|%Tm|%Td|%TH|%TM|%f\n') 2>/dev/null )
  if [[ -n $out ]]; then
    while IFS='|' read -r t s mode y mo dd h mi name; do
      [[ -z $name ]] && continue
      ex=0
      [[ $t != d && $t != l && $mode =~ ^[0-7]+$ ]] && (( (8#$mode) & 0111 )) && ex=1
      if [[ $t == d ]]; then disp="/$name"; elif (( ex )); then disp="*$name"; else disp=" $name"; fi
      nm+=("$disp"); ty+=("$t"); sz+=("$s"); rk+=("$name"); xx+=("$ex")
      tm+=("$(fmt_mtime "$y" "$mo" "$dd" "$h" "$mi")")
      tk+=("$(printf '%04d%02d%02d%02d%02d' "$((10#$y))" "$((10#$mo))" "$((10#$dd))" "$((10#$h))" "$((10#$mi))")")
    done <<< "$out"
  fi

  local n=${#nm[@]} i k
  local -a di=() fi=()
  for (( i = 0; i < n; i++ )); do
    [[ ${ty[$i]} == d ]] && di+=("$i") || fi+=("$i")
  done

  local SEP=$'\x1f' revflag=""
  (( ${REV[$p]} )) && revflag="-r"
  local di_sorted="" fi_sorted=""
  if (( ${#di[@]} > 0 )); then
    di_sorted=$(
      for i in "${di[@]}"; do
        case ${SORT[$p]} in
          size) k=$(printf '%020d' "${sz[$i]}") ;;
          date) k="${tk[$i]}" ;;
          *)    k="${rk[$i]}" ;;
        esac
        printf '%s%s%s\n' "$k" "$SEP" "$i"
      done | LC_ALL=C sort $revflag | cut -d"$SEP" -f2
    )
  fi
  if (( ${#fi[@]} > 0 )); then
    fi_sorted=$(
      for i in "${fi[@]}"; do
        case ${SORT[$p]} in
          size) k=$(printf '%020d' "${sz[$i]}") ;;
          date) k="${tk[$i]}" ;;
          *)    k="${rk[$i]}" ;;
        esac
        printf '%s%s%s\n' "$k" "$SEP" "$i"
      done | LC_ALL=C sort $revflag | cut -d"$SEP" -f2
    )
  fi

  local -a order=()
  [[ -n $di_sorted ]] && order+=($di_sorted)
  [[ -n $fi_sorted ]] && order+=($fi_sorted)

  # ".." parent entry, always first
  local pd parent_time="-"
  pd=$( (cd "$(dirname "$d")" 2>/dev/null && find . -maxdepth 0 -printf '%TY|%Tm|%Td|%TH|%TM') 2>/dev/null )
  if [[ -n $pd ]]; then
    IFS='|' read -r y mo dd h mi <<< "$pd"
    parent_time=$(fmt_mtime "$y" "$mo" "$dd" "$h" "$mi")
  fi

  local -a f_nn=() f_tt=() f_ss=() f_tm=() f_rr=() f_xx=()
  f_nn+=("/.."); f_tt+=(d); f_ss+=("UP--DIR"); f_tm+=("$parent_time"); f_rr+=(".."); f_xx+=(0)
  for i in "${order[@]}"; do
    f_nn+=("${nm[$i]}"); f_tt+=("${ty[$i]}"); f_ss+=("${sz[$i]}")
    f_tm+=("${tm[$i]}"); f_rr+=("${rk[$i]}"); f_xx+=("${xx[$i]}")
  done
  NN=("${f_nn[@]}"); TT=("${f_tt[@]}"); SS=("${f_ss[@]}")
  TM=("${f_tm[@]}"); RR=("${f_rr[@]}"); XX=("${f_xx[@]}")
  POS[$p]=0; OFF[$p]=0
}

type_color() { # p idx -> pair (assumes not the current/highlighted row)
  local p=$1 i=$2
  local -n TT=TYPES_$p RR=REALS_$p XX=EXEC_$p
  local t=${TT[$i]} rn=${RR[$i]}
  case $t in
    d) echo 2 ;;
    l) echo 4 ;;
    c|b|p|s) echo 5 ;;
    *)
      case $rn in
        *.sh)                 echo 14 ;;  # scripts -> cyan
        *.md|*.json)          echo 11 ;;  # docs -> yellow
        .*)                   echo 7 ;;   # dotfiles -> default
        *.log)                echo 7 ;;   # logs -> default
        *)
          if (( XX[$i] )); then echo 3; else echo 7; fi
          ;;
      esac
      ;;
  esac
}

# ------------------------------------------------------------------ drawing
name_width() { # w -> name column width
  local w=$1 nw=$(( w - SIZEW - TIMEW - 4 ))
  (( nw < 4 )) && nw=4
  echo "$nw"
}

draw_panel() {
  local p=$1
  local -n NN=NAMES_$p SS=SIZES_$p TM=TIMES_$p TT=TYPES_$p
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
  local top="<─ ${dp:0:$(( w - 8 ))} "
  local fill=$(( w - 2 - ${#top} - 5 ))
  (( fill < 0 )) && fill=0
  printf -v dstr '─%.0s' $(seq 1 "$fill")
  top+="$dstr.[^]>"
  top=${top:0:$(( w - 2 ))}
  mvwaddstr "$win" 0 1 "$top"
  # path highlight (pair 13, black-on-white) covers the path plus one space on
  # each side; only the active panel gets it (the inactive path stays border
  # color), matching real MC
  if (( active )); then
    wattrset "$win" 0 13
    mvwaddstr "$win" 0 3 " ${dp:0:$(( w - 8 ))} "
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
    if (( idx == pos && active )); then
      # interior (cols 1..w-2) is a black-on-cyan strip; the border columns
      # (0 and w-1) keep the border color drawn by box()
      wmove "$win" "$row" 1
      wchgat "$win" $(( w - 2 )) 0 6
      wattrset "$win" 0 6
      mvwaddstr "$win" "$row" 1 "$(printf '%-*s' "$NAMEW" "${NN[$idx]}")"
      mvwaddch "$win" "$row" "$SD" "│"
      mvwaddstr "$win" "$row" $(( SD + 1 )) "$(printf '%*s' "$SIZEW" "${SS[$idx]}")"
      mvwaddch "$win" "$row" $(( SD + SIZEW + 1 )) "│"
      mvwaddstr "$win" "$row" $(( SD + SIZEW + 2 )) "$(printf '%-*s' "$TIMEW" "${TM[$idx]}")"
    else
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
  mvwhline "$win" "$sy" 1 "$ACS_HLINE" "$(( w - 2 ))"
  mvwaddch "$win" "$sy" "$(( w - 1 ))" "$ACS_RTEE"

  local status
  if (( pos == 0 )); then
    status="UP--DIR"
  else
    if [[ ${TT[$pos]} == d ]]; then status="dir"; else status="file ${SS[$pos]} bytes"; fi
  fi
  wattrset "$win" 0 7
  mvwprintw "$win" "$(( h - 2 ))" 1 '%s' "${status:0:$(( w - 2 ))}"

  local total_kb avail_kb fstr="no info"
  read -r _ total_kb _ avail_kb _ _ <<< "$(df -P -k "${DIR[$p]}" 2>/dev/null | tail -1)"
  if [[ -n ${total_kb:-} ]]; then
    fstr="$(hum "$avail_kb") / $(hum "$total_kb") ($(( avail_kb * 100 / total_kb ))%)"
  fi
  local blen=${#fstr} rd=1 left
  left=$(( w - 5 - blen ))
  (( left < 0 )) && left=0
  printf -v ld '─%.0s' $(seq 1 "$left")
  printf -v rdstr '─%.0s' $(seq 1 "$rd")
  wattrset "$win" 0 7
  mvwaddstr "$win" "$(( h - 1 ))" 1 "$ld $fstr $rdstr"
}

  draw_menu() {
   local i full
  printf -v full ' %.0s' $(seq 1 "$COLS")
  # menu bar: bright-white-on-cyan (16); mnemonic bright-yellow (17); the
  # highlighted item inverted to white-on-black (18), mnemonic (19).
  wattrset 0 0 16
  mvwaddstr 0 0 0 "$full"
  for (( i = 0; i < ${#MENUNAMES[@]}; i++ )); do
    local name=${MENUNAMES[$i]} x=${MENU_X[$i]}
    local mn=${name:0:1} rest=${name:1}
    if (( i == menu_bar_sel && menu_open )); then
      wattrset 0 0 19; mvwaddstr 0 0 "$x" "$mn"
      wattrset 0 0 18; mvwaddstr 0 0 "$(( x + 1 ))" "$rest"
    else
      wattrset 0 0 17; mvwaddstr 0 0 "$x" "$mn"
      wattrset 0 0 16; mvwaddstr 0 0 "$(( x + 1 ))" "$rest"
    fi
  done
}

# The dropdown is its own top panel window so it composites over the file
# panels (stdscr is below them). Geometry is cached in MENU_G*.
MENU_WIN=0; MENU_PANEL=0; MENU_GX=0; MENU_GY=0; MENU_GW=0; MENU_GH=0

menu_draw_dd() {
  local bsel=$menu_bar_sel
  local name=${MENUNAMES[$bsel]}
  local -n MI="MENU_${name}"
  local maxlen=0 maxsc=0 lab sc e nent=0
  for e in "${MI[@]}"; do
    if [[ $e == --- ]]; then (( nent++ )); continue; fi
    lab=${e%%|*}; sc=${e#*|}; sc=${sc%|*}
    (( nent++ ))
    (( ${#lab} > maxlen )) && maxlen=${#lab}
    (( ${#sc} > maxsc )) && maxsc=${#sc}
  done
  local inner=$(( 1 + maxlen + (maxsc > 0 ? 2 + maxsc : 0) ))
  local bw=$(( inner + 2 ))
  local h=$(( nent + 2 ))
  local x0=$(( MENU_X[$bsel] - 2 ))
  (( x0 < 0 )) && x0=0
  (( x0 + bw > COLS )) && x0=$(( COLS - bw ))
  local y0=1
  (( h > HINTY - 1 - y0 )) && h=$(( HINTY - 1 - y0 ))
  if (( MENU_WIN == 0 || MENU_GX != x0 || MENU_GY != y0 || MENU_GW != bw || MENU_GH != h )); then
    (( MENU_WIN > 0 )) && { del_panel "$MENU_PANEL" 2>/dev/null; delwin "$MENU_WIN"; }
    newwin "$h" "$bw" "$y0" "$x0"
    MENU_WIN=$bc_win
    new_panel "$MENU_WIN"; MENU_PANEL=$bc_panel
    MENU_GX=$x0; MENU_GY=$y0; MENU_GW=$bw; MENU_GH=$h
    werase "$MENU_WIN"
  fi
  local top mid sp
  printf -v top '─%.0s' $(seq 1 "$(( bw - 2 ))"); top="┌${top}┐"
  printf -v mid '─%.0s' $(seq 1 "$(( bw - 2 ))"); mid="├${mid}┤"
  printf -v sp ' %.0s' $(seq 1 "$inner")
  wattrset "$MENU_WIN" 0 16
  mvwaddstr "$MENU_WIN" 0 0 "$top"
  local r=0 itemidx=0
  for e in "${MI[@]}"; do
    if (( 1 + r >= h )); then break; fi
    if [[ $e == --- ]]; then
      wattrset "$MENU_WIN" 0 16
      mvwaddstr "$MENU_WIN" "$(( r + 1 ))" 0 "$mid"
    else
      lab=${e%%|*}; sc=${e#*|}; sc=${sc%|*}; mnem=${e##*|}
      local sel=0; (( itemidx == menu_sel )) && sel=1
      local tp tp2 mpos=0 i lc
      tp=$(( sel ? 18 : 16 )); tp2=$(( sel ? 19 : 17 ))
      for (( i = 0; i < ${#lab}; i++ )); do
        lc=${lab:i:1}; lc=${lc,,}
        [[ $lc == "${mnem,,}" ]] && { mpos=$i; break; }
      done
      wattrset "$MENU_WIN" 0 "$tp";   mvwaddstr "$MENU_WIN" "$(( r + 1 ))" 1 "$sp"
      wattrset "$MENU_WIN" 0 16;      mvwaddstr "$MENU_WIN" "$(( r + 1 ))" 0 "│"
      wattrset "$MENU_WIN" 0 "$tp";   mvwaddstr "$MENU_WIN" "$(( r + 1 ))" 2 "${lab:0:mpos}"
      wattrset "$MENU_WIN" 0 "$tp2";  mvwaddstr "$MENU_WIN" "$(( r + 1 ))" $(( 2 + mpos )) "${lab:mpos:1}"
      wattrset "$MENU_WIN" 0 "$tp";   mvwaddstr "$MENU_WIN" "$(( r + 1 ))" $(( 3 + mpos )) "${lab:mpos+1}"
      if [[ -n $sc ]]; then
        wattrset "$MENU_WIN" 0 "$tp"
        mvwaddstr "$MENU_WIN" "$(( r + 1 ))" "$(( inner - maxsc + 1 ))" "$sc"
      fi
      wattrset "$MENU_WIN" 0 16; mvwaddstr "$MENU_WIN" "$(( r + 1 ))" "$(( inner + 1 ))" "│"
      (( itemidx++ ))
    fi
    (( r++ ))
  done
  if (( 1 + r < h )); then
    local bot; printf -v bot '─%.0s' $(seq 1 "$(( bw - 2 ))"); bot="└${bot}┘"
    wattrset "$MENU_WIN" 0 16
    mvwaddstr "$MENU_WIN" "$(( r + 1 ))" 0 "$bot"
  fi
  # doupdate (called by the caller) composites this top panel over the panels
}

menu_dd_close() {
  (( MENU_WIN > 0 )) && { del_panel "$MENU_PANEL" 2>/dev/null; delwin "$MENU_WIN"; }
  MENU_WIN=0; MENU_PANEL=0
}

draw_bottom() {
  local clear
  printf -v clear ' %.0s' $(seq 1 "$COLS")
  clear=${clear:1}
  # hint: default colors
  wattrset 0 0 0
  mvwaddstr 0 "$HINTY" 0 "$clear"
  mvwaddstr 0 "$HINTY" 0 "Hint: Tab switch panel, Enter open, F2 menu, F10 quit, or type 'quit'+Enter (no F-key)."
  # command line: default colors, ~ abbreviated path
  wattrset 0 0 0
  mvwaddstr 0 "$CMY" 0 "$clear"
  local cwd=${DIR[$CUR]}
  local scwd=$cwd
  if [[ $cwd == "$HOME" ]]; then scwd="~"
  elif [[ $cwd == "$HOME"/* ]]; then scwd="~${cwd#"$HOME"}"
  fi
  local prompt="${USER:-$(whoami)}@${HOSTNAME%%.*}:${scwd}\$ "
  mvwaddstr 0 "$CMY" 0 "$prompt"
  mvwaddstr 0 "$CMY" "${#prompt}" "$CMD_LINE"
  # button bar: bright-white numbers on black, black labels on cyan
  wattrset 0 0 0
  mvwaddstr 0 "$BTNY" 0 "$clear"
  local -a bl=(Help Menu View Edit Copy RenMov Mkdir Delete PullDn Quit)
  local x=0 num last=$(( ${#bl[@]} - 1 ))
  for num in "${!bl[@]}"; do
    local n
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
  local -n NN=NAMES_$p SS=SIZES_$p TT=TYPES_$p
  local status statusline
  if (( newpos == 0 )); then
    status="UP--DIR"
  elif [[ ${TT[$newpos]} == d ]]; then
    status="dir"
  else
    status="file ${SS[$newpos]} bytes"
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
  printf -v dstr '─%.0s' $(seq 1 "$fill")
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

draw_cmdline() {
  local clear
  printf -v clear ' %.0s' $(seq 1 "$COLS")
  clear=${clear:1}
  wattrset 0 0 1
  mvwaddstr 0 "$CMY" 0 "$clear"
  local cwd=${DIR[$CUR]}
  local scwd=$cwd
  if [[ $cwd == "$HOME" ]]; then scwd="~"
  elif [[ $cwd == "$HOME"/* ]]; then scwd="~${cwd#"$HOME"}"
  fi
  local prompt="${USER:-$(whoami)}@${HOSTNAME%%.*}:${scwd}\$ "
  mvwaddstr 0 "$CMY" 0 "$prompt"
  mvwaddstr 0 "$CMY" "${#prompt}" "$CMD_LINE"
  move "$CMY" "$(( ${#prompt} + ${#CMD_LINE} ))"
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

# generic modal dialogs ---------------------------------------------
message_dialog() { # title line1 [line2 ...]
  local title=$1; shift
  local -a lines=("$@")
  local w=50 h=$(( ${#lines[@]} + 5 ))
  (( w < 40 )) && w=40; (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  (( h > LINES - 4 )) && h=$(( LINES - 4 ))
  dialog_box "$w" "$h" "$title"
  local i
  for (( i = 0; i < ${#lines[@]}; i++ )); do
    mvwaddstr "$dw" "$(( i + 2 ))" 2 "${lines[$i]:0:$(( w - 4 ))}"
  done
  wattrset "$dw" 0 1
  mvwaddstr "$dw" "$(( h - 2 ))" $(( (w - 18) / 2 )) "[ OK ]   [ Cancel ]"
  wrefresh "$dw"
  while :; do
    wgetch "$dw" || break
    case $key in
      $'\r'|$'q'|$'Q'|$'\x1b') break ;;
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
view_draw() { # paint the full-screen viewer window and refresh it
  local win=$V_WIN
  local rows=$(( LINES - 2 )); (( rows < 1 )) && rows=1
  local maxoff=$(( V_N - rows )); (( maxoff < 0 )) && maxoff=0
  (( V_OFF < 0 )) && V_OFF=0
  (( V_OFF > maxoff )) && V_OFF=$maxoff
  local total=${V_TOTAL:-0}; (( total < 0 )) && total=0

  # byte offset of first visible line; MC clamps to total (100%) at the bottom
  local off=${V_BTOFF[$V_OFF]:-0}
  (( V_OFF >= maxoff && maxoff > 0 )) && off=$total
  (( off < 0 )) && off=0
  (( off > total )) && off=$total
  local pct=0
  (( total > 0 )) && pct=$(( (off * 100) / total ))

  werase "$win"

  # title bar (pair 6): full-width cyan; path left, offset/total + pct right
  wattrset "$win" 0 6
  local offsettotal="${off}/${total}" pctpart="${pct}%" pctfield left_raw gap left title
  pctfield=$(printf '%17s' "$pctpart")
  gap=$(( COLS - 17 - ${#V_PATH} - ${#offsettotal} ))
  (( gap < 0 )) && gap=0
  left_raw="${V_PATH}$(printf '%*s' "$gap" '')${offsettotal}"
  left=$(printf '%-*s' "$((COLS - 17))" "$left_raw")
  title="${left}${pctfield}"
  mvwaddnstr "$win" 0 0 "$title" "$COLS"

  # content (pair 7): full-width blue, rows 1 .. LINES-2
  wattrset "$win" 0 7
  local i idx line
  for (( i = 1; i < LINES - 1; i++ )); do
    idx=$(( V_OFF + i - 1 ))
    line=""; (( idx < V_N )) && line="${V_LINES[$idx]}"
    line="${line:0:$COLS}"
    mvwaddnstr "$win" "$i" 0 "$(printf '%-*s' "$COLS" "$line")" "$COLS"
  done

  # function-key hint bar (numbers pair 15, labels pair 6)
  view_fnbar "$win"

  wrefresh "$win"
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

drain_view_nav() { # fold any queued navigation keys into a single V_OFF step
  local win=$V_WIN
  local old=${BC_WDELAY[$win]:-0}
  BC_WDELAY[$win]=1
  local rows=$(( LINES - 2 )); (( rows < 1 )) && rows=1
  local maxoff=$(( V_N - rows )); (( maxoff < 0 )) && maxoff=0
  local k
  while :; do
    wgetch "$win" || break
    k=$key
    case $k in
      $KEY_UP)    (( V_OFF > 0 )) && V_OFF=$(( V_OFF - 1 )) ;;
      $KEY_DOWN)  (( V_OFF < maxoff )) && V_OFF=$(( V_OFF + 1 )) ;;
      $KEY_HOME)  V_OFF=0 ;;
      $KEY_END)   V_OFF=$maxoff ;;
      $KEY_PPAGE) (( V_OFF >= rows )) && V_OFF=$(( V_OFF - rows )) || V_OFF=0 ;;
      $KEY_NPAGE) (( V_OFF + rows <= maxoff )) && V_OFF=$(( V_OFF + rows )) || V_OFF=$maxoff ;;
      *)          ungetch "$key"; break ;;
    esac
  done
  BC_WDELAY[$win]=$old
  (( V_OFF < 0 )) && V_OFF=0
  (( V_OFF > maxoff )) && V_OFF=$maxoff
}

view_loop() { # modal key loop; returns 0 to close the viewer
  local win=$V_WIN
  local rows=$(( LINES - 2 )); (( rows < 1 )) && rows=1
  local maxoff=$(( V_N - rows )); (( maxoff < 0 )) && maxoff=0
  local k
  while :; do
    wgetch "$win" || return 0
    k=$key
    case $k in
      $KEY_UP)    (( V_OFF > 0 )) && V_OFF=$(( V_OFF - 1 )) ;;
      $KEY_DOWN)  (( V_OFF < maxoff )) && V_OFF=$(( V_OFF + 1 )) ;;
      $KEY_HOME)  V_OFF=0 ;;
      $KEY_END)   V_OFF=$maxoff ;;
      $KEY_PPAGE) (( V_OFF >= rows )) && V_OFF=$(( V_OFF - rows )) || V_OFF=0 ;;
      $KEY_NPAGE) (( V_OFF + rows <= maxoff )) && V_OFF=$(( V_OFF + rows )) || V_OFF=$maxoff ;;
      "q"|"Q"|$'\x1b'|"$KEY_F3"|"$KEY_F10") return 0 ;;
      *)          continue ;;
    esac
    drain_view_nav
    view_draw
  done
  return 0
}

view_file() { # real name
  local real=$1
  local f="${DIR[$CUR]}/$real"
  if [[ ! -r $f ]]; then
    message_dialog "View" "Cannot read $real"
    return
  fi
  local -a lines=() bto=()
  local ln off=0
  while IFS= read -r ln || [[ -n $ln ]]; do
    bto+=("$off"); lines+=("$ln"); off=$(( off + ${#ln} + 1 ))
  done < <(cat -- "$f" 2>/dev/null || echo "[binary or unreadable]")
  (( ${#lines[@]} == 0 )) && { lines+=(""); bto+=(0); }
  V_LINES=("${lines[@]}")
  V_N=${#lines[@]}
  V_OFF=0
  V_PATH="$f"
  V_BTOFF=("${bto[@]}")
  V_TOTAL=$(wc -c < "$f" 2>/dev/null | tr -d ' \t')
  [[ -z $V_TOTAL ]] && V_TOTAL=$off

  local saved_esc=$ESCDELAY
  ESCDELAY=80

  newwin "$LINES" "$COLS" 0 0
  V_WIN=$bc_win
  view_draw
  view_loop
  delwin "$V_WIN"
  ESCDELAY=$saved_esc
  draw_all
  doupdate
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

do_mkdir() {
  input_dialog "Create directory" "Create directory:" "" || return
  local name=$DLG_RESULT
  [[ -z $name ]] && return
  mkdir "${DIR[$CUR]}/$name" 2>/dev/null && list_dir "$CUR"
}

do_delete() {
  local real
  real=$(cur_real)
  [[ $real == ".." ]] && return
  confirm_dialog "Delete" "Delete '${DIR[$CUR]}/$real'?" || return
  [[ $DLG_RESULT == y ]] || return
  rm -rf -- "${DIR[$CUR]}/$real" 2>/dev/null && list_dir "$CUR"
}

do_copy() {
  local real
  real=$(cur_real)
  [[ $real == ".." ]] && return
  local dest=${DIR[$(( 1 - CUR ))]}
  input_dialog "Copy" "Copy to directory:" "$dest" || return
  local d=$DLG_RESULT
  [[ -z $d || ! -d $d ]] && { message_dialog "Copy" "Not a directory: $d"; return; }
  cp -r -- "${DIR[$CUR]}/$real" "$d/" 2>/dev/null && list_dir "$(( 1 - CUR ))"
}

do_move() {
  local real
  real=$(cur_real)
  [[ $real == ".." ]] && return
  local dest=${DIR[$(( 1 - CUR ))]}
  input_dialog "Rename / Move" "Rename/move to:" "$dest" || return
  local d=$DLG_RESULT
  [[ -z $d ]] && return
  if [[ $d == /* || $d == ~* ]]; then
    d=${d/#~/$HOME}
    [[ -d $d ]] || { message_dialog "Move" "Not a directory: $d"; return; }
    mv -- "${DIR[$CUR]}/$real" "$d/" 2>/dev/null && list_dir "$CUR"
  else
    mv -- "${DIR[$CUR]}/$real" "${DIR[$CUR]}/$d" 2>/dev/null && list_dir "$CUR"
  fi
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

fkey_help() {
  message_dialog "F-keys" \
    "F1 Help   F2 Menu   F3 View   F4 Edit" \
    "F5 Copy   F6 RenMov F7 Mkdir  F8 Delete" \
    "F9 PullDn  F10 Quit" \
    "Arrows move, Tab/Left/Right switch panel" \
    "Enter open, r refresh, type to run command"
}

about_mc() {
  message_dialog "About mc (bash port)" \
    "A Midnight Commander-style file manager" \
    "written in bash on lib/bc.sh." \
    "Dual panels, command line, F-key actions."
}

run_menu() {
  menu_open=1; menu_bar_sel=0; menu_dd=0; menu_sel=0
  local nmb=${#MENUNAMES[@]} chosen=""
  local prev_dd=0
  while :; do
    menu_real_n "$menu_bar_sel"
    draw_all; (( menu_dd )) && menu_draw_dd; doupdate
    wgetch 0 || break
    prev_dd=$menu_dd
    case $key in
      $KEY_LEFT)  menu_bar_sel=$(( (menu_bar_sel + nmb - 1) % nmb )); menu_sel=0 ;;
      $KEY_RIGHT) menu_bar_sel=$(( (menu_bar_sel + 1) % nmb )); menu_sel=0 ;;
      $KEY_DOWN)
        if (( menu_dd == 0 )); then menu_dd=1; menu_sel=0
        else menu_sel=$(( (menu_sel + 1) % REALN )); fi ;;
      $KEY_UP)
        if (( menu_dd == 1 )); then
          (( menu_sel == 0 )) && menu_dd=0 || (( menu_sel-- ))
        else menu_dd=1; menu_sel=0; fi ;;
      $'\r')
        if (( menu_dd == 0 )); then menu_dd=1; menu_sel=0
        else menu_entry_at "$menu_bar_sel" "$menu_sel"; chosen="$ENTRY"
             menu_open=0; menu_dd=0; break; fi ;;
      $'\x1b') menu_open=0; menu_dd=0; break ;;
      [a-zA-Z])
        local ch=${key,,} ri ll lf
        if (( menu_dd == 1 )); then
          for (( ri = 0; ri < REALN; ri++ )); do
            menu_entry_at "$menu_bar_sel" "$ri"; lf=${ENTRY##*|}; lf=${lf,,}
            [[ $lf == "$ch" ]] && { menu_sel=$ri; break; }
          done
        else
          for (( ri = 0; ri < nmb; ri++ )); do
            lf=${MENUNAMES[ri]:0:1}; lf=${lf,,}
            [[ $lf == "$ch" ]] && { menu_bar_sel=$ri; menu_sel=0; break; }
          done
        fi ;;
    esac
    (( menu_dd == 0 && prev_dd == 1 )) && menu_dd_close
  done
  menu_open=0; menu_dd=0
  menu_dd_close
  [[ -z $chosen ]] && return
  local label=${chosen%|*} name=${MENUNAMES[$menu_bar_sel]}
  case $name in
    Left|Right)
      case $label in
        "Quick view")    do_view ;;
        "Rescan")        draw_all; doupdate ;;
        "Sort order...") message_dialog "Sort order" "Not implemented." ;;
        *)               message_dialog "$name" "Not implemented: $label" ;;
      esac ;;
    File)
      case $label in
        "View")         do_view ;;
        "Edit")         message_dialog "Edit" "No editor configured." ;;
        "Copy")         do_copy ;;
        "Rename/Move")  do_move ;;
        "Mkdir")        do_mkdir ;;
        "Delete")       do_delete ;;
        "Quick cd")     focus_cmdline ;;
        "Exit")         STOP=1 ;;
        *)              message_dialog "File" "Not implemented: $label" ;;
      esac ;;
    Command)
      case $label in
        "Swap panels")  CUR=$(( 1 - CUR )); draw_all; doupdate ;;
        "Command line") focus_cmdline ;;
        "User menu")    message_dialog "User menu" "Not implemented." ;;
        *)              message_dialog "Command" "Not implemented: $label" ;;
      esac ;;
    Options)
      case $label in
        "Save setup") message_dialog "Options" "Save setup not implemented." ;;
        *)            message_dialog "Options" "Not implemented: $label" ;;
      esac ;;
  esac
}

focus_cmdline() { # F9: focus the command line (fresh line to type a command)
  CMD_LINE=""
}

execute_cmd() {
  [[ -z $CMD_LINE ]] && return
  local cmd=$CMD_LINE
  CMD_LINE=""
  if [[ $cmd =~ ^cd[[:space:]]*(.*)$ ]]; then
    local target="${BASH_REMATCH[1]//\"/}"
    target=${target/#~/$HOME}
    if [[ -z $target ]]; then target="$HOME"; fi
    if [[ -d $target ]]; then
      DIR[$CUR]=$target; list_dir "$CUR"
    else
      message_dialog "cd" "Not a directory: $target"
    fi
    return
  fi
  case $cmd in
    exit|quit) STOP=1; return ;;
  esac
  local out
  out=$( (cd "${DIR[$CUR]}" 2>/dev/null && eval "$cmd") 2>&1 )
  if [[ -n $out ]]; then
    local -a olines=()
    while IFS= read -r ln; do olines+=("$ln"); done <<< "$out"
    message_dialog "Output" "${olines[@]}"
  fi
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

# ------------------------------------------------------------------ main
init_ui() {
  (( LINES < 12 || COLS < 60 )) && { echo "Terminal too small" >&2; return 1; }
  PH=$(( LINES - 4 ))
  PW=$(( COLS / 2 ))
  HINTY=$(( 1 + PH ))
  CMY=$(( 1 + PH + 1 ))
  BTNY=$(( 1 + PH + 2 ))
  newwin "$PH" "$PW" 1 0; WIN[0]=$bc_win; new_panel "${WIN[0]}"
  newwin "$PH" "$PW" 1 "$PW"; WIN[1]=$bc_win; new_panel "${WIN[1]}"
  list_dir 0; list_dir 1
}

main() {
  initscr || exit 1
  cbreak
  noecho
  keypad 0 1
  start_color
  trap 'endwin' EXIT INT TERM
  # Pairs 1,9,10 are the menu bar / dropdown (left unchanged).  The rest are the
  # main-window palette, matching real Midnight Commander's colors.
  init_pair 1 "$COLOR_WHITE"   "$COLOR_BLACK"   # menu bar, hint/cmdline/buttons
  init_pair 2 15 "$COLOR_BLUE"               # directories (bright white)
  init_pair 3 15 "$COLOR_BLUE"               # executables
  init_pair 4 15 "$COLOR_BLUE"               # symlinks
  init_pair 5 15 "$COLOR_BLUE"               # special files
  init_pair 6 "$COLOR_BLACK"   "$COLOR_CYAN"  # selected entry: full row (active panel)
  init_pair 7 "$COLOR_WHITE"   "$COLOR_BLUE"  # active border, dividers, status+size text
  init_pair 8 "$COLOR_WHITE"   "$COLOR_BLUE"  # inactive border
  init_pair 9 "$COLOR_BLACK"   "$COLOR_YELLOW" # active menu item / selected menu entry
  init_pair 10 "$COLOR_BLACK"  "$COLOR_CYAN"  # dropdown bg/text
  init_pair 11 "$COLOR_YELLOW" "$COLOR_BLUE"  # doc files (.md/.json)
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
    case $k in
      $KEY_UP)     (( POS[$CUR] > 0 )) && { POS[$CUR]=$(( POS[$CUR]-1 )); nav=1; } ;;
      $KEY_DOWN)   (( POS[$CUR] < ${#_CN[@]}-1 )) && { POS[$CUR]=$(( POS[$CUR]+1 )); nav=1; } ;;
      $KEY_HOME)   POS[$CUR]=0; nav=1 ;;
      $KEY_END)   POS[$CUR]=$(( ${#_CN[@]} - 1 )); nav=1 ;;
      $KEY_PPAGE) POS[$CUR]=$(( POS[$CUR] - $(page_rows "$CUR") )); clamp_pos "$CUR"; nav=1 ;;
      $KEY_NPAGE) POS[$CUR]=$(( POS[$CUR] + $(page_rows "$CUR") )); clamp_pos "$CUR"; nav=1 ;;
      $KEY_LEFT)   CUR=$(( 1 - CUR )); switched=1 ;;
      $KEY_RIGHT)  CUR=$(( 1 - CUR )); switched=1 ;;
      $'\t')       CUR=$(( 1 - CUR )); switched=1 ;;
      $'\r')       if [[ -n $CMD_LINE ]]; then execute_cmd; else do_open; fi ;;
      "r")         list_dir "$CUR" ;;
      $KEY_F1)    fkey_help ;;
      $KEY_F2)    run_menu ;;
      $KEY_F3)    do_view ;;
      $KEY_F4)    message_dialog "Edit" "No editor configured." ;;
      $KEY_F5)    do_copy ;;
      $KEY_F6)    do_move ;;
      $KEY_F7)    do_mkdir ;;
      $KEY_F8)    do_delete ;;
      $KEY_F9)    run_menu ;;
      $KEY_F10)   STOP=1 ;;
      $'\x1b')    [[ -n $CMD_LINE ]] && CMD_LINE="" ;;
      $'\x7f' | $'\x08')
        CMD_LINE=${CMD_LINE:0:-1}
        draw_cmdline
        doupdate
        continue
        ;;
      *)
        if [[ ${#k} == 1 && ${k:0:1} == [[:print:]] ]]; then
          CMD_LINE+=$k
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
      update_selection "$CUR" "$prev_pos" || { draw_panel "$CUR"; wrefresh "${WIN[$CUR]}"; }
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
