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
readonly ACS_S1='─'
readonly ACS_S9='│'
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
readonly ACS_S3='│'
readonly ACS_S7='─'
readonly ACS_CKBOARD='▒'
readonly ACS_DEGREE='°'
readonly ACS_PLMINUS='±'
readonly ACS_BULLET='•'
readonly ACS_LARROW='←'
readonly ACS_RARROW='→'
readonly ACS_DARROW='↓'
readonly ACS_UARROW='↑'
readonly ACS_BOARD='▒'
readonly ACS_LANTERN='▓'
readonly ACS_BLOCK='█'
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
BC_PAIRS=0
BC_WN=1
BC_STARTED=0
BC_OLDSTTY=""
BC_WINCH=0            # set by a SIGWINCH trap; consumed by wgetch as KEY_RESIZE
BC_FORCEFULL=0       # when set, the next doupdate recomposites the whole screen

# ncurses globals (mirrored by initscr / start_color)
COLS=80
LINES=24
COLORS=0
COLOR_PAIRS=0
ESCDELAY=1000
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
declare -A BC_PAIRS_A=() # pair -> fg
declare -A BC_PAIRS_B=() # pair -> bg
declare -A BC_SGRC=()  # "a/p" -> sgr code
declare -a BC_WLIST=()
declare -A BC_WBUF=() # buffer owner per window (w -> owner window id)
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
  BC_WKEYPAD[$w]=0
  BC_WBUF[$w]=$w
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
  BC_PAIRS=$(( BC_COLORS * 24 ))
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
  return 0
}

_BC_TI_KEY=0
_bc_ti_lookup() { # $1 full sequence -> _BC_TI_KEY, returns 0 on exact match
  local i
  for i in ${!BC_KEYSEQ[@]}; do
    if [[ $1 == "${BC_KEYSEQ[i]}" ]]; then
      _BC_TI_KEY=${BC_KEYVAL[i]}
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
    if (( p > 0 )); then
      if [[ -n ${BC_PAIRS_A[$p]:-} ]]; then
        local fg=${BC_PAIRS_A[$p]} bg=${BC_PAIRS_B[$p]}
        if (( fg < 8 )); then
          s="${s:+$s;}$(( 30 + fg ))"
        elif (( fg < 16 )); then
          s="${s:+$s;}$(( 90 + (fg - 8) ))"   # bright fg 8-15 -> 90-97 (matches mc)
        else
          s="${s:+$s;}38;5;$fg"
        fi
        if (( bg < 8 )); then
          s="${s:+$s;}$(( 40 + bg ))"
        elif (( bg < 16 )); then
          s="${s:+$s;}$(( 100 + (bg - 8) ))"  # bright bg 8-15 -> 100-107
        else
          s="${s:+$s;}48;5;$bg"
        fi
      else
        local fg=$(( p % 8 ))
        local bg=$(( p / 8 ))
        s="${s:+$s;}38;5;$fg;48;5;$bg"
      fi
    fi
    [[ -z $s ]] && s="0"
    BC_SGRC[$k]=$s
  fi
  BC_SGR=$s
}

