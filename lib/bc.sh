# bc.sh — a bash terminal UI library (ncurses-flavoured API).
# Source this file. Requires bash >= 4.3, stty, tput. ASCII only.

if [ -n "${BC_LOADED:-}" ]; then
  return 0 2>/dev/null
fi
BC_LOADED=1

# --------------------------------------------------------------- attributes
readonly A_NORMAL=0
readonly A_BOLD=1
readonly A_DIM=2
readonly A_REVERSE=4
readonly A_BLINK=8
readonly A_UNDERLINE=16
readonly A_INVIS=32
readonly A_PROTECT=64
readonly A_ALTCHARSET=128
readonly A_COLOR=256
readonly A_ITALIC=512   # ncurses standout() maps to smso, which is italic here

# ------------------------------------------------------------ ACS box chars
readonly ACS_UL='┌'
readonly ACS_UR='┐'
readonly ACS_LL='└'
readonly ACS_LR='┘'
readonly ACS_HLINE='─'
readonly ACS_VLINE='│'
readonly ACS_TTEE='┬'
readonly ACS_BTEE='┴'
readonly ACS_LTEE='├'
readonly ACS_RTEE='┤'
readonly ACS_PLUS='┼'
readonly ACS_S1='⎺'
readonly ACS_S9='⎽'
readonly ACS_DIAMOND='◆'
readonly ACS_CHECK='☐'
readonly ACS_STARS='☰'
readonly ACS_ATEER='█'
# ncurses long-name aliases (ACS_*); glyphs follow the library's Unicode
# convention and match the short names above where they overlap.
readonly ACS_ULCORNER='┌'
readonly ACS_LLCORNER='└'
readonly ACS_URCORNER='┐'
readonly ACS_LRCORNER='┘'
readonly ACS_S3='⎻'
readonly ACS_S7='⎼'
readonly ACS_CKBOARD='▒'
readonly ACS_DEGREE='°'
readonly ACS_PLMINUS='±'
readonly ACS_BULLET='·'
readonly ACS_LARROW='←'
readonly ACS_RARROW='→'
readonly ACS_DARROW='↓'
readonly ACS_UARROW='↑'
readonly ACS_BOARD='▒'
readonly ACS_LANTERN='☃'
readonly ACS_BLOCK='▮'
readonly ACS_LEQUAL='≤'
readonly ACS_GEQUAL='≥'
readonly ACS_PI='π'
readonly ACS_NEQUAL='≠'
readonly ACS_STERLING='£'

# -------------------------------------------------------------- key values
# Values mirror /usr/include/ncurses.h (octal there).
readonly ERR=-1
readonly KEY_CODE_YES=256
readonly KEY_MIN=257
readonly KEY_BREAK=257
readonly KEY_DOWN=258
readonly KEY_UP=259
readonly KEY_LEFT=260
readonly KEY_RIGHT=261
readonly KEY_HOME=262
readonly KEY_BACKSPACE=263
readonly KEY_F0=264
readonly KEY_F1=265
readonly KEY_F2=266
readonly KEY_F3=267
readonly KEY_F4=268
readonly KEY_F5=269
readonly KEY_F6=270
readonly KEY_F7=271
readonly KEY_F8=272
readonly KEY_F9=273
readonly KEY_F10=274
readonly KEY_F11=275
readonly KEY_F12=276
readonly KEY_DL=328
readonly KEY_IL=329
readonly KEY_DC=330
readonly KEY_IC=331
readonly KEY_EIC=332
readonly KEY_CLEAR=333
readonly KEY_EOS=334
readonly KEY_EOL=335
readonly KEY_SF=336
readonly KEY_SR=337
readonly KEY_NPAGE=338
readonly KEY_PPAGE=339
readonly KEY_STAB=340
readonly KEY_CTAB=341
readonly KEY_CATAB=342
readonly KEY_ENTER=343
readonly KEY_SRESET=344
readonly KEY_RESET=345
readonly KEY_PRINT=346
readonly KEY_LL=347
readonly KEY_A1=348
readonly KEY_A3=349
readonly KEY_B2=350
readonly KEY_C1=351
readonly KEY_C3=352
readonly KEY_BTAB=353
readonly KEY_BEG=354
readonly KEY_BEGIN=354
readonly KEY_CANCEL=355
readonly KEY_CLOSE=356
readonly KEY_COMMAND=357
readonly KEY_COPY=358
readonly KEY_CREATE=359
readonly KEY_END=360
readonly KEY_EXIT=361
readonly KEY_FIND=362
readonly KEY_HELP=363
readonly KEY_MARK=364
readonly KEY_MESSAGE=365
readonly KEY_MOVE=366
readonly KEY_NEXT=367
readonly KEY_OPEN=368
readonly KEY_OPTIONS=369
readonly KEY_PREVIOUS=370
readonly KEY_REDO=371
readonly KEY_REFERENCE=372
readonly KEY_REFRESH=373
readonly KEY_REPLACE=374
readonly KEY_RESTART=375
readonly KEY_RESUME=376
readonly KEY_SAVE=377
readonly KEY_SBEG=378
readonly KEY_SCANCEL=379
readonly KEY_SCOMMAND=380
readonly KEY_SCOPY=381
readonly KEY_SCREATE=382
readonly KEY_SDC=383
readonly KEY_SDL=384
readonly KEY_SELECT=385
readonly KEY_SEND=386
readonly KEY_SEOL=387
readonly KEY_SEXIT=388
readonly KEY_SFIND=389
readonly KEY_SHELP=390
readonly KEY_SHOME=391
readonly KEY_SIC=392
readonly KEY_SLEFT=393
readonly KEY_SMESSAGE=394
readonly KEY_SMOVE=395
readonly KEY_SNEXT=396
readonly KEY_SOPTIONS=397
readonly KEY_SPREVIOUS=398
readonly KEY_SPRINT=399
readonly KEY_SREDO=400
readonly KEY_SREPLACE=401
readonly KEY_SRIGHT=402
readonly KEY_SRSUME=403
readonly KEY_SSAVE=404
readonly KEY_SSUSPEND=405
readonly KEY_SUNDO=406
readonly KEY_SUSPEND=407
readonly KEY_UNDO=408
readonly KEY_MOUSE=409
readonly KEY_RESIZE=410
readonly KEY_ALT_SH=411   # Alt-S-h / Alt-H (ESC H) -- mc's "show directory history" key (the 'v' button); what the dialog field's "[^]" completer opens
readonly KEY_MAX=511
readonly KEY_DELETE=330   # X/Open alias for KEY_DC

# Mouse bstate bits (ncurses: 5-bit slots per button, MASK(b,m) = m <<
# ((b-1)*5); button 4 = wheel up, button 5 = wheel down; modifier bits from
# bit 25: CTRL=1<<25, SHIFT=2<<25, ALT=4<<25, REPORT_MOUSE_POSITION=8<<25,
# matching the installed ncurses 6.6 build).
readonly NCURSES_BUTTON_RELEASED=1
readonly NCURSES_BUTTON_PRESSED=2
readonly NCURSES_BUTTON_CLICKED=4
readonly BUTTON1_RELEASED=1
readonly BUTTON1_PRESSED=2
readonly BUTTON1_CLICKED=4
readonly BUTTON1_DOUBLE_CLICKED=8
readonly BUTTON1_TRIPLE_CLICKED=16
readonly BUTTON2_RELEASED=32
readonly BUTTON2_PRESSED=64
readonly BUTTON2_CLICKED=128
readonly BUTTON2_DOUBLE_CLICKED=256
readonly BUTTON2_TRIPLE_CLICKED=512
readonly BUTTON3_RELEASED=1024
readonly BUTTON3_PRESSED=2048
readonly BUTTON3_CLICKED=4096
readonly BUTTON3_DOUBLE_CLICKED=8192
readonly BUTTON3_TRIPLE_CLICKED=16384
readonly BUTTON4_RELEASED=32768
readonly BUTTON4_PRESSED=65536
readonly BUTTON4_CLICKED=131072
readonly BUTTON4_DOUBLE_CLICKED=262144
readonly BUTTON4_TRIPLE_CLICKED=524288
readonly BUTTON5_RELEASED=1048576
readonly BUTTON5_PRESSED=2097152
readonly BUTTON5_CLICKED=4194304
readonly BUTTON5_DOUBLE_CLICKED=8388608
readonly BUTTON5_TRIPLE_CLICKED=16777216
readonly BUTTON_PRESSED=$(( BUTTON1_PRESSED | BUTTON2_PRESSED | BUTTON3_PRESSED | BUTTON4_PRESSED | BUTTON5_PRESSED ))
readonly BUTTON_RELEASED=$(( BUTTON1_RELEASED | BUTTON2_RELEASED | BUTTON3_RELEASED | BUTTON4_RELEASED | BUTTON5_RELEASED ))
readonly BUTTON_CLICKED=$(( BUTTON1_CLICKED | BUTTON2_CLICKED | BUTTON3_CLICKED | BUTTON4_CLICKED | BUTTON5_CLICKED ))
readonly BUTTON_DOUBLE_CLICKED=$(( BUTTON1_DOUBLE_CLICKED | BUTTON2_DOUBLE_CLICKED | BUTTON3_DOUBLE_CLICKED | BUTTON4_DOUBLE_CLICKED | BUTTON5_DOUBLE_CLICKED ))
readonly BUTTON_TRIPLE_CLICKED=$(( BUTTON1_TRIPLE_CLICKED | BUTTON2_TRIPLE_CLICKED | BUTTON3_TRIPLE_CLICKED | BUTTON4_TRIPLE_CLICKED | BUTTON5_TRIPLE_CLICKED ))
readonly BUTTON_CTRL=33554432
readonly BUTTON_SHIFT=67108864
readonly BUTTON_ALT=134217728
readonly REPORT_MOUSE_POSITION=268435456
readonly ALL_MOUSE_EVENTS=268435455
# Mask of bits a valid mousemask() may contain
readonly _BC_MOUSE_VALID_BITS=$(( REPORT_MOUSE_POSITION | BUTTON_ALT | BUTTON_CTRL \
  | BUTTON_SHIFT | BUTTON_PRESSED | BUTTON_RELEASED | BUTTON_CLICKED \
  | BUTTON_DOUBLE_CLICKED | BUTTON_TRIPLE_CLICKED ))

# Mouse state
BC_MOUSE_MASK=0           # current mousemask; 0 = mouse off
BC_MOUSE_MASK2=0          # expanded mask (click implies press+release, etc.)
BC_MOUSE_ENABLED=0        # 1 = enable sequence already sent to terminal
BC_MEVENTS=()             # queue of pending events: "id x y bstate"
BC_ME_ID=0
BC_ME_X=0
BC_ME_Y=0
BC_ME_BSTATE=0
BC_MOUSE_PRESSED=0        # buttons currently tracked as pressed (_mouse_bstate)
BC_MAXCLICK=166           # max interval (ms) to compose click gestures
                          # (ncurses DEFAULT_MAXCLICK)
BC_OLD_MAXCLICK=0         # previous maxclick (mouseinterval)
BC_MOUSE_TYPE=0           # 1 = mouse known to be available/enabled
BC_PENDING_IN=""          # chars saved for the next wgetch (ungetch/ungetmouse)
BC_PENDING_KEY=""         # function-key code saved for the next wgetch

# -------------------------------------------------------- ncurses constants
readonly SP=32             # the space character

# ------------------------------------------------------------------ colors
readonly COLOR_BLACK=0
readonly COLOR_RED=1
readonly COLOR_GREEN=2
readonly COLOR_YELLOW=3
readonly COLOR_BLUE=4
readonly COLOR_MAGENTA=5
readonly COLOR_CYAN=6
readonly COLOR_WHITE=7

# ----------------------------------------------------------------- state
BC_STDSCR=0
BC_CURR=0
BC_LINES=24
BC_COLS=80
BC_COLORS=0
BC_COLOR_STARTED=0     # set by start_color; ncurses ignores pairs until then
BC_DEFAULT_COLORS=0    # set by use_default_colors/assume_default_colors
BC_PAIRS=0
BC_WN=1
BC_STARTED=0
BC_OLDSTTY=""
BC_WINCH=0            # set by a SIGWINCH trap; consumed by wgetch as KEY_RESIZE
BC_FORCEFULL=0       # when set, the next doupdate recomposites the whole screen
BC_INITPAINT=0       # when set, the next stdscr refresh paints the background
BC_TEST_SEQ=0        # incremented by doupdate when BC_TEST_DIR is set
BC_NO_SCROLLREG=${BC_NO_SCROLLREG:-0}
BC_SCROLLREQ=""      # pending safe terminal scroll: "win top bottom n"
declare -A BC_SCROLL=() # window scrollok flag
declare -A BC_SR=()     # window scroll region: "top bottom"

# ncurses globals (mirrored by initscr / start_color)
COLS=80
LINES=24
COLORS=0
COLOR_PAIRS=0
ESCDELAY=1000
BC_HALFTENTHS=0
TABSIZE=8
PC=0                # termcap: padding char
BC=$'\b'            # termcap: backspace char
UP=$'\x1b[A'        # termcap: cursor-up string
SCR_FILE='SCR.SAV'
BC_ESC=${UP:0:1}  # the ESC byte (real 0x1b, not a 2-char sequence)

# slk (soft key) state
BC_SLK=0
BC_SLK_PENDING=0
BC_SLK_FMT=0
BC_SLK_LINES=0
BC_SLK_MAXLAB=0
BC_SLK_MAXLEN=0
BC_SLK_LABCNT=0
BC_SLK_WIN=""
BC_SLK_ATTR=0
BC_SLK_PAIR=0
BC_SLK_HIDDEN=0
BC_SLK_DIRTY=0
declare -a BC_SLK_TEXT=()  # label text (leading blanks stripped)
declare -a BC_SLK_FORM=()  # formatted label, MAXLEN chars
declare -a BC_SLK_X=()     # label column position
declare -a BC_SLK_LD=()    # per-label dirty

declare -A BC_C=()   # desired char   key "$y $x"
declare -A BC_A=()   # desired attr
declare -A BC_P=()   # desired pair
declare -A BC_S=()   # last sent char
declare -A BC_SA=()  # last sent attr
declare -A BC_SP=()  # last sent pair
declare -A BC_MK=()  # dirty marks, key "$win/$y $x"
declare -A BC_WD=()  # dirty key lists per window
# Row-level fast path: a window row drawn full-width with a single pen is stored
# as one char string (BC_CROW) plus that pen (BC_PUNI, key "buf ay"); its mere
# presence means the row cache is authoritative and the per-cell BC_C/A/P for
# that row are stale. Any per-cell op flushes the row first (_bc_flush_row).
# The composited screen keeps the same row form (BC_SCROW/BC_SPROW) so a whole
# row can be diffed and emitted in O(1). Dirty rows tracked per window in
# BC_WDR (comma list) with BC_MKR marks.
declare -A BC_CROW=()  # row char string, key "$buf $ay"
declare -A BC_PUNI=()  # row uniform pen "a p", key "$buf $ay"
declare -A BC_SCROW=() # last sent screen row chars, key "$ay"
declare -A BC_SPROW=() # last sent screen row pen "a p", key "$ay"
declare -A BC_WDR=()   # dirty row lists per window
declare -A BC_MKR=()   # dirty row marks, key "$win/$ay"
declare -A BC_WY=()  # window origin y
declare -A BC_WX=()  # window origin x
declare -A BC_WH=()  # window height
declare -A BC_WW=()  # window width
declare -A BC_WBG=() # window background char
declare -A BC_WBGA=() # window background attr
declare -A BC_WBGP=() # window background pair
declare -A BC_WAX=()  # window cursor x
declare -A BC_WAY=()  # window cursor y
declare -A BC_WCURA=() # window current attr
declare -A BC_WCURP=() # window current pair
declare -A BC_WDELAY=() # window nodelay flag
declare -A BC_WTIMEOUT=() # window timeout delay
declare -A BC_PAIRS_A=() # pair -> fg
declare -A BC_PAIRS_B=() # pair -> bg
declare -A BC_PAIRS_FREE=() # pair -> 1 if freed (colors retained)
declare -A BC_COLOR_R=() # color -> red
declare -A BC_COLOR_G=() # color -> green
declare -A BC_COLOR_B=() # color -> blue
declare -A BC_SGRC=()  # "a/p" -> sgr code
declare -a BC_WLIST=()
declare -A BC_WBUF=() # buffer owner per window (w -> owner window id)
declare -A BC_BUF2W=() # reverse: buffer id -> owning window
declare -A BC_WPAR=() # parent window id, -1 for top-level windows
declare -A BC_WPOY=() # parent-relative origin y (ncurses _pary)
declare -A BC_WPOX=() # parent-relative origin x (ncurses _parx)
declare -A BC_PADY=()  # pad: last prefresh pminrow
declare -A BC_PADX=()  # pad: last prefresh pmincol
declare -A BC_PADT=()  # pad: last prefresh sminrow
declare -A BC_PADL=()  # pad: last prefresh smincol
declare -A BC_PADB=()  # pad: last prefresh smaxrow
declare -A BC_PADR=()  # pad: last prefresh smaxcol
declare -A BC_WCLEAR=()
declare -A BC_WIDC=()
declare -A BC_WIDL=()
declare -A BC_WIMM=()
declare -A BC_WLEAVE=()
declare -A BC_WNOTIMEOUT=()
declare -A BC_WSYNC=()
declare -A BC_WPAD=()
# panel state: BC_PSTACK holds panel ids ordered bottom -> top
BC_PN=0
declare -A BC_PWIN=()   # panel id -> window id
declare -A BC_PHID=()   # panel id -> 1 if hidden
declare -A BC_PUSR=()   # panel id -> opaque user pointer (string)
declare -a BC_PSTACK=()
bc_panel=""

key=""
wch=""
wcha=0
wchp=0
BC_GMY=0
BC_GMX=0
BC_GBY=0
BC_GBX=0
BC_GPY=-1
BC_GPX=-1
bc_str=""
bc_delay=0
bc_parent=-1
bc_top=0
bc_bottom=0
bc_chstr=()
bc_chattr=()
bc_chpair=()
BC_CR=0
BC_CG=0
BC_CB=0
BC_CPF=0
BC_CPB=0
BC_EPF=0
BC_EPB=0
BC_DEFAULT_FG=-1
BC_DEFAULT_BG=-1
bc_pair=-1
bc_key=-1
BC_CAN_CHANGE_COLOR=0
BC_ERASECHAR=127
BC_KILLCHAR=21
BC_ERASEWCHAR=127
BC_KILLWCHAR=21
BC_META=0
BC_FILTER=0
curscr=0
newscr=0

# ------------------------------------------------------------ internals
_bc_init_window() { # w y x h
  local w=$1
  BC_WY[$w]=$2
  BC_WX[$w]=$3
  BC_WH[$w]=$4
  BC_WW[$w]=$5
  BC_WBG[$w]=' '
  BC_WBGA[$w]=0
  BC_WBGP[$w]=0
  BC_WAX[$w]=0
  BC_WAY[$w]=0
  BC_WCURA[$w]=0
  BC_WCURP[$w]=0
  BC_WDELAY[$w]=0
  if (( BC_HALFTENTHS )); then
    BC_WTIMEOUT[$w]=$(( BC_HALFTENTHS * 100 ))
  else
    BC_WTIMEOUT[$w]=-1
  fi
  BC_WKEYPAD[$w]=0
  BC_WYOFF[$w]=0
  BC_WBUF[$w]=$w
  BC_BUF2W[$w]=$w
  BC_WPAR[$w]=-1
  BC_WCLEAR[$w]=0
  BC_WIDC[$w]=0
  BC_WIDL[$w]=0
  BC_WIMM[$w]=0
  BC_WLEAVE[$w]=0
  BC_WNOTIMEOUT[$w]=0
  BC_WSYNC[$w]=0
  BC_WPAD[$w]=0
  BC_SCROLL[$w]=0
  BC_SR[$w]=""
  BC_WLIST+=("$w")
}

_bc_term() {
  local t
  t=$(tput lines 2>/dev/null) || t=""
  if [[ $t =~ ^[0-9]+$ ]] && (( t > 0 )); then BC_LINES=$t; else BC_LINES=24; fi
  t=$(tput cols 2>/dev/null) || t=""
  if [[ $t =~ ^[0-9]+$ ]] && (( t > 0 )); then BC_COLS=$t; else BC_COLS=80; fi
  t=$(tput colors 2>/dev/null) || t=""
  if [[ $t =~ ^[0-9]+$ ]]; then BC_COLORS=$t; else BC_COLORS=0; fi
  BC_PAIRS=65536
  LINES=$BC_LINES
  COLS=$BC_COLS
  COLORS=$BC_COLORS
  COLOR_PAIRS=$BC_PAIRS
  BC_OLDSTTY=$(stty -g 2>/dev/null) || BC_OLDSTTY=""
  stty raw -echo 2>/dev/null
  printf '\e[?1049h\e[2J\e[?25l'
  _bc_load_keytable
  [[ -n $BC_SMKX ]] && printf '%s' "$BC_SMKX"
  trap '_bc_endwin_trap' EXIT
}

_bc_endwin_trap() {
  if (( BC_STARTED )); then
    endwin
  fi
}

# ------------------------------------------------------------ key table
# Like ncurses keytry, key decoding is driven by the terminal's terminfo
# definitions, not hard-coded sequences. The table is built once from
# infocmp at initscr time; wgetch matches the byte stream against it.
BC_KEYSEQ=()   # full key sequences (all start with ESC)
BC_KEYVAL=()   # matching KEY_* value
declare -A BC_KEYOK=() # key -> 0 if disabled by keyok

