#!/bin/bash
# screen.sh -- parse a tmux `capture-pane -e` SGR capture into a per-cell grid and
# assert on it. Source this file from a test script.
#
# It also provides raw-PTY helpers (start_raw / raw_clean / cursor_from_raw) for
# byte-level escape-stream and cursor verification.
#
# Capturing a screen (see visual_diff.sh / integration.sh):
#   tmux capture-pane -t <sess> -e -p > cap.sgr     # colours + attrs (SGR)
#   tmux capture-pane -t <sess>     -p > cap.plain  # characters only
#
# Loading and asserting:
#   source tests/lib/screen.sh
#   screen_load cap.sgr 100 30
#   expect_cell  0 0 'N' 16:4 16:6 ''            # one cell: char fg bg attrs
#   expect_run   0 0 'File' 16:4 16:6 ''          # a run of uniform-style cells
#   expect_line  5 0 'some text at col 0'         # characters only (colours ignored)
#   screen_result                             # print summary, return 0 iff no failures
#
# Comparing two captures (e.g. real MC vs the clone):
#   screen_diff a.sgr b.sgr 100 30              # per-cell diff, 0 iff identical
#
# Normalized colour tokens:  d (default) | 16:N | 256:N | rgb:R,G,B
# Attrs token (sorted, comma-joined, empty if none):
#   bold dim italic underline blink reverse conceal strike

# ------------------------------------------------------------------ SGR state machine
SC_FG=d; SC_BG=d
SC_B=0; SC_D=0; SC_I=0; SC_U=0; SC_BL=0; SC_R=0; SC_C=0; SC_S=0

_scr_reset_all() { SC_FG=d; SC_BG=d; SC_B=0; SC_D=0; SC_I=0; SC_U=0; SC_BL=0; SC_R=0; SC_C=0; SC_S=0; }

# apply one SGR parameter list (the bytes between ESC[ and the final 'm')
_scr_sgr() {
  local params=$1
  [[ -z $params ]] && { _scr_reset_all; return; }   # ESC[m is a full reset
  local IFS=';'
  local -a tok=($params)
  local n=${#tok[@]} i=0 t
  while (( i < n )); do
    t=${tok[i]}
    case $t in
      0)     _scr_reset_all ;;
      1)     SC_B=1 ;;
      2)     SC_D=1 ;;
      3)     SC_I=1 ;;
      4|21)  SC_U=1 ;;
      5|6)   SC_BL=1 ;;
      7)     SC_R=1 ;;
      8)     SC_C=1 ;;
      9)     SC_S=1 ;;
      22)    SC_B=0; SC_D=0 ;;
      23)    SC_I=0 ;;
      24)    SC_U=0 ;;
      25)    SC_BL=0 ;;
      27)    SC_R=0 ;;
      28)    SC_C=0 ;;
      29)    SC_S=0 ;;
      3[0-7])    SC_FG="16:$(( t - 30 ))" ;;
       9[0-7])    SC_FG="16:$(( t - 90 + 8 ))" ;;
       39)     SC_FG=d ;;
       4[0-7])    SC_BG="16:$(( t - 40 ))" ;;
       10[0-7])   SC_BG="16:$(( t - 100 + 8 ))" ;;
      49)     SC_BG=d ;;
      38)
        if [[ ${tok[i+1]:-} == 5 ]]; then SC_FG="256:${tok[i+2]}"; i=$((i+2))
        elif [[ ${tok[i+1]:-} == 2 ]]; then SC_FG="rgb:${tok[i+2]},${tok[i+3]},${tok[i+4]}"; i=$((i+4)); fi ;;
      48)
        if [[ ${tok[i+1]:-} == 5 ]]; then SC_BG="256:${tok[i+2]}"; i=$((i+2))
        elif [[ ${tok[i+1]:-} == 2 ]]; then SC_BG="rgb:${tok[i+2]},${tok[i+3]},${tok[i+4]}"; i=$((i+4)); fi ;;
    esac
    i=$((i+1))
  done
}

# current style -> "bold,dim,..." (sorted) in $REPLY
_scr_attrs() {
  local s=""
  (( SC_B  )) && s+="${s:+,}bold"
  (( SC_D  )) && s+="${s:+,}dim"
  (( SC_I  )) && s+="${s:+,}italic"
  (( SC_U  )) && s+="${s:+,}underline"
  (( SC_BL )) && s+="${s:+,}blink"
  (( SC_R  )) && s+="${s:+,}reverse"
  (( SC_C  )) && s+="${s:+,}conceal"
  (( SC_S  )) && s+="${s:+,}strike"
  REPLY=$s
}