# record one absolute cell as changed for a window
_bc_cell() { # w ay ax ch a p
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
  if [[ ${2:- } == ' ' && ${3:-0} -eq 0 && ${4:-0} -eq 0 ]]; then
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

# clear a window line from relative (y,x) to the end of the line
_bc_clrtoeol_cell() { # w y x
  local w=$1 y=$2 x=$3
  local ww=${BC_WW[$w]}
  (( y >= ${BC_WH[$w]} || x >= ww )) && return 0
  _bc_render "$w" ' ' 0 0
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
  _bc_render "$w" ' ' 0 0
  _bc_cell "$w" "$ay" "$ax" "$BC_RCH" "$BC_RA" "$BC_RP"
}

# fill a window with its background rendition, marking every cell dirty
_bc_erase_region() { # w
  local w=$1
  local y0=${BC_WY[$w]} x0=${BC_WX[$w]} h=${BC_WH[$w]} ww=${BC_WW[$w]}
  local y x
  _bc_render "$w" ' ' 0 0
  for (( y = 0; y < h; y++ )); do
    for (( x = 0; x < ww; x++ )); do
      _bc_cell "$w" "$(( y0 + y ))" "$(( x0 + x ))" "$BC_RCH" "$BC_RA" "$BC_RP"
    done
  done
  BC_WAX[$w]=0
  BC_WAY[$w]=0
}

_bc_clear_marks() { # w
  local w=$1 mk
  for mk in "${!BC_MK[@]}"; do
    if [[ $mk == "$w/"* ]]; then
      unset "BC_MK[$mk]"
    fi
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
  BC_PENDING_IN+=$KEY_MOUSE
  return 0
}

has_mouse() {
  if (( BC_MOUSE_TYPE )); then
    return 0
  fi
  [[ $TERM == *xterm* ]]
  return $?
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

# Read the X10 payload that follows "\EM": three raw bytes Cb Cx Cy.
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
        BC_PENDING_IN+="$c$s$s2"
        break
        ;;
      'M')
        if _bc_mouse_read_x10; then
          _bc_mouse_decode_x10
          _bc_mouse_push_event
          continue
        fi
        BC_PENDING_IN+="$c$s"
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
cbreak() { stty -icanon 2>/dev/null; return 0; }
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
  (( BC_COLORS > 0 ))
  return $?
}

has_colors() { (( BC_COLORS > 0 )); }

has_named_color() { has_colors "$@"; }

use_default_colors() { return 0; }

init_color() { return 0; }

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

derwin() { # win nlines ncol begin_y begin_x (absolute, within parent)
  local w=$1 h=$2 wd=$3 y=$4 x=$5
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
  bc_win=$id
  return 0
}

subwin() { derwin "$@"; }

delwin() {
  local w=$1
  # remember the region so the next composite can reveal what is underneath it
  [[ -n ${BC_WY[$w]:-} ]] && BC_DELRECTS+="|${BC_WY[$w]} ${BC_WX[$w]} ${BC_WH[$w]} ${BC_WW[$w]}"
  _bc_clear_marks "$w"
  unset "BC_WD[$w]" "BC_WBUF[$w]"
  unset "BC_WY[$w]" "BC_WX[$w]" "BC_WH[$w]" "BC_WW[$w]"
  unset "BC_WBG[$w]" "BC_WBGA[$w]" "BC_WBGP[$w]"
  unset "BC_WAX[$w]" "BC_WAY[$w]" "BC_WCURA[$w]" "BC_WCURP[$w]" "BC_WDELAY[$w]"
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
  return 0
}

resizestdscr() { resizeterm "$@"; }

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

beep() { printf '\a'; return 0; }
flash() { return 0; }

# ---------------------------------------------------------- output / text
waddstr() { # win str
  local w=${1:-$BC_CURR}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "$2" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
  return 0
}

addstr() { waddstr "$BC_CURR" "$@"; }

waddnstr() { # win str n
  local w=${1:-$BC_CURR}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "${2:0:$3}" "${BC_WCURA[$w]}" "${BC_WCURP[$w]}"
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

waddch() { # win ch [a p]
  local w=${1:-$BC_CURR}
  local a=${3:-${BC_WCURA[$w]}}
  local p=${4:-${BC_WCURP[$w]}}
  _bc_emit "$w" "${BC_WAY[$w]}" "${BC_WAX[$w]}" "${2:- }" "$a" "$p"
  return 0
}

addch() { waddch "$BC_CURR" "$@"; }

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
  local k="$buf/$(( BC_WY[$w] + $2 )) $(( BC_WX[$w] + $3 ))"
  wch=${BC_C[$k]:- }
  wcha=${BC_A[$k]:-0}
  wchp=${BC_P[$k]:-0}
  return 0
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
  return 0
}