_bc_ti_decode() { # $1 raw terminfo string -> _BC_TI decoded bytes
  local s=$1
  s=${s//'\sp'/ }
  s=${s//'\s'/ }
  _BC_TI=$(printf '%b' "$s")   # \E \e \0nnn \\ \n \t \a \b \f \r \v
}

_bc_load_keytable() {
  BC_KEYSEQ=()
  BC_KEYVAL=()
  BC_SMKX=""
  BC_RMKX=""
  [[ -n ${TERM:-} ]] || return 0
  local -A valmap=(
    [kcuu1]=$KEY_UP   [kcud1]=$KEY_DOWN [kcul1]=$KEY_LEFT [kcub1]=$KEY_LEFT [kcuf1]=$KEY_RIGHT
    [khome]=$KEY_HOME [kend]=$KEY_END
    [kf1]=$KEY_F1  [kf2]=$KEY_F2  [kf3]=$KEY_F3  [kf4]=$KEY_F4  [kf5]=$KEY_F5
    [kf6]=$KEY_F6  [kf7]=$KEY_F7  [kf8]=$KEY_F8  [kf9]=$KEY_F9  [kf10]=$KEY_F10
    [kf11]=$KEY_F11 [kf12]=$KEY_F12
    [kdch1]=$KEY_DC [kich1]=$KEY_IC [kpp]=$KEY_PPAGE [knp]=$KEY_NPAGE
    [kclr]=$KEY_CLEAR
  )
  local out line ent cap val
  out=$(infocmp -1 -x "${TERM}" 2>/dev/null) || return 0
  while IFS= read -r line; do
    [[ $line == \#* || $line == *'|'* || -z ${line//[[:space:]]/} ]] && continue
    local IFS=,
    for ent in $line; do
      ent=${ent#"${ent%%[![:space:]]*}"}
      ent=${ent%"${ent##*[![:space:]]}"}
      [[ $ent == *=* ]] || continue
      cap=${ent%%=*}
      val=${ent#*=}
      if [[ $cap == smkx || $cap == rmkx ]]; then
        _bc_ti_decode "$val"
        [[ -n $_BC_TI ]] || continue
        if [[ $cap == smkx ]]; then BC_SMKX=$_BC_TI; else BC_RMKX=$_BC_TI; fi
        continue
      fi
      [[ -n ${valmap[$cap]:-} ]] || continue
      _bc_ti_decode "$val"
      [[ -n $_BC_TI ]] || continue
      BC_KEYSEQ+=("$_BC_TI")
      BC_KEYVAL+=("${valmap[$cap]}")
    done
  done <<< "$out"
  # Alt-S-h / Alt-H: ESC followed by 'H' -- mc's "show directory history" key
  # (the 'v' button), i.e. what a dialog field's "[^]" completer opens.
  # Not a terminfo capability, so map it explicitly.
  BC_KEYSEQ+=($'\x1bH'); BC_KEYVAL+=($KEY_ALT_SH)
  return 0
}

_BC_TI_KEY=0
_bc_ti_lookup() { # $1 full sequence -> _BC_TI_KEY, returns 0 on exact match
  local i k
  for i in ${!BC_KEYSEQ[@]}; do
    if [[ $1 == "${BC_KEYSEQ[i]}" ]]; then
      k=${BC_KEYVAL[i]}
      [[ ${BC_KEYOK[$k]:-1} == 0 ]] && continue
      _BC_TI_KEY=$k
      return 0
    fi
  done
  return 1
}

_bc_ti_prefix() { # $1 partial sequence -> 0 if a longer entry starts with it
  local i
  for i in ${!BC_KEYSEQ[@]}; do
    (( ${#BC_KEYSEQ[i]} > ${#1} )) && [[ "${BC_KEYSEQ[i]}" == "$1"* ]] && return 0
  done
  return 1
}

_bc_key_code() { # key -> bc_key_code
  local k=$1
  if [[ $k =~ ^[0-9]+$ ]]; then
    bc_key_code=$k
  else
    printf -v bc_key_code '%d' "'$k"
  fi
}

has_key() { # key
  local k=$1 name
  _bc_key_code "$k"
  k=$bc_key_code
  (( k == KEY_RESIZE )) && return 0
  for name in $(compgen -v KEY_); do
    if (( ${!name} == k )); then
      return 0
    fi
  done
  return 1
}

_bc_keyname_char() { # c
  local c=$1
  if (( c == 0 )); then
    printf '@@'
  elif (( c < 32 )); then
    printf '^%b' "\\$(printf '%03o' "$(( c + 64 ))")"
  elif (( c == 127 )); then
    printf '^?'
  elif (( c < 128 )); then
    printf '%b' "\\$(printf '%03o' "$c")"
  else
    printf ''
  fi
}

keyname() { # c
  local c=$1 name
  _bc_key_code "$c"
  c=$bc_key_code
  for name in $(compgen -v KEY_); do
    if (( ${!name} == c )); then
      printf '%s' "$name"
      return 0
    fi
  done
  _bc_keyname_char "$c"
  return 0
}

key_defined() { # definition -> bc_key
  local def=$1
  bc_key=$ERR
  if _bc_ti_lookup "$def"; then
    bc_key=$_BC_TI_KEY
    printf '%s' "$bc_key"
    return 0
  fi
  return 1
}

keybound() { # definition options -> bc_key
  key_defined "$1"
}

keyok() { # key return -> bc_key previous
  local k=$1 bf=${2:-1}
  local prev=${BC_KEYOK[$k]:-1}
  bc_key=$prev
  if [[ $bf == 0 || $bf == false ]]; then
    BC_KEYOK[$k]=0
  else
    BC_KEYOK[$k]=1
  fi
  return 0
}

define_key() { # definition key
  local def=$1 k=$2 i
  [[ -n $def ]] || return 1
  for i in "${!BC_KEYSEQ[@]}"; do
    if [[ ${BC_KEYSEQ[i]} == "$def" ]]; then
      if (( k == ERR )); then
        unset "BC_KEYSEQ[i]"
        unset "BC_KEYVAL[i]"
      else
        BC_KEYVAL[i]=$k
      fi
      return 0
    fi
  done
  if (( k != ERR )); then
    BC_KEYSEQ+=("$def")
    BC_KEYVAL+=("$k")
  fi
  return 0
}

# build (and cache) the SGR sequence for an attr/pair combination
_bc_sgr() { # a p
  local a=$1 p=$2 k="$1/$2"
  local s="${BC_SGRC[$k]:-}"
  if [[ -z $s ]]; then
    s=""
    (( a & 1 )) && s="${s:+$s;}1"
    (( a & 2 )) && s="${s:+$s;}2"
    (( a & 8 )) && s="${s:+$s;}5"
    (( a & 16 )) && s="${s:+$s;}4"
    (( a & 32 )) && s="${s:+$s;}8"
    (( a & 64 )) && s="${s:+$s;}73"
    (( a & 4 )) && s="${s:+$s;}7"
    (( a & 512 )) && s="${s:+$s;}3"
    if (( BC_COLOR_STARTED )); then
      if [[ -n ${BC_PAIRS_A[$p]:-} ]]; then
        local fg=${BC_PAIRS_A[$p]} bg=${BC_PAIRS_B[$p]}
        if (( fg < 0 )); then
          s="${s:+$s;}39"
        elif (( fg < 8 )); then
          s="${s:+$s;}$(( 30 + fg ))"
        elif (( fg < 16 )); then
          s="${s:+$s;}$(( 90 + (fg - 8) ))"   # bright fg 8-15 -> 90-97 (matches mc)
        else
          s="${s:+$s;}38;5;$fg"
        fi
        if (( bg < 0 )); then
          s="${s:+$s;}49"
        elif (( bg < 8 )); then
          s="${s:+$s;}$(( 40 + bg ))"
        elif (( bg < 16 )); then
          s="${s:+$s;}$(( 100 + (bg - 8) ))"  # bright bg 8-15 -> 100-107
        else
          s="${s:+$s;}48;5;$bg"
        fi
      else
        if (( BC_DEFAULT_COLORS )); then
          local df=${BC_DEFAULT_FG:-0} db=${BC_DEFAULT_BG:-0}
          if (( df < 0 )); then s="${s:+$s;}39"; elif (( df < 8 )); then s="${s:+$s;}$(( 30 + df ))"; elif (( df < 16 )); then s="${s:+$s;}$(( 90 + (df - 8) ))"; else s="${s:+$s;}38;5;$df"; fi
          if (( db < 0 )); then s="${s:+$s;}49"; elif (( db < 8 )); then s="${s:+$s;}$(( 40 + db ))"; elif (( db < 16 )); then s="${s:+$s;}$(( 100 + (db - 8) ))"; else s="${s:+$s;}48;5;$db"; fi
        else
          s="${s:+$s;}30;40"
        fi
      fi
    fi
    [[ -z $s ]] && s="0"
    BC_SGRC[$k]=$s
  fi
  BC_SGR=$s
}

# materialize a cached uniform row back into the per-cell arrays and drop the
# cache, so a per-cell op can safely edit it. No-op when the row isn't cached.
_bc_flush_row() { # w ay
  local w=$1 ay=$2
  local buf=${BC_WBUF[$w]}
  local rk="$buf $ay"
  [[ -n ${BC_PUNI[$rk]+x} ]] || return 0
  local row=${BC_CROW[$rk]} pen=${BC_PUNI[$rk]}
  local a=${pen% *} p=${pen#* }
  local o=${BC_BUF2W[$buf]:-$w}
  local wx=${BC_WX[$o]} ww=${BC_WW[$o]} i ch k
  for (( i = 0; i < ww; i++ )); do
    ch=${row:i:1}
    k="$buf/$ay $(( wx + i ))"
    BC_C[$k]=$ch; BC_A[$k]=$a; BC_P[$k]=$p
  done
  unset "BC_PUNI[$rk]" "BC_CROW[$rk]"
}

# materialize every cached row of a window into per-cell arrays, so a reader or
# bulk op that works per-cell sees authoritative data.
_bc_flush_win() { # w
  local w=$1
  local ay0 wy=${BC_WY[$w]} wh=${BC_WH[$w]}
  for (( ay0 = wy; ay0 < wy + wh; ay0++ )); do _bc_flush_row "$w" "$ay0"; done
}

# record one absolute cell as changed for a window
_bc_cell() { # w ay ax ch a p
  _bc_flush_row "$1" "$2"
  local buf=${BC_WBUF[$1]}
  local k="$buf/$2 $3" mk="$1/$2 $3"
  BC_C[$k]=$4
  BC_A[$k]=$5
  BC_P[$k]=$6
  if [[ -z ${BC_MK[$mk]:-} ]]; then
    BC_MK[$mk]=1
    BC_WD[$1]+=",$2 $3"
  fi
}

# render_char semantics (lib_addch.c): a plain space inherits the window
# background; any char ORs in the window attrs and background attrs, and the
# colour pair falls back char -> window attrs -> background.
_bc_render() { # w ch a p -> BC_RCH BC_RA BC_RP
  local w=$1
  local wa=${BC_WCURA[$w]} wp=${BC_WCURP[$w]}
  local ba=${BC_WBGA[$w]} bp=${BC_WBGP[$w]}
  if [[ ${2:- } == ' ' && ${3:-0} -eq ${wa} && ${4:-0} -eq ${wp} ]]; then
    BC_RCH=${BC_WBG[$w]}
    BC_RA=$(( wa | ba ))
    if (( wp )); then
      BC_RP=$wp
    else
      BC_RP=$bp
    fi
  else
    BC_RCH=$2
    BC_RA=$(( ${3:-0} | wa | ba ))
    if (( ${4:-0} )); then
      BC_RP=$4
    elif (( wp )); then
      BC_RP=$wp
    else
      BC_RP=$bp
    fi
  fi
}

# write into a window at relative (y,x); clamps, advances the window cursor
_bc_put() { # w y x ch a p
  local w=$1
  if (( $2 < 0 || $3 < 0 || $2 >= BC_WH[$w] || $3 >= BC_WW[$w] )); then
    return 0
  fi
  _bc_render "$w" "$4" "$5" "$6"
  _bc_cell "$w" "$(( BC_WY[$w] + $2 ))" "$(( BC_WX[$w] + $3 ))" "$BC_RCH" "$BC_RA" "$BC_RP"
  local nx=$(( $3 + 1 )) ny=$2
  if (( nx >= BC_WW[$w] )); then
    nx=0
    ny=$(( ny + 1 ))
  fi
  if (( ny >= BC_WH[$w] )); then
    ny=$(( BC_WH[$w] - 1 ))
    nx=$(( BC_WW[$w] - 1 ))
  fi
  BC_WAX[$w]=$nx
  BC_WAY[$w]=$ny
}

# emit a string starting at (y,x), advancing the cursor like waddstr.
# Control characters follow ncurses addch semantics: '\n' clears to end of
# line then moves to column 0 of the next line (no move on the bottom line),
# '\r' returns to column 0, '\b' steps back one column (not past 0).
_bc_emit() { # w y x text a p
  local w=$1 y=$2 x=$3 text=$4 a=$5 p=$6
  local i=0 h=${BC_WH[$w]} ww=${BC_WW[$w]} ch
  local len=${#text}
  # Fast path: plain text that fits on one row within the window. Inline the
  # bounds check, render and cell-set that _bc_put/_bc_render/_bc_cell would do
  # per char, hoisting the constant attr/pair math out of the loop.
  if (( y >= 0 && y < h && x >= 0 && x + len <= ww )) &&
     [[ $text != *$'\n'* && $text != *$'\r'* && $text != *$'\b'* ]]; then
    local wa=${BC_WCURA[$w]} wp=${BC_WCURP[$w]} ba=${BC_WBGA[$w]} bp=${BC_WBGP[$w]} bg=${BC_WBG[$w]}
    local ra_ns=$(( ${a:-0} | wa | ba )) rp_ns
    if (( ${p:-0} )); then rp_ns=$p; elif (( wp )); then rp_ns=$wp; else rp_ns=$bp; fi
    local special=0 ra_sp=0 rp_sp=$rp_sp
    if (( ${a:-0} == wa && ${p:-0} == wp )); then
      special=1; ra_sp=$(( wa | ba ))
      if (( wp )); then rp_sp=$wp; else rp_sp=$bp; fi
    fi
    local buf=${BC_WBUF[$w]} k mk yy=$y ayoff=${BC_WY[$w]} axoff=${BC_WX[$w]} ay ax
    ay=$(( ayoff + yy ))
    local rk="$buf $ay"
    # Full-row write: store the whole row as one char string + one pen. The row
    # cache is laid out in the buffer owner's columns, so only the owner may use
    # these fast paths (a derwin sharing the buffer has different columns).
    if [[ $buf == "$w" ]] && (( x == 0 && x + len == ww )); then
      local cs=$text
      if (( special )) && [[ $bg != ' ' ]]; then cs=${text// /$bg}; fi
      BC_CROW[$rk]=$cs; BC_PUNI[$rk]="$ra_ns $rp_ns"
      [[ -z ${BC_MKR[$w/$ay]:-} ]] && { BC_MKR[$w/$ay]=1; BC_WDR[$w]+=",$ay"; }
      BC_WAX[$w]=$(( x + len )); BC_WAY[$w]=$y
      return 0
    fi
    # Partial span onto an existing uniform row with the same pen: splice it in.
    if [[ $buf == "$w" && -n ${BC_PUNI[$rk]+x} && ${BC_PUNI[$rk]} == "$ra_ns $rp_ns" ]]; then
      local row=${BC_CROW[$rk]}
      BC_CROW[$rk]="${row:0:x}${text}${row:x+len}"
      [[ -z ${BC_MKR[$w/$ay]:-} ]] && { BC_MKR[$w/$ay]=1; BC_WDR[$w]+=",$ay"; }
      BC_WAX[$w]=$(( x + len )); BC_WAY[$w]=$y
      return 0
    fi
    # Otherwise drop any cache and write this span per-cell.
    _bc_flush_row "$w" "$ay"
    while (( i < len )); do
      ch=${text:i:1}
      ax=$(( axoff + x )); k="$buf/$ay $ax"
      if (( special )) && [[ $ch == ' ' ]]; then
        BC_C[$k]=$bg; BC_A[$k]=$ra_sp; BC_P[$k]=$rp_sp
      else
        BC_C[$k]=$ch; BC_A[$k]=$ra_ns; BC_P[$k]=$rp_ns
      fi
      mk="$w/$ay $ax"
      [[ -z ${BC_MK[$mk]:-} ]] && { BC_MK[$mk]=1; BC_WD[$w]+=",$ay $ax"; }
      x=$(( x + 1 )); i=$(( i + 1 ))
    done
    BC_WAX[$w]=$x; BC_WAY[$w]=$y
    return 0
  fi
  while (( i < ${#text} )); do
    ch=${text:i:1}
    case $ch in
      $'\n')
        _bc_clrtoeol_cell "$w" "$y" "$x"
        if (( y < h - 1 )); then
          y=$(( y + 1 ))
          x=0
        fi
        ;;
      $'\r')
        x=0
        ;;
      $'\b')
        (( x > 0 )) && x=$(( x - 1 ))
        ;;
      *)
        _bc_put "$w" "$y" "$x" "$ch" "$a" "$p"
        x=$(( x + 1 ))
        if (( x >= ww )); then
          x=0
          y=$(( y + 1 ))
        fi
        ;;
    esac
    i=$(( i + 1 ))
  done
  (( y >= h )) && y=$(( h - 1 ))
  (( x >= ww )) && x=$(( ww - 1 ))
  BC_WAX[$w]=$x
  BC_WAY[$w]=$y
}

# set BC_RCH/BC_RA/BC_RP to the window's background rendition (ncurses _bkgd)
_bc_bg() { # w -> BC_RCH BC_RA BC_RP
  local w=$1
  BC_RCH=${BC_WBG[$w]:- }
  BC_RA=${BC_WBGA[$w]:-0}
  BC_RP=${BC_WBGP[$w]:-0}
}

# clear a window line from relative (y,x) to the end of the line
_bc_clrtoeol_cell() { # w y x
  local w=$1 y=$2 x=$3
  local ww=${BC_WW[$w]}
  (( y >= ${BC_WH[$w]} || x >= ww )) && return 0
  _bc_bg "$w"
  local k
  for (( x = x; x < ww; x++ )); do
    k="$(( BC_WY[$w] + y )) $(( BC_WX[$w] + x ))"
    _bc_cell "$w" "$(( BC_WY[$w] + y ))" "$(( BC_WX[$w] + x ))" "$BC_RCH" "$BC_RA" "$BC_RP"
  done
}

# set one absolute cell to the window background rendition
_bc_clear_cell() { # w ay ax
  local w=$1 ay=$2 ax=$3
  (( ay < 0 || ax < 0 || ay >= ${BC_WH[$w]} || ax >= ${BC_WW[$w]} )) && return 0
  _bc_bg "$w"
  _bc_cell "$w" "$ay" "$ax" "$BC_RCH" "$BC_RA" "$BC_RP"
}

# fill a window with its background rendition, marking every cell dirty
_bc_erase_region() { # w
  local w=$1
  local y0=${BC_WY[$w]} x0=${BC_WX[$w]} h=${BC_WH[$w]} ww=${BC_WW[$w]}
  local buf=${BC_WBUF[$w]} ay ax k mk wd=""
  _bc_bg "$w"
  local ch=$BC_RCH a=$BC_RA p=$BC_RP
  # same effect as _bc_cell per cell, inlined (this is a hot path)
  for (( ay = y0; ay < y0 + h; ay++ )); do
    _bc_flush_row "$w" "$ay"
    for (( ax = x0; ax < x0 + ww; ax++ )); do
      k="$buf/$ay $ax"
      BC_C[$k]=$ch; BC_A[$k]=$a; BC_P[$k]=$p
      mk="$w/$ay $ax"
      if [[ -z ${BC_MK[$mk]:-} ]]; then BC_MK[$mk]=1; wd+=",$ay $ax"; fi
    done
  done
  BC_WD[$w]+=$wd
  BC_WAX[$w]=0
  BC_WAY[$w]=0
}

# Every mark "w/key" is set together with an entry in BC_WD[w], so the
# window's own dirty list names exactly its marks (no scan of all marks).
_bc_clear_marks() { # w
  local w=$1 k IFS=','
  for k in ${BC_WD[$w]:-}; do
    [[ -n $k ]] && unset "BC_MK[$w/$k]"
  done
}

# ------------------------------------------------------------ init / end
initscr() {
  if (( ! BC_STARTED )); then
    _bc_term
    BC_STARTED=1
    if (( BC_SLK_PENDING )); then
      _bc_slk_apply
    fi
    if (( BC_MOUSE_MASK && ! BC_MOUSE_ENABLED )); then
      _bc_mouse_enable 1
    fi
  fi
  if [[ -z ${BC_WY[0]:-} ]]; then
    _bc_init_window 0 0 0 "$BC_LINES" "$BC_COLS"
    BC_WKEYPAD[0]=1
    # ncurses paints the whole screen with the window background on the first
    # refresh, so blank cells carry the background rendition (pair 0 once
    # start_color has run). The paint is done on the first stdscr refresh (see
    # wrefresh) so it can skip window-covered cells that were never written.
    BC_INITPAINT=1
  fi
  BC_CURR=0
  return 0
}

endwin() {
  if (( ! BC_STARTED )); then
    return 0
  fi
  if (( BC_MOUSE_ENABLED )); then
    _bc_mouse_enable 0
  fi
  [[ -n $BC_RMKX ]] && printf '%s' "$BC_RMKX"
  printf '\e[?25h\e[0m\e[?1049l'
  if [[ -n $BC_OLDSTTY ]]; then
    stty "$BC_OLDSTTY" 2>/dev/null
  fi
  BC_STARTED=0
  return 0
}

isendwin() { (( ! BC_STARTED )); }

use_window() { # win -> bc_win previous
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  bc_win=$BC_CURR
  BC_CURR=$w
  curscr=$BC_STDSCR
  newscr=$BC_CURR
  return 0
}

has_ic() { return 0; }
has_il() { return 0; }

erasechar() { printf '%s' "$BC_ERASECHAR"; }
killchar() { printf '%s' "$BC_KILLCHAR"; }
erasewchar() { BC_ERASEWCHAR=$BC_ERASECHAR; return 0; }
killwchar() { BC_KILLWCHAR=$BC_KILLCHAR; return 0; }

meta() { # win bf
  local bf=${2:-0}
  if [[ $bf == 0 || $bf == false ]]; then
    BC_META=0
  else
    BC_META=1
  fi
  return 0
}

intrflush() { return 0; }
qiflush() { return 0; }
noqiflush() { return 0; }

filter() { BC_FILTER=1; return 0; }
nofilter() { BC_FILTER=0; return 0; }

# save the current terminal mode (ncurses def_prog_mode)
def_prog_mode() {
  BC_PROG_STTY=$(stty -g 2>/dev/null) || BC_PROG_STTY=""
  return 0
}

# restore the mode saved by def_prog_mode and re-enter curses, forcing a
# full redraw on the next refresh (ncurses reset_prog_mode)
reset_prog_mode() {
  if [[ -n ${BC_PROG_STTY:-} ]]; then
    stty "$BC_PROG_STTY" 2>/dev/null
  fi
  if (( ! BC_STARTED )); then
    printf '\e[?1049h\e[2J\e[?25l'
    BC_STARTED=1
  fi
  BC_S=(); BC_SA=(); BC_SP=()
  _bc_mark_all "$BC_STDSCR"
  return 0
}

# mark every cell of a window dirty so the next refresh redraws it all
_bc_mark_all() { # w
  local w=$1 y x k mk wd=""
  for (( y = 0; y < ${BC_WH[$w]}; y++ )); do
    for (( x = 0; x < ${BC_WW[$w]}; x++ )); do
      k="$(( BC_WY[$w] + y )) $(( BC_WX[$w] + x ))"
      mk="$w/$k"
      if [[ -z ${BC_MK[$mk]:-} ]]; then
        BC_MK[$mk]=1
        wd+=",$k"
      fi
    done
  done
  BC_WD[$w]+="$wd"
  return 0
}

_bc_mark_cell() { # w ay ax
  local mk="$1/$2 $3"
  if [[ -z ${BC_MK[$mk]:-} ]]; then
    BC_MK[$mk]=1
    BC_WD[$1]+=",$2 $3"
  fi
}

_bc_mark_region() { # w ay ax h ww
  local w=$1 y=$2 x=$3 h=$4 ww=$5
  local ay ax
  for (( ay = y; ay < y + h; ay++ )); do
    for (( ax = x; ax < x + ww; ax++ )); do
      _bc_mark_cell "$w" "$ay" "$ax"
    done
  done
}

_bc_unmark_region() { # w ay ax h ww
  local w=$1 y=$2 x=$3 h=$4 ww=$5
  local ay ax mk k ky kx
  for (( ay = y; ay < y + h; ay++ )); do
    for (( ax = x; ax < x + ww; ax++ )); do
      mk="$w/$ay $ax"
      unset "BC_MK[$mk]"
    done
  done
  local -a keep=()
  local IFS=','
  for k in ${BC_WD[$w]}; do
    [[ -z $k ]] && continue
    ky=${k%% *}
    kx=${k##* }
    if (( ky >= y && ky < y + h && kx >= x && kx < x + ww )); then
      continue
    fi
    keep+=("$k")
  done
  BC_WD[$w]=""
  if (( ${#keep[@]} )); then
    local IFS=','
    BC_WD[$w]="${keep[*]}"
  fi
}

_bc_expand_scroll_dirty() { # w top bottom
  local w=$1 top=$2 bottom=$3
  local y0=$(( BC_WY[$w] + top )) x0=${BC_WX[$w]}
  local h=$(( bottom - top + 1 )) ww=${BC_WW[$w]}
  _bc_mark_region "$w" "$y0" "$x0" "$h" "$ww"
}

_bc_scroll_window_cells() { # w top bottom n
  local w=$1 top=$2 bottom=$3 n=$4
  local buf=${BC_WBUF[$w]}
  local x0=${BC_WX[$w]} ww=${BC_WW[$w]}
  local h=$(( bottom - top + 1 ))
  local y src ax srck dstk
  _bc_render "$w" ' ' 0 0
  local bch=$BC_RCH ba=$BC_RA bp=$BC_RP

  if (( n > 0 )); then
    if (( n >= h )); then
      for (( y = top; y <= bottom; y++ )); do
        for (( ax = x0; ax < x0 + ww; ax++ )); do
          _bc_cell "$w" "$y" "$ax" "$bch" "$ba" "$bp"
        done
      done
      return 0
    fi
    for (( y = top; y <= bottom - n; y++ )); do
      src=$(( y + n ))
      for (( ax = x0; ax < x0 + ww; ax++ )); do
        srck="$buf/$src $ax"
        dstk="$buf/$y $ax"
        if [[ -n ${BC_C[$srck]+set} ]]; then
          BC_C[$dstk]=${BC_C[$srck]}
          BC_A[$dstk]=${BC_A[$srck]:-0}
          BC_P[$dstk]=${BC_P[$srck]:-0}
        else
          unset "BC_C[$dstk]" "BC_A[$dstk]" "BC_P[$dstk]"
        fi
      done
    done
    for (( y = bottom - n + 1; y <= bottom; y++ )); do
      for (( ax = x0; ax < x0 + ww; ax++ )); do
        _bc_cell "$w" "$y" "$ax" "$bch" "$ba" "$bp"
      done
    done
  elif (( n < 0 )); then
    n=$(( -n ))
    if (( n >= h )); then
      for (( y = top; y <= bottom; y++ )); do
        for (( ax = x0; ax < x0 + ww; ax++ )); do
          _bc_cell "$w" "$y" "$ax" "$bch" "$ba" "$bp"
        done
      done
      return 0
    fi
    for (( y = bottom; y >= top + n; y-- )); do
      src=$(( y - n ))
      for (( ax = x0; ax < x0 + ww; ax++ )); do
        srck="$buf/$src $ax"
        dstk="$buf/$y $ax"
        if [[ -n ${BC_C[$srck]+set} ]]; then
          BC_C[$dstk]=${BC_C[$srck]}
          BC_A[$dstk]=${BC_A[$srck]:-0}
          BC_P[$dstk]=${BC_P[$srck]:-0}
        else
          unset "BC_C[$dstk]" "BC_A[$dstk]" "BC_P[$dstk]"
        fi
      done
    done
    for (( y = top; y < top + n; y++ )); do
      for (( ax = x0; ax < x0 + ww; ax++ )); do
        _bc_cell "$w" "$y" "$ax" "$bch" "$ba" "$bp"
      done
    done
  fi
  return 0
}

_bc_shift_screen_model() { # top bottom n
  local top=$1 bottom=$2 n=$3
  local h=$(( bottom - top + 1 ))
  local y src x k sk
  # shift the whole-row screen cache in lockstep with the per-cell model
  local ay2 src2
  if (( n > 0 )); then
    if (( n >= h )); then
      for (( ay2 = top; ay2 <= bottom; ay2++ )); do unset "BC_SCROW[$ay2]" "BC_SPROW[$ay2]"; done
    else
      for (( ay2 = top; ay2 <= bottom - n; ay2++ )); do
        src2=$(( ay2 + n ))
        if [[ -n ${BC_SCROW[$src2]+set} ]]; then BC_SCROW[$ay2]=${BC_SCROW[$src2]}; BC_SPROW[$ay2]=${BC_SPROW[$src2]}; else unset "BC_SCROW[$ay2]" "BC_SPROW[$ay2]"; fi
      done
      for (( ay2 = bottom - n + 1; ay2 <= bottom; ay2++ )); do unset "BC_SCROW[$ay2]" "BC_SPROW[$ay2]"; done
    fi
  elif (( n < 0 )); then
    local nn=$(( -n ))
    if (( nn >= h )); then
      for (( ay2 = top; ay2 <= bottom; ay2++ )); do unset "BC_SCROW[$ay2]" "BC_SPROW[$ay2]"; done
    else
      for (( ay2 = bottom; ay2 >= top + nn; ay2-- )); do
        src2=$(( ay2 - nn ))
        if [[ -n ${BC_SCROW[$src2]+set} ]]; then BC_SCROW[$ay2]=${BC_SCROW[$src2]}; BC_SPROW[$ay2]=${BC_SPROW[$src2]}; else unset "BC_SCROW[$ay2]" "BC_SPROW[$ay2]"; fi
      done
      for (( ay2 = top; ay2 < top + nn; ay2++ )); do unset "BC_SCROW[$ay2]" "BC_SPROW[$ay2]"; done
    fi
  fi
  if (( n > 0 )); then
    if (( n >= h )); then
      for (( y = top; y <= bottom; y++ )); do
        for (( x = 0; x < BC_COLS; x++ )); do
          k="$y $x"
          unset "BC_S[$k]" "BC_SA[$k]" "BC_SP[$k]"
        done
      done
      return 0
    fi
    for (( y = top; y <= bottom - n; y++ )); do
      src=$(( y + n ))
      for (( x = 0; x < BC_COLS; x++ )); do
        k="$y $x"
        sk="$src $x"
        if [[ -n ${BC_S[$sk]+set} ]]; then
          BC_S[$k]=${BC_S[$sk]}
          BC_SA[$k]=${BC_SA[$sk]:-0}
          BC_SP[$k]=${BC_SP[$sk]:-0}
        else
          unset "BC_S[$k]" "BC_SA[$k]" "BC_SP[$k]"
        fi
      done
    done
    for (( y = bottom - n + 1; y <= bottom; y++ )); do
      for (( x = 0; x < BC_COLS; x++ )); do
        k="$y $x"
        unset "BC_S[$k]" "BC_SA[$k]" "BC_SP[$k]"
      done
    done
  elif (( n < 0 )); then
    n=$(( -n ))
    if (( n >= h )); then
      for (( y = top; y <= bottom; y++ )); do
        for (( x = 0; x < BC_COLS; x++ )); do
          k="$y $x"
          unset "BC_S[$k]" "BC_SA[$k]" "BC_SP[$k]"
        done
      done
      return 0
    fi
    for (( y = bottom; y >= top + n; y-- )); do
      src=$(( y - n ))
      for (( x = 0; x < BC_COLS; x++ )); do
        k="$y $x"
        sk="$src $x"
        if [[ -n ${BC_S[$sk]+set} ]]; then
          BC_S[$k]=${BC_S[$sk]}
          BC_SA[$k]=${BC_SA[$sk]:-0}
          BC_SP[$k]=${BC_SP[$sk]:-0}
        else
          unset "BC_S[$k]" "BC_SA[$k]" "BC_SP[$k]"
        fi
      done
    done
    for (( y = top; y < top + n; y++ )); do
      for (( x = 0; x < BC_COLS; x++ )); do
        k="$y $x"
        unset "BC_S[$k]" "BC_SA[$k]" "BC_SP[$k]"
      done
    done
  fi
  return 0
}

_bc_scroll_safe() { # w top bottom n
  local w=$1 top=$2 bottom=$3 n=$4
  (( BC_NO_SCROLLREG == 0 )) || return 1
  (( BC_FORCEFULL == 0 )) || return 1
  [[ -z ${BC_DELRECTS:-} ]] || return 1
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  local h=$(( bottom - top + 1 ))
  local an=$n
  (( an < 0 )) && an=$(( -an ))
  (( an > 0 && an < h )) || return 1
  (( BC_WX[$w] == 0 && BC_WW[$w] == BC_COLS )) || return 1
  (( BC_WY[$w] == 0 && BC_WH[$w] == BC_LINES )) || return 1
  local p top_p=""
  if (( w == BC_STDSCR )); then
    for p in "${BC_PSTACK[@]}"; do
      [[ ${BC_PHID[$p]:-0} != 1 ]] && return 1
    done
  else
    for p in "${BC_PSTACK[@]}"; do
      [[ ${BC_PHID[$p]:-0} != 1 ]] && top_p=$p
    done
    [[ -n $top_p && ${BC_PWIN[$top_p]} == "$w" ]] || return 1
  fi
  return 0
}

_bc_combine_scroll_req() { # w top bottom n
  local w=$1 top=$2 bottom=$3 n=$4
  if [[ -n ${BC_SCROLLREQ:-} ]]; then
    local ow otop obot on
    read -r ow otop obot on <<< "$BC_SCROLLREQ"
    if [[ $ow == "$w" && $otop == "$top" && $obot == "$bottom" ]]; then
      local sum=$(( on + n ))
      _bc_expand_scroll_dirty "$w" "$top" "$bottom"
      if (( sum == 0 )); then
        BC_SCROLLREQ=""
      else
        BC_SCROLLREQ="$w $top $bottom $sum"
      fi
      return 0
    fi
    _bc_expand_scroll_dirty "$ow" "$otop" "$obot"
    BC_FORCEFULL=1
  fi
  BC_SCROLLREQ="$w $top $bottom $n"
}

# --------------------------------------------------------------------- mouse
# Terminal mouse reporting.
#
# Primary wire format is SGR 1006 ("\E[<b;x;y M|m") - what xterm-256color
# emits (its kmous is "\E[<"). The legacy X10 format ("\E[M Cb Cx Cy") is
# decoded as a fallback. bstate values follow ncurses NCURSES_MOUSE_VERSION 2
# (5-bit slot per button; wheel up = button 4, wheel down = button 5).
#
# wgetch() reads a whole *run* of consecutive mouse reports (delimited by a
# quiet period of BC_MAXCLICK ms, the ncurses DEFAULT_MAXCLICK default of
# 166 ms), then merges the run like ncurses _nc_mouse_parse: a same-position
# press/release pair becomes a CLICK (when the mask requests clicks), and a
# click run becomes a DOUBLE, then a TRIPLE (per button; the click run is
# not position-compared, matching ncurses). Events are filtered against the
# mask, queued in BC_MEVENTS and wgetch returns KEY_MOUSE with the head
# event copied into BC_ME_ID/BC_ME_X/BC_ME_Y/BC_ME_BSTATE (a peek - the
# queue is consumed only by getmouse()).

_bc_mouse_mask2() { # $1 mask -> BC_MOUSE_MASK2 (click implies press|release, ...)
  local m=$(( $1 & _BC_MOUSE_VALID_BITS )) n off
  for n in 1 2 3 4 5; do
    off=$(( 5 * (n - 1) ))
    (( m & (16 << off) )) && m=$(( m | 8 << off ))
    (( m & (8 << off) )) && m=$(( m | 4 << off ))
    (( m & (4 << off) )) && m=$(( m | 3 << off ))
  done
  BC_MOUSE_MASK2=$m
}

_bc_mouse_enable() { # $1 1|0
  if (( $1 )); then
    printf '\e[?1006;1000h'
    BC_MOUSE_ENABLED=1
    BC_MOUSE_TYPE=1
  else
    printf '\e[?1006;1000l'
    BC_MOUSE_ENABLED=0
  fi
}

mousemask() { # $1 newmask [ $2 var_to_receive_oldmask ]
  local newmask=${1:-0}
  [[ $newmask =~ ^[0-9]+$ ]] || newmask=0
  newmask=$(( newmask & _BC_MOUSE_VALID_BITS ))
  if (( $# >= 2 )); then
    printf -v "$2" '%d' "$BC_MOUSE_MASK"
  fi
  if (( BC_MOUSE_MASK != 0 )); then
    BC_MOUSE_TYPE=1
  fi
  if (( BC_STARTED )); then
    if (( BC_MOUSE_MASK == 0 && newmask != 0 )); then
      _bc_mouse_enable 1
    elif (( BC_MOUSE_MASK != 0 && newmask == 0 )); then
      _bc_mouse_enable 0
    fi
  fi
  BC_MOUSE_MASK=$newmask
  _bc_mouse_mask2 "$newmask"
  return 0
}

mouse_set() { # $1 mask (default ALL_MOUSE_EVENTS)
  mousemask "${1:-$ALL_MOUSE_EVENTS}"
}

mouseinterval() { # $1 maxclick ms; old value in BC_OLD_MAXCLICK
  local old=$BC_MAXCLICK
  [[ ${1:-} =~ ^[0-9]+$ ]] && BC_MAXCLICK=$1
  BC_OLD_MAXCLICK=$old
  return 0
}

getmouse() { # -> BC_ME_ID BC_ME_X BC_ME_Y BC_ME_BSTATE; 0 ok, 1 queue empty
  if (( ${#BC_MEVENTS[@]} == 0 )); then
    return 1
  fi
  local ev=${BC_MEVENTS[0]}
  BC_MEVENTS=("${BC_MEVENTS[@]:1}")
  read -r BC_ME_ID BC_ME_X BC_ME_Y BC_ME_BSTATE <<< "$ev"
  return 0
}

ungetmouse() { # push back the event currently in BC_ME_*
  BC_MEVENTS=("0 $BC_ME_X $BC_ME_Y $BC_ME_BSTATE" "${BC_MEVENTS[@]}")
  BC_PENDING_KEY=$KEY_MOUSE
  return 0
}

has_mouse() {
  if (( BC_MOUSE_TYPE )); then
    return 0
  fi
  [[ $TERM == *xterm* ]]
  return $?
}

wenclose() { # win y x -> 0 if screen coords are inside win, 1 otherwise
  local w=${1:-$BC_CURR} y=${2:-0} x=${3:-0} yoff
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  [[ $y =~ ^-?[0-9]+$ && $x =~ ^-?[0-9]+$ ]] || return 1
  yoff=${BC_WYOFF[$w]:-0}
  y=$(( y - yoff ))
  (( y >= BC_WY[$w] && y <= BC_WY[$w] + BC_WH[$w] - 1
     && x >= BC_WX[$w] && x <= BC_WX[$w] + BC_WW[$w] - 1 ))
}

wmouse_trafo() { # win y x toscreen -> BC_MT_Y BC_MT_X; 0 ok, 1 outside
  local w=${1:-$BC_CURR} y=${2:-0} x=${3:-0} toscreen=${4:-1}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  [[ $y =~ ^-?[0-9]+$ && $x =~ ^-?[0-9]+$ ]] || return 1
  local yoff=${BC_WYOFF[$w]:-0}
  if [[ $toscreen == 0 || $toscreen == false ]]; then
    if wenclose "$w" "$y" "$x"; then
      BC_MT_Y=$(( y - BC_WY[$w] - yoff ))
      BC_MT_X=$(( x - BC_WX[$w] ))
      return 0
    fi
  else
    local sy=$(( y + BC_WY[$w] + yoff )) sx=$(( x + BC_WX[$w] ))
    if wenclose "$w" "$sy" "$sx"; then
      BC_MT_Y=$sy BC_MT_X=$sx
      return 0
    fi
  fi
  return 1
}

mouse_trafo() { # y x toscreen -> BC_MT_Y BC_MT_X; 0 ok, 1 outside
  wmouse_trafo "$BC_STDSCR" "$@"
}

# Read the SGR 1006 payload that follows "\E[<": "b;x;y" then a final 'M'|'m'.
# Sets _BC_SGR_B/_BC_SGR_X/_BC_SGR_Y/_BC_SGR_FINAL. 0 on success, 1 incomplete.
_bc_mouse_read_sgr() {
  local c payload="" final="" t b x y
  printf -v t '%d.%03d' $(( ESCDELAY / 1000 )) $(( ESCDELAY % 1000 ))
  while IFS= read -rsn1 -t "$t" c; do
    case $c in
      M|m) final=$c; break ;;
      [0-9] | ';') payload+=$c ;;
    esac
  done
  [[ -z $final ]] && return 1
  IFS=';' read -r b x y _ <<< "$payload"
  [[ $b =~ ^[0-9]+$ && $x =~ ^[0-9]+$ && $y =~ ^[0-9]+$ ]] || return 1
  _BC_SGR_B=$b _BC_SGR_X=$x _BC_SGR_Y=$y _BC_SGR_FINAL=$final
  return 0
}

# Read the X10 payload that follows "\E[M": three raw bytes Cb Cx Cy.
# Cx/Cy are always >= 0x21; Cb may be a NUL byte (Cb=0, left press). bash
# read() strips NUL bytes silently, but "read -d ''" reports a NUL as a
# successful read of an empty string, so Cb is read that way: rc=0 with
# an empty variable means Cb was NUL.
# Sets _BC_X10_CB/_BC_X10_CX/_BC_X10_CY as numbers.
# 0 on success, 1 incomplete.
_bc_mouse_read_x10() {
  local c v t
  printf -v t '%d.%03d' $(( ESCDELAY / 1000 )) $(( ESCDELAY % 1000 ))
  c=""
  IFS= read -rsn1 -d '' -t "$t" c || return 1
  if [[ -z $c ]]; then
    _BC_X10_CB=0
  else
    _BC_X10_CB=$(printf '%d' "'$c")
  fi
  v=""
  IFS= read -rsn2 -t "$t" v
  if (( ${#v} < 2 )); then
    return 1
  fi
  _BC_X10_CX=$(printf '%d' "'${v:0:1}")
  _BC_X10_CY=$(printf '%d' "'${v:1:1}")
  return 0
}

# ncurses handle_wheel(): $1 button, $2 wheel(1|0) -> _BC_HW_BSTATE _BC_HW_RESULT
_bc_mouse_handle_wheel() {
  local b=$1 wheel=$2
  local btn=$(( b & 3 )) bstate=0 result=1
  case $btn in
    0)
      if (( wheel )); then
        bstate=$BUTTON4_PRESSED
      elif (( BC_MOUSE_PRESSED & BUTTON1_PRESSED )); then
        bstate=$REPORT_MOUSE_POSITION
      else
        bstate=$BUTTON1_PRESSED
      fi
      (( ! wheel )) && BC_MOUSE_PRESSED=$(( BC_MOUSE_PRESSED | BUTTON1_PRESSED ))
      ;;
    1)
      if (( wheel )); then
        bstate=$BUTTON5_PRESSED
      elif (( BC_MOUSE_PRESSED & BUTTON2_PRESSED )); then
        bstate=$REPORT_MOUSE_POSITION
      else
        bstate=$BUTTON2_PRESSED
      fi
      (( ! wheel )) && BC_MOUSE_PRESSED=$(( BC_MOUSE_PRESSED | BUTTON2_PRESSED ))
      ;;
    2)
      if (( BC_MOUSE_PRESSED & BUTTON3_PRESSED )); then
        bstate=$REPORT_MOUSE_POSITION
      else
        bstate=$BUTTON3_PRESSED
      fi
      BC_MOUSE_PRESSED=$(( BC_MOUSE_PRESSED | BUTTON3_PRESSED ))
      ;;
    *)
      bstate=$REPORT_MOUSE_POSITION
      result=0
      ;;
  esac
  _BC_HW_BSTATE=$bstate _BC_HW_RESULT=$result
  return 0
}

# Decode the SGR event in _BC_SGR_* -> _BC_EVT_BSTATE/_BC_EVT_X/_BC_EVT_Y
_bc_mouse_decode_sgr() {
  local b=$_BC_SGR_B x=$_BC_SGR_X y=$_BC_SGR_Y final=$_BC_SGR_FINAL
  local wheel=0 bstate
  (( (b & 64) == 64 )) && wheel=1
  _BC_EVT_X=$(( x > 0 ? x - 1 : 0 ))
  _BC_EVT_Y=$(( y > 0 ? y - 1 : 0 ))
  if [[ $final == M ]]; then
    _bc_mouse_handle_wheel "$b" "$wheel"
    bstate=$_BC_HW_BSTATE
  else
    local b3=$(( 1 + (b & 3) )) off pressed release
    if (( b >= 132 )); then b3=6
    elif (( b >= 128 )); then b3=$(( b - 120 ))
    elif (( b >= 64 )); then b3=$(( b - 60 ))
    fi
    if (( b3 > 5 )); then
      bstate=$REPORT_MOUSE_POSITION
    else
      off=$(( 5 * (b3 - 1) ))
      pressed=$(( 2 << off )) release=$(( 1 << off ))
      if (( BC_MOUSE_PRESSED & pressed )); then
        bstate=$release
        BC_MOUSE_PRESSED=$(( BC_MOUSE_PRESSED & ~pressed ))
      else
        bstate=$REPORT_MOUSE_POSITION
      fi
    fi
  fi
  (( b & 4 )) && bstate=$(( bstate | BUTTON_SHIFT ))
  (( b & 8 )) && bstate=$(( bstate | BUTTON_ALT ))
  (( b & 16 )) && bstate=$(( bstate | BUTTON_CTRL ))
  _BC_EVT_BSTATE=$bstate
  return 0
}

# Decode the X10 event in _BC_X10_* -> _BC_EVT_BSTATE/_BC_EVT_X/_BC_EVT_Y
_bc_mouse_decode_x10() {
  local cb=$_BC_X10_CB cx=$_BC_X10_CX cy=$_BC_X10_CY
  local wheel=0 btn bstate
  (( (cb & 96) == 96 )) && wheel=1
  if (( cb >= 160 )); then btn=$(( cb - 152 ))
  elif (( cb >= 96 )); then btn=$(( cb - 92 ))
  else btn=$(( cb & 3 )); fi
  _BC_EVT_X=$(( cx - 33 )); (( _BC_EVT_X < 0 )) && _BC_EVT_X=0
  _BC_EVT_Y=$(( cy - 33 )); (( _BC_EVT_Y < 0 )) && _BC_EVT_Y=0
  if (( btn > 5 )); then
    bstate=$REPORT_MOUSE_POSITION
  else
    _bc_mouse_handle_wheel "$cb" "$wheel"
    bstate=$_BC_HW_BSTATE
    if (( !_BC_HW_RESULT )); then
      if (( BC_MOUSE_PRESSED & BUTTON_PRESSED )); then
        bstate=0
        local n off
        for n in 1 2 3 4 5; do
          off=$(( 5 * (n - 1) ))
          (( BC_MOUSE_PRESSED & (2 << off) )) && bstate=$(( bstate | (1 << off) ))
        done
        BC_MOUSE_PRESSED=0
      else
        bstate=$REPORT_MOUSE_POSITION
      fi
    fi
  fi
  (( cb & 4 )) && bstate=$(( bstate | BUTTON_SHIFT ))
  (( cb & 8 )) && bstate=$(( bstate | BUTTON_ALT ))
  (( cb & 16 )) && bstate=$(( bstate | BUTTON_CTRL ))
  _BC_EVT_BSTATE=$bstate
  return 0
}

# Queue the event in _BC_EVT_*, merging like ncurses _nc_mouse_parse:
# a same-position press/release pair becomes a CLICK, then a same-position
# click run becomes a DOUBLE, then a TRIPLE (per button, per mask2 request).
_bc_mouse_push_event() {
  local bstate=$_BC_EVT_BSTATE x=$_BC_EVT_X y=$_BC_EVT_Y
  local n off i _ps _rs lid lx ly lbstate
  i=$(( ${#BC_MEVENTS[@]} - 1 ))
  if (( i >= 0 )); then
    read -r lid lx ly lbstate <<< "${BC_MEVENTS[$i]}"
    # press/release pair -> CLICK
    if (( lx == x && ly == y )) && (( lbstate & BUTTON_PRESSED )) \
       && ! (( bstate & BUTTON_PRESSED )); then
      _ps=0; _rs=0
      for n in 1 2 3 4 5; do
        off=$(( 5 * (n - 1) ))
        (( lbstate & (2 << off) )) && _ps=$(( _ps | (1 << (n - 1)) ))
        (( bstate & (1 << off) )) && _rs=$(( _rs | (1 << (n - 1)) ))
      done
      if (( _ps == _rs )); then
        for n in 1 2 3 4 5; do
          off=$(( 5 * (n - 1) ))
          if (( _rs & (1 << (n - 1)) )) && (( BC_MOUSE_MASK2 & (4 << off) )); then
            bstate=$(( bstate & ~(1 << off) | (4 << off) ))
          fi
        done
        BC_MEVENTS=("${BC_MEVENTS[@]:0:i}")
        i=$(( ${#BC_MEVENTS[@]} - 1 ))
      fi
    fi
    # click run -> DOUBLE / TRIPLE (ncurses does not compare x/y here)
    if (( bstate & BUTTON_CLICKED )) && (( i >= 0 )); then
      read -r lid lx ly lbstate <<< "${BC_MEVENTS[$i]}"
      for n in 1 2 3 4 5; do
        off=$(( 5 * (n - 1) ))
        if (( bstate & (4 << off) )); then
          if (( lbstate & (4 << off) )) && (( BC_MOUSE_MASK2 & (8 << off) )); then
            bstate=$(( bstate & ~(4 << off) | (8 << off) ))
            BC_MEVENTS=("${BC_MEVENTS[@]:0:i}")
            break
          fi
          if (( lbstate & (8 << off) )) && (( BC_MOUSE_MASK2 & (16 << off) )); then
            bstate=$(( bstate & ~(4 << off) | (16 << off) ))
            BC_MEVENTS=("${BC_MEVENTS[@]:0:i}")
            break
          fi
        fi
      done
    fi
  fi
  BC_MEVENTS+=("0 $x $y $bstate")
  return 0
}

# Drop queued events whose bstate is not requested by the mask.
_bc_mouse_filter() {
  local i ev bstate keep=()
  for i in "${!BC_MEVENTS[@]}"; do
    ev=${BC_MEVENTS[$i]}
    bstate=${ev##* }
    (( bstate & BC_MOUSE_MASK2 )) && keep+=("$ev")
  done
  BC_MEVENTS=()
  (( ${#keep[@]} )) && BC_MEVENTS=("${keep[@]}")
  return 0
}

# Start a mouse run from the first decoded event (_BC_EVT_*): queue it, then
# read further mouse reports arriving within BC_MAXCLICK ms, queueing each.
# A non-mouse byte ends the run and is pushed back via BC_PENDING_IN.
_bc_mouse_run() {
  _bc_mouse_push_event
  local t c s s2
  printf -v t '%d.%03d' $(( BC_MAXCLICK / 1000 )) $(( BC_MAXCLICK % 1000 ))
  while :; do
    c=""
    IFS= read -rsn1 -t "$t" c || break
    if [[ $c != $'\x1b' ]]; then
      BC_PENDING_IN+=$c
      break
    fi
    s=""
    IFS= read -rsn1 -t "$t" s || { BC_PENDING_IN+=$c; break; }
    case $s in
      '[')
        if ! IFS= read -rsn1 -t "$t" s2; then
          BC_PENDING_IN+="$c$s"
          break
        fi
        if [[ $s2 == '<' ]] && _bc_mouse_read_sgr; then
          _bc_mouse_decode_sgr
          _bc_mouse_push_event
          continue
        fi
        if [[ $s2 == 'M' ]] && _bc_mouse_read_x10; then
          _bc_mouse_decode_x10
          _bc_mouse_push_event
          continue
        fi
        BC_PENDING_IN+="$c$s$s2"
        break
        ;;
      *)
        BC_PENDING_IN+="$c$s"
        break
        ;;
    esac
  done
  _bc_mouse_filter
  return 0
}

# mode switches (mostly no-ops under stty raw, kept for API parity)
# as in ncurses, cbreak keeps signal keys working (initscr's stty raw drops them)
cbreak() { stty -icanon isig 2>/dev/null; return 0; }
noecho() { stty -echo 2>/dev/null; return 0; }
raw() { stty raw -echo 2>/dev/null; return 0; }
noraw() { if [[ -n $BC_OLDSTTY ]]; then stty "$BC_OLDSTTY" 2>/dev/null; fi; return 0; }
keypad() { # win bf
  local w=${1:-$BC_CURR}
  if (( ${2:-1} )); then
    BC_WKEYPAD[$w]=1
  else
    BC_WKEYPAD[$w]=0
  fi
  return 0
}

# --------------------------------------------------------------- colors
start_color() {
  if (( ! BC_STARTED )); then
    initscr
  fi
  (( BC_COLORS > 0 )) || return 1
  BC_COLOR_STARTED=1
  BC_PAIRS_A[0]=7
  BC_PAIRS_B[0]=0
  _bc_init_palette
  return 0
}

_bc_init_palette() {
  local c r g b idx
  # standard 16 colors (ncurses default palette, 0-1000 scale)
  local -a _bc_pal=(
    0 0 0     680 0 0     0 680 0     680 680 0
    0 0 680   680 0 680   0 680 680   680 680 680
    0 0 0     1000 0 0    0 1000 0    1000 1000 0
    0 0 1000  1000 0 1000 0 1000 1000 1000 1000 1000
  )
  for ((c = 0; c < 16 && c < BC_COLORS; c++)); do
    BC_COLOR_R[$c]=${_bc_pal[c*3]}
    BC_COLOR_G[$c]=${_bc_pal[c*3+1]}
    BC_COLOR_B[$c]=${_bc_pal[c*3+2]}
  done
  # 6x6x6 color cube (16-231)
  local -a _bc_cube=(0 95 135 175 215 255)
  for ((c = 16; c <= 231 && c < BC_COLORS; c++)); do
    idx=$((c - 16))
    r=$((idx / 36)); g=$(( (idx / 6) % 6 )); b=$((idx % 6))
    BC_COLOR_R[$c]=$(( _bc_cube[r] * 1000 / 255 ))
    BC_COLOR_G[$c]=$(( _bc_cube[g] * 1000 / 255 ))
    BC_COLOR_B[$c]=$(( _bc_cube[b] * 1000 / 255 ))
  done
  # grayscale ramp (232-255)
  for ((c = 232; c <= 255 && c < BC_COLORS; c++)); do
    r=$((8 + (c - 232) * 10))
    BC_COLOR_R[$c]=$(( r * 1000 / 255 ))
    BC_COLOR_G[$c]=$(( r * 1000 / 255 ))
    BC_COLOR_B[$c]=$(( r * 1000 / 255 ))
  done
}

has_colors() { (( BC_COLORS > 0 )); }

has_named_color() { has_colors "$@"; }

use_default_colors() {
  BC_DEFAULT_COLORS=1
  BC_DEFAULT_FG=-1
  BC_DEFAULT_BG=-1
  BC_PAIRS_A[0]=-1
  BC_PAIRS_B[0]=-1
  return 0
}

init_color() { # color r g b
  local c=$1
  if (( c < 0 || c >= BC_COLORS )); then
    return 1
  fi
  BC_COLOR_R[$c]=$2
  BC_COLOR_G[$c]=$3
  BC_COLOR_B[$c]=$4
  return 0
}

can_change_color() { (( BC_CAN_CHANGE_COLOR )); }

color_content() { # color -> BC_CR BC_CG BC_CB
  local c=$1
  if (( c < 0 || c >= BC_COLORS )); then
    return 1
  fi
  BC_CR=${BC_COLOR_R[$c]:-0}
  BC_CG=${BC_COLOR_G[$c]:-0}
  BC_CB=${BC_COLOR_B[$c]:-0}
  return 0
}

extended_color_content() { color_content "$@"; }

pair_content() { # pair -> BC_CPF BC_CPB
  local p=$1
  if (( p < 0 || p > BC_PAIRS )); then
    return 1
  fi
  BC_CPF=${BC_PAIRS_A[$p]:-0}
  BC_CPB=${BC_PAIRS_B[$p]:-0}
  return 0
}

extended_pair_content() { # pair -> BC_EPF BC_EPB
  local p=$1
  if (( p < 0 || p > BC_PAIRS )); then
    return 1
  fi
  BC_EPF=${BC_PAIRS_A[$p]:-0}
  BC_EPB=${BC_PAIRS_B[$p]:-0}
  return 0
}

init_extended_color() { init_color "$@"; }

init_extended_pair() { init_pair "$@"; }

assume_default_colors() { # fg bg
  BC_DEFAULT_COLORS=1
  BC_DEFAULT_FG=${1:--1}
  BC_DEFAULT_BG=${2:--1}
  BC_PAIRS_A[0]=$BC_DEFAULT_FG
  BC_PAIRS_B[0]=$BC_DEFAULT_BG
  return 0
}

color_set() { # pair [opts]
  local p=${1:-0}
  if (( p < 0 || p > BC_PAIRS )); then
    return 1
  fi
  BC_WCURP[$BC_CURR]=$p
  return 0
}

PAIR_NUMBER() { printf '%s' "$(( $1 & 0x1ff ))"; }

find_pair() { # fg bg -> bc_pair
  local fg=$1 bg=$2 p
  bc_pair=-1
  for p in "${!BC_PAIRS_A[@]}"; do
    [[ ${BC_PAIRS_FREE[$p]:-} == 1 ]] && continue
    if [[ ${BC_PAIRS_A[$p]} == "$fg" && ${BC_PAIRS_B[$p]} == "$bg" ]]; then
      bc_pair=$p
      printf '%s' "$p"
      return 0
    fi
  done
  return 1
}

alloc_pair() { # fg bg -> bc_pair
  local fg=$1 bg=$2 p
  bc_pair=-1
  for (( p = 1; p <= BC_PAIRS; p++ )); do
    if [[ -z ${BC_PAIRS_A[$p]+set} ]] || [[ ${BC_PAIRS_FREE[$p]:-} == 1 ]]; then
      BC_PAIRS_A[$p]=$fg
      BC_PAIRS_B[$p]=$bg
      BC_PAIRS_FREE[$p]=0
      bc_pair=$p
      printf '%s' "$p"
      return 0
    fi
  done
  return 1
}

free_pair() { # pair
  local p=$1
  [[ -n ${BC_PAIRS_A[$p]+set} ]] || return 1
  BC_PAIRS_FREE[$p]=1
  return 0
}

init_pair() {
  local n=$1
  if (( n < 1 || n > BC_PAIRS )); then
    return 1
  fi
  BC_PAIRS_A[$n]=$2
  BC_PAIRS_B[$n]=$3
  return 0
}

COLOR_PAIR() { printf '%s' "$1"; }

# -------------------------------------------------------------- windows
# Window creation stores the new handle in the global bc_win
# (bash cannot return a pointer; see DESIGN.md).
newwin() { # nlines ncols begin_y begin_x
  if (( $1 < 1 || $2 < 1 )); then
    return 1
  fi
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" "$3" "$4" "$1" "$2"
  bc_win=$id
  return 0
}

derwin() { # win nlines ncol begin_y begin_x (relative to parent)
  local w=$1 h=$2 wd=$3 y=$4 x=$5
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if (( y < 0 || x < 0 || h < 0 || wd < 0 )); then
    return 1
  fi
  if (( h == 0 )); then h=$(( BC_WH[$w] - y )); fi
  if (( wd == 0 )); then wd=$(( BC_WW[$w] - x )); fi
  if (( h < 1 || wd < 1 )); then
    return 1
  fi
  if (( y + h > BC_WH[$w] || x + wd > BC_WW[$w] )); then
    return 1
  fi
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" "$(( BC_WY[$w] + y ))" "$(( BC_WX[$w] + x ))" "$h" "$wd"
  BC_WBUF[$id]=$w
  BC_WPAR[$id]=$w
  BC_WPOY[$id]=$y
  BC_WPOX[$id]=$x
  bc_win=$id
  return 0
}

subwin() { # win nlines ncol begin_y begin_x (absolute screen coords)
  local w=$1
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  derwin "$w" "$2" "$3" "$(( $4 - BC_WY[$w] ))" "$(( $5 - BC_WX[$w] ))"
}

_bc_move_window_cells() { # w oldy oldx newy newx
  local w=$1 oldy=$2 oldx=$3 newy=$4 newx=$5
  local buf=${BC_WBUF[$w]} h=${BC_WH[$w]} ww=${BC_WW[$w]}
  local -A oldc=() olda=() oldp=()
  local y x k bg ba bp
  for (( y = 0; y < h; y++ )); do
    for (( x = 0; x < ww; x++ )); do
      k="$buf/$(( oldy + y )) $(( oldx + x ))"
      oldc["$y $x"]=${BC_C[$k]:- }
      olda["$y $x"]=${BC_A[$k]:-0}
      oldp["$y $x"]=${BC_P[$k]:-0}
    done
  done
  bg=${BC_WBG[$w]:- } ba=${BC_WBGA[$w]:-0} bp=${BC_WBGP[$w]:-0}
  for (( y = 0; y < h; y++ )); do
    for (( x = 0; x < ww; x++ )); do
      _bc_cell "$w" "$(( oldy + y ))" "$(( oldx + x ))" "$bg" "$ba" "$bp"
    done
  done
  for (( y = 0; y < h; y++ )); do
    for (( x = 0; x < ww; x++ )); do
      _bc_cell "$w" "$(( newy + y ))" "$(( newx + x ))" "${oldc["$y $x"]}" "${olda["$y $x"]}" "${oldp["$y $x"]}"
    done
  done
}

mvwin() { # win y x
  local w=$1
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  local oldy=${BC_WY[$w]} oldx=${BC_WX[$w]} newy=$2 newx=$3
  if (( oldy != newy || oldx != newx )) && [[ ${BC_WBUF[$w]} == "$w" ]]; then
    _bc_move_window_cells "$w" "$oldy" "$oldx" "$newy" "$newx"
  fi
  BC_WY[$w]=$newy
  BC_WX[$w]=$newx
  _bc_mark_all "$w"
  return 0
}

mvderwin() { # win y x (relative to parent)
  local w=$1
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  local p=${BC_WPAR[$w]:--1}
  if (( p >= 0 )); then
    BC_WY[$w]=$(( BC_WY[$p] + $2 ))
    BC_WX[$w]=$(( BC_WX[$p] + $3 ))
  else
    BC_WY[$w]=$2
    BC_WX[$w]=$3
  fi
  BC_WPOY[$w]=$2
  BC_WPOX[$w]=$3
  _bc_mark_all "$w"
  return 0
}

wsyncup() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  return 0
}

wsyncdown() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  return 0
}

syncup() { wsyncup "$BC_CURR"; }
syncdown() { wsyncdown "$BC_CURR"; }

dupwin() { # win -> bc_win
  local w=$1
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  _bc_flush_win "$w"
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" "${BC_WY[$w]}" "${BC_WX[$w]}" "${BC_WH[$w]}" "${BC_WW[$w]}"
  BC_WBG[$id]=${BC_WBG[$w]}
  BC_WBGA[$id]=${BC_WBGA[$w]}
  BC_WBGP[$id]=${BC_WBGP[$w]}
  BC_WAX[$id]=${BC_WAX[$w]}
  BC_WAY[$id]=${BC_WAY[$w]}
  BC_WCURA[$id]=${BC_WCURA[$w]}
  BC_WCURP[$id]=${BC_WCURP[$w]}
  BC_WDELAY[$id]=${BC_WDELAY[$w]}
  BC_WTIMEOUT[$id]=${BC_WTIMEOUT[$w]}
  BC_WKEYPAD[$id]=${BC_WKEYPAD[$w]}
  BC_WYOFF[$id]=${BC_WYOFF[$w]}
  BC_WCLEAR[$id]=${BC_WCLEAR[$w]}
  BC_WIDC[$id]=${BC_WIDC[$w]}
  BC_WIDL[$id]=${BC_WIDL[$w]}
  BC_WIMM[$id]=${BC_WIMM[$w]}
  BC_WLEAVE[$id]=${BC_WLEAVE[$w]}
  BC_WNOTIMEOUT[$id]=${BC_WNOTIMEOUT[$w]}
  BC_WSYNC[$id]=${BC_WSYNC[$w]}
  BC_SCROLL[$id]=${BC_SCROLL[$w]}
  BC_SR[$id]=${BC_SR[$w]}
  local buf=${BC_WBUF[$w]} y x k
  for (( y = 0; y < BC_WH[$w]; y++ )); do
    for (( x = 0; x < BC_WW[$w]; x++ )); do
      k="$buf/$(( BC_WY[$w] + y )) $(( BC_WX[$w] + x ))"
      if [[ -n ${BC_C[$k]+set} || -n ${BC_A[$k]+set} || -n ${BC_P[$k]+set} ]]; then
        _bc_cell "$id" "$(( BC_WY[$id] + y ))" "$(( BC_WX[$id] + x ))" \
          "${BC_C[$k]:- }" "${BC_A[$k]:-0}" "${BC_P[$k]:-0}"
      fi
    done
  done
  _bc_mark_all "$id"
  bc_win=$id
  return 0
}

putwin() { # win file
  local w=$1 f=$2
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  _bc_flush_win "$w"
  local buf=${BC_WBUF[$w]} y x k
  {
    printf 'BCWIN\t1\n'
    printf 'HDR\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
      "${BC_WY[$w]}" "${BC_WX[$w]}" "${BC_WH[$w]}" "${BC_WW[$w]}" \
      "${BC_WBG[$w]}" "${BC_WBGA[$w]}" "${BC_WBGP[$w]}" \
      "${BC_WAX[$w]}" "${BC_WAY[$w]}" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}" \
      "${BC_WDELAY[$w]}" "${BC_WTIMEOUT[$w]}" "${BC_WKEYPAD[$w]}" "${BC_WYOFF[$w]}" \
      "${BC_WPAD[$w]}" "${BC_WCLEAR[$w]}" "${BC_WIDC[$w]}" "${BC_WIDL[$w]}" \
      "${BC_WIMM[$w]}" "${BC_WLEAVE[$w]}" "${BC_WNOTIMEOUT[$w]}" "${BC_WSYNC[$w]}" \
      "${BC_SCROLL[$w]}" "${BC_SR[$w]}"
    for (( y = 0; y < BC_WH[$w]; y++ )); do
      for (( x = 0; x < BC_WW[$w]; x++ )); do
        k="$buf/$(( BC_WY[$w] + y )) $(( BC_WX[$w] + x ))"
        if [[ -n ${BC_C[$k]+set} || -n ${BC_A[$k]+set} || -n ${BC_P[$k]+set} ]]; then
          printf 'CELL\t%s\t%s\t%s\t%s\t%s\n' \
            "$(( BC_WY[$w] + y ))" "$(( BC_WX[$w] + x ))" \
            "${BC_C[$k]:- }" "${BC_A[$k]:-0}" "${BC_P[$k]:-0}"
        fi
      done
    done
  } > "$f"
  return 0
}

getwin() { # file -> bc_win
  local f=$1 line _ y x h wd bg bga bgp ax ay ca cp delay timeout keypad yoff pad
  local clear idc idl imm leave notimeout sync scroll sr ay ax ch a p
  if ! { exec 3< "$f"; } 2>/dev/null; then
    return 1
  fi
  IFS= read -r line <&3 || { exec 3<&-; return 1; }
  [[ $line == BCWIN* ]] || { exec 3<&-; return 1; }
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" 0 0 1 1
  while IFS= read -r line <&3; do
    case $line in
      HDR*)
        IFS=$'\t' read -r _ y x h wd bg bga bgp ax ay ca cp delay timeout keypad yoff pad \
          clear idc idl imm leave notimeout sync scroll sr <<< "$line"
        BC_WY[$id]=$y
        BC_WX[$id]=$x
        BC_WH[$id]=$h
        BC_WW[$id]=$wd
        BC_WBG[$id]=$bg
        BC_WBGA[$id]=$bga
        BC_WBGP[$id]=$bgp
        BC_WAX[$id]=$ax
        BC_WAY[$id]=$ay
        BC_WCURA[$id]=$ca
        BC_WCURP[$id]=$cp
        BC_WDELAY[$id]=$delay
        BC_WTIMEOUT[$id]=$timeout
        BC_WKEYPAD[$id]=$keypad
        BC_WYOFF[$id]=$yoff
        BC_WPAD[$id]=$pad
        BC_WCLEAR[$id]=$clear
        BC_WIDC[$id]=$idc
        BC_WIDL[$id]=$idl
        BC_WIMM[$id]=$imm
        BC_WLEAVE[$id]=$leave
        BC_WNOTIMEOUT[$id]=$notimeout
        BC_WSYNC[$id]=$sync
        BC_SCROLL[$id]=$scroll
        BC_SR[$id]=$sr
        ;;
      CELL*)
        IFS=$'\t' read -r _ ay ax ch a p <<< "$line"
        _bc_cell "$id" "$ay" "$ax" "$ch" "$a" "$p"
        ;;
    esac
  done
  exec 3<&-
  bc_win=$id
  return 0
}

newpad() { # nlines ncols
  if (( $1 < 1 || $2 < 1 )); then
    return 1
  fi
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" 0 0 "$1" "$2"
  BC_WPAD[$id]=1
  bc_win=$id
  return 0
}

subpad() { # win nlines ncols begin_y begin_x (absolute, within parent pad)
  local w=$1 h=$2 wd=$3 y=$4 x=$5
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if (( y < BC_WY[$w] || x < BC_WX[$w] )); then
    return 1
  fi
  if (( y + h > BC_WY[$w] + BC_WH[$w] || x + wd > BC_WX[$w] + BC_WW[$w] )); then
    return 1
  fi
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" "$y" "$x" "$h" "$wd"
  BC_WBUF[$id]=$w
  BC_WPAR[$id]=$w
  BC_WPAD[$id]=1
  bc_win=$id
  return 0
}

is_pad() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WPAD[$w]:-} && ${BC_WPAD[$w]} != 0 ]]
}

_bc_prefresh_copy() { # pad pminrow pmincol sminrow smincol smaxrow smaxcol
  local w=$1 pminrow=$2 pmincol=$3 sminrow=$4 smincol=$5 smaxrow=$6 smaxcol=$7
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  _bc_flush_win "$w"
  local buf=${BC_WBUF[$w]}
  local h=$(( smaxrow - sminrow + 1 ))
  local wd=$(( smaxcol - smincol + 1 ))
  if (( h < 0 || wd < 0 )); then
    return 1
  fi
  if (( pminrow < 0 )); then
    sminrow=$(( sminrow - pminrow ))
    h=$(( h + pminrow ))
    pminrow=0
  fi
  if (( pmincol < 0 )); then
    smincol=$(( smincol - pmincol ))
    wd=$(( wd + pmincol ))
    pmincol=0
  fi
  if (( pminrow + h > BC_WH[$w] )); then
    h=$(( BC_WH[$w] - pminrow ))
  fi
  if (( pmincol + wd > BC_WW[$w] )); then
    wd=$(( BC_WW[$w] - pmincol ))
  fi
  if (( sminrow < 0 )); then
    pminrow=$(( pminrow - sminrow ))
    h=$(( h + sminrow ))
    sminrow=0
  fi
  if (( smincol < 0 )); then
    pmincol=$(( pmincol - smincol ))
    wd=$(( wd + smincol ))
    smincol=0
  fi
  if (( sminrow + h > BC_LINES )); then
    h=$(( BC_LINES - sminrow ))
  fi
  if (( smincol + wd > BC_COLS )); then
    wd=$(( BC_COLS - smincol ))
  fi
  if (( h <= 0 || wd <= 0 )); then
    return 0
  fi
  local y x sy sx k
  for (( y = 0; y < h; y++ )); do
    sy=$(( sminrow + y ))
    for (( x = 0; x < wd; x++ )); do
      sx=$(( smincol + x ))
      k="$buf/$(( pminrow + y )) $(( pmincol + x ))"
      _bc_cell "$BC_STDSCR" "$sy" "$sx" "${BC_C[$k]:- }" "${BC_A[$k]:-0}" "${BC_P[$k]:-0}"
    done
  done
  BC_PADY[$w]=$pminrow
  BC_PADX[$w]=$pmincol
  BC_PADT[$w]=$sminrow
  BC_PADL[$w]=$smincol
  BC_PADB[$w]=$smaxrow
  BC_PADR[$w]=$smaxcol
  return 0
}

pnoutrefresh() { # pad pminrow pmincol sminrow smincol smaxrow smaxcol
  _bc_prefresh_copy "$@"
}

prefresh() { # pad pminrow pmincol sminrow smincol smaxrow smaxcol
  _bc_prefresh_copy "$@" || return 1
  wrefresh "$BC_STDSCR"
}

pechochar() { # pad ch
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WPAD[$w]:-} && ${BC_WPAD[$w]} != 0 ]] || return 1
  waddch "$w" "$2" || return 1
  prefresh "$w" "${BC_PADY[$w]:-0}" "${BC_PADX[$w]:-0}" "${BC_PADT[$w]:-0}" \
           "${BC_PADL[$w]:-0}" "${BC_PADB[$w]:-$(( BC_LINES - 1 ))}" \
           "${BC_PADR[$w]:-$(( BC_COLS - 1 ))}"
}

scrollok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_SCROLL[$w]=0
  else
    BC_SCROLL[$w]=1
  fi
  return 0
}

idlok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WIDL[$w]=0
  else
    BC_WIDL[$w]=1
  fi
  return 0
}

clearok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WCLEAR[$w]=0
  else
    BC_WCLEAR[$w]=1
  fi
  return 0
}

idcok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WIDC[$w]=0
  else
    BC_WIDC[$w]=1
  fi
  return 0
}

immedok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WIMM[$w]=0
  else
    BC_WIMM[$w]=1
  fi
  return 0
}

leaveok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WLEAVE[$w]=0
  else
    BC_WLEAVE[$w]=1
  fi
  return 0
}

syncok() { # win bool
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WSYNC[$w]=0
  else
    BC_WSYNC[$w]=1
  fi
  return 0
}

is_cleared() { [[ ${BC_WCLEAR[$1]:-0} == 1 ]] && return 0 || return 1; }
is_idcok() { [[ ${BC_WIDC[$1]:-0} == 1 ]] && return 0 || return 1; }
is_idlok() { [[ ${BC_WIDL[$1]:-0} == 1 ]] && return 0 || return 1; }
is_immedok() { [[ ${BC_WIMM[$1]:-0} == 1 ]] && return 0 || return 1; }
is_leaveok() { [[ ${BC_WLEAVE[$1]:-0} == 1 ]] && return 0 || return 1; }
is_syncok() { [[ ${BC_WSYNC[$1]:-0} == 1 ]] && return 0 || return 1; }
is_scrollok() { [[ ${BC_SCROLL[$1]:-0} == 1 ]] && return 0 || return 1; }
is_nodelay() { [[ ${BC_WDELAY[$1]:-0} == 1 ]] && return 0 || return 1; }
is_notimeout() { [[ ${BC_WNOTIMEOUT[$1]:-0} == 1 ]] && return 0 || return 1; }
is_subwin() { [[ ${BC_WPAR[$1]:--1} != -1 ]] && return 0 || return 1; }

wgetdelay() { # win -> bc_delay
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  bc_delay=${BC_WDELAY[$w]:-0}
  return 0
}

wgetparent() { # win -> bc_parent
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  bc_parent=${BC_WPAR[$w]:--1}
  return 0
}

wgetscrreg() { # win -> bc_top bc_bottom
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ -n ${BC_SR[$w]:-} ]]; then
    read -r bc_top bc_bottom <<< "${BC_SR[$w]}"
    return 0
  fi
  bc_top=0
  bc_bottom=$(( BC_WH[$w] - 1 ))
  return 1
}

getpary() { # win -> BC_GPY
  local w=${1:-$BC_CURR}
  local p=${BC_WPAR[$w]:--1}
  if (( p >= 0 )); then
    BC_GPY=${BC_WPOY[$w]:-0}
  else
    BC_GPY=-1
  fi
  return 0
}

getparx() { # win -> BC_GPX
  local w=${1:-$BC_CURR}
  local p=${BC_WPAR[$w]:--1}
  if (( p >= 0 )); then
    BC_GPX=${BC_WPOX[$w]:-0}
  else
    BC_GPX=-1
  fi
  return 0
}

wsetscrreg() { # win top bottom
  local w=${1:-$BC_CURR} top=$2 bottom=$3
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  (( top >= 0 && bottom < BC_WH[$w] && top <= bottom )) || return 1
  BC_SR[$w]="$top $bottom"
  return 0
}

setscrreg() { wsetscrreg "$BC_STDSCR" "$@"; }

wscrl() { # win n
  local w=${1:-$BC_CURR} n=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  (( ${BC_SCROLL[$w]:-0} )) || return 1
  (( n == 0 )) && return 0
  _bc_flush_win "$w"
  local top=0 bottom=$(( BC_WH[$w] - 1 ))
  if [[ -n ${BC_SR[$w]:-} ]]; then
    read -r top bottom <<< "${BC_SR[$w]}"
  fi
  _bc_scroll_window_cells "$w" "$(( BC_WY[$w] + top ))" "$(( BC_WY[$w] + bottom ))" "$n"
  _bc_combine_scroll_req "$w" "$top" "$bottom" "$n"
  return 0
}

scroll() { wscrl "${1:-$BC_CURR}" 1; }

scrl() { wscrl "$BC_CURR" "$1"; }

delwin() {
  local w=$1
  # remember the region so the next composite can reveal what is underneath it
  [[ -n ${BC_WY[$w]:-} ]] && BC_DELRECTS+="|${BC_WY[$w]} ${BC_WX[$w]} ${BC_WH[$w]} ${BC_WW[$w]}"
  _bc_clear_marks "$w"
  # Drop the cells only when the window owns its buffer: a derwin/subwin
  # shares its parent's cells, which must survive it (as in ncurses). The
  # owner's cells live in its rectangle, so walk that instead of every cell.
  local buf=${BC_WBUF[$w]:-} k ay ax
  if [[ -n $buf && $buf == "$w" ]]; then
    for (( ay = BC_WY[$w]; ay < BC_WY[$w] + BC_WH[$w]; ay++ )); do
      unset "BC_CROW[$buf $ay]" "BC_PUNI[$buf $ay]"
      for (( ax = BC_WX[$w]; ax < BC_WX[$w] + BC_WW[$w]; ax++ )); do
        k="$buf/$ay $ax"
        unset "BC_C[$k]" "BC_A[$k]" "BC_P[$k]"
      done
    done
  fi
  if [[ -n ${BC_WDR[$w]:-} ]]; then
    local IFS=','
    for k in ${BC_WDR[$w]}; do [[ -n $k ]] && unset "BC_MKR[$w/$k]"; done
    unset IFS
  fi
  unset "BC_WDR[$w]"
  unset "BC_WD[$w]" "BC_WBUF[$w]"
  unset "BC_WY[$w]" "BC_WX[$w]" "BC_WH[$w]" "BC_WW[$w]"
  unset "BC_WBG[$w]" "BC_WBGA[$w]" "BC_WBGP[$w]"
  unset "BC_WAX[$w]" "BC_WAY[$w]" "BC_WCURA[$w]" "BC_WCURP[$w]" "BC_WDELAY[$w]"
  unset "BC_WTIMEOUT[$w]" "BC_WYOFF[$w]"
  unset "BC_WPAR[$w]" "BC_WCLEAR[$w]" "BC_WIDC[$w]" "BC_WIDL[$w]"
  unset "BC_WIMM[$w]" "BC_WLEAVE[$w]" "BC_WNOTIMEOUT[$w]" "BC_WSYNC[$w]"
  unset "BC_SCROLL[$w]" "BC_SR[$w]"
  local -a nl=()
  local z
  for z in "${BC_WLIST[@]}"; do
    if [[ $z != "$w" ]]; then
      nl+=("$z")
    fi
  done
  BC_WLIST=("${nl[@]}")
  return 0
}

# Re-read the terminal size, resize the standard window, and physically clear
# the screen so no stale content from the old dimensions survives.
resizeterm() {
  local t
  t=$(tput lines 2>/dev/null); [[ $t =~ ^[0-9]+$ ]] && (( t > 0 )) && BC_LINES=$t
  t=$(tput cols 2>/dev/null); [[ $t =~ ^[0-9]+$ ]] && (( t > 0 )) && BC_COLS=$t
  LINES=$BC_LINES; COLS=$BC_COLS
  BC_WH[0]=$BC_LINES; BC_WW[0]=$BC_COLS
  printf '%s[2J%s[H' "$BC_ESC" "$BC_ESC"
  # ncurses resizeterm forces a full repaint: drop the curscr model and mark
  # stdscr dirty so the next refresh redraws everything on the cleared screen.
  BC_S=(); BC_SA=(); BC_SP=()
  _bc_mark_all "$BC_STDSCR"
  return 0
}

resizestdscr() { resizeterm "$@"; }

wresize() { # win lines cols
  local w=${1:-$BC_CURR} lines=${2:-0} cols=${3:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  (( lines > 0 && cols > 0 )) || return 1
  BC_WH[$w]=$lines
  BC_WW[$w]=$cols
  _bc_mark_all "$w"
  return 0
}

resize_term() { # lines cols
  local lines=${1:-0} cols=${2:-0}
  (( lines > 0 && cols > 0 )) || return 1
  BC_LINES=$lines
  BC_COLS=$cols
  LINES=$lines
  COLS=$cols
  BC_WH[0]=$lines
  BC_WW[0]=$cols
  _bc_mark_all 0
  return 0
}

is_term_resized() { # lines cols
  (( $1 != BC_LINES || $2 != BC_COLS ))
}

move() { wmove "$BC_STDSCR" "$1" "$2"; }

wmove() { # win y x
  local w=${1:-$BC_CURR}
  if (( $2 < 0 || $3 < 0 || $2 >= BC_WH[$w] || $3 >= BC_WW[$w] )); then
    return 1
  fi
  BC_WAY[$w]=$2
  BC_WAX[$w]=$3
  return 0
}

mvcur() { # y x
  move "$1" "$2"
  if (( $? == 0 )); then
    wrefresh "$BC_STDSCR"
  fi
}

getmaxyx() { # win
  local w=${1:-$BC_CURR}
  BC_GMY=${BC_WH[$w]}
  BC_GMX=${BC_WW[$w]}
  return 0
}

getbegyx() { # win
  local w=${1:-$BC_CURR}
  BC_GBY=${BC_WY[$w]}
  BC_GBX=${BC_WX[$w]}
  return 0
}

# window-relative cursor position (ncurses getyx)
getyx() { # win -> BC_GCY BC_GCX
  local w=${1:-$BC_CURR}
  BC_GCY=${BC_WAY[$w]}
  BC_GCX=${BC_WAX[$w]}
  return 0
}

getcury() { # win -> BC_GCY
  local w=${1:-$BC_CURR}
  BC_GCY=${BC_WAY[$w]}
  return 0
}

getcurx() { # win -> BC_GCX
  local w=${1:-$BC_CURR}
  BC_GCX=${BC_WAX[$w]}
  return 0
}

getbegy() { # win -> BC_GBY
  local w=${1:-$BC_CURR}
  BC_GBY=${BC_WY[$w]}
  return 0
}

getbegx() { # win -> BC_GBX
  local w=${1:-$BC_CURR}
  BC_GBX=${BC_WX[$w]}
  return 0
}

getmaxy() { # win -> BC_GMY
  local w=${1:-$BC_CURR}
  BC_GMY=$(( BC_WH[$w] - 1 ))
  return 0
}

getmaxx() { # win -> BC_GMX
  local w=${1:-$BC_CURR}
  BC_GMX=$(( BC_WW[$w] - 1 ))
  return 0
}

getattrs() { # win -> BC_GA
  local w=${1:-$BC_CURR}
  BC_GA=${BC_WCURA[$w]}
  return 0
}

getbkgd() { # win -> BC_GBKG BC_GBKG_A BC_GBKG_P
  local w=${1:-$BC_CURR}
  BC_GBKG=${BC_WBG[$w]}
  BC_GBKG_A=${BC_WBGA[$w]}
  BC_GBKG_P=${BC_WBGP[$w]}
  return 0
}

# ----------------------------------------------------------- erase / fill
werase() { _bc_erase_region "${1:-$BC_CURR}"; }
wclear() { werase "$@"; }
clear() { werase "$BC_STDSCR"; }

# clear from the window cursor to the end of its line (ncurses clrtoeol)
wclrtoeol() { # win
  local w=${1:-$BC_CURR}
  _bc_clrtoeol_cell "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}"
  return 0
}

clrtoeol() { wclrtoeol "$BC_STDSCR"; }

wclrtobot() { # win
  local w=${1:-$BC_CURR}
  local y=${BC_WAY[$w]} x=${BC_WAX[$w]} yy
  _bc_clrtoeol_cell "$w" "$y" "$x"
  for (( yy = y + 1; yy < BC_WH[$w]; yy++ )); do
    _bc_clrtoeol_cell "$w" "$yy" 0
  done
  return 0
}

clrtobot() { wclrtobot "$BC_STDSCR"; }
erase() { werase "$BC_STDSCR"; }

beep() { printf '\a'; return 0; }
flash() { return 0; }

# ---------------------------------------------------------- output / text
waddstr() { # win str
  local w=${1:-$BC_CURR}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "$2" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
  return 0
}

addstr() { waddstr "$BC_STDSCR" "$@"; }

waddnstr() { # win str n
  local w=${1:-$BC_CURR} s=$2 n=${3:-0}
  (( n >= 0 )) && s=${s:0:n}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "$s" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
  return 0
}

addnstr() { waddnstr "$BC_CURR" "$@"; }

mvwaddstr() { # win y x str
  wmove "$1" "$2" "$3" && waddstr "$1" "$4"
}

mvaddstr() { mvwaddstr "$BC_STDSCR" "$@"; }

mvwaddnstr() { # win y x str n
  wmove "$1" "$2" "$3" && waddnstr "$1" "$4" "$5"
}

mvaddnstr() { mvwaddnstr "$BC_STDSCR" "$@"; }

# printf-style output: format with bash printf, then emit the result
printw() { # fmt [args...]
  local out
  printf -v out "$1" "${@:2}"
  addstr "$out"
  return 0
}

mvprintw() { # y x fmt [args...]
  move "$1" "$2" || return 1
  local out
  printf -v out "$3" "${@:4}"
  addstr "$out"
  return 0
}

mvwprintw() { # win y x fmt [args...]
  wmove "$1" "$2" "$3" || return 1
  local out
  printf -v out "$4" "${@:5}"
  waddstr "$1" "$out"
  return 0
}

wprintw() { # win fmt [args...]
  local w=${1:-$BC_CURR}
  local out
  printf -v out "$2" "${@:3}"
  waddstr "$w" "$out"
  return 0
}

vwprintw() { wprintw "$@"; }
vw_printw() { wprintw "$@"; }

waddch() { # win ch [a p]
  local w=${1:-$BC_CURR}
  local a=${3:-${BC_WCURA[$w]}}
  local p=${4:-${BC_WCURP[$w]}}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "${2:- }" "$a" "$p"
  return 0
}

addch() { waddch "$BC_STDSCR" "$@"; }

mvwaddch() { # win y x ch [a p]
  wmove "$1" "$2" "$3" && waddch "$1" "${4:- }" ${5:+"$5"} ${6:+"$6"}
}

mvaddch() { mvwaddch "$BC_STDSCR" "$@"; }

winsn() { # win y x n str
  local w=$1 y=$2 x=$3 n=$4 str=$5
  while (( ${#str} < n )); do
    str+=" "
  done
  _bc_emit "$w" "$y" "$x" "$str" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
  return 0
}

mvwinch() { # win y x -> sets wch, wcha, wchp
  local w=$1
  local buf=${BC_WBUF[$w]}
  local ay=$(( BC_WY[$w] + $2 )) rk="$buf $(( BC_WY[$w] + $2 ))"
  if [[ -n ${BC_PUNI[$rk]+x} ]]; then
    local pen=${BC_PUNI[$rk]}
    local o=${BC_BUF2W[$buf]:-$w}
    wch=${BC_CROW[$rk]:$(( BC_WX[$w] + $3 - BC_WX[$o] )):1}
    wcha=${pen% *}; wchp=${pen#* }
    return 0
  fi
  local k="$buf/$ay $(( BC_WX[$w] + $3 ))"
  wch=${BC_C[$k]:- }
  wcha=${BC_A[$k]:-0}
  wchp=${BC_P[$k]:-0}
  return 0
}

winch() { # win -> sets wch, wcha, wchp
  local w=${1:-$BC_CURR}
  mvwinch "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}"
}

inch() { winch "$BC_STDSCR"; }

mvwinchnstr() { # win y x n -> bc_chstr bc_chattr bc_chpair bc_str
  wmove "$1" "$2" "$3" && inchnstr "$1" "$4"
}

mvwinchstr() { # win y x -> bc_chstr bc_chattr bc_chpair bc_str
  wmove "$1" "$2" "$3" && inchstr "$1"
}

inchnstr() { # win n -> bc_chstr bc_chattr bc_chpair bc_str
  local w=${1:-$BC_CURR} n=${2:-0}
  local y=${BC_WAY[$w]} x=${BC_WAX[$w]} ww=${BC_WW[$w]}
  local buf=${BC_WBUF[$w]} ay=$(( BC_WY[$w] + y ))
  _bc_flush_row "$w" "$ay"
  bc_chstr=(); bc_chattr=(); bc_chpair=(); bc_str=""
  local i=0 k
  while (( x < ww && (n <= 0 || i < n) )); do
    k="$buf/$ay $(( BC_WX[$w] + x ))"
    bc_chstr+=("${BC_C[$k]:- }")
    bc_chattr+=("${BC_A[$k]:-0}")
    bc_chpair+=("${BC_P[$k]:-0}")
    bc_str+="${BC_C[$k]:- }"
    x=$(( x + 1 ))
    i=$(( i + 1 ))
  done
  return 0
}

inchstr() { inchnstr "${1:-$BC_CURR}" 0; }

instr() { # win n -> bc_str
  local w=${1:-$BC_CURR} n=${2:-0}
  local y=${BC_WAY[$w]} x=${BC_WAX[$w]} ww=${BC_WW[$w]}
  local buf=${BC_WBUF[$w]} ay=$(( BC_WY[$w] + y ))
  _bc_flush_row "$w" "$ay"
  bc_str=""
  local i=0 k
  while (( x < ww && (n <= 0 || i < n) )); do
    k="$buf/$ay $(( BC_WX[$w] + x ))"
    bc_str+="${BC_C[$k]:- }"
    x=$(( x + 1 ))
    i=$(( i + 1 ))
  done
  return 0
}

innstr() { instr "${1:-$BC_CURR}" "$2"; }

mvwinstr() { # win y x -> bc_str
  wmove "$1" "$2" "$3" && instr "$1"
}

mvwinnstr() { # win y x n -> bc_str
  wmove "$1" "$2" "$3" && innstr "$1" "$4"
}

waddchstr() { # win str
  local w=${1:-$BC_CURR}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "$2" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
  return 0
}

addchstr() { waddchstr "$BC_CURR" "$@"; }

mvwaddchstr() { # win y x str
  wmove "$1" "$2" "$3" && waddchstr "$1" "$4"
}

mvaddchstr() { mvwaddchstr "$BC_STDSCR" "$@"; }

waddchnstr() { # win str n
  local w=${1:-$BC_CURR}
  local s=$2
  if (( $3 >= 0 )); then
    s=${s:0:$3}
  fi
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "$s" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
  return 0
}

addchnstr() { waddchnstr "$BC_CURR" "$@"; }

mvwaddchnstr() { # win y x str n
  wmove "$1" "$2" "$3" && waddchnstr "$1" "$4" "$5"
}

mvaddchnstr() { mvwaddchnstr "$BC_STDSCR" "$@"; }

_bc_ins_cell() { # w y x ch a p
  local w=$1 y=$2 x=$3
  local ww=${BC_WW[$w]} buf=${BC_WBUF[$w]}
  (( y < 0 || y >= BC_WH[$w] || x < 0 || x >= ww )) && return 0
  _bc_render "$w" "$4" "$5" "$6"
  local ch=$BC_RCH a=$BC_RA p=$BC_RP
  local ay=$(( BC_WY[$w] + y )) ax sk dk
  for (( ax = ww - 1; ax > x; ax-- )); do
    sk="$buf/$ay $(( BC_WX[$w] + ax - 1 ))"
    dk="$buf/$ay $(( BC_WX[$w] + ax ))"
    if [[ -n ${BC_C[$sk]+set} ]]; then
      BC_C[$dk]=${BC_C[$sk]}
      BC_A[$dk]=${BC_A[$sk]:-0}
      BC_P[$dk]=${BC_P[$sk]:-0}
    else
      unset "BC_C[$dk]" "BC_A[$dk]" "BC_P[$dk]"
    fi
  done
  _bc_cell "$w" "$ay" "$(( BC_WX[$w] + x ))" "$ch" "$a" "$p"
  _bc_mark_region "$w" "$ay" "$(( BC_WX[$w] + x ))" 1 $(( ww - x ))
  return 0
}

_bc_del_cell() { # w y x
  local w=$1 y=$2 x=$3
  local ww=${BC_WW[$w]} buf=${BC_WBUF[$w]}
  (( y < 0 || y >= BC_WH[$w] || x < 0 || x >= ww )) && return 0
  local ay=$(( BC_WY[$w] + y )) ax sk dk
  for (( ax = x; ax < ww - 1; ax++ )); do
    sk="$buf/$ay $(( BC_WX[$w] + ax + 1 ))"
    dk="$buf/$ay $(( BC_WX[$w] + ax ))"
    if [[ -n ${BC_C[$sk]+set} ]]; then
      BC_C[$dk]=${BC_C[$sk]}
      BC_A[$dk]=${BC_A[$sk]:-0}
      BC_P[$dk]=${BC_P[$sk]:-0}
    else
      unset "BC_C[$dk]" "BC_A[$dk]" "BC_P[$dk]"
    fi
  done
  _bc_clear_cell "$w" "$ay" "$(( BC_WX[$w] + ww - 1 ))"
  _bc_mark_region "$w" "$ay" "$(( BC_WX[$w] + x ))" 1 $(( ww - x ))
  return 0
}

winsch() { # win ch [a p]
  local w=${1:-$BC_CURR}
  local a=${3:-${BC_WCURA[$w]}}
  local p=${4:-${BC_WCURP[$w]}}
  _bc_ins_cell "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "${2:- }" "$a" "$p"
  if (( BC_WAX[$w] + 1 < BC_WW[$w] )); then
    BC_WAX[$w]=$(( BC_WAX[$w] + 1 ))
  fi
  return 0
}

insch() { winsch "$BC_CURR" "$@"; }

mvwinsch() { # win y x ch [a p]
  wmove "$1" "$2" "$3" && winsch "$1" "${4:- }" ${5:+"$5"} ${6:+"$6"}
}

mvinsch() { mvwinsch "$BC_STDSCR" "$@"; }

winsnstr() { # win n str
  local w=${1:-$BC_CURR} n=$2 str=$3
  local len=${#str}
  (( n < 0 )) && n=$len
  (( n > len )) && n=$len
  local i=0
  for (( i = 0; i < n; i++ )); do
    _bc_ins_cell "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "${str:i:1}" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
    if (( BC_WAX[$w] + 1 < BC_WW[$w] )); then
      BC_WAX[$w]=$(( BC_WAX[$w] + 1 ))
    fi
  done
  return 0
}

insnstr() { winsnstr "$BC_CURR" "$@"; }

winsstr() { winsnstr "${1:-$BC_CURR}" -1 "$2"; }

insstr() { winsstr "$BC_CURR" "$@"; }

mvwinsnstr() { # win y x n str
  wmove "$1" "$2" "$3" && winsnstr "$1" "$4" "$5"
}

mvwinsstr() { # win y x str
  wmove "$1" "$2" "$3" && winsstr "$1" "$4"
}

mvinsnstr() { mvwinsnstr "$BC_STDSCR" "$@"; }

mvinsstr() { mvwinsstr "$BC_STDSCR" "$@"; }

wdelch() { # win
  local w=${1:-$BC_CURR}
  _bc_del_cell "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}"
  return 0
}

delch() { wdelch "$BC_CURR"; }

mvwdelch() { # win y x
  wmove "$1" "$2" "$3" && wdelch "$1"
}

mvdelch() { mvwdelch "$BC_STDSCR" "$@"; }

wdeleteln() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  local y=${BC_WAY[$w]} h=${BC_WH[$w]}
  _bc_scroll_window_cells "$w" "$(( BC_WY[$w] + y ))" "$(( BC_WY[$w] + h - 1 ))" 1
  _bc_mark_region "$w" "$(( BC_WY[$w] + y ))" "${BC_WX[$w]}" $(( h - y )) "${BC_WW[$w]}"
  return 0
}

deleteln() { wdeleteln "$BC_CURR"; }

winsertln() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  local y=${BC_WAY[$w]} h=${BC_WH[$w]}
  _bc_scroll_window_cells "$w" "$(( BC_WY[$w] + y ))" "$(( BC_WY[$w] + h - 1 ))" -1
  _bc_mark_region "$w" "$(( BC_WY[$w] + y ))" "${BC_WX[$w]}" $(( h - y )) "${BC_WW[$w]}"
  return 0
}

insertln() { winsertln "$BC_CURR"; }

winsdelln() { # win n
  local w=${1:-$BC_CURR} n=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  (( n == 0 )) && return 0
  local y=${BC_WAY[$w]} h=${BC_WH[$w]}
  _bc_scroll_window_cells "$w" "$(( BC_WY[$w] + y ))" "$(( BC_WY[$w] + h - 1 ))" "$(( -n ))"
  _bc_mark_region "$w" "$(( BC_WY[$w] + y ))" "${BC_WX[$w]}" $(( h - y )) "${BC_WW[$w]}"
  return 0
}

insdelln() { winsdelln "$BC_CURR" "$@"; }

copywin() { # src dst sminy sminx dminy dminx dmaxy dmaxx overlay
  local src=$1 dst=$2 sminy=$3 sminx=$4 dminy=$5 dminx=$6 dmaxy=$7 dmaxx=$8 ov=${9:-0}
  [[ -n ${BC_WY[$src]:-} && -n ${BC_WY[$dst]:-} ]] || return 1
  _bc_flush_win "$src"
  local sh=${BC_WH[$src]} sw=${BC_WW[$src]} dh=${BC_WH[$dst]} dw=${BC_WW[$dst]}
  local rows=$(( dmaxy - dminy + 1 )) cols=$(( dmaxx - dminx + 1 ))
  if (( sminy < 0 )); then dminy=$(( dminy - sminy )); sminy=0; fi
  if (( sminx < 0 )); then dminx=$(( dminx - sminx )); sminx=0; fi
  if (( dminy < 0 )); then sminy=$(( sminy - dminy )); dminy=0; fi
  if (( dminx < 0 )); then sminx=$(( sminx - dminx )); dminx=0; fi
  if (( sminy + rows > sh )); then rows=$(( sh - sminy )); fi
  if (( sminx + cols > sw )); then cols=$(( sw - sminx )); fi
  if (( dminy + rows > dh )); then rows=$(( dh - dminy )); fi
  if (( dminx + cols > dw )); then cols=$(( dw - dminx )); fi
  (( rows <= 0 || cols <= 0 )) && return 0
  local sbuf=${BC_WBUF[$src]} dbuf=${BC_WBUF[$dst]}
  local -a dk=() dc=() da=() dp=()
  local y x sk ch a p
  for (( y = 0; y < rows; y++ )); do
    for (( x = 0; x < cols; x++ )); do
      sk="$sbuf/$(( BC_WY[$src] + sminy + y )) $(( BC_WX[$src] + sminx + x ))"
      ch=${BC_C[$sk]:- }
      if [[ $ov != 0 && $ov != false && $ch == ' ' ]]; then
        continue
      fi
      a=${BC_A[$sk]:-0}
      p=${BC_P[$sk]:-0}
      dk+=("$(( dminy + y )) $(( dminx + x ))")
      dc+=("$ch")
      da+=("$a")
      dp+=("$p")
    done
  done
  local i
  for i in "${!dk[@]}"; do
    _bc_cell "$dst" "$(( BC_WY[$dst] + ${dk[i]%% *} ))" "$(( BC_WX[$dst] + ${dk[i]##* } ))" "${dc[i]}" "${da[i]}" "${dp[i]}"
  done
  return 0
}

overlay() { # src dst
  local src=$1 dst=$2
  copywin "$src" "$dst" 0 0 0 0 $(( BC_WH[$dst] - 1 )) $(( BC_WW[$dst] - 1 )) 1
}

overwrite() { # src dst
  local src=$1 dst=$2
  copywin "$src" "$dst" 0 0 0 0 $(( BC_WH[$dst] - 1 )) $(( BC_WW[$dst] - 1 )) 0
}

# -------------------------------------------------------------- graphics
wborder() { # win ls rs ts bs [tl tr bl br]
  local w=${1:-$BC_CURR}
  local ls=${2:-$ACS_VLINE} rs=${3:-$ACS_VLINE}
  local ts=${4:-$ACS_HLINE} bs=${5:-$ACS_HLINE}
  local tl=${6:-$ACS_UL} tr=${7:-$ACS_UR}
  local bl=${8:-$ACS_LL} br=${9:-$ACS_LR}
  local h=${BC_WH[$w]} ww=${BC_WW[$w]} i
  local a=${BC_WCURA[$w]} p=${BC_WCURP[$w]}
  local oy=${BC_WAY[$w]} ox=${BC_WAX[$w]}
  for (( i = 1; i < h - 1; i++ )); do
    _bc_put "$w" "$i" 0 "$ls" "$a" "$p"
    _bc_put "$w" "$i" $(( ww - 1 )) "$rs" "$a" "$p"
  done
  for (( i = 1; i < ww - 1; i++ )); do
    _bc_put "$w" 0 "$i" "$ts" "$a" "$p"
    _bc_put "$w" $(( h - 1 )) "$i" "$bs" "$a" "$p"
  done
  _bc_put "$w" 0 0 "$tl" "$a" "$p"
  _bc_put "$w" 0 $(( ww - 1 )) "$tr" "$a" "$p"
  _bc_put "$w" $(( h - 1 )) 0 "$bl" "$a" "$p"
  _bc_put "$w" $(( h - 1 )) $(( ww - 1 )) "$br" "$a" "$p"
  BC_WAY[$w]=$oy
  BC_WAX[$w]=$ox
  return 0
}

wborder_set() { wborder "$@"; }

box() { # win [verch horch]
  local w=${1:-$BC_CURR}
  wborder "$w" "${2:-$ACS_VLINE}" "${2:-$ACS_VLINE}" "${3:-$ACS_HLINE}" "${3:-$ACS_HLINE}"
}

box_set() { # win [vcl hcl tl tr bl br]
  local w=${1:-$BC_CURR}
  wborder_set "$w" "${2:-$ACS_VLINE}" "${2:-$ACS_VLINE}" "${3:-$ACS_HLINE}" "${3:-$ACS_HLINE}" \
    "${4:-$ACS_UL}" "${5:-$ACS_UR}" "${6:-$ACS_LL}" "${7:-$ACS_LR}"
}

border() { # [ls rs ts bs tl tr bl br]
  wborder "$BC_STDSCR" "$@"
}

mvborder() { # y x [ls rs ts bs tl tr bl br]
  move "$1" "$2" && border "${@:3}"
}

mvwborder() { # win y x [ls rs ts bs tl tr bl br]
  wmove "$1" "$2" "$3" && wborder "$1" "${@:4}"
}

whline() { # win ch n
  local w=${1:-$BC_CURR} ch=$2 n=$3 i
  local oy=${BC_WAY[$w]} ox=${BC_WAX[$w]}
  local y=$oy x=$ox
  local a=${BC_WCURA[$w]} p=${BC_WCURP[$w]}
  for (( i = 0; i < n; i++ )); do
    _bc_put "$w" "$y" $(( x + i )) "$ch" "$a" "$p"
  done
  BC_WAY[$w]=$oy
  BC_WAX[$w]=$ox
  return 0
}

wvline() { # win ch n
  local w=${1:-$BC_CURR} ch=$2 n=$3 i
  local oy=${BC_WAY[$w]} ox=${BC_WAX[$w]}
  local y=$oy x=$ox
  local a=${BC_WCURA[$w]} p=${BC_WCURP[$w]}
  for (( i = 0; i < n; i++ )); do
    _bc_put "$w" $(( y + i )) "$x" "$ch" "$a" "$p"
  done
  BC_WAY[$w]=$oy
  BC_WAX[$w]=$ox
  return 0
}

hline() { whline "$BC_CURR" "$@"; }
vline() { wvline "$BC_CURR" "$@"; }

# draw a horizontal/vertical line of n chars starting at (y,x) on stdscr
# (ncurses mvhline/mvvline: move to (y,x), then emit n chars)
mvhline() { # y x ch n
  wmove "$BC_STDSCR" "$1" "$2" || return 1
  hline "$3" "$4"
}

mvwhline() { # win y x ch n
  wmove "$1" "$2" "$3" || return 1
  whline "$1" "$4" "$5"
}

mvvline() { # y x ch n
  wmove "$BC_STDSCR" "$1" "$2" || return 1
  vline "$3" "$4"
}

mvwvline() { # win y x ch n
  wmove "$1" "$2" "$3" || return 1
  wvline "$1" "$4" "$5"
}

hline_set() { hline "${1:0:1}" "$2"; }
vline_set() { vline "${1:0:1}" "$2"; }
whline_set() { whline "$1" "${2:0:1}" "$3"; }
wvline_set() { wvline "$1" "${2:0:1}" "$3"; }
mvhline_set() { # y x cchar n
  wmove "$BC_STDSCR" "$1" "$2" || return 1
  hline_set "$3" "$4"
}
mvvline_set() { # y x cchar n
  wmove "$BC_STDSCR" "$1" "$2" || return 1
  vline_set "$3" "$4"
}
mvwhline_set() { # win y x cchar n
  wmove "$1" "$2" "$3" || return 1
  whline_set "$1" "$4" "$5"
}
mvwvline_set() { # win y x cchar n
  wmove "$1" "$2" "$3" || return 1
  wvline_set "$1" "$4" "$5"
}

wbkgd() { # win ch a p
  local w=${1:-$BC_CURR}
  local oldc=${BC_WBG[$w]} olda=${BC_WBGA[$w]} oldp=${BC_WBGP[$w]}
  local newc=${2:- } newa=${3:-0} newp=${4:-0}
  if [[ $newc == "$oldc" && $newa -eq $olda && $newp -eq $oldp ]]; then
    return 0
  fi
  # the new background's attrs become the window's attr state
  BC_WCURA[$w]=$newa
  if (( newp )); then
    BC_WCURP[$w]=$newp
  elif (( oldp )); then
    BC_WCURP[$w]=0
  fi
  BC_WBG[$w]=$newc
  BC_WBGA[$w]=$newa
  BC_WBGP[$w]=$newp
  # re-apply the background to every existing cell
  local buf=${BC_WBUF[$w]}
  local y x k ch a p
  for (( y = 0; y < BC_WH[$w]; y++ )); do
    for (( x = 0; x < BC_WW[$w]; x++ )); do
      k="$buf/$(( BC_WY[$w] + y )) $(( BC_WX[$w] + x ))"
      ch=${BC_C[$k]:- }
      a=${BC_A[$k]:-0}
      p=${BC_P[$k]:-0}
      if [[ $ch == "$oldc" ]]; then
        ch=$newc
      fi
      a=$(( (a & ~olda) | newa ))
      if (( p == 0 || p == oldp )); then
        p=$newp
      fi
      if [[ $ch != ' ' || $a -ne 0 || $p -ne 0 ]]; then
        _bc_cell "$w" "$(( BC_WY[$w] + y ))" "$(( BC_WX[$w] + x ))" "$ch" "$a" "$p"
      fi
    done
  done
  return 0
}

wbkgdset() { # win ch a p
  local w=${1:-$BC_CURR}
  BC_WBG[$w]=${2:- }
  BC_WBGA[$w]=${3:-0}
  BC_WBGP[$w]=${4:-0}
  BC_WCURA[$w]=${3:-0}
  if (( ${4:-0} )); then
    BC_WCURP[$w]=${4}
  fi
  return 0
}

wbkgset() { wbkgdset "$@"; }
bkgd() { wbkgd "$BC_STDSCR" "$@"; }
bkgdset() { wbkgdset "$BC_STDSCR" "$@"; }

bkgrnd() { # win cchar [a p]
  local w=${1:-$BC_CURR}
  wbkgd "$w" "${2:0:1}" "${3:-0}" "${4:-0}"
}

bkgrndset() { # win cchar [a p]
  local w=${1:-$BC_CURR}
  wbkgdset "$w" "${2:0:1}" "${3:-0}" "${4:-0}"
}

getbkgrnd() { # win -> wch wcha wchp
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  wch=${BC_WBG[$w]}
  wcha=${BC_WBGA[$w]}
  wchp=${BC_WBGP[$w]}
  return 0
}

# --------------------------------------------------------------- slk
# Soft-key labels. slk_init(fmt) with fmt 0..3 reserves 1 line (fmt 0..2)
# or 2 lines (fmt 3) at the bottom of the screen; the stored format is
# fmt+1: 1,2 -> 8 labels of 8 cols, 3,4 -> 12 labels of 5 cols.

_bc_slk_init_labels() { # stored fmt, cols
  local fmt=$1 cols=$2
  local i x gap
  BC_SLK_ATTR=4  # A_STANDOUT (no-color-video is unset)
  BC_SLK_PAIR=0
  BC_SLK_HIDDEN=0
  if (( fmt < 3 )); then
    BC_SLK_MAXLAB=8
    BC_SLK_MAXLEN=8
  else
    BC_SLK_MAXLAB=12
    BC_SLK_MAXLEN=5
  fi
  BC_SLK_LABCNT=$BC_SLK_MAXLAB
  BC_SLK_TEXT=()
  BC_SLK_FORM=()
  BC_SLK_X=()
  BC_SLK_LD=()
  for (( i = 0; i < BC_SLK_LABCNT; i++ )); do
    BC_SLK_TEXT[i]=""
    BC_SLK_FORM[i]=$(printf '%*s' "$BC_SLK_MAXLEN" '')
    BC_SLK_LD[i]=0
  done
  if (( fmt >= 3 )); then
    gap=$(( (cols - 3 * (3 + 4 * BC_SLK_MAXLEN)) / 2 ))
  elif (( fmt == 2 )); then
    gap=$(( cols - BC_SLK_MAXLAB * BC_SLK_MAXLEN - 6 ))
  else
    gap=$(( (cols - BC_SLK_MAXLAB * BC_SLK_MAXLEN - 5) / 2 ))
  fi
  (( gap < 1 )) && gap=1
  for (( i = 0, x = 0; i < BC_SLK_MAXLAB; i++ )); do
    BC_SLK_X[i]=$x
    x=$(( x + BC_SLK_MAXLEN ))
    if (( fmt >= 3 )) && (( i == 3 || i == 7 )); then
      x=$(( x + gap ))
    elif (( fmt == 2 )) && (( i == 3 )); then
      x=$(( x + gap ))
    elif (( fmt == 1 )) && (( i == 2 || i == 4 )); then
      x=$(( x + gap ))
    else
      x=$(( x + 1 ))
    fi
  done
  BC_SLK_DIRTY=1
}

_bc_slk_apply() {
  local n=$BC_SLK_LINES
  (( n > 0 && n < BC_LINES )) || n=1
  BC_LINES=$(( BC_LINES - n ))
  LINES=$BC_LINES
  if [[ -n ${BC_WY[0]:-} ]] && (( BC_WY[0] == 0 && BC_WX[0] == 0 )); then
    BC_WH[0]=$BC_LINES
  fi
  _bc_init_window "$BC_WN" "$BC_LINES" 0 "$n" "$BC_COLS"
  BC_SLK_WIN=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_slk_init_labels "$BC_SLK_FMT" "$BC_COLS"
  BC_SLK=1
  BC_SLK_PENDING=0
}

slk_init() {
  local fmt=${1-}
  [[ $fmt =~ ^[0-9]+$ ]] || return 1
  (( fmt >= 0 && fmt <= 3 && ! BC_SLK )) || return 1
  local stored=$(( fmt + 1 ))
  BC_SLK_FMT=$stored
  if (( stored < 3 )); then
    BC_SLK_LINES=1
  else
    BC_SLK_LINES=$(( stored - 2 ))
  fi
  if (( BC_STARTED )); then
    _bc_slk_apply
  else
    BC_SLK_PENDING=1
  fi
  return 0
}

slk_set() {
  local i=${1-} str=${2-} fmt=${3-}
  [[ $i =~ ^[0-9]+$ && $fmt =~ ^[0-9]+$ ]] || return 1
  (( BC_SLK && i >= 1 && i <= BC_SLK_LABCNT && fmt >= 0 && fmt <= 2 )) || return 1
  local n=$(( i - 1 )) limit=$BC_SLK_MAXLEN
  local t=$str k=0 c offset=0
  while [[ -n $t && ${t:0:1} == [$' \t\n\r\f\v'] ]]; do
    t=${t:1}
  done
  while (( k < ${#t} )); do
    c=${t:k:1}
    printf -v _bc_o '%d' "'$c"
    (( _bc_o < 32 || _bc_o > 126 )) && break
    (( k++ ))
  done
  (( k > limit )) && k=$limit
  local text=${t:0:k}
  case $fmt in
    1) offset=$(( (limit - k) / 2 )) ;;
    2) offset=$(( limit - k )) ;;
  esac
  (( offset < 0 )) && offset=0
  local form=""
  (( offset > 0 )) && form+=$(printf '%*s' "$offset" '')
  form+=$text
  local trail=$(( limit - offset - k ))
  (( trail > 0 )) && form+=$(printf '%*s' "$trail" '')
  BC_SLK_TEXT[n]=$text
  BC_SLK_FORM[n]=$form
  BC_SLK_LD[n]=1
  return 0
}

slk_label() {
  local n=${1-}
  [[ $n =~ ^[0-9]+$ ]] || return 1
  (( BC_SLK && n >= 1 && n <= BC_SLK_LABCNT )) || return 1
  printf '%s' "${BC_SLK_TEXT[n-1]}"
  return 0
}

_bc_slk_paint_info() {
  local w=$BC_SLK_WIN i
  wmove "$w" 0 0
  for (( i = 0; i < BC_WW[$w]; i++ )); do
    waddch "$w" "$ACS_HLINE"
  done
  for (( i = 0; i < BC_SLK_MAXLAB; i++ )); do
    mvwaddstr "$w" 0 "${BC_SLK_X[i]}" "F$(( i + 1 ))"
  done
}

_bc_slk_refresh_impl() {
  local w=$BC_SLK_WIN i
  (( BC_SLK )) || return 1
  (( BC_SLK_HIDDEN )) && return 0
  for (( i = 0; i < BC_SLK_LABCNT; i++ )); do
    if (( BC_SLK_DIRTY || BC_SLK_LD[i] )); then
      if (( i < BC_SLK_MAXLAB )); then
        if (( BC_SLK_FMT == 4 )); then
          _bc_slk_paint_info
        fi
        wmove "$w" "$(( BC_SLK_LINES - 1 ))" "${BC_SLK_X[i]}"
        BC_WCURA[$w]=$BC_SLK_ATTR
        BC_WCURP[$w]=$BC_SLK_PAIR
        waddstr "$w" "${BC_SLK_FORM[i]}"
        BC_WCURA[$w]=${BC_WCURA[0]}
        BC_WCURP[$w]=${BC_WCURP[0]}
      fi
      BC_SLK_LD[i]=0
    fi
  done
  BC_SLK_DIRTY=0
  return 0
}

slk_noutrefresh() {
  (( BC_SLK )) || return 1
  (( BC_SLK_HIDDEN )) && return 0
  _bc_slk_refresh_impl || return 1
  wnoutrefresh "$BC_SLK_WIN"
  return 0
}

slk_refresh() {
  (( BC_SLK )) || return 1
  (( BC_SLK_HIDDEN )) && return 0
  _bc_slk_refresh_impl || return 1
  wrefresh "$BC_SLK_WIN"
  return 0
}

slk_clear() {
  (( BC_SLK )) || return 1
  BC_SLK_HIDDEN=1
  BC_WBG[$BC_SLK_WIN]="${BC_WBG[0]}"
  BC_WBGA[$BC_SLK_WIN]="${BC_WBGA[0]}"
  BC_WBGP[$BC_SLK_WIN]="${BC_WBGP[0]}"
  BC_WCURA[$BC_SLK_WIN]="${BC_WCURA[0]}"
  BC_WCURP[$BC_SLK_WIN]="${BC_WCURP[0]}"
  werase "$BC_SLK_WIN"
  wrefresh "$BC_SLK_WIN"
  return 0
}

slk_restore() {
  (( BC_SLK )) || return 1
  BC_SLK_HIDDEN=0
  BC_SLK_DIRTY=1
  slk_refresh
}

slk_touch() {
  (( BC_SLK )) || return 1
  BC_SLK_DIRTY=1
  return 0
}

slk_color() {
  local p=${1-}
  [[ $p =~ ^-?[0-9]+$ ]] || return 1
  (( BC_SLK && p >= 0 && p < BC_PAIRS )) || return 1
  BC_SLK_PAIR=$p
  return 0
}

slk_attr() {
  local r=0
  if (( BC_SLK )); then
    r=$(( BC_SLK_ATTR & ~256 ))
    if (( BC_SLK_PAIR > 0 )); then
      r=$(( r | 256 ))
    fi
  fi
  printf '%s' "$r"
  return 0
}

slk_attrset() {
  local a=${1-}
  (( BC_SLK )) || return 1
  BC_SLK_ATTR=$a
  BC_SLK_PAIR=0
  return 0
}

slk_attron() {
  local a=${1-}
  (( BC_SLK )) || return 1
  BC_SLK_ATTR=$(( BC_SLK_ATTR | a ))
  if (( a & 256 )); then
    BC_SLK_PAIR=$(( (a & ~256) >> 9 ))
  fi
  return 0
}

slk_attroff() {
  local a=${1-}
  (( BC_SLK )) || return 1
  BC_SLK_ATTR=$(( BC_SLK_ATTR & ~a ))
  if (( a & 256 )); then
    BC_SLK_PAIR=0
  fi
  return 0
}

slk_attr_set() { # attr pair opts
  local a=${1-} p=${2-}
  [[ $a =~ ^-?[0-9]+$ && $p =~ ^-?[0-9]+$ ]] || return 1
  (( BC_SLK && p >= 0 && p < BC_PAIRS )) || return 1
  BC_SLK_ATTR=$a
  if (( p > 0 )); then
    BC_SLK_PAIR=$p
  else
    BC_SLK_PAIR=0
  fi
  return 0
}

slk_attr_off() { # attr opts
  [[ -z ${2-} ]] || return 1
  slk_attroff "$1"
}

slk_attr_on() { # attr opts
  [[ -z ${2-} ]] || return 1
  slk_attron "$1"
}

# --------------------------------------------------------------- refresh
wrefresh() { # win
  local w=${1:-$BC_CURR}
  local buf=${BC_WBUF[$w]}
  local -a keys=()
  local -A covered=()
  local k y x ch a p out="" lasty=-1 lastx=-1
  if [[ -n ${BC_SCROLLREQ:-} ]]; then
    local srw stop sb sn
    read -r srw stop sb sn <<< "$BC_SCROLLREQ"
    if [[ $srw == "$w" ]]; then
      _bc_expand_scroll_dirty "$w" "$stop" "$sb"
      BC_SCROLLREQ=""
    fi
  fi
  if [[ $w == "$BC_STDSCR" ]] && (( BC_INITPAINT )); then
    BC_INITPAINT=0
    local -A real=()
    local IFS=','
    for k in ${BC_WD[$w]}; do [[ -n $k ]] && real["$k"]=1; done
    local w2 yy xx wy wx wh ww
    for w2 in "${!BC_WY[@]}"; do
      [[ $w2 == "$BC_STDSCR" ]] && continue
      wy=${BC_WY[$w2]}; wx=${BC_WX[$w2]}; wh=${BC_WH[$w2]}; ww=${BC_WW[$w2]}
      for (( yy = wy; yy < wy + wh; yy++ )); do
        for (( xx = wx; xx < wx + ww; xx++ )); do
          [[ -n ${real["$yy $xx"]:-} ]] && continue
          covered["$yy $xx"]=1
        done
      done
    done
    for (( yy = 0; yy < BC_LINES; yy++ )); do
      for (( xx = 0; xx < BC_COLS; xx++ )); do
        k="$yy $xx"
        [[ -n ${covered[$k]:-} || -n ${real[$k]:-} ]] && continue
        BC_WD[$w]+=",$k"
      done
    done
  fi
  if [[ -n ${BC_WD[$w]:-} ]]; then
    local IFS=','
    for k in ${BC_WD[$w]}; do
      [[ -n $k ]] && keys+=("$k")
    done
    _bc_clear_marks "$w"
    unset "BC_WD[$w]"
  fi
  for k in "${keys[@]}"; do
    y=${k%% *}
    x=${k##* }
    [[ -n ${covered["$y $x"]:-} ]] && continue
    ch=${BC_C["$buf/$k"]:- }
    a=${BC_A["$buf/$k"]:-0}
    p=${BC_P["$buf/$k"]:-0}
    if [[ ${BC_S[$k]:-} == "$ch" && ${BC_SA[$k]:-0} == "$a" && ${BC_SP[$k]:-0} == "$p" ]]; then
      continue
    fi
    if [[ -z ${BC_LO[$y]+set} || $x -lt ${BC_LO[$y]} ]]; then BC_LO[$y]=$x; fi
    if [[ -z ${BC_HI[$y]+set} || $x -gt ${BC_HI[$y]} ]]; then BC_HI[$y]=$x; fi
  done
  for y in "${!BC_LO[@]}"; do
    local lo=${BC_LO[$y]} hi=${BC_HI[$y]}
    for (( x = lo; x <= hi; x++ )); do
      k="$y $x"
      [[ -n ${covered[$k]:-} ]] && continue
      ch=${BC_C["$buf/$k"]:- }
      a=${BC_A["$buf/$k"]:-0}
      p=${BC_P["$buf/$k"]:-0}
      _bc_sgr "$a" "$p"
      if (( lasty != y || lastx != x - 1 )); then
        out+="${BC_ESC}[$(( y + 1 ));$(( x + 1 ))H"
      fi
      out+="${BC_ESC}[0m${BC_ESC}[${BC_SGR}m"
      out+=$ch
      BC_S[$k]=$ch
      BC_SA[$k]=$a
      BC_SP[$k]=$p
      lasty=$y
      lastx=$x
    done
  done
  unset 'BC_LO[*]' 'BC_HI[*]'
  if [[ -n $out ]]; then
    printf '%s' "$out"
  fi
  printf '%s[%d;%dH' "$BC_ESC" "$(( BC_WAY[$w] + BC_WY[$w] + 1 ))" "$(( BC_WAX[$w] + BC_WX[$w] + 1 ))"
  return 0
}

refresh() { wrefresh "$BC_STDSCR"; }

wnoutrefresh() { wrefresh "$@"; }

touchwin() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  _bc_mark_all "$w"
  return 0
}

untouchwin() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  _bc_clear_marks "$w"
  BC_WD[$w]=""
  return 0
}

is_wintouched() { # win
  local w=${1:-$BC_CURR}
  [[ -n ${BC_WD[$w]:-} ]]
}

touchline() { # win start count
  local w=${1:-$BC_CURR} start=${2:-0} count=${3:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  (( count <= 0 )) && return 0
  _bc_mark_region "$w" "$(( BC_WY[$w] + start ))" "${BC_WX[$w]}" "$count" "${BC_WW[$w]}"
  return 0
}

wtouchln() { # win y count changed
  local w=${1:-$BC_CURR} y=${2:-0} count=${3:-0} changed=${4:-1}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  (( count <= 0 )) && return 0
  if [[ $changed == 0 || $changed == false ]]; then
    _bc_unmark_region "$w" "$(( BC_WY[$w] + y ))" "${BC_WX[$w]}" "$count" "${BC_WW[$w]}"
  else
    _bc_mark_region "$w" "$(( BC_WY[$w] + y ))" "${BC_WX[$w]}" "$count" "${BC_WW[$w]}"
  fi
  return 0
}

is_linetouched() { # win line
  local w=${1:-$BC_CURR} line=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  local ay=$(( BC_WY[$w] + line )) k ky
  local IFS=','
  for k in ${BC_WD[$w]}; do
    ky=${k%% *}
    if (( ky == ay )); then
      return 0
    fi
  done
  return 1
}

# Which window shows at each screen cell: BC_OWN["y x"] = window (cells not
# covered by a visible panel are stdscr's). Rebuilt only when the panel stack,
# a hidden flag or a panel window's rectangle changes, so compositing a dirty
# cell is one lookup instead of a walk over every panel.
# BC_TINT["y x"] = a tint panel above that window (see panel_tint): the
# character comes from the owner, the attributes/colour from the tint.
declare -A BC_OWN=() BC_TINT=()
declare -A BC_PTINT=()  # panel id -> 1 for a tint (see-through) panel
BC_OWNSIG=""
_bc_owner_map() {
  local p w sig="$BC_LINES $BC_COLS"
  for p in "${BC_PSTACK[@]}"; do
    w=${BC_PWIN[$p]}
    sig+="|$w ${BC_PHID[$p]:-0} ${BC_PTINT[$p]:-0} ${BC_WY[$w]} ${BC_WX[$w]} ${BC_WH[$w]} ${BC_WW[$w]}"
  done
  [[ $sig == "$BC_OWNSIG" ]] && return 0
  BC_OWN=() BC_TINT=()
  local y x y0 y1 x0 x1 t
  for p in "${BC_PSTACK[@]}"; do
    [[ ${BC_PHID[$p]:-0} == 1 ]] && continue
    w=${BC_PWIN[$p]}
    [[ -n ${BC_WY[$w]:-} ]] || continue
    y0=${BC_WY[$w]} x0=${BC_WX[$w]}
    y1=$(( y0 + BC_WH[$w] )) x1=$(( x0 + BC_WW[$w] ))
    (( y0 < 0 )) && y0=0
    (( x0 < 0 )) && x0=0
    (( y1 > BC_LINES )) && y1=$BC_LINES
    (( x1 > BC_COLS )) && x1=$BC_COLS
    t=${BC_PTINT[$p]:-0}
    for (( y = y0; y < y1; y++ )); do
      if (( t )); then
        for (( x = x0; x < x1; x++ )); do BC_TINT["$y $x"]=$w; done
      else
        for (( x = x0; x < x1; x++ )); do BC_OWN["$y $x"]=$w; unset "BC_TINT[$y $x]"; done
      fi
    done
  done
  BC_OWNSIG=$sig
}

# Extension (not in ncurses): a tint panel is see-through. Where it is the
# topmost panel, the screen shows the character of whatever lies below with
# the tint window's attributes and colour pair (e.g. Midnight Commander's
# shadows, which darken the text they fall on).
panel_tint() { # p on
  BC_PTINT[$1]=$(( ${2:-1} ? 1 : 0 ))
  _bc_win_rect_dirty "${BC_PWIN[$1]}"
  return 0
}

# Composite the visible content at one absolute cell: stdscr is the base, and
# the topmost visible panel in the stack that covers the cell wins. Sets
# _BC_CC / _BC_CA / _BC_CP.
_bc_composite_cell() { # ay ax
  local ay=$1 ax=$2 w buf p
  buf=${BC_WBUF[$BC_STDSCR]}
  _BC_CC=${BC_C["$buf/$ay $ax"]:-${BC_WBG[$BC_STDSCR]}}
  _BC_CA=${BC_A["$buf/$ay $ax"]:-0}
  _BC_CP=${BC_P["$buf/$ay $ax"]:-0}
  local tw=""
  for p in "${BC_PSTACK[@]}"; do
    [[ ${BC_PHID[$p]} == 1 ]] && continue
    w=${BC_PWIN[$p]}
    if (( ay >= BC_WY[$w] && ay < BC_WY[$w] + BC_WH[$w] && ax >= BC_WX[$w] && ax < BC_WX[$w] + BC_WW[$w] )); then
      if [[ ${BC_PTINT[$p]:-0} == 1 ]]; then tw=$w; continue; fi
      tw=""
      buf=${BC_WBUF[$w]}
      _BC_CC=${BC_C["$buf/$ay $ax"]:-${BC_WBG[$w]}}
      _BC_CA=${BC_A["$buf/$ay $ax"]:-0}
      _BC_CP=${BC_P["$buf/$ay $ax"]:-0}
    fi
  done
  if [[ -n $tw ]]; then
    buf=${BC_WBUF[$tw]}
    _BC_CA=${BC_A["$buf/$ay $ax"]:-${BC_WBGA[$tw]}}
    _BC_CP=${BC_P["$buf/$ay $ax"]:-${BC_WBGP[$tw]}}
  fi
  return 0
}

# Recomposite every cell that changed since the last update and emit only the
# diffs. The changed set is the union of the dirty cells of every window and
# the rectangles of any windows deleted since the last composite. BC_S (keyed
# "y x") holds the last composited screen, so unchanged cells are never
# re-emitted and the topmost window always wins at a cell.
doupdate() {
  local ay ax k p w r y x
  local scroll_out=""
  if [[ -n ${BC_SCROLLREQ:-} ]]; then
    local sw stop sb sn
    read -r sw stop sb sn <<< "$BC_SCROLLREQ"
    BC_SCROLLREQ=""
    if _bc_scroll_safe "$sw" "$stop" "$sb" "$sn"; then
      local atop=$(( BC_WY[$sw] + stop )) abottom=$(( BC_WY[$sw] + sb ))
      local an=$sn
      (( an < 0 )) && an=$(( -an ))
      scroll_out="${BC_ESC}[$(( atop + 1 ));$(( abottom + 1 ))r"
      if (( sn > 0 )); then
        scroll_out+="${BC_ESC}[${sn}S"
      else
        scroll_out+="${BC_ESC}[${an}T"
      fi
      scroll_out+="${BC_ESC}[r"
      _bc_shift_screen_model "$atop" "$abottom" "$sn"
    else
      _bc_expand_scroll_dirty "$sw" "$stop" "$sb"
      BC_FORCEFULL=1
    fi
  fi
  declare -A RC=()
  declare -A ROWDIRTY=()
  local -a wins=("$BC_STDSCR")
  for p in "${BC_PSTACK[@]}"; do wins+=("${BC_PWIN[$p]}"); done
  # bounding box of the dirty region, taken from the rects of the windows that
  # reported dirty cells or dirty rows (an over-approximation that is cheap).
  local bminy=999999 bmaxy=-1 bminx=999999 bmaxx=-1 hasdirty=0
  for w in "${wins[@]}"; do
    [[ -n ${BC_WD[$w]:-} || -n ${BC_WDR[$w]:-} ]] || continue
    hasdirty=1
    local wy=${BC_WY[$w]} wx=${BC_WX[$w]} wh=${BC_WH[$w]} ww=${BC_WW[$w]}
    (( wy < bminy )) && bminy=$wy
    (( wy + wh - 1 > bmaxy )) && bmaxy=$(( wy + wh - 1 ))
    (( wx < bminx )) && bminx=$wx
    (( wx + ww - 1 > bmaxx )) && bmaxx=$(( wx + ww - 1 ))
  done
  # reveal what lies under any window deleted since the last composite. The
  # region must be unconditionally re-emitted (BC_S is cleared there), because
  # the deleted window may have desynced BC_S via wrefresh, so a diff-based
  # skip could leave stale content showing through.
  if [[ -n ${BC_DELRECTS:-} ]]; then
    local ry0 rx0 rh rww r
    local -a delrects
    IFS='|' read -r -a delrects <<< "$BC_DELRECTS"
    for r in "${delrects[@]}"; do
      [[ -n $r ]] || continue
      read -r ry0 rx0 rh rww <<< "$r"
      (( ry0 < bminy )) && bminy=$ry0
      (( ry0 + rh - 1 > bmaxy )) && bmaxy=$(( ry0 + rh - 1 ))
      (( rx0 < bminx )) && bminx=$rx0
      (( rx0 + rww - 1 > bmaxx )) && bmaxx=$(( rx0 + rww - 1 ))
      for (( ay = ry0; ay < ry0 + rh; ay++ )); do
        unset "BC_SCROW[$ay]" "BC_SPROW[$ay]"
        for (( ax = rx0; ax < rx0 + rww; ax++ )); do
          RC["$ay $ax"]=1
          unset "BC_S[$ay $ax]" "BC_SA[$ay $ax]" "BC_SP[$ay $ax]"
        done
      done
    done
    hasdirty=1
  fi
  # the very first composite (or a forced full rebuild after a resize) repaints
  # the whole screen: clear the last-composited model and recompute every cell.
  local FULL=0
  if (( ! hasdirty && ${#BC_S[@]} == 0 && ${#BC_SCROW[@]} == 0 )) || (( BC_FORCEFULL )); then
    BC_FORCEFULL=0
    FULL=1
    BC_S=(); BC_SA=(); BC_SP=(); BC_SCROW=(); BC_SPROW=()
    bminy=0; bmaxy=$(( BC_LINES - 1 )); bminx=0; bmaxx=$(( BC_COLS - 1 ))
  fi
  if (( ! hasdirty && ! FULL && ${#RC[@]} == 0 )); then
    [[ -n $scroll_out ]] && printf '%s' "$scroll_out"
    return 0
  fi

  local out="$scroll_out" lasty=-1 lastx=-1 last_sgr="" ch a pp emitted=0
  # Fast path: if a single topmost visible panel fully contains the dirty
  # region and no higher window overlaps it, that panel wins every dirty cell,
  # so read its cells directly instead of walking the stack per cell. If no
  # panel touches the region at all, stdscr owns it and is read directly.
  local topbuf="" topbg=0 owner=0 ownerw=0
  local i p w j pj pw pwy pwx pwh pww wy wx wh ww
  for (( i=${#BC_PSTACK[@]}-1; i>=0; i-- )); do
    p=${BC_PSTACK[i]}
    [[ ${BC_PHID[$p]:-0} == 1 || ${BC_PTINT[$p]:-0} == 1 ]] && continue
    w=${BC_PWIN[$p]}
    wy=${BC_WY[$w]}; wx=${BC_WX[$w]}; wh=${BC_WH[$w]}; ww=${BC_WW[$w]}
    (( wy <= bminy && wx <= bminx && wy + wh > bmaxy && wx + ww > bmaxx )) || continue
    local safe=1
    for (( j=i+1; j<${#BC_PSTACK[@]}; j++ )); do
      pj=${BC_PSTACK[j]}; [[ ${BC_PHID[$pj]:-0} == 1 ]] && continue
      pw=${BC_PWIN[$pj]}
      pwy=${BC_WY[$pw]}; pwx=${BC_WX[$pw]}; pwh=${BC_WH[$pw]}; pww=${BC_WW[$pw]}
      if (( pwy <= bmaxy && pwy + pwh > bminy && pwx <= bmaxx && pwx + pww > bminx )); then safe=0; break; fi
    done
    (( safe )) || continue
    topbuf=${BC_WBUF[$w]}; topbg=${BC_WBG[$w]}; owner=1; ownerw=$w; break
  done
  if (( ! owner )); then
    local touches=0
    for p in "${BC_PSTACK[@]}"; do
      [[ ${BC_PHID[$p]:-0} == 1 ]] && continue
      w=${BC_PWIN[$p]}
      wy=${BC_WY[$w]}; wx=${BC_WX[$w]}; wh=${BC_WH[$w]}; ww=${BC_WW[$w]}
      if (( wy <= bmaxy && wy + wh > bminy && wx <= bmaxx && wx + ww > bminx )); then touches=1; break; fi
    done
    if (( ! touches )); then topbuf=${BC_WBUF[$BC_STDSCR]}; topbg=${BC_WBG[$BC_STDSCR]}; fi
  fi

  if (( FULL )); then
    # full rebuild: drop every row cache so per-cell is authoritative, then
    # repaint the whole screen per-cell.
    local rkf bwf ayf
    for rkf in "${!BC_PUNI[@]}"; do
      bwf=${rkf% *}; ayf=${rkf##* }
      _bc_flush_row "${BC_BUF2W[$bwf]}" "$ayf"
    done
    for (( ay = bminy; ay <= bmaxy; ay++ )); do
      for (( ax = bminx; ax <= bmaxx; ax++ )); do RC["$ay $ax"]=1; done
    done
  else
    # Split the dirty set: rows the owner window holds as a uniform row cache
    # are emitted whole (ROWDIRTY); everything else is recomposited per-cell.
    local owbuf=""; (( owner )) && owbuf=$topbuf
    # pass 1: classify cached rows. Owner rows with a live uniform cache are
    # emitted whole (ROWDIRTY); any other cached row is flushed to per-cell.
    for w in "${wins[@]}"; do
      local isowner=0; [[ -n $owbuf && ${BC_WBUF[$w]} == "$owbuf" ]] && isowner=1
      if [[ -n ${BC_WDR[$w]:-} ]]; then
        local IFS=',' ay0
        for ay0 in ${BC_WDR[$w]}; do
          [[ -n $ay0 ]] || continue
          if (( isowner )) && [[ -n ${BC_PUNI["$owbuf $ay0"]+x} ]]; then
            ROWDIRTY[$ay0]=1
          else
            _bc_flush_row "$w" "$ay0"
            local wxw=${BC_WX[$w]} www=${BC_WW[$w]} ax0
            for (( ax0 = wxw; ax0 < wxw + www; ax0++ )); do RC["$ay0 $ax0"]=1; done
          fi
        done
        unset IFS
      fi
    done
    # pass 2: per-cell dirty cells, skipping rows already emitted whole.
    for w in "${wins[@]}"; do
      if [[ -n ${BC_WD[$w]:-} ]]; then
        local IFS=',' k0
        for k0 in ${BC_WD[$w]}; do
          [[ -n $k0 ]] || continue
          [[ -n ${ROWDIRTY[${k0%% *}]+x} ]] && continue
          RC[$k0]=1
        done
        unset IFS
      fi
    done
    # the per-cell composite path samples every window's cells, so any row cache
    # that could be read under a dirty cell must be materialized first.
    if (( ! owner )); then
      local rkg bwg ayg
      for rkg in "${!BC_PUNI[@]}"; do
        bwg=${rkg% *}; ayg=${rkg##* }
        _bc_flush_row "${BC_BUF2W[$bwg]}" "$ayg"
      done
    fi
  fi
  if (( ${#RC[@]} == 0 && ${#ROWDIRTY[@]} == 0 )); then
    [[ -n $scroll_out ]] && printf '%s' "$scroll_out"
    return 0
  fi

  # emit whole rows owned by the top window straight from the row cache
  if (( ${#ROWDIRTY[@]} > 0 )); then
    local wxo=${BC_WX[$ownerw]} rk cs pen pa pp2
    for (( ay = bminy; ay <= bmaxy; ay++ )); do
      [[ -n ${ROWDIRTY[$ay]+x} ]] || continue
      rk="$topbuf $ay"; cs=${BC_CROW[$rk]}; pen=${BC_PUNI[$rk]}
      [[ ${BC_SCROW[$ay]:-} == "$cs" && ${BC_SPROW[$ay]:-} == "$pen" ]] && continue
      pa=${pen% *}; pp2=${pen#* }
      _bc_sgr "$pa" "$pp2"
      if [[ $last_sgr != "$BC_SGR" ]]; then out+="${BC_ESC}[${BC_SGR}m"; last_sgr=$BC_SGR; fi
      out+="${BC_ESC}[$(( ay + 1 ));$(( wxo + 1 ))H"
      out+="$cs"
      # keep the per-cell screen model in sync, otherwise a later per-cell
      # composite or scroll diffs against stale BC_S and paints mixed rows.
      local ww_o=${BC_WW[$ownerw]} i_o ch_o k_o
      for (( i_o = 0; i_o < ww_o; i_o++ )); do
        ch_o=${cs:i_o:1}; k_o="$ay $(( wxo + i_o ))"
        BC_S[$k_o]=$ch_o; BC_SA[$k_o]=$pa; BC_SP[$k_o]=$pp2
      done
      BC_SCROW[$ay]=$cs; BC_SPROW[$ay]=$pen
      lasty=-1
      emitted=$(( emitted + 1 ))
    done
  fi

  # Order the dirty cells row-major. For large regions a bbox scan beats
  # forking an external sort; for small ones sorting the few keys is cheaper.
  local -a keys
  if (( ${#RC[@]} > 0 )); then
   if (( ${#RC[@]} > 1500 )); then
    keys=()
    for (( ay = bminy; ay <= bmaxy; ay++ )); do
      for (( ax = bminx; ax <= bmaxx; ax++ )); do
        [[ -n ${RC["$ay $ax"]+x} ]] && keys+=("$ay $ax")
      done
    done
  else
    mapfile -t keys < <(printf '%s\n' "${!RC[@]}" | sort -k1,1n -k2,2n)
  fi
  [[ -n $topbuf ]] || _bc_owner_map
  local ow ob
  for k in "${keys[@]}"; do
    ay=${k% *} ax=${k#* }
    if [[ -n $topbuf ]]; then
      _BC_CC=${BC_C["$topbuf/$k"]:-$topbg}; _BC_CA=${BC_A["$topbuf/$k"]:-0}; _BC_CP=${BC_P["$topbuf/$k"]:-0}
    else
      # same result as _bc_composite_cell, via the cached owner map
      ow=${BC_OWN[$k]:-$BC_STDSCR}; ob=${BC_WBUF[$ow]}
      _BC_CC=${BC_C["$ob/$k"]:-${BC_WBG[$ow]}}; _BC_CA=${BC_A["$ob/$k"]:-0}; _BC_CP=${BC_P["$ob/$k"]:-0}
      if [[ -n ${BC_TINT[$k]:-} ]]; then
        ow=${BC_TINT[$k]}; ob=${BC_WBUF[$ow]}
        _BC_CA=${BC_A["$ob/$k"]:-${BC_WBGA[$ow]}}; _BC_CP=${BC_P["$ob/$k"]:-${BC_WBGP[$ow]}}
      fi
    fi
    ch=$_BC_CC; a=$_BC_CA; pp=$_BC_CP
    if [[ ${BC_S[$k]:-} == "$ch" && ${BC_SA[$k]:-0} == "$a" && ${BC_SP[$k]:-0} == "$pp" ]]; then
      lasty=-1
      continue
    fi
    _bc_sgr "$a" "$pp"
    if [[ $last_sgr != "$BC_SGR" ]]; then out+="${BC_ESC}[${BC_SGR}m"; last_sgr=$BC_SGR; fi
    if (( lasty != ay || lastx != ax - 1 )); then
      out+="${BC_ESC}[$(( ay + 1 ));$(( ax + 1 ))H"
    fi
    out+=$ch
    BC_S[$k]=$ch; BC_SA[$k]=$a; BC_SP[$k]=$pp
    unset "BC_SCROW[$ay]" "BC_SPROW[$ay]"
    lasty=$ay; lastx=$ax
    emitted=$(( emitted + 1 ))
   done
  fi

  [[ -n $out ]] && printf '%s' "$out"
  printf '%s[%d;%dH' "$BC_ESC" "$(( BC_WAY[$BC_STDSCR] + 1 ))" "$(( BC_WAX[$BC_STDSCR] + 1 ))"
  # clear the dirty marks for exactly the cells/rows we flushed
  for w in "${wins[@]}"; do
    if [[ -n ${BC_WD[$w]:-} ]]; then
      local IFS=','
      for k in ${BC_WD[$w]}; do [[ -n $k ]] && unset "BC_MK[$w/$k]"; done
      unset IFS
      unset "BC_WD[$w]"
    fi
    if [[ -n ${BC_WDR[$w]:-} ]]; then
      local IFS=','
      for k in ${BC_WDR[$w]}; do [[ -n $k ]] && unset "BC_MKR[$w/$k]"; done
      unset IFS
      unset "BC_WDR[$w]"
    fi
  done
  BC_DELRECTS=""
  if [[ -n ${BC_TEST_DIR:-} ]]; then
    BC_TEST_SEQ=$(( BC_TEST_SEQ + 1 ))
    printf '%s\n' "$BC_TEST_SEQ" > "$BC_TEST_DIR/seq"
  fi
  return 0
}

# --------------------------------------------------------------- panels
# Panels attach independent windows to a bottom -> top stack. doupdate()
# composites stdscr then the visible panels in stack order, so the topmost
# visible panel wins in overlapping regions. User pointers are opaque
# strings the caller interprets.
new_panel() { # win
  local p=$BC_PN
  BC_PN=$(( BC_PN + 1 ))
  BC_PWIN[$p]=$1
  BC_PHID[$p]=0
  BC_PUSR[$p]=""
  BC_PSTACK+=("$p")
  bc_panel=$p
  return 0
}

del_panel() { # p
  local p=$1 z
  local -a ns=()
  for z in "${BC_PSTACK[@]}"; do
    [[ $z != "$p" ]] && ns+=("$z")
  done
  BC_PSTACK=("${ns[@]}")
  unset "BC_PWIN[$p]" "BC_PHID[$p]" "BC_PUSR[$p]" "BC_PTINT[$p]"
  return 0
}

panel_window() { # p -> bc_panel_win
  bc_panel_win=${BC_PWIN[$1]}
  return 0
}

set_panel_userptr() { # p ptr
  BC_PUSR[$1]=$2
  return 0
}

panel_userptr() { # p -> bc_panel_user
  bc_panel_user=${BC_PUSR[$1]}
  return 0
}

# Mark a window's rectangle as changed so the next composite re-renders it.
# Panel stacking changes (move/hide/show/reorder) do not dirty the individual
# cells whose winner changes, so the affected region must be re-emitted.
_bc_win_rect_dirty() { # w
  [[ -n ${BC_WY[$1]:-} ]] && BC_DELRECTS+="|${BC_WY[$1]} ${BC_WX[$1]} ${BC_WH[$1]} ${BC_WW[$1]}"
  return 0
}

# The region that can change when the stack is reordered is the union of every
# visible panel's rectangle (the topmost winner can differ in any overlap).
_bc_stack_dirty() {
  local z w
  for z in "${BC_PSTACK[@]}"; do
    [[ ${BC_PHID[$z]} == 1 ]] && continue
    w=${BC_PWIN[$z]}
    _bc_win_rect_dirty "$w"
  done
  return 0
}

top_panel() { # p
  local p=$1 z
  local -a ns=()
  for z in "${BC_PSTACK[@]}"; do
    [[ $z != "$p" ]] && ns+=("$z")
  done
  ns+=("$p")
  BC_PSTACK=("${ns[@]}")
  _bc_stack_dirty
  return 0
}

bottom_panel() { # p
  local p=$1 z
  local -a ns=("$p")
  for z in "${BC_PSTACK[@]}"; do
    [[ $z != "$p" ]] && ns+=("$z")
  done
  BC_PSTACK=("${ns[@]}")
  _bc_stack_dirty
  return 0
}

hide_panel() { # p
  local w=${BC_PWIN[$1]}
  BC_PHID[$1]=1
  _bc_win_rect_dirty "$w"
  return 0
}

show_panel() { # p
  local w=${BC_PWIN[$1]}
  BC_PHID[$1]=0
  _bc_win_rect_dirty "$w"
  return 0
}

move_panel() { # p ny nx
  local p=$1 w=${BC_PWIN[$1]}
  local ny=$2 nx=$3
  local oy=${BC_WY[$w]} ox=${BC_WX[$w]}
  (( ny == oy && nx == ox )) && return 0
  local buf=${BC_WBUF[$w]}
  local h=${BC_WH[$w]} ww=${BC_WW[$w]}
  local y x k oyk kk
  declare -A sc=() sa=() sp=()
  for (( y = 0; y < h; y++ )); do
    for (( x = 0; x < ww; x++ )); do
      oyk="$(( oy + y )) $(( ox + x ))"
      if [[ -n ${BC_C["$buf/$oyk"]:-} ]]; then
        k="$(( ny + y )) $(( nx + x ))"
        sc[$k]=${BC_C["$buf/$oyk"]}
        sa[$k]=${BC_A["$buf/$oyk"]}
        sp[$k]=${BC_P["$buf/$oyk"]}
        # drop the old-position cell so the window leaves no ghost behind
        unset "BC_C[$buf/$oyk]" "BC_A[$buf/$oyk]" "BC_P[$buf/$oyk]"
      fi
    done
  done
  # Remember the vacated old rectangle so the next composite re-renders it and
  # reveals what lies underneath (otherwise the window leaves a ghost behind).
  BC_DELRECTS+="|$oy $ox $h $ww"
  _bc_clear_marks "$w"
  unset "BC_WD[$w]"
  BC_WY[$w]=$ny
  BC_WX[$w]=$nx
  for kk in "${!sc[@]}"; do
    _bc_cell "$w" "${kk%% *}" "${kk##* }" "${sc[$kk]}" "${sa[$kk]}" "${sp[$kk]}"
  done
  return 0
}

replace_panel() { # p win
  local p=$1 old=${BC_PWIN[$1]}
  if [[ -n ${BC_WY[$old]:-} ]]; then
    BC_DELRECTS+="|${BC_WY[$old]} ${BC_WX[$old]} ${BC_WH[$old]} ${BC_WW[$old]}"
  fi
  BC_PWIN[$p]=$2
  # The new window's whole rectangle must be recomposited, not just the cells
  # it explicitly drew, so it covers whatever lower windows showed through.
  _bc_win_rect_dirty "$2"
  return 0
}

update_panels() { return 0; }

# ---------------------------------------------------- screen save / restore
# Dump format: one line per row, cells separated by US (\x1f), each cell is
# "attr pair char" (char last so it may itself be a space).
# scr_init loads the saved image into the library's notion of what is already
# on the physical screen (the curscr model, BC_S) WITHOUT emitting anything.
# It must not truncate SCR_FILE: ncurses scr_init only reads it.
scr_init() {
  local y=-1 x rest cell a p ch line
  [[ -f $SCR_FILE ]] || return 1
  while IFS= read -r line; do
    y=$(( y + 1 ))
    x=0
    local -a cells
    IFS=$'\x1f' read -r -a cells <<< "$line"
    for cell in "${cells[@]}"; do
      a=${cell%% *}; rest=${cell#* }; p=${rest%% *}; ch=${rest#* }
      [[ -z $ch ]] && ch=' '
      BC_S["$y $x"]=$ch
      BC_SA["$y $x"]=$a
      BC_SP["$y $x"]=$p
      x=$(( x + 1 ))
    done
  done < "$SCR_FILE"
  return 0
}
scr_init_sp() { scr_init "$@"; }

# scr_dump writes the window's virtual buffer (newscr), not the last-shown
# screen model, matching ncurses putwin(newscr).
scr_dump() {
  local y x k line cell buf=${BC_WBUF[$BC_STDSCR]}
  _bc_flush_win "$BC_STDSCR"
  : > "$SCR_FILE" || return 1
  for (( y = 0; y < LINES; y++ )); do
    line=""
    for (( x = 0; x < COLS; x++ )); do
      k="$buf/$y $x"
      cell="${BC_A[$k]:-0} ${BC_P[$k]:-0} ${BC_C[$k]:- }"
      line="${line:+$line$'\x1f'}$cell"
    done
    printf '%s\n' "$line" >> "$SCR_FILE"
  done
  return 0
}

# scr_restore replaces the virtual buffer (newscr) with the saved image and
# leaves it dirty; the next refresh emits the difference against curscr.
scr_restore() {
  local y=-1 x rest cell a p ch line
  [[ -f $SCR_FILE ]] || return 1
  while IFS= read -r line; do
    y=$(( y + 1 ))
    x=0
    local -a cells
    IFS=$'\x1f' read -r -a cells <<< "$line"
    for cell in "${cells[@]}"; do
      a=${cell%% *}; rest=${cell#* }; p=${rest%% *}; ch=${rest#* }
      [[ -z $ch ]] && ch=' '
      _bc_cell "$BC_STDSCR" "$y" "$x" "$ch" "$a" "$p"
      x=$(( x + 1 ))
    done
  done < "$SCR_FILE"
  return 0
}

# scr_set = scr_init (curscr = image) then newscr = curscr. Both the curscr
# model and the virtual buffer become the image, with nothing emitted, so the
# next refresh diffs against the image and can leave stale physical cells.
scr_set() {
  local y=-1 x rest cell a p ch line
  [[ -f $SCR_FILE ]] || return 1
  while IFS= read -r line; do
    y=$(( y + 1 ))
    x=0
    local -a cells
    IFS=$'\x1f' read -r -a cells <<< "$line"
    for cell in "${cells[@]}"; do
      a=${cell%% *}; rest=${cell#* }; p=${rest%% *}; ch=${rest#* }
      [[ -z $ch ]] && ch=' '
      _bc_cell "$BC_STDSCR" "$y" "$x" "$ch" "$a" "$p"
      BC_S["$y $x"]=$ch
      BC_SA["$y $x"]=$a
      BC_SP["$y $x"]=$p
      x=$(( x + 1 ))
    done
  done < "$SCR_FILE"
  return 0
}

scr_restore_sp() { scr_restore "$@"; }
scr_set_sp() { scr_set "$@"; }

# Full alternate-screen context switching is not supported in bash; report ERR.
use_screen() { return 1; }

# ------------------------------------------------------------------ input
nodelay() { # win nodelay
  local w=${1:-$BC_CURR}
  if (( ${2:-1} )); then
    BC_WDELAY[$w]=1
    BC_WTIMEOUT[$w]=0
  else
    BC_WDELAY[$w]=0
    BC_WTIMEOUT[$w]=-1
  fi
  return 0
}

halfdelay() { # tenths
  local t=${1:-10}
  [[ $t =~ ^[0-9]+$ ]] || t=10
  BC_HALFTENTHS=$t
  local w
  for w in "${!BC_WY[@]}"; do
    BC_WTIMEOUT[$w]=$(( t * 100 ))
    BC_WDELAY[$w]=0
  done
  return 0
}

wtimeout() { # win delay
  local w=${1:-$BC_CURR} delay=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  BC_WTIMEOUT[$w]=$delay
  if (( delay < 0 )); then
    BC_WDELAY[$w]=0
  elif (( delay == 0 )); then
    BC_WDELAY[$w]=1
  else
    BC_WDELAY[$w]=0
  fi
  return 0
}

timeout() { wtimeout "$BC_STDSCR" "$@"; }

notimeout() { # win bf
  local w=${1:-$BC_CURR} bf=${2:-0}
  [[ -n ${BC_WY[$w]:-} ]] || return 1
  if [[ $bf == 0 || $bf == false ]]; then
    BC_WNOTIMEOUT[$w]=0
  else
    BC_WNOTIMEOUT[$w]=1
  fi
  return 0
}

flushinp() {
  local c
  while IFS= read -rsn1 -t 0.001 c; do :; done
  return 0
}

ungetch() { # $1 ch to push back
  local k=${1:-$key}
  if [[ $k =~ ^[0-9]+$ ]] && (( k > 255 )); then
    BC_PENDING_KEY=$k
  else
    BC_PENDING_IN="$k$BC_PENDING_IN"
  fi
  return 0
}

wgetch() { # win -> sets global key; 0 if read, 1 if ERR
  local w=${1:-$BC_CURR}
  local c s="" t rc
  wrefresh "$w"
  while :; do
    if (( BC_WINCH )); then
      BC_WINCH=0
      key=$KEY_RESIZE
      return 0
    fi
    if [[ -n $BC_PENDING_KEY ]]; then
      key=$BC_PENDING_KEY
      BC_PENDING_KEY=""
      return 0
    fi
    if [[ -n $BC_PENDING_IN ]]; then
      key=${BC_PENDING_IN:0:1}
      BC_PENDING_IN=${BC_PENDING_IN:1}
      return 0
    fi
    local to=0.05
    if (( BC_WDELAY[$w] )); then
      to=0.001
    elif (( ${BC_WTIMEOUT[$w]:-0} > 0 )); then
      printf -v to '%d.%03d' $(( BC_WTIMEOUT[$w] / 1000 )) $(( BC_WTIMEOUT[$w] % 1000 ))
    fi
    IFS= read -rsn1 -t "$to" c; rc=$?
    if (( BC_WINCH )); then
      BC_WINCH=0
      key=$KEY_RESIZE
      return 0
    fi
    if (( rc > 128 )); then
      # A timed-out read (rc > 128): nothing was read, so keep polling. A
      # nodelay window or a positive wtimeout reports ERR instead of looping.
      if (( BC_WDELAY[$w] || ${BC_WTIMEOUT[$w]:-0} > 0 )); then
        return 1
      fi
      continue
    fi
    if (( rc )); then
      return 1
    fi
    if [[ -z $c ]]; then
      # bash's read treats CR/LF as line terminators and strips them, so a
      # successful empty read means a CR/LF byte arrived -> report ENTER.
      key=$'\r'
      return 0
    fi
    if [[ $c == $'\x1b' ]]; then
      # Accumulate the full escape sequence, then match it against the
      # terminfo key table (mouse reports are special-cased first).
      printf -v t '%d.%03d' $(( ESCDELAY / 1000 )) $(( ESCDELAY % 1000 ))
      local seq=$'\x1b' s2
      while :; do
        s2=""
        if ! IFS= read -rsn1 -t "$t" s2; then
          if [[ $seq == $'\x1b' ]]; then
            key=$'\x1b'
            return 0
          fi
          _bc_ti_prefix "$seq" && continue
          key=$'\x1b'
          BC_PENDING_IN+="${seq:1}"
          return 0
        fi
        seq+=$s2
        if (( BC_MOUSE_MASK )) && [[ $seq == $'\x1b[<' ]]; then
          if _bc_mouse_read_sgr; then
            _bc_mouse_decode_sgr
            _bc_mouse_run
            if (( ${#BC_MEVENTS[@]} )); then
              key=$KEY_MOUSE
              read -r BC_ME_ID BC_ME_X BC_ME_Y BC_ME_BSTATE <<< "${BC_MEVENTS[0]}"
              return 0
            fi
            seq=""
            continue
          fi
        fi
        if (( BC_MOUSE_MASK )) && [[ $seq == $'\x1b[M' ]]; then
          if _bc_mouse_read_x10; then
            _bc_mouse_decode_x10
            _bc_mouse_run
            if (( ${#BC_MEVENTS[@]} )); then
              key=$KEY_MOUSE
              read -r BC_ME_ID BC_ME_X BC_ME_Y BC_ME_BSTATE <<< "${BC_MEVENTS[0]}"
              return 0
            fi
            seq=""
            continue
          fi
        fi
        if _bc_ti_lookup "$seq"; then
          key=$_BC_TI_KEY
          return 0
        fi
        if ! _bc_ti_prefix "$seq"; then
          key=$'\x1b'
          BC_PENDING_IN+="${seq:1}"
          return 0
        fi
      done
    fi
    key=$c
    return 0
  done
}

getch() { wgetch "$BC_STDSCR"; }
getkey() { wgetch "$BC_STDSCR"; }

wechochar() { # win ch [a p]
  local w=${1:-$BC_CURR}
  waddch "$w" "${2:- }" ${3:+"$3"} ${4:+"$4"} && wrefresh "$w"
}

echochar() { wechochar "$BC_STDSCR" "$@"; }

wadd_wch() { # win wch [a p]
  local w=${1:-$BC_CURR}
  waddch "$w" "${2:0:1}" ${3:+"$3"} ${4:+"$4"}
}

add_wch() { wadd_wch "$BC_CURR" "$@"; }

mvwadd_wch() { # win y x wch [a p]
  wmove "$1" "$2" "$3" && wadd_wch "$1" "${4:- }" ${5:+"$5"} ${6:+"$6"}
}

mvadd_wch() { mvwadd_wch "$BC_STDSCR" "$@"; }

wadd_wchnstr() { # win wstr n
  waddnstr "${1:-$BC_CURR}" "$2" "$3"
}

add_wchnstr() { wadd_wchnstr "$BC_CURR" "$@"; }

mvwadd_wchnstr() { # win y x wstr n
  wmove "$1" "$2" "$3" && wadd_wchnstr "$1" "$4" "$5"
}

mvadd_wchnstr() { mvwadd_wchnstr "$BC_STDSCR" "$@"; }

wadd_wchstr() { # win wstr
  waddstr "${1:-$BC_CURR}" "$2"
}

add_wchstr() { wadd_wchstr "$BC_CURR" "$@"; }

mvwadd_wchstr() { # win y x wstr
  wmove "$1" "$2" "$3" && wadd_wchstr "$1" "$4"
}

mvadd_wchstr() { mvwadd_wchstr "$BC_STDSCR" "$@"; }

wecho_wchar() { # win wch [a p]
  local w=${1:-$BC_CURR}
  wadd_wch "$w" "${2:- }" ${3:+"$3"} ${4:+"$4"} && wrefresh "$w"
}

echo_wchar() { wecho_wchar "$BC_STDSCR" "$@"; }

wget_wch() { # win -> wch wcha wchp; 0 ok, 1 ERR
  local w=${1:-$BC_CURR}
  if wgetch "$w"; then
    wch=$key
    wcha=0
    wchp=0
    return 0
  fi
  return 1
}

get_wch() { wget_wch "$BC_STDSCR"; }

mvwget_wch() { # win y x -> wch wcha wchp
  wmove "$1" "$2" "$3" && wget_wch "$1"
}

mvget_wch() { mvwget_wch "$BC_STDSCR" "$@"; }

win_wch() { # win -> wch wcha wchp
  winch "${1:-$BC_CURR}"
}

in_wch() { win_wch "$BC_STDSCR"; }

mvwin_wch() { # win y x -> wch wcha wchp
  mvwinch "$1" "$2" "$3"
}

mvin_wch() { mvwin_wch "$BC_STDSCR" "$@"; }

win_wchnstr() { # win n -> bc_chstr bc_chattr bc_chpair bc_str
  inchnstr "${1:-$BC_CURR}" "$2"
}

in_wchnstr() { win_wchnstr "$BC_STDSCR" "$@"; }

mvwin_wchnstr() { # win y x n -> bc_chstr bc_chattr bc_chpair bc_str
  mvwinchnstr "$1" "$2" "$3" "$4"
}

mvin_wchnstr() { mvwin_wchnstr "$BC_STDSCR" "$@"; }

win_wchstr() { # win -> bc_chstr bc_chattr bc_chpair bc_str
  inchstr "${1:-$BC_CURR}"
}

in_wchstr() { win_wchstr "$BC_STDSCR"; }

mvwin_wchstr() { # win y x -> bc_chstr bc_chattr bc_chpair bc_str
  mvwinchstr "$1" "$2" "$3"
}

mvin_wchstr() { mvwin_wchstr "$BC_STDSCR" "$@"; }

wins_wch() { # win wch [a p]
  winsch "${1:-$BC_CURR}" "${2:0:1}" ${3:+"$3"} ${4:+"$4"}
}

ins_wch() { wins_wch "$BC_CURR" "$@"; }

mvwins_wch() { # win y x wch [a p]
  wmove "$1" "$2" "$3" && wins_wch "$1" "${4:- }" ${5:+"$5"} ${6:+"$6"}
}

mvins_wch() { mvwins_wch "$BC_STDSCR" "$@"; }

winsn_wch() { # win wstr n
  winsnstr "${1:-$BC_CURR}" "$3" "$2"
}

insn_wch() { winsn_wch "$BC_CURR" "$@"; }

mvwinsn_wch() { # win y x wstr n
  wmove "$1" "$2" "$3" && winsn_wch "$1" "$4" "$5"
}

mvinsn_wch() { mvwinsn_wch "$BC_STDSCR" "$@"; }

wins_wchstr() { # win wstr
  winsstr "${1:-$BC_CURR}" "$2"
}

ins_wchstr() { wins_wchstr "$BC_CURR" "$@"; }

mvwins_wchstr() { # win y x wstr
  wmove "$1" "$2" "$3" && wins_wchstr "$1" "$4"
}

mvins_wchstr() { mvwins_wchstr "$BC_STDSCR" "$@"; }

wins_wchnstr() { # win wstr n
  winsnstr "${1:-$BC_CURR}" "$3" "$2"
}

ins_wchnstr() { wins_wchnstr "$BC_CURR" "$@"; }

mvwins_wchnstr() { # win y x wstr n
  wmove "$1" "$2" "$3" && wins_wchnstr "$1" "$4" "$5"
}

mvins_wchnstr() { mvwins_wchnstr "$BC_STDSCR" "$@"; }

unget_wch() { # wch
  ungetch "${1:-$key}"
}

napms() { # ms
  local ms=${1:-0}
  if (( ms > 0 )); then
    local t
    printf -v t '%d.%03d' $(( ms / 1000 )) $(( ms % 1000 ))
    sleep "$t" >/dev/null 2>&1 || true
  fi
  return 0
}

mcprint() { # str
  return 1
}

setcchar() { # cchar wch attrs color_pair ext -> bc_cchar bc_cchar_a bc_cchar_p
  local cchar=$1 wch=$2 attrs=${3:-0} cp=${4:-0} ext=${5:-}
  bc_cchar="${wch:0:1}"
  bc_cchar_a=$attrs
  bc_cchar_p=$cp
  bc_cchar_ext=$ext
  return 0
}

getcchar() { # cchar -> wch wcha wchp
  local cchar=$1
  wch=${cchar:0:1}
  wcha=${bc_cchar_a:-0}
  wchp=${bc_cchar_p:-0}
  return 0
}

wcwidth() { # wch
  local c=${1:0:1} n
  [[ -z $c ]] && return 0
  printf -v n '%d' "'$c"
  if (( n >= 0 && n < 32 )) || (( n >= 127 && n < 160 )); then
    return 0
  fi
  return 1
}

# read a line into the global bc_str, echoing each char to the window like
# ncurses wgetstr (the terminal is raw/-echo, so we echo into the window)
wgetstr() { # win [n]
  local w=${1:-$BC_CURR} n=${2:-0}
  local c cy cx
  bc_str=""
  while :; do
    if ! wgetch "$w"; then
      break
    fi
    c=$key
    case $c in
      $'\n') break ;;
      $'\r') break ;;
      $'\x1b') return 1 ;;
      $'\x7f' | $'\x08')
        if (( ${#bc_str} > 0 )); then
          bc_str=${bc_str:0:-1}
          cy=${BC_WAY[$w]}; cx=${BC_WAX[$w]}
          if (( cx > 0 )); then
            cx=$(( cx - 1 ))
            _bc_clear_cell "$w" "$(( BC_WY[$w] + cy ))" "$(( BC_WX[$w] + cx ))"
          fi
          BC_WAX[$w]=$cx
        fi
        ;;
      *)
        if (( n > 0 && ${#bc_str} >= n )); then
          ungetch "$c"
          break
        fi
        bc_str+=$c
        waddch "$w" "$c"
        ;;
    esac
  done
  return 0
}

wgetnstr() { # win n
  wgetstr "${1:-$BC_CURR}" "${2:-0}"
}

mvwgetstr() { # win y x
  wmove "$1" "$2" "$3" && wgetstr "$1"
}

mvwgetnstr() { # win y x n
  wmove "$1" "$2" "$3" && wgetnstr "$1" "$4"
}

getstr() { wgetstr "$BC_STDSCR"; }
getnstr() { wgetnstr "$BC_STDSCR" "$@"; }
mvgetnstr() { mvwgetnstr "$BC_STDSCR" "$@"; }
mvgetstr() { mvwgetstr "$BC_STDSCR" "$@"; }

mvwgetch() { # win y x
  wmove "$1" "$2" "$3" && wgetch "$1"
}
mvgetch() { mvwgetch "$BC_STDSCR" "$@"; }

_bc_scan_range_match() { # range neg ch -> 0 if ch matches
  local range=$1 neg=$2 ch=$3
  local n=${#range} i=0 in=0 a b ca cb cc
  while (( i < n )); do
    a=${range:i:1}
    if (( i + 2 < n )) && [[ ${range:i+1:1} == '-' ]]; then
      b=${range:i+2:1}
      printf -v ca '%d' "'$a"
      printf -v cb '%d' "'$b"
      printf -v cc '%d' "'$ch"
      if (( ca <= cc && cc <= cb )); then
        in=1
        break
      fi
      i=$(( i + 3 ))
    else
      if [[ $a == "$ch" ]]; then
        in=1
        break
      fi
      i=$(( i + 1 ))
    fi
  done
  if (( neg )); then
    (( ! in ))
  else
    (( in ))
  fi
}

_bc_scanw_int() { # conv str pos limit -> bc_scanw_val bc_scanw_pos
  local conv=$1 str=$2 pos=$3 limit=$4
  local start=$pos sign='' digits=''
  if [[ ${str:pos:1} == + || ${str:pos:1} == - ]]; then
    sign=${str:pos:1}
    ((pos++))
  fi
  case $conv in
    x|X)
      if [[ ${str:pos:2} == 0x || ${str:pos:2} == 0X ]]; then
        digits=${str:pos:2}
        pos=$(( pos + 2 ))
      fi
      while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9a-fA-F] ]]; do
        digits+=${str:pos:1}
        ((pos++))
      done
      if [[ -z $digits || $digits == 0[xX] ]]; then
        bc_scanw_pos=$start
        return 1
      fi
      ;;
    o)
      while (( pos < limit )) && [[ ${str:pos:1} =~ [0-7] ]]; do
        digits+=${str:pos:1}
        ((pos++))
      done
      if [[ -z $digits ]]; then
        bc_scanw_pos=$start
        return 1
      fi
      ;;
    i)
      if [[ ${str:pos:2} == 0x || ${str:pos:2} == 0X ]]; then
        digits=${str:pos:2}
        pos=$(( pos + 2 ))
        while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9a-fA-F] ]]; do
          digits+=${str:pos:1}
          ((pos++))
        done
        if [[ -z $digits || $digits == 0[xX] ]]; then
          bc_scanw_pos=$start
          return 1
        fi
      elif [[ ${str:pos:1} == 0 ]]; then
        digits=0
        ((pos++))
        while (( pos < limit )) && [[ ${str:pos:1} =~ [0-7] ]]; do
          digits+=${str:pos:1}
          ((pos++))
        done
      else
        while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9] ]]; do
          digits+=${str:pos:1}
          ((pos++))
        done
        if [[ -z $digits ]]; then
          bc_scanw_pos=$start
          return 1
        fi
      fi
      ;;
    *)
      while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9] ]]; do
        digits+=${str:pos:1}
        ((pos++))
      done
      if [[ -z $digits ]]; then
        bc_scanw_pos=$start
        return 1
      fi
      ;;
  esac
  bc_scanw_val=$sign$digits
  bc_scanw_pos=$pos
  return 0
}

_bc_scanw_float() { # str pos limit -> bc_scanw_val bc_scanw_pos
  local str=$1 pos=$2 limit=$3
  local start=$pos sign='' digits='' exp_digits=''
  if [[ ${str:pos:1} == + || ${str:pos:1} == - ]]; then
    sign=${str:pos:1}
    ((pos++))
  fi
  while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9] ]]; do
    digits+=${str:pos:1}
    ((pos++))
  done
  if [[ ${str:pos:1} == . ]]; then
    ((pos++))
    while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9] ]]; do
      digits+=${str:pos:1}
      ((pos++))
    done
  fi
  if [[ ${str:pos:1} == e || ${str:pos:1} == E ]]; then
    ((pos++))
    if [[ ${str:pos:1} == + || ${str:pos:1} == - ]]; then
      ((pos++))
    fi
    while (( pos < limit )) && [[ ${str:pos:1} =~ [0-9] ]]; do
      exp_digits+=${str:pos:1}
      ((pos++))
    done
    if [[ -z $exp_digits ]]; then
      bc_scanw_pos=$start
      return 1
    fi
  fi
  if [[ -z $digits ]]; then
    bc_scanw_pos=$start
    return 1
  fi
  bc_scanw_val=$sign${str:start:pos-start}
  bc_scanw_pos=$pos
  return 0
}

_bc_scanw() { # fmt var... -> assigns vars, bc_scanw_count, returns count
  local _bc_fmt=$1
  shift
  local _bc_str=$bc_str
  local _bc_slen=${#_bc_str} _bc_pos=0 _bc_assigned=0 _bc_argi=1
  local _bc_i=0 _bc_flen=${#_bc_fmt} _bc_c _bc_conv _bc_width _bc_suppress _bc_limit _bc_val _bc_sign _bc_num _bc_name _bc_range _bc_neg
  while (( _bc_i < _bc_flen )); do
    _bc_c=${_bc_fmt:_bc_i:1}
    if [[ $_bc_c != '%' ]]; then
      if [[ $_bc_c =~ [[:space:]] ]]; then
        while (( _bc_pos < _bc_slen )) && [[ ${_bc_str:_bc_pos:1} =~ [[:space:]] ]]; do
          ((_bc_pos++))
        done
      else
        if (( _bc_pos >= _bc_slen )) || [[ ${_bc_str:_bc_pos:1} != "$_bc_c" ]]; then
          break
        fi
        ((_bc_pos++))
      fi
      ((_bc_i++))
      continue
    fi
    ((_bc_i++))
    _bc_suppress=0
    if [[ ${_bc_fmt:_bc_i:1} == '*' ]]; then
      _bc_suppress=1
      ((_bc_i++))
    fi
    _bc_width=''
    while [[ ${_bc_fmt:_bc_i:1} =~ [0-9] ]]; do
      _bc_width+=${_bc_fmt:_bc_i:1}
      ((_bc_i++))
    done
    while [[ ${_bc_fmt:_bc_i:1} =~ [hlLjzt] ]]; do
      ((_bc_i++))
    done
    _bc_conv=${_bc_fmt:_bc_i:1}
    ((_bc_i++))
    if [[ -z $_bc_conv ]]; then
      break
    fi
    if [[ $_bc_conv == '%' ]]; then
      if (( _bc_pos >= _bc_slen )) || [[ ${_bc_str:_bc_pos:1} != '%' ]]; then
        break
      fi
      ((_bc_pos++))
      continue
    fi
    if [[ $_bc_conv != c && $_bc_conv != '[' && $_bc_conv != n ]]; then
      while (( _bc_pos < _bc_slen )) && [[ ${_bc_str:_bc_pos:1} =~ [[:space:]] ]]; do
        ((_bc_pos++))
      done
    fi
    if [[ $_bc_conv == c ]]; then
      if [[ -n $_bc_width ]]; then
        _bc_limit=$(( _bc_pos + _bc_width ))
      else
        _bc_limit=$(( _bc_pos + 1 ))
      fi
    elif [[ -n $_bc_width ]]; then
      _bc_limit=$(( _bc_pos + _bc_width ))
    else
      _bc_limit=$_bc_slen
    fi
    if (( _bc_limit > _bc_slen )); then
      _bc_limit=$_bc_slen
    fi
    _bc_val=''
    case $_bc_conv in
      c)
        if (( _bc_pos >= _bc_limit )); then
          break
        fi
        _bc_val=${_bc_str:_bc_pos:_bc_limit-_bc_pos}
        _bc_pos=$_bc_limit
        ;;
      s)
        while (( _bc_pos < _bc_limit )) && [[ ${_bc_str:_bc_pos:1} != [[:space:]] ]]; do
          _bc_val+=${_bc_str:_bc_pos:1}
          ((_bc_pos++))
        done
        if [[ -z $_bc_val ]]; then
          break
        fi
        ;;
      d|i|u|x|X|o)
        if ! _bc_scanw_int "$_bc_conv" "$_bc_str" "$_bc_pos" "$_bc_limit"; then
          break
        fi
        _bc_val=$bc_scanw_val
        _bc_pos=$bc_scanw_pos
        ;;
      f|e|E|g|G)
        if ! _bc_scanw_float "$_bc_str" "$_bc_pos" "$_bc_limit"; then
          break
        fi
        _bc_val=$bc_scanw_val
        _bc_pos=$bc_scanw_pos
        ;;
      n)
        _bc_val=$_bc_pos
        ;;
      '[')
        _bc_range=''
        _bc_neg=0
        if [[ ${_bc_fmt:_bc_i:1} == '^' ]]; then
          _bc_neg=1
          ((_bc_i++))
        fi
        if [[ ${_bc_fmt:_bc_i:1} == ']' ]]; then
          _bc_range+=']'
          ((_bc_i++))
        fi
        while (( _bc_i < _bc_flen )) && [[ ${_bc_fmt:_bc_i:1} != ']' ]]; do
          _bc_range+=${_bc_fmt:_bc_i:1}
          ((_bc_i++))
        done
        if (( _bc_i < _bc_flen )); then
          ((_bc_i++))
        fi
        while (( _bc_pos < _bc_limit )); do
          _bc_c=${_bc_str:_bc_pos:1}
          if _bc_scan_range_match "$_bc_range" "$_bc_neg" "$_bc_c"; then
            _bc_val+=$_bc_c
            ((_bc_pos++))
          else
            break
          fi
        done
        if [[ -z $_bc_val ]]; then
          break
        fi
        ;;
      *)
        break
        ;;
    esac
    if (( _bc_suppress )); then
      continue
    fi
    if (( _bc_argi > $# )); then
      break
    fi
    _bc_name=${!_bc_argi}
    case $_bc_conv in
      d|u)
        if [[ $_bc_val == +* ]]; then
          _bc_num=$(( 10#${_bc_val#+} ))
        elif [[ $_bc_val == -* ]]; then
          _bc_num=$(( -10#${_bc_val#-} ))
        else
          _bc_num=$(( 10#$_bc_val ))
        fi
        printf -v "$_bc_name" '%d' "$_bc_num"
        ;;
      i)
        printf -v "$_bc_name" '%d' "$(( _bc_val ))"
        ;;
      x|X)
        if [[ $_bc_val == 0[xX]* || $_bc_val == +0[xX]* || $_bc_val == -0[xX]* ]]; then
          printf -v "$_bc_name" '%d' "$(( _bc_val ))"
        elif [[ $_bc_val == +* ]]; then
          printf -v "$_bc_name" '%d' "$(( 16#${_bc_val#+} ))"
        elif [[ $_bc_val == -* ]]; then
          printf -v "$_bc_name" '%d' "$(( -16#${_bc_val#-} ))"
        else
          printf -v "$_bc_name" '%d' "$(( 16#$_bc_val ))"
        fi
        ;;
      o)
        if [[ $_bc_val == +* ]]; then
          _bc_num=$(( 8#${_bc_val#+} ))
        elif [[ $_bc_val == -* ]]; then
          _bc_num=$(( -8#${_bc_val#-} ))
        else
          _bc_num=$(( 8#$_bc_val ))
        fi
        printf -v "$_bc_name" '%d' "$_bc_num"
        ;;
      *)
        printf -v "$_bc_name" '%s' "$_bc_val"
        ;;
    esac
    ((_bc_argi++))
    if [[ $_bc_conv != n ]]; then
      ((_bc_assigned++))
    fi
  done
  bc_scanw_count=$_bc_assigned
  if (( _bc_assigned > 255 )); then
    return 255
  fi
  return "$_bc_assigned"
}

wscanw() { # win fmt var...
  local w=${1:-$BC_CURR}
  shift
  if ! wgetnstr "$w" 1023; then
    bc_scanw_count=-1
    return 1
  fi
  _bc_scanw "$@"
}

scanw() { wscanw "$BC_STDSCR" "$@"; }

mvwscanw() { # win y x fmt var...
  if ! wmove "$1" "$2" "$3"; then
    bc_scanw_count=-1
    return 1
  fi
  wscanw "$1" "${@:4}"
}

mvscanw() { mvwscanw "$BC_STDSCR" "$@"; }

vwscanw() { wscanw "$@"; }
vw_scanw() { wscanw "$@"; }

# --------------------------------------------------------- attrs / pairs
wattrset() { # win a p
  local w=${1:-$BC_CURR}
  BC_WCURA[$w]=$2
  BC_WCURP[$w]=${3:-0}
  return 0
}

attrset() { wattrset "$BC_STDSCR" "$@"; }

wattron() { # win a
  local w=${1:-$BC_CURR}
  BC_WCURA[$w]=$(( BC_WCURA[$w] | $2 ))
  return 0
}

attron() { wattron "$BC_STDSCR" "$1"; }

wattroff() { # win a
  local w=${1:-$BC_CURR}
  BC_WCURA[$w]=$(( BC_WCURA[$w] & ~$2 ))
  return 0
}

attroff() { wattroff "$BC_STDSCR" "$1"; }

wattr_get() { # win -> BC_AG BC_AP
  local w=${1:-$BC_CURR}
  BC_AG=${BC_WCURA[$w]}
  BC_AP=${BC_WCURP[$w]}
  return 0
}

wattr_set() { # win a p
  local w=${1:-$BC_CURR}
  BC_WCURA[$w]=${2:-0}
  BC_WCURP[$w]=${3:-0}
  return 0
}

wattr_on() { # win a
  local w=${1:-$BC_CURR}
  BC_WCURA[$w]=$(( BC_WCURA[$w] | ${2:-0} ))
  return 0
}

wattr_off() { # win a
  local w=${1:-$BC_CURR}
  BC_WCURA[$w]=$(( BC_WCURA[$w] & ~${2:-0} ))
  return 0
}

attr_get() { wattr_get "$BC_STDSCR"; }
attr_set() { wattr_set "$BC_STDSCR" "$@"; }
attr_on() { wattr_on "$BC_STDSCR" "$@"; }
attr_off() { wattr_off "$BC_STDSCR" "$@"; }

standend() { wattrset "$BC_STDSCR" 0 0; }
standout() { wattron "$BC_STDSCR" "$A_ITALIC"; }

# change attributes of a line of cells (ncurses chgat): from (y,x) for n
# cells (n<0 -> to end of line), single line, no wrap, cursor unchanged.
# The character is preserved; attribute bits are replaced, pair is set.
_bc_chgat_impl() { # w y x n attr pair
  local w=$1 y=$2 x=$3 n=$4 attr=$5 pair=$6
  local h=${BC_WH[$w]} ww=${BC_WW[$w]}
  (( y < 0 || y >= h )) && return 0
  _bc_flush_row "$w" "$(( BC_WY[$w] + y ))"
  (( x < 0 )) && x=0
  local end
  if (( n == -1 )); then
    end=$(( ww - 1 ))
  else
    end=$(( x + n - 1 ))
    (( end >= ww )) && end=$(( ww - 1 ))
  fi
  (( x > end )) && return 0
  local ay=$(( BC_WY[$w] + y ))
  local buf=${BC_WBUF[$w]}
  local i k bk ch mk
  local ax0=$(( BC_WX[$w] + x ))
  local ax1=$(( BC_WX[$w] + end ))
  for (( i = ax0; i <= ax1; i++ )); do
    k="$ay $i"
    bk="$buf/$k"
    ch=${BC_C[$bk]:-${BC_WBG[$w]}}
    BC_C[$bk]=$ch
    BC_A[$bk]=$attr
    BC_P[$bk]=$pair
    mk="$w/$k"
    if [[ -z ${BC_MK[$mk]:-} ]]; then
      BC_MK[$mk]=1
      BC_WD[$w]+=",$k"
    fi
  done
}

wchgat() { # win n attr pair [s]
  local w=${1:-$BC_CURR}
  _bc_chgat_impl "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "$2" "$3" "${4:-0}"
  return 0
}

chgat() { # n attr pair [s]
  wchgat "$BC_STDSCR" "$@"
  return 0
}

mvchgat() { # y x n attr pair [s]
  wmove "$BC_STDSCR" "$1" "$2" || return 1
  _bc_chgat_impl "$BC_STDSCR" "$1" "$2" "$3" "$4" "${5:-0}"
  return 0
}

# ------------------------------------------------------ rendition on stdout
vidattr() { _bc_sgr "${1:-0}" "${2:-0}"; printf '\e[%sm' "$BC_SGR"; }
vid_attr() { vidattr "$@"; }
vidputs() { _bc_sgr "${2:-0}" "${3:-0}"; printf '\e[%sm%s' "$BC_SGR" "$1"; }
vid_puts() { vidputs "$@"; }

# ------------------------------------------------------------- cursor / io
curs_set() {
  if (( ${1:-2} == 0 )); then
    printf '\e[?25l'
  else
    printf '\e[?25h'
  fi
  return 0
}

delay_output() { # ms
  local ms=${1:-100}
  printf -v _bc_d '%d.%03d' "$(( ms / 1000 ))" "$(( ms % 1000 ))"
  sleep "$_bc_d"
  return 0
}


