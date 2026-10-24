# lib/dialog.sh — dialog/whiptail-style boxes on top of lib/widgets.sh.
#
#   bc_msgbox TITLE TEXT              an OK box; status 0
#   bc_yesno  TITLE TEXT              Yes/No; status 0 = Yes
#   bc_menu   TITLE TEXT TAG ITEM…    a scrolling menu; the chosen TAG is left
#                                     in REPLY, status 1 on Esc/Cancel
#
# Each call takes over the terminal, runs, and hands it back again (exactly
# like dialog does), so the app can run normal shell commands and print normal
# output between dialogs. TEXT may contain literal \n sequences (as dialog's
# does); they become line breaks.
#
# The look mimics dialog's default colours: cyan-on-blue background, grey
# boxes with a black shadow, white borders, blue titles, < OK > style buttons
# with the default one highlighted, and a blue selection bar in menus. The
# colours are allocated with alloc_pair on first use, so they cannot clash
# with an app's own pairs.
#
# Keys: Up/Down/PgUp/PgDn/Home/End move, a letter jumps to the next tag that
# starts with it, Enter chooses, Esc cancels, Tab (and Left/Right) move
# between the menu and the buttons. Mouse: click to select, double-click to
# choose, click a button to press it, wheel to scroll.

[[ -n ${BCD_LOADED:-} ]] && return 0
BCD_LOADED=1
[[ -n ${BCW_LOADED:-} ]] || source "${BASH_SOURCE[0]%/*}/widgets.sh"

# ---------------------------------------------------------------- colours
BCD_COLORS=0
BCD_BG= BCD_BOX= BCD_BORDER= BCD_TITLE= BCD_HOT= BCD_TAG= BCD_BAR=
BCD_SELTAG= BCD_SELTAG2= BCD_SCROLL= BCD_SHADOW=
_bcd_colors() {
  (( BCD_COLORS )) && return
  BCD_COLORS=1
  alloc_pair 6 4; BCD_BG=$bc_pair        # screen: cyan on blue
  alloc_pair 0 7; BCD_BOX=$bc_pair       # box text: black on grey
  alloc_pair 7 7; BCD_BORDER=$bc_pair    # border: white on grey
  alloc_pair 4 7; BCD_TITLE=$bc_pair     # title: blue on grey
  alloc_pair 1 7; BCD_HOT=$bc_pair       # hot letter (unselected): red
  alloc_pair 4 7; BCD_TAG=$bc_pair       # menu tag (unselected): blue
  alloc_pair 7 4; BCD_BAR=$bc_pair       # selected row: white on blue
  alloc_pair 1 4; BCD_SELTAG=$bc_pair    # selected tag hot letter: red
  alloc_pair 3 4; BCD_SELTAG2=$bc_pair   # selected tag / label: yellow
  alloc_pair 2 7; BCD_SCROLL=$bc_pair    # scrollbar arrows: green
  alloc_pair 0 0; BCD_SHADOW=$bc_pair    # shadow: black
}

# ------------------------------------------------------ terminal handover
BCD_SCREEN=0
_bcd_open() {
  if (( ! BCL_STARTED )); then
    bc_init mouse || return 1
    bc_screen "bg"
    _bcd_colors
    bc_style screen pair=$BCD_BG attr=$A_BOLD
    bc_style bg pair=$BCD_BG attr=$A_BOLD
    BCD_SCREEN=1
  else
    initscr || return 1
    _bcd_colors
    BC_DELRECTS=""
    BC_FORCEFULL=1
    bc_dirty all
  fi
  return 0
}

_bcd_close() {
  [[ ${BCL_KIND[bcd]:-} == float ]] && bc_close bcd
  endwin
}

