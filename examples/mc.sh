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
#   F9 view     F10 quit              printable chars    : command line
#   Esc         focus command line
source "${BASH_SOURCE[0]%/*}/../lib/bc.sh"

# ---- per-panel state (suffix 0=left, 1=right) ----
NAMES_0=(); TYPES_0=(); SIZES_0=(); TIMES_0=(); REALS_0=(); EXEC_0=()
NAMES_1=(); TYPES_1=(); SIZES_1=(); TIMES_1=(); REALS_1=(); EXEC_1=()
DIR=("$HOME" "$HOME")
POS_0=0; POS_1=0; OFF_0=0; OFF_1=0
SORT=(name name)
REV=(0 0)
WIN=()

CUR=0                 # active panel (0 left, 1 right)
CMD_LINE=""
STOP=0
DLG_RESULT=""

# column widths
SIZEW=8
TIMEW=15

MO=(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

# menus and their items
MENUNAMES=(File Search Command Disk Options Help)
MENU_File=("View" "Edit" "Delete" "Rename / Move" "Copy" "Mkdir" "Chmod" "Chown")
MENU_Search=("Find file" "Exchange panels")
MENU_Command=("Directory menu" "Command line")
MENU_Disk=("Exchange panels")
MENU_Options=("Sort by name" "Sort by size" "Sort by date" "Reverse sort")
MENU_Help=("About mc" "F-key help" "Quit")

# ------------------------------------------------------------------ helpers
hum() { # kb -> human
  local kb=$1
  if (( kb >= 1048576 )); then printf '%dG' "$(( kb / 1048576 ))"
  elif (( kb >= 1024 )); then printf '%dM' "$(( kb / 1024 ))"
  else printf '%dK' "$kb"; fi
}

# list a directory into the panel's arrays; ".." is always entry 0
list_dir() {
  local p=$1
  local -n NN=NAMES_$p TT=TYPES_$p SS=SIZES_$p TM=TIMES_$p RR=REALS_$p XX=EXEC_$p
  local d=${DIR[$p]}
  d=$(cd "$d" 2>/dev/null && pwd) || d="$HOME"
  DIR[$p]=$d

  local -a nm=() ty=() sz=() tk=() tm=() rk=() xx=()
  local out t s mode y mo dd h mi name disp ex
  out=$( (cd "$d" 2>/dev/null && find . -mindepth 1 -maxdepth 1 \
        -printf '%y|%s|%m|%TY|%Tm|%Td|%TH|%TM|%f\n') 2>/dev/null )
  if [[ -n $out ]]; then
    while IFS='|' read -r t s mode y mo dd h mi name; do
      [[ -z $name ]] && continue
      disp=$name
      [[ $t == d ]] && disp="/$name"
      ex=0
      [[ $t != d && $t != l && $mode =~ ^[0-7]+$ ]] && (( (8#$mode) & 0111 )) && ex=1
      nm+=("$disp"); ty+=("$t"); sz+=("$s"); rk+=("$name"); xx+=("$ex")
      tm+=("$(printf '%s %2d %s:%s' "${MO[$((10#$mo - 1))]}" "$((10#$dd))" "$h" "$mi")")
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
    parent_time=$(printf '%s %2d %s:%s' "${MO[$((10#$mo - 1))]}" "$((10#$dd))" "$h" "$mi")
  fi

  local -a f_nn=() f_tt=() f_ss=() f_tm=() f_rr=() f_xx=()
  f_nn+=(".."); f_tt+=(d); f_ss+=("UP--DIR"); f_tm+=("$parent_time"); f_rr+=(".."); f_xx+=(0)
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
  local -n TT=TYPES_$p XX=EXEC_$p
  case ${TT[$i]} in
    d) echo 2 ;;
    l) echo 4 ;;
    c|b|p|s) echo 5 ;;
    *)
      if (( XX[$i] )); then echo 3; else echo 1; fi
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
  local -n NN=NAMES_$p SS=SIZES_$p TM=TIMES_$p
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

  werase "$win"
  wattrset "$win" $(( active ? 1 : 0 )) "$bp"
  box "$win"

  # top border: <- path ---- . >
  local path=${DIR[$p]}
  local dp=${path/#$HOME/~}
  local top="<- ${dp:0:$(( w - 8 ))} "
  local fill=$(( w - 2 - ${#top} - 3 ))
  (( fill < 0 )) && fill=0
  printf -v dstr '─%.0s' $(seq 1 "$fill")
  top+="$dstr. >"
  top=${top:0:$(( w - 2 ))}
  mvwaddstr "$win" 0 1 "$top"

  # header row
  local NAMEW
  NAMEW=$(name_width "$w")
  local SD=$(( 1 + NAMEW + 1 )) TD=$(( SD + SIZEW + 1 ))
  local ind
  case ${SORT[$p]} in size) ind=s ;; date) ind=d ;; *) ind=n ;; esac
  (( REV[$p] )) && ind="^$ind"
  local hname hsize htime
  hname=$(printf '%-*s' "$NAMEW" "  $ind  Name")
  hsize=$(printf '%*s' "$SIZEW" "Size")
  htime=$(printf '%-*s' "$TIMEW" "Modify time")
  wattrset "$win" 1 "$bp"
  mvwaddstr "$win" 1 0 "│${hname}│${hsize}│${htime}│"

  # entry rows
  local y idx cpair nstr rest
  for (( y = 0; y < rows; y++ )); do
    idx=$(( off + y ))
    (( idx >= cnt )) && break
    if (( idx == pos )); then
      cpair=6
    else
      cpair=$(type_color "$p" "$idx")
    fi
    nstr=$(printf '%-*s' "$NAMEW" "${NN[$idx]}")
    wattrset "$win" $(( cpair == 6 ? 1 : 0 )) "$cpair"
    mvwaddstr "$win" "$(( y + 2 ))" 1 "$nstr"
    rest="│$(printf '%*s' "$SIZEW" "${SS[$idx]}")│$(printf '%-*s' "$TIMEW" "${TM[$idx]}")│"
    wattrset "$win" 0 "$cpair"
    mvwaddstr "$win" "$(( y + 2 ))" "$SD" "$rest"
  done

  # separator, status, bottom
  local sy=$(( h - 3 ))
  wattrset "$win" $(( active ? 1 : 0 )) "$bp"
  mvwaddch "$win" "$sy" 0 "$ACS_LTEE"
  mvwhline "$win" "$sy" 1 "$ACS_HLINE" "$(( w - 2 ))"
  mvwaddch "$win" "$sy" "$(( w - 1 ))" "$ACS_RTEE"

  local status
  if (( pos == 0 )); then
    status="UP--DIR"
  else
    local et=${NN[$pos]:0:1}
    if [[ ${NN[$pos]} == /.* ]]; then status="dir"; else status="file ${SS[$pos]} bytes"; fi
  fi
  wattrset "$win" 0 1
  mvwprintw "$win" "$(( h - 2 ))" 1 '%s' "${status:0:$(( w - 2 ))}"

  local total_kb avail_kb fstr="no info"
  read -r _ total_kb _ avail_kb _ _ <<< "$(df -P -k "${DIR[$p]}" 2>/dev/null | tail -1)"
  if [[ -n ${total_kb:-} ]]; then
    fstr="$(hum "$avail_kb") / $(hum "$total_kb") ($(( avail_kb * 100 / total_kb ))%)"
  fi
  local blen=${#fstr} left
  left=$(( (w - 2 - blen) / 2 ))
  (( left < 0 )) && left=0
  local rd=$(( w - 2 - left - blen - 2 ))
  (( rd < 0 )) && rd=0
  printf -v ld '─%.0s' $(seq 1 "$left")
  printf -v rdstr '─%.0s' $(seq 1 "$rd")
  wattrset "$win" $(( active ? 1 : 0 )) "$bp"
  mvwaddstr "$win" "$(( h - 1 ))" 1 "$ld $fstr $rdstr"
}

draw_menu() {
  local clear
  printf -v clear ' %.0s' $(seq 1 "$COLS")
  clear=${clear:1}
  wattrset 0 0 1
  mvwaddstr 0 0 0 "$clear"
  local -a names=(Left File Search Command Disk Options Help)
  local -a pos=(2 12 22 32 42 52 62)
  local i
  for (( i = 0; i < 7; i++ )); do
    mvwaddstr 0 0 "${pos[$i]}" "${names[$i]}"
  done
  mvwaddstr 0 0 "$(( COLS - 6 ))" "Right"
  local ax aname
  if (( CUR == 0 )); then ax=2; aname=Left; else ax=$(( COLS - 6 )); aname=Right; fi
  wattrset 0 1 9
  mvwaddstr 0 0 "$ax" "$aname"
  wattrset 0 0 1
}

draw_bottom() {
  local clear
  printf -v clear ' %.0s' $(seq 1 "$COLS")
  clear=${clear:1}
  # hint
  wattrset 0 0 1
  mvwaddstr 0 "$HINTY" 0 "$clear"
  mvwaddstr 0 "$HINTY" 0 "Hint: Tab switches panel, Enter opens, type to run a command."
  # command line
  mvwaddstr 0 "$CMY" 0 "$clear"
  local cwd=${DIR[$CUR]} scwd=${cwd/#$HOME/~}
  local prompt="${USER:-$(whoami)}@${HOSTNAME%%.*}:${scwd}\$ "
  mvwaddstr 0 "$CMY" 0 "$prompt"
  mvwaddstr 0 "$CMY" "${#prompt}" "$CMD_LINE"
  # button bar
  mvwaddstr 0 "$BTNY" 0 "$clear"
  local -a bl=(Help Menu View Edit Copy RenMov Mkdir Delete PullDn Quit)
  local x=1 num
  for num in "${!bl[@]}"; do
    local n=$(( num + 1 ))
    wattrset 0 1 1
    mvwaddstr 0 "$BTNY" "$x" "$n"
    wattrset 0 0 1
    mvwaddstr 0 "$BTNY" "$(( x + ${#n} ))" "${bl[$num]}    "
    x=$(( x + ${#n} + ${#bl[$num]} + 4 ))
  done
}

draw_all() {
  draw_menu
  draw_panel 0
  draw_panel 1
  draw_bottom
}

draw_cmdline() {
  local clear
  printf -v clear ' %.0s' $(seq 1 "$COLS")
  clear=${clear:1}
  wattrset 0 0 1
  mvwaddstr 0 "$CMY" 0 "$clear"
  local cwd=${DIR[$CUR]} scwd=${cwd/#$HOME/~}
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
  newwin h w "$y" "$x"
  dw=$bc_win
  werase dw; box dw
  # title bar
  local tlen=${#title} tx
  tx=$(( (w - tlen) / 2 ))
  (( tx < 2 )) && tx=2
  wattrset dw 1 9
  mvwhline dw 0 1 "$ACS_HLINE" "$(( w - 2 ))"
  mvwaddstr dw 0 "$tx" "$title"
  wattrset dw 0 1
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
    mvwaddstr dw 2 "$i" 2 "${lines[$i]:0:$(( w - 4 ))}"
  done
  wattrset dw 0 1
  mvwaddstr dw "$(( h - 2 ))" $(( (w - 18) / 2 )) "[ OK ]   [ Cancel ]"
  wrefresh dw
  while :; do
    wgetch dw || break
    case $key in
      $'\r'|$'q'|$'Q'|$'\x1b') break ;;
    esac
  done
  delwin dw
}

input_dialog() { # title prompt default -> DLG_RESULT; 0 ok / 1 cancel
  local title=$1 prompt=$2 def=$3
  local buf="$def"
  local w=50
  (( ${#prompt} + 8 > w )) && w=$(( ${#prompt} + 8 ))
  (( w < 40 )) && w=40; (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  local h=9
  dialog_box "$w" "$h" "$title"
  mvwaddstr dw 2 2 "${prompt:0:$(( w - 4 ))}"
  local row=4
  wrefresh dw
  local redraw=1
  while :; do
    if (( redraw )); then
      wmove dw "$row" 2
      wclrtoeol dw
      waddstr dw "$buf"
      wrefresh dw
      redraw=0
    fi
    wgetch dw || break
    case $key in
      $'\r') DLG_RESULT="$buf"; delwin dw; return 0 ;;
      $'\x1b') delwin dw; return 1 ;;
      $'\x7f'|$'\x08') buf=${buf:0:-1}; redraw=1 ;;
      *)
        if [[ ${#key} == 1 && ${key:0:1} == [[:print:]] ]]; then
          buf+=$key; redraw=1
        fi
        ;;
    esac
  done
  delwin dw
  return 1
}

confirm_dialog() { # title prompt -> DLG_RESULT y/n; 0 yes / 1 no
  local title=$1 prompt=$2
  local w=46 h=8
  (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  dialog_box "$w" "$h" "$title"
  mvwaddstr dw 2 2 "${prompt:0:$(( w - 4 ))}"
  mvwaddstr dw 4 2 "Are you sure? [y]es or [n]o:"
  wrefresh dw
  while :; do
    wgetch dw || break
    case $key in
      y|Y) DLG_RESULT=y; delwin dw; return 0 ;;
      n|N|$'\x1b'|$'\r') DLG_RESULT=n; delwin dw; return 1 ;;
    esac
  done
  delwin dw
  return 1
}

menu_dialog() { # menuindex -> DLG_RESULT = selected item index (0..n) or -1
  local mi=$1
  local -n items
  local name=${MENUNAMES[$mi]}
  local arr="MENU_${name/ /_}"
  local -n items=$arr 2>/dev/null || items=()
  local n=${#items[@]}
  local sel=0
  local w=28 h=$(( n + 5 ))
  (( w < 24 )) && w=24; (( w > COLS - 8 )) && w=$(( COLS - 8 ))
  (( h > LINES - 4 )) && h=$(( LINES - 4 ))
  dialog_box "$w" "$h" "$name"
  while :; do
    local i mark
    for (( i = 0; i < n; i++ )); do
      mark="  "
      (( i == sel )) && mark="->"
      wattrset dw $(( i == sel ? 1 : 0 )) $(( i == sel ? 9 : 1 ))
      mvwaddstr dw "$(( i + 2 ))" 2 "${mark} ${items[$i]}"
    done
    wattrset dw 0 1
    wrefresh dw
    wgetch dw || break
    case $key in
      $KEY_UP) sel=$(( (sel - 1 + n) % n )) ;;
      $KEY_DOWN) sel=$(( (sel + 1) % n )) ;;
      $'\r') DLG_RESULT=$sel; delwin dw; return 0 ;;
      $'\x1b') DLG_RESULT=-1; delwin dw; return 1 ;;
    esac
  done
  delwin dw
  return 1
}

# ------------------------------------------------------------------ actions
cur_real() { # real name of current entry in active panel
  local -n RR=REALS_$CUR
  echo "${RR[${POS[$CUR]}]}"
}
do_open() {
  local real
  real=$(cur_real)
  if [[ $real == ".." ]]; then
    DIR[$CUR]=$(dirname "${DIR[$CUR]}")
  elif [[ -d "${DIR[$CUR]}/$real" ]]; then
    DIR[$CUR]="${DIR[$CUR]}/$real"
  elif [[ -f "${DIR[$CUR]}/$real" ]]; then
    view_file "$real"
    return
  else
    return
  fi
  list_dir "$CUR"
}

view_file() { # real name
  local real=$1
  local f="${DIR[$CUR]}/$real"
  if [[ ! -r $f ]]; then
    message_dialog "View" "Cannot read $real"
    return
  fi
  local lines
  lines=$( (cat -- "$f" 2>/dev/null || echo "[binary or unreadable]") | head -100 )
  local -a ll=()
  while IFS= read -r ln; do ll+=("$ln"); done <<< "$lines"
  (( ${#ll[@]} == 0 )) && ll+=("")
  message_dialog "View: $real" "${ll[@]}"
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
    "F9 View   F10 Quit" \
    "Arrows move, Tab/Left/Right switch panel" \
    "Enter open, r refresh, type to run command"
}

about_mc() {
  message_dialog "About mc (bash port)" \
    "A Midnight Commander-style file manager" \
    "written in bash on lib/bc.sh." \
    "Dual panels, command line, F-key actions."
}

run_menu() { # menuindex
  local mi=$1
  menu_dialog "$mi" || return
  local sel=$DLG_RESULT
  local -n items
  local name=${MENUNAMES[$mi]}
  local arr="MENU_${name/ /_}"
  local -n items=$arr 2>/dev/null || items=()
  local item=${items[$sel]}
  case $name in
    File)
      case $item in
        View) do_view ;;
        Edit) message_dialog "Edit" "No editor configured." ;;
        Delete) do_delete ;;
        "Rename / Move") do_move ;;
        Copy) do_copy ;;
        Mkdir) do_mkdir ;;
        Chmod) message_dialog "Chmod" "Not implemented." ;;
        Chown) message_dialog "Chown" "Not implemented." ;;
      esac
      ;;
    Search)
      case $item in
        "Find file") message_dialog "Search" "Find is not implemented." ;;
        "Exchange panels") do_exchange ;;
      esac
      ;;
    Command)
      case $item in
        "Directory menu") message_dialog "Command" "Directory menu not implemented." ;;
        "Command line") : ;;
      esac
      ;;
    Disk)
      case $item in
        "Exchange panels") do_exchange ;;
      esac
      ;;
    Options)
      case $item in
        "Sort by name") do_sort name ;;
        "Sort by size") do_sort size ;;
        "Sort by date") do_sort date ;;
        "Reverse sort") do_reverse ;;
      esac
      ;;
    Help)
      case $item in
        "About mc") about_mc ;;
        "F-key help") fkey_help ;;
        Quit) STOP=1 ;;
      esac
      ;;
  esac
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
  init_pair 1 "$COLOR_WHITE" "$COLOR_BLACK"
  init_pair 2 "$COLOR_BLUE" "$COLOR_BLACK"
  init_pair 3 "$COLOR_GREEN" "$COLOR_BLACK"
  init_pair 4 "$COLOR_MAGENTA" "$COLOR_BLACK"
  init_pair 5 "$COLOR_RED" "$COLOR_BLACK"
  init_pair 6 "$COLOR_WHITE" "$COLOR_BLUE"
  init_pair 7 "$COLOR_YELLOW" "$COLOR_BLACK"
  init_pair 8 "$COLOR_WHITE" "$COLOR_BLACK"
  init_pair 9 "$COLOR_BLACK" "$COLOR_YELLOW"

  init_ui || { endwin; exit 1; }

  draw_all
  doupdate

  local k
  while :; do
    local -n _CN=NAMES_$CUR
    getch || break
    k=$key
    case $k in
      $KEY_UP)     POS[$CUR]=$(( POS[$CUR] > 0 ? POS[$CUR]-1 : 0 )) ;;
      $KEY_DOWN)   POS[$CUR]=$(( POS[$CUR] < ${#_CN[@]}-1 ? POS[$CUR]+1 : POS[$CUR] )) ;;
      $KEY_LEFT)   CUR=$(( 1 - CUR )) ;;
      $KEY_RIGHT)  CUR=$(( 1 - CUR )) ;;
      $'\t')       CUR=$(( 1 - CUR )) ;;
      $'\r')       do_open ;;
      "r")         list_dir "$CUR" ;;
      $KEY_HOME)   POS[$CUR]=0 ;;
      $KEY_END)   POS[$CUR]=$(( ${#_CN[@]} - 1 )) ;;
      $KEY_PPAGE) POS[$CUR]=$(( POS[$CUR] - 20 )) ;;
      $KEY_NPAGE) POS[$CUR]=$(( POS[$CUR] + 20 )) ;;
      $KEY_F1)    fkey_help ;;
      $KEY_F2)    run_menu 0 ;;
      $KEY_F3)    do_view ;;
      $KEY_F4)    message_dialog "Edit" "No editor configured." ;;
      $KEY_F5)    do_copy ;;
      $KEY_F6)    do_move ;;
      $KEY_F7)    do_mkdir ;;
      $KEY_F8)    do_delete ;;
      $KEY_F9)    do_view ;;
      $KEY_F10)   STOP=1 ;;
      $'\x1b')    : ;;
      *)
        if [[ ${#k} == 1 && ${k:0:1} == [[:print:]] ]]; then
          CMD_LINE+=$k
          draw_cmdline
          doupdate
          continue
        fi
        ;;
    esac
    draw_all
    doupdate
    (( STOP )) && break
  done
  endwin
}

main "$@"