# advance _CSI_I past the CSI sequence that starts at _CSI_I (index of ESC)
#   -> _CSI_TERM = final byte, _CSI_BODY = bytes between '[' and final byte
_scr_next_csi() { # line i
  local line=$1 i=$2 ch
  local lch=${#line} j=$(( i + 2 ))
  while (( j < lch )); do
    ch=${line:j:1}
    [[ $ch == [@-~] ]] && break      # CSI final byte is 0x40..0x7E
    (( j++ ))
  done
  if (( j >= lch )); then _CSI_TERM=""; _CSI_BODY=""; _CSI_I=$lch; return 1; fi
  _CSI_TERM=$ch
  _CSI_BODY=${line:i+2:j-i-2}
  _CSI_I=$(( j + 1 ))
}

# skip a non-CSI escape sequence whose ESC is at index i (line[i+1] != '[').
# OSC (ESC ]) ends at BEL or ST; DCS (ESC P) / SOS (ESC <) end at ST (ESC \);
# any other 2-byte escape is just ESC + one final byte. -> _SCR_EI = index past it.
_scr_skip_esc() { # line i
  local line=$1 i=$2
  local lch=${#line} c=${line:i+1:1}
  if [[ $c == ']' || $c == 'P' || $c == '<' ]]; then
    i=$((i+2))
    while (( i < lch )); do
      if [[ ${line:i:1} == $'\x1b' && ${line:i+1:1} == $'\x5c' ]]; then i=$((i+2)); break; fi
      if [[ $c == ']' && ${line:i:1} == $'\a' ]]; then i=$((i+1)); break; fi
      (( i++ ))
    done
  else
    i=$((i+2))
  fi
  _SCR_EI=$i
}

# parse one captured row into grid row $1 (0-based), width $2
_scr_row() { # line y w
  local line=$1 y=$2 w=$3 i=0 x=0 ch
  local lch=${#line}
  while (( i < lch )); do
    if [[ ${line:i:1} == $'\x1b' ]]; then
      if [[ ${line:i+1:1} == '[' ]]; then
        _scr_next_csi "$line" "$i"
        i=$_CSI_I
        [[ $_CSI_TERM == [mM] ]] && _scr_sgr "$_CSI_BODY"
      else
        _scr_skip_esc "$line" "$i"
        i=$_SCR_EI
      fi
      continue
    fi
    ch=${line:i:1}
    _scr_attrs
    GRID_C["$y $x"]=$ch
    GRID_FG["$y $x"]=$SC_FG
    GRID_BG["$y $x"]=$SC_BG
    GRID_A["$y $x"]=$REPLY
    (( i++ )); (( x++ ))
  done
  # tmux omits trailing blank cells: pad the rest of the row with default space
  while (( x < w )); do
    GRID_C["$y $x"]=' '; GRID_FG["$y $x"]=d; GRID_BG["$y $x"]=d; GRID_A["$y $x"]=""
    (( x++ ))
  done
}

# ------------------------------------------------------------------ grid globals
declare -gA GRID_C=() GRID_FG=() GRID_BG=() GRID_A=()
GRID_W=0; GRID_H=0

# screen_load FILE W H  -> fills the global grid from an SGR (or plain) capture
screen_load() { # file w h
  local file=$1 w=$2 h=$3
  local -a lines=()
  mapfile -t lines < "$file"
  GRID_C=(); GRID_FG=(); GRID_BG=(); GRID_A=()
  # fresh style (a capture is a self-contained stream)
  _scr_reset_all
  local y
  for (( y = 0; y < h; y++ )); do
    _scr_row "${lines[y]:-}" "$y" "$w"
  done
  GRID_W=$w; GRID_H=$h
}

# ------------------------------------------------------------------ accessors
cell() { # y x  -> "char<TAB>fg<TAB>bg<TAB>attrs"
  printf '%s\t%s\t%s\t%s' \
    "${GRID_C["$1 $2"]:- }" "${GRID_FG["$1 $2"]:-d}" "${GRID_BG["$1 $2"]:-d}" "${GRID_A["$1 $2"]:-}"
}

grid_tsv() { # y<TAB>x<TAB>char<TAB>fg<TAB>bg<TAB>attrs  (one row-major line per cell)
  local y x
  for (( y = 0; y < GRID_H; y++ )); do
    for (( x = 0; x < GRID_W; x++ )); do
      printf '%d\t%d\t%s\t%s\t%s\t%s\n' "$y" "$x" \
        "${GRID_C["$y $x"]:- }" "${GRID_FG["$y $x"]:-d}" "${GRID_BG["$y $x"]:-d}" "${GRID_A["$y $x"]:-}"
    done
  done
}

grid_plain() { # characters only, one line per row (padded to GRID_W)
  local y x line
  for (( y = 0; y < GRID_H; y++ )); do
    line=""
    for (( x = 0; x < GRID_W; x++ )); do line+=${GRID_C["$y $x"]:- }; done
    printf '%s\n' "$line"
  done
}

# ------------------------------------------------------------------ assertions
SCR_PASS=0; SCR_FAIL=0
_scr_ok()   { printf 'ok   %s\n' "$1"; SCR_PASS=$(( SCR_PASS + 1 )); }
_scr_bad()  { printf 'FAIL %s\n' "$1"; SCR_FAIL=$(( SCR_FAIL + 1 )); }

# expect_cell Y X CHAR FG BG ATTRS [LABEL]
expect_cell() { # y x ch fg bg attrs label
  local y=$1 x=$2 wc=$3 wfg=$4 wbg=$5 wa=$6 label=${7:-"cell $1,$2"}
  local c=${GRID_C["$y $x"]:- } fg=${GRID_FG["$y $x"]:-d} bg=${GRID_BG["$y $x"]:-d} a=${GRID_A["$y $x"]:-}
  if [[ $c == "$wc" && $fg == "$wfg" && $bg == "$wbg" && $a == "$wa" ]]; then
    _scr_ok "$label"
  else
    _scr_bad "$label: want [c=$wc fg=$wfg bg=$wbg a=$wa] got [c=$c fg=$fg bg=$bg a=$a]"
  fi
}

# expect_run Y X0 TEXT FG BG ATTRS [LABEL]  -- TEXT rendered in one uniform style
expect_run() { # y x0 text fg bg attrs label
  local y=$1 x0=$2 text=$3 wfg=$4 wbg=$5 wa=$6 label=${7:-"run $1@$2 '$text'"}
  local n=${#text} okc=1 x i
  for (( x = x0, i = 0; x < x0 + n; x++, i++ )); do
    [[ ${GRID_C["$y $x"]:- } == "${text:i:1}" ]] || okc=0
    [[ ${GRID_FG["$y $x"]:-d} == "$wfg" ]] || okc=0
    [[ ${GRID_BG["$y $x"]:-d} == "$wbg" ]] || okc=0
    [[ ${GRID_A["$y $x"]:-} == "$wa" ]] || okc=0
  done
  (( okc )) && _scr_ok "$label" || _scr_bad "$label: want [$text fg=$wfg bg=$wbg a=$wa]"
}

# expect_line Y X0 TEXT [LABEL]  -- characters only, colours/attrs ignored
expect_line() { # y x0 text label
  local y=$1 x0=$2 want=$3 label=${4:-"line $1@$2"}
  local n=${#want} got="" x
  for (( x = x0; x < x0 + n; x++ )); do got+=${GRID_C["$y $x"]:- }; done
  [[ $got == "$want" ]] && _scr_ok "$label" || _scr_bad "$label: want [$want] got [$got]"
}

# screen_diff A B W H  -- per-cell comparison of two captures; 0 iff identical
screen_diff() { # a b w h
  local a=$1 b=$2 w=$3 h=$4 ta tb d n
  ta=$( screen_load "$a" "$w" "$h"; grid_tsv )
  tb=$( screen_load "$b" "$w" "$h"; grid_tsv )
  if [[ $ta == "$tb" ]]; then
    echo "identical: $(( w * h )) cells match"
    return 0
  fi
  d=$( diff <(printf '%s\n' "$ta") <(printf '%s\n' "$tb") )
  printf '%s\n' "$d"
  n=$( grep -c '^[<>]' <<< "$d" )
  echo "$n differing cells (of $(( w * h )))"
  return 1
}

# screen_result  -- print a summary; return 0 iff SCR_FAIL is 0
screen_result() {
  echo
  if (( SCR_FAIL == 0 )); then echo "screen: $SCR_PASS passed"; else echo "screen: $SCR_PASS passed, $SCR_FAIL FAILED"; fi
  (( SCR_FAIL == 0 ))
}

# ------------------------------------------------------------------ raw PTY helpers
SCREEN_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# start_raw COLUMNS LINES OUTFILE CMD...
#   Run CMD on a real PTY via `script`, capturing the raw byte stream to OUTFILE.
#   COLUMNS/LINES are exported so `tput cols`/`tput lines` (used by lib/bc.sh) see
#   the requested size. The `script` header/footer lines are left in OUTFILE; use
#   raw_clean to strip them.
start_raw() { # cols lines outfile cmd args...
  local cols=$1 lines=$2 outfile=$3; shift 3
  ( export COLUMNS="$cols" LINES="$lines"
    script -q -e -f -m classic -c "$*" "$outfile" </dev/null >/dev/null 2>&1 )
}

# raw_clean INFILE  -> stdout with the `script` start/stop banner lines removed
raw_clean() { # infile
  grep -avE '^Script (started|done) on ' "$1"
}

# cursor_from_raw RAWFILE W H  -> "row col" (1-based) of the final cursor position,
#   tracked through the raw escape stream (CUP/CUD/CUU/CUF/CUB/CR/LF + wrap).
cursor_from_raw() { # rawfile w h
  local f=$1 w=$2 h=$3
  od -An -tx1 "$f" | LC_ALL=C awk -v W="$w" -v H="$h" -f "$SCREEN_LIB_DIR/cursor.awk"
}