# ------------------------------------------------------------- text prep
# dialog turns literal \n in the text into line breaks; wrap to MAXW.
BCD_TEXT=""
_bcd_prep() { # text maxw
  local t=${1//\\n/$'\n'} maxw=$2 line out="" cur="" word
  while IFS= read -r line; do
    if (( ${#line} <= maxw )); then out+=" $line"$'\n'; continue; fi
    cur=""
    for word in $line; do
      if [[ -z $cur ]]; then cur=$word
      elif (( ${#cur} + 1 + ${#word} <= maxw )); then cur+=" $word"
      else out+=" $cur"$'\n'; cur=$word
      fi
    done
    out+=" $cur"$'\n'
  done <<< "$t"
  BCD_TEXT=${out%$'\n'}
}

# ---------------------------------------------------------------- buttons
# BCD_BTNS: label per button; BCD_BRES: result per button; BCD_BSEL: active.
BCD_BTNS=() BCD_BRES=() BCD_BSEL=0 BCD_WON=btns

_bcd_bwidths() { # -> BCD_BW (one button), BCD_BTOT (row)
  local n=${#BCD_BTNS[@]} i maxl=0
  for (( i = 0; i < n; i++ )); do (( ${#BCD_BTNS[i]} > maxl )) && maxl=${#BCD_BTNS[i]}; done
  BCD_BW=$(( maxl + 2 ))
  BCD_BTOT=$(( n * BCD_BW + (n - 1) * 2 ))
}

_bcd_press() { # index
  local r=${BCD_BRES[$1]}
  if [[ -n $r ]]; then bc_close bcd "$r"; else bc_close bcd; fi
}

draw_btn() { # area
  local a=$1 i n=${#BCD_BTNS[@]} x lab l r
  _bcd_bwidths
  bc_size "$a"
  bc_clear "$a"
  x=$(( (BCL_W - BCD_BTOT) / 2 )); (( x < 0 )) && x=0
  for (( i = 0; i < n; i++ )); do
    lab=${BCD_BTNS[i]}
    l=$(( (BCD_BW - 2 - ${#lab}) / 2 )); r=$(( BCD_BW - 2 - ${#lab} - l ))
    if (( i == BCD_BSEL )); then
      bc_print "$a" 0 "$x" "<" pair=$BCD_BAR attr=$A_BOLD
      bc_print "$a" 0 $(( x + 1 )) "$(printf '%*s' "$l" '')${lab:0:1}" pair=$BCD_BAR attr=$A_BOLD
      bc_print "$a" 0 $(( x + 1 + l + 1 )) "${lab:1}$(printf '%*s' "$r" '')" pair=$BCD_SELTAG2
      bc_print "$a" 0 $(( x + BCD_BW - 1 )) ">" pair=$BCD_BAR attr=$A_BOLD
    else
      bc_print "$a" 0 "$x" "<" pair=$BCD_BORDER
      bc_print "$a" 0 $(( x + 1 )) "$(printf '%*s' "$l" '')${lab:0:1}" pair=$BCD_HOT attr=$A_BOLD
      bc_print "$a" 0 $(( x + 1 + l + 1 )) "${lab:1}$(printf '%*s' "$r" '')" pair=$BCD_BOX attr=$A_BOLD
      bc_print "$a" 0 $(( x + BCD_BW - 1 )) ">" pair=$BCD_BORDER
    fi
    x=$(( x + BCD_BW + 2 ))
  done
}

_bcd_btn_click() { # area y x bstate
  (( $4 & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )) || return 0
  local i n=${#BCD_BTNS[@]} x
  _bcd_bwidths
  bc_size btn
  x=$(( (BCL_W - BCD_BTOT) / 2 )); (( x < 0 )) && x=0
  for (( i = 0; i < n; i++ )); do
    if (( $3 >= x && $3 < x + BCD_BW )); then BCD_BSEL=$i; _bcd_press "$i"; return 0; fi
    x=$(( x + BCD_BW + 2 ))
  done
  return 0
}

# ------------------------------------------------------------------ menu
BCD_TAGS=() BCD_DESCS=() BCD_SEL=0 BCD_TOP=0 BCD_NSHOW=0 BCD_TW=0

_bcd_scroll() {
  (( BCD_SEL < BCD_TOP )) && BCD_TOP=$BCD_SEL
  (( BCD_SEL >= BCD_TOP + BCD_NSHOW )) && BCD_TOP=$(( BCD_SEL - BCD_NSHOW + 1 ))
  (( BCD_TOP < 0 )) && BCD_TOP=0
}

draw_list() { # area
  local a=$1 r y tag desc line
  bc_size "$a"
  bc_clear "$a"
  local h=$BCL_H w=$BCL_W
  local inner=$(( w - 2 ))
  BCD_NSHOW=$(( h - 2 ))
  _bcd_scroll
  printf -v line '%*s' "$inner" ''; line=${line// /$ACS_HLINE}
  bc_print "$a" 0 0 "$ACS_ULCORNER$line$ACS_URCORNER" pair=$BCD_BORDER attr=$A_BOLD
  (( BCD_TOP > 0 )) && bc_print "$a" 0 5 "↑(-)" pair=$BCD_SCROLL
  for (( y = 1; y <= BCD_NSHOW; y++ )); do
    r=$(( BCD_TOP + y - 1 ))
    bc_print "$a" "$y" 0 "$ACS_VLINE" pair=$BCD_BORDER attr=$A_BOLD
    if (( r >= ${#BCD_TAGS[@]} )); then
      bc_print "$a" "$y" 1 "$ACS_VLINE" pair=$BCD_BORDER attr=$A_BOLD
      continue
    fi
    tag=${BCD_TAGS[r]}; desc=${BCD_DESCS[r]}
    tag=${tag:0:$BCD_TW}
    if (( r == BCD_SEL )); then
      bc_print "$a" "$y" 1 "$(printf '%*s' "$inner" '')" pair=$BCD_BAR
      bc_print "$a" "$y" 6 "${tag:0:1}" pair=$BCD_SELTAG attr=$A_BOLD
      bc_print "$a" "$y" 7 "${tag:1}" pair=$BCD_SELTAG2
      bc_print "$a" "$y" $(( 6 + BCD_TW + 2 )) "$desc" pair=$BCD_BAR attr=$A_BOLD
    else
      bc_print "$a" "$y" 6 "${tag:0:1}" pair=$BCD_HOT
      bc_print "$a" "$y" 7 "${tag:1}" pair=$BCD_TAG attr=$A_BOLD
      bc_print "$a" "$y" $(( 6 + BCD_TW + 2 )) "$desc" pair=$BCD_BOX
    fi
    bc_print "$a" "$y" $(( w - 1 )) "$ACS_VLINE" pair=$BCD_BORDER attr=$A_BOLD
  done
  bc_print "$a" $(( h - 1 )) 0 "$ACS_LLCORNER$line$ACS_LRCORNER" pair=$BCD_BORDER attr=$A_BOLD
  (( BCD_TOP + BCD_NSHOW < ${#BCD_TAGS[@]} )) && \
    bc_print "$a" $(( h - 1 )) 5 "↓(+)" pair=$BCD_SCROLL
}

_bcd_list_click() { # area y x bstate
  local r=$(( BCD_TOP + $2 - 1 ))
  if (( $4 & BUTTON4_PRESSED )); then
    (( BCD_SEL > 0 )) && BCD_SEL=$(( BCD_SEL - 1 ))
  elif (( $4 & BUTTON5_PRESSED )); then
    (( BCD_SEL < ${#BCD_TAGS[@]} - 1 )) && BCD_SEL=$(( BCD_SEL + 1 ))
  elif (( $4 & (BUTTON1_PRESSED | BUTTON1_CLICKED | BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
    (( r >= 0 && r < ${#BCD_TAGS[@]} )) || return 0
    BCD_SEL=$r
    if (( $4 & (BUTTON1_DOUBLE_CLICKED | BUTTON1_TRIPLE_CLICKED) )); then
      bc_close bcd "${BCD_TAGS[r]}"
      return 0
    fi
  else
    return 0
  fi
  bc_dirty list
  return 0
}

# --------------------------------------------------------------- key loop
# One handler for the whole float (keys=_bcd_key on bc_float, no area has
# focus); keys not handled here are dropped.
BCD_MODE=""
_bcd_key() { # key
  local k=$1 i n=${#BCD_BTNS[@]} nt=${#BCD_TAGS[@]}
  local inlist=0
  [[ $BCD_MODE == menu && $BCD_WON == list ]] && inlist=1
  case $k in
    $'\e')
      if [[ $BCD_MODE == msgbox ]]; then bc_close bcd ok; else bc_close bcd; fi ;;
    $'\t')
      if [[ $BCD_MODE == menu ]]; then
        [[ $BCD_WON == list ]] && BCD_WON=btns || BCD_WON=list
      else
        BCD_BSEL=$(( (BCD_BSEL + 1) % n )); bc_dirty btn
      fi ;;
    "$KEY_LEFT"|"$KEY_UP")
      if (( inlist )); then
        (( BCD_SEL > 0 )) && BCD_SEL=$(( BCD_SEL - 1 )); bc_dirty list
      else
        (( BCD_BSEL > 0 )) && BCD_BSEL=$(( BCD_BSEL - 1 )); bc_dirty btn
      fi ;;
    "$KEY_RIGHT"|"$KEY_DOWN")
      if (( inlist )); then
        (( BCD_SEL < nt - 1 )) && BCD_SEL=$(( BCD_SEL + 1 )); bc_dirty list
      else
        (( BCD_BSEL < n - 1 )) && BCD_BSEL=$(( BCD_BSEL + 1 )); bc_dirty btn
      fi ;;
    "$KEY_HOME")
        (( inlist )) && { BCD_SEL=0; bc_dirty list; } ;;
    "$KEY_END")
        (( inlist )) && { BCD_SEL=$(( nt - 1 )); bc_dirty list; } ;;
    "$KEY_PPAGE")
        (( inlist )) && { BCD_SEL=$(( BCD_SEL - BCD_NSHOW )); (( BCD_SEL < 0 )) && BCD_SEL=0; bc_dirty list; } ;;
    "$KEY_NPAGE")
        (( inlist )) && { BCD_SEL=$(( BCD_SEL + BCD_NSHOW )); (( BCD_SEL > nt - 1 )) && BCD_SEL=$(( nt - 1 )); bc_dirty list; } ;;
    $'\r'|$'\n'|"$KEY_ENTER")
      if (( inlist )); then
        (( nt > 0 )) && bc_close bcd "${BCD_TAGS[BCD_SEL]}"
      else
        _bcd_press "$BCD_BSEL"
      fi ;;
    ' ')
      [[ $BCD_MODE != menu ]] && _bcd_press "$BCD_BSEL" ;;
    [a-zA-Z])
      if [[ $BCD_MODE == menu ]]; then
        local t=$(( BCD_SEL + 1 ))
        for (( i = 0; i < nt; i++, t++ )); do
          if [[ ${BCD_TAGS[t % nt]:0:1} == [${k,,}${k^^}] ]]; then BCD_SEL=$(( t % nt )); break; fi
        done
        bc_dirty list
      else
        for (( i = 0; i < n; i++ )); do
          [[ ${BCD_BTNS[i]:0:1} == [${k,,}${k^^}] ]] && { _bcd_press "$i"; break; }
        done
      fi ;;
  esac
  return 0
}

# ------------------------------------------------------------- the box
_bcd_box() { # title text menu|plain
  local title=$1 text=$2 menu=$3
  local maxw=$(( BC_COLS - 10 )); (( maxw < 20 )) && maxw=20
  _bcd_prep "$text" "$maxw"
  bc_float bcd size=autoxauto border title="$title" pair=$BCD_BOX \
    bpair=$BCD_BORDER tpair=$BCD_TITLE shadow=mc spair=$BCD_SHADOW \
    keys=_bcd_key || return 1
  if [[ $menu == menu ]]; then
    bc_grid bcd "
      txt
      list
      g
      sep
      btn
    " rows="auto auto 1 1 1" cols="auto"
  else
    bc_grid bcd "
      txt
      sep
      btn
    " rows="auto 1 1" cols="auto"
  fi
  bc_style sep divider bpair=$BCD_BORDER
  bc_text txt "$BCD_TEXT"
  _bcd_bwidths
  bc_content btn 1 "$BCD_BTOT"
  if [[ $menu == menu ]]; then
    local tl tw=0 dw=0 i inner n maxn
    tl=$(printf '%s\n' "$BCD_TEXT" | wc -l)
    for (( i = 0; i < ${#BCD_TAGS[@]}; i++ )); do
      (( ${#BCD_TAGS[i]} > tw )) && tw=${#BCD_TAGS[i]}
      (( ${#BCD_DESCS[i]} > dw )) && dw=${#BCD_DESCS[i]}
    done
    inner=$(( 6 + tw + 2 + dw + 1 ))
    local maxinner=$(( BC_COLS - 12 )); (( inner > maxinner )) && inner=$maxinner
    (( tw > inner - 9 )) && tw=$(( inner - 9 ))
    BCD_TW=$tw
    n=${#BCD_TAGS[@]}; maxn=$(( BC_LINES - tl - 9 )); (( maxn < 1 )) && maxn=1
    (( n > maxn )) && n=$maxn
    bc_content list $(( n + 2 )) $(( inner + 2 ))
    BCL_CLICKFN[list]=_bcd_list_click
  fi
  BCL_CLICKFN[btn]=_bcd_btn_click
  bc_dirty txt list btn
  bc_focus ""
  bc_modal bcd
}

# bc_msgbox TITLE TEXT
bc_msgbox() {
  _bcd_open || return 1
  BCD_MODE=msgbox BCD_BTNS=("OK") BCD_BRES=(ok) BCD_BSEL=0 BCD_WON=btns
  _bcd_box "$1" "$2" plain
  local rc=$?
  _bcd_close
  return "$rc"
}

# bc_yesno TITLE TEXT — status 0 = Yes
bc_yesno() {
  _bcd_open || return 1
  BCD_MODE=yesno BCD_BTNS=("Yes" "No") BCD_BRES=(yes no) BCD_BSEL=0 BCD_WON=btns
  _bcd_box "$1" "$2" plain
  local res=$BCL_RESULT
  _bcd_close
  [[ $res == yes ]]
}

# bc_menu TITLE TEXT TAG ITEM … — the chosen TAG in REPLY; status 1 = cancelled
bc_menu() {
  local title=$1 text=$2; shift 2
  _bcd_open || { REPLY=""; return 1; }
  BCD_MODE=menu BCD_TAGS=() BCD_DESCS=() BCD_SEL=0 BCD_TOP=0 BCD_WON=list
  BCD_BTNS=("OK" "Cancel") BCD_BRES=(ok cancel) BCD_BSEL=0
  while (( $# >= 2 )); do BCD_TAGS+=("$1"); BCD_DESCS+=("$2"); shift 2; done
  _bcd_box "$title" "$text" menu
  local res=$BCL_RESULT
  _bcd_close
  if [[ -z $res || $res == cancel ]]; then REPLY=""; return 1; fi
  REPLY=$res
  return 0
}