wborder_set() { return 0; }

box() { # win [verch horch]
  local w=${1:-$BC_CURR}
  wborder "$w" "${2:-$ACS_VLINE}" "${2:-$ACS_VLINE}" "${3:-$ACS_HLINE}" "${3:-$ACS_HLINE}"
}

hline() { wborder "$1" "$ACS_VLINE" "$ACS_VLINE" "$ACS_HLINE" "$ACS_HLINE"; }
vline() { wborder "$1" "$ACS_VLINE" "$ACS_VLINE" "$ACS_HLINE" "$ACS_HLINE"; }

# draw a horizontal/vertical line of n chars starting at (y,x) on stdscr
# (ncurses mvhline/mvvline: move to (y,x), then emit n chars)
mvhline() { # y x ch n
  wmove "$BC_STDSCR" "$1" "$2" || return 1
  local i
  for (( i = 0; i < $4; i++ )); do
    waddch "$BC_STDSCR" "$3"
  done
  return 0
}

mvwhline() { # win y x ch n
  local w=${1:-$BC_CURR}
  wmove "$w" "$2" "$3" || return 1
  local i
  for (( i = 0; i < $5; i++ )); do
    waddch "$w" "$4"
  done
  return 0
}

mvvline() { # y x ch n
  local i
  for (( i = 0; i < $4; i++ )); do
    mvwaddch "$BC_STDSCR" "$(( $1 + i ))" "$2" "$3"
  done
  return 0
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

wbkgset() { wbkgd "$@"; }
bkgd() { wbkgd "$BC_STDSCR" "$@"; }
bkgdset() { wbkgset "$@"; }

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
  local k y x ch a p out="" lasty=-1 lastx=-1
  if [[ -n ${BC_WD[$w]:-} ]]; then
    local IFS=','
    for k in ${BC_WD[$w]}; do
      [[ -n $k ]] && keys+=("$k")
    done
    unset "BC_WD[$w]"
    _bc_clear_marks "$w"
  fi
  for k in "${keys[@]}"; do
    y=${k%% *}
    x=${k##* }
    ch=${BC_C["$buf/$k"]:- }
    a=${BC_A["$buf/$k"]:-0}
    p=${BC_P["$buf/$k"]:-0}
    if [[ ${BC_S[$k]:-} == "$ch" && ${BC_SA[$k]:-0} == "$a" && ${BC_SP[$k]:-0} == "$p" ]]; then
      continue
    fi
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
  if [[ -n $out ]]; then
    printf '%s' "$out"
  fi
  printf '%s[%d;%dH' "$BC_ESC" "$(( BC_WAY[$w] + BC_WY[$w] + 1 ))" "$(( BC_WAX[$w] + BC_WX[$w] + 1 ))"
  return 0
}

refresh() { wrefresh "$BC_STDSCR"; }

wnoutrefresh() { wrefresh "$@"; }

# Composite the visible content at one absolute cell: stdscr is the base, and
# the topmost visible panel in the stack that covers the cell wins. Sets
# _BC_CC / _BC_CA / _BC_CP.
_bc_composite_cell() { # ay ax
  local ay=$1 ax=$2 w buf p
  buf=${BC_WBUF[$BC_STDSCR]}
  _BC_CC=${BC_C["$buf/$ay $ax"]:-${BC_WBG[$BC_STDSCR]}}
  _BC_CA=${BC_A["$buf/$ay $ax"]:-0}
  _BC_CP=${BC_P["$buf/$ay $ax"]:-0}
  for p in "${BC_PSTACK[@]}"; do
    [[ ${BC_PHID[$p]} == 1 ]] && continue
    w=${BC_PWIN[$p]}
    if (( ay >= BC_WY[$w] && ay < BC_WY[$w] + BC_WH[$w] && ax >= BC_WX[$w] && ax < BC_WX[$w] + BC_WW[$w] )); then
      buf=${BC_WBUF[$w]}
      _BC_CC=${BC_C["$buf/$ay $ax"]:-${BC_WBG[$w]}}
      _BC_CA=${BC_A["$buf/$ay $ax"]:-0}
      _BC_CP=${BC_P["$buf/$ay $ax"]:-0}
    fi
  done
  return 0
}

# Recomposite every cell that changed since the last update and emit only the
# diffs. The changed set is the union of the dirty cells of every window and
# the rectangles of any windows deleted since the last composite. BC_S (keyed
# "y x") holds the last composited screen, so unchanged cells are never
# re-emitted and the topmost window always wins at a cell.
doupdate() {
  local ay ax k p w r y x
  declare -A RC=()
  local -a wins=("$BC_STDSCR")
  for p in "${BC_PSTACK[@]}"; do wins+=("${BC_PWIN[$p]}"); done
  # dirty cells of every window (stdscr base + all panels in the stack)
  for w in "${wins[@]}"; do
    [[ -n ${BC_WD[$w]:-} ]] || continue
    local IFS=','
    for k in ${BC_WD[$w]}; do [[ -n $k ]] && RC[$k]=1; done
    unset IFS
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
      for (( ay = ry0; ay < ry0 + rh; ay++ )); do
        for (( ax = rx0; ax < rx0 + rww; ax++ )); do
          RC["$ay $ax"]=1
          unset "BC_S[$ay $ax]" "BC_SA[$ay $ax]" "BC_SP[$ay $ax]"
        done
      done
    done
  fi
  # the very first composite (or a forced full rebuild after a resize) repaints
  # the whole screen: clear the last-composited model and recompute every cell
  if (( ${#RC[@]} == 0 && ${#BC_S[@]} == 0 )) || (( BC_FORCEFULL )); then
    BC_FORCEFULL=0
    BC_S=(); BC_SA=(); BC_SP=()
    for (( ay = 0; ay < BC_LINES; ay++ )); do
      for (( ax = 0; ax < BC_COLS; ax++ )); do RC["$ay $ax"]=1; done
    done
  fi
  (( ${#RC[@]} == 0 )) && return 0

  local out="" lasty=-1 lastx=-1 last_sgr="" ch a pp emitted=0
  while read -r ay ax; do
    _bc_composite_cell "$ay" "$ax"
    ch=$_BC_CC; a=$_BC_CA; pp=$_BC_CP
    k="$ay $ax"
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
    lasty=$ay; lastx=$ax
    emitted=$(( emitted + 1 ))
  done < <(printf '%s\n' "${!RC[@]}" | sort -k1,1n -k2,2n)

  [[ -n $out ]] && printf '%s' "$out"
  printf '%s[%d;%dH' "$BC_ESC" "$(( BC_WAY[$BC_STDSCR] + 1 ))" "$(( BC_WAX[$BC_STDSCR] + 1 ))"
  # clear the dirty marks for exactly the cells we flushed
  for w in "${wins[@]}"; do
    [[ -n ${BC_WD[$w]:-} ]] || continue
    local IFS=','
    for k in ${BC_WD[$w]}; do [[ -n $k ]] && unset "BC_MK[$w/$k]"; done
    unset IFS
    unset "BC_WD[$w]"
  done
  BC_DELRECTS=""
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
  unset "BC_PWIN[$p]" "BC_PHID[$p]" "BC_PUSR[$p]"
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
  BC_PWIN[$1]=$2
  return 0
}

update_panels() { return 0; }

# ---------------------------------------------------- screen save / restore
# Dump format: one line per row, cells separated by US (\x1f), each cell is
# "attr pair char" (char last so it may itself be a space).
scr_init() { : > "$SCR_FILE" 2>/dev/null; return 0; }
scr_init_sp() { scr_init "$@"; }

scr_dump() {
  local y x cell line
  : > "$SCR_FILE" || return 1
  for (( y = 0; y < LINES; y++ )); do
    line=""
    for (( x = 0; x < COLS; x++ )); do
      cell="${BC_SA["$y $x"]:-0} ${BC_SP["$y $x"]:-0} ${BC_S["$y $x"]:- }"
      line="${line:+$line$'\x1f'}$cell"
    done
    printf '%s\n' "$line" >> "$SCR_FILE"
  done
  return 0
}

scr_set() {
  local y=-1 x rest cell a p ch
  [[ -f $SCR_FILE ]] || return 1
  werase "$BC_STDSCR"
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
  wrefresh "$BC_STDSCR"
  return 0
}

scr_restore() {
  local y=-1 x rest cell a p ch
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
  wrefresh "$BC_STDSCR"
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
  else
    BC_WDELAY[$w]=0
  fi
  return 0
}

halfdelay() { # tenths
  BC_HALFTENTHS=${1:-10}
  return 0
}

flushinp() {
  local c
  while IFS= read -rsn1 -t 0.001 c; do :; done
  return 0
}

ungetch() { # $1 ch to push back
  BC_PENDING_IN="${1:-$key}$BC_PENDING_IN"
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
    if [[ -n $BC_PENDING_IN ]]; then
      key=${BC_PENDING_IN:0:1}
      BC_PENDING_IN=${BC_PENDING_IN:1}
      return 0
    fi
    if (( BC_WDELAY[$w] )); then
      IFS= read -rsn1 -t 0.001 c; rc=$?
    else
      # Short timeout so a SIGWINCH (trapped, deferred until this read
      # completes) can be picked up as KEY_RESIZE instead of blocking forever.
      IFS= read -rsn1 -t 0.05 c; rc=$?
    fi
    if (( BC_WINCH )); then
      BC_WINCH=0
      key=$KEY_RESIZE
      return 0
    fi
    if (( rc > 128 )); then
      # A timed-out read (rc > 128): nothing was read, so keep polling. A
      # nodelay window reports ERR instead of looping.
      (( BC_WDELAY[$w] )) && return 1
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
        if (( BC_MOUSE_MASK )) && [[ $seq == $'\x1bM' ]]; then
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

echochar() { wgetch "$BC_STDSCR" && waddch "$BC_STDSCR" "$key"; }

# read a line into the global bc_str, echoing each char to the window like
# ncurses wgetstr (the terminal is raw/-echo, so we echo into the window)
wgetstr() { # win
  local w=${1:-$BC_CURR}
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
            _bc_clear_cell "$w" "$cy" "$cx"
          fi
          BC_WAX[$w]=$cx
        fi
        ;;
      *)
        bc_str+=$c
        waddch "$w" "$c"
        ;;
    esac
  done
  return 0
}

getstr() { wgetstr "$BC_STDSCR"; }

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

standend() { wattrset "$BC_STDSCR" 0 0; }
standout() { wattron "$BC_STDSCR" "$(( A_BOLD | A_REVERSE ))"; }

# change attributes of a line of cells (ncurses chgat): from (y,x) for n
# cells (n<0 -> to end of line), single line, no wrap, cursor unchanged.
# The character is preserved; attribute bits are replaced, pair is set.
_bc_chgat_impl() { # w y x n attr pair
  local w=$1 y=$2 x=$3 n=$4 attr=$5 pair=$6
  local h=${BC_WH[$w]} ww=${BC_WW[$w]}
  (( y < 0 || y >= h )) && return 0
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

# ------------------------------------------------------------------ pads
newpad() { # lines cols
  if (( $1 < 1 || $2 < 1 )); then
    return 1
  fi
  local id=$BC_WN
  BC_WN=$(( BC_WN + 1 ))
  _bc_init_window "$id" 0 0 "$1" "$2"
  bc_win=$id
  return 0
}

prefresh() { # pad pmin_y pmin_x smin_y smin_x x1 y1 x2 y2
  local w=$1
  werase "$BC_STDSCR"
  wrefresh "$BC_STDSCR"
  return 0
}
