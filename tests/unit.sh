#!/bin/bash
# Headless unit tests for lib/bc.sh (no tty required).
REPO="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$REPO/tmp"
mkdir -p "$TMP"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }
check() { if [[ "$3" == "$2" ]]; then ok "$1"; else bad "$1: want [$2] got [$3]"; fi; }
E=$'\x1b'

source "$REPO/lib/bc.sh"

# --- A. constants vs installed ncurses ---
cat > "$TMP/consts.c" <<'EOF'
#include <ncurses.h>
#include <stdio.h>
int main(void) {
  printf("%d ", KEY_UP); printf("%d ", KEY_DOWN); printf("%d ", KEY_LEFT);
  printf("%d ", KEY_RIGHT); printf("%d ", KEY_HOME); printf("%d ", KEY_END);
  printf("%d ", KEY_BACKSPACE); printf("%d ", KEY_F(1)); printf("%d ", KEY_F(12));
  printf("%d ", KEY_DC); printf("%d ", KEY_IC); printf("%d ", KEY_CLEAR);
  printf("%d ", KEY_NPAGE); printf("%d ", KEY_PPAGE); printf("%d ", KEY_BEG);
  printf("%d ", KEY_MOUSE); printf("%d ", KEY_RESIZE); printf("%d ", KEY_MAX);
  printf("%d ", KEY_ENTER); printf("%d ", KEY_CODE_YES);
  printf("%d ", BUTTON1_PRESSED); printf("%d ", BUTTON1_RELEASED);
  printf("%d ", BUTTON1_CLICKED); printf("%d ", BUTTON1_DOUBLE_CLICKED);
  printf("%d ", BUTTON1_TRIPLE_CLICKED); printf("%d ", BUTTON2_PRESSED);
  printf("%d ", BUTTON3_PRESSED); printf("%d ", BUTTON4_PRESSED);
  printf("%d ", BUTTON5_PRESSED);
  printf("%d ", ALL_MOUSE_EVENTS);
  printf("%d ", REPORT_MOUSE_POSITION); printf("%d ", BUTTON_SHIFT);
  printf("%d ", BUTTON_ALT); printf("%d ", BUTTON_CTRL);
  printf("\n");
  return 0;
}
EOF
names=(KEY_UP KEY_DOWN KEY_LEFT KEY_RIGHT KEY_HOME KEY_END KEY_BACKSPACE
       KEY_F1 KEY_F12 KEY_DC KEY_IC KEY_CLEAR KEY_NPAGE KEY_PPAGE KEY_BEGIN
       KEY_MOUSE KEY_RESIZE KEY_MAX KEY_ENTER KEY_CODE_YES
       BUTTON1_PRESSED BUTTON1_RELEASED BUTTON1_CLICKED BUTTON1_DOUBLE_CLICKED
       BUTTON1_TRIPLE_CLICKED BUTTON2_PRESSED BUTTON3_PRESSED BUTTON4_PRESSED
       BUTTON5_PRESSED ALL_MOUSE_EVENTS
       REPORT_MOUSE_POSITION BUTTON_SHIFT BUTTON_ALT BUTTON_CTRL)
if command -v gcc >/dev/null 2>&1; then
  if gcc -o "$TMP/consts" "$TMP/consts.c" -lncurses 2>"$TMP/consts.err"; then
    cvals=($("$TMP/consts"))
    if (( ${#cvals[@]} == ${#names[@]} )); then
      for i in "${!names[@]}"; do
        n=${names[$i]}
        check "const $n" "${cvals[$i]}" "${!n}"
      done
    else
      bad "constant count: C ${#cvals[@]} vs bc ${#names[@]}"
    fi
  else
    bad "gcc compile failed (see $TMP/consts.err)"
  fi
else
  bad "gcc not found; skipped constant comparison"
fi

# aggregated mouse masks are internal to bash-curses (not in ncurses.h);
# verify them arithmetically as sums of the per-button bits
check "BUTTON_PRESSED sum"    "$(( BUTTON1_PRESSED + BUTTON2_PRESSED + BUTTON3_PRESSED + BUTTON4_PRESSED + BUTTON5_PRESSED ))" "$BUTTON_PRESSED"
check "BUTTON_RELEASED sum"   "$(( BUTTON1_RELEASED + BUTTON2_RELEASED + BUTTON3_RELEASED + BUTTON4_RELEASED + BUTTON5_RELEASED ))" "$BUTTON_RELEASED"
check "BUTTON_CLICKED sum"    "$(( BUTTON1_CLICKED + BUTTON2_CLICKED + BUTTON3_CLICKED + BUTTON4_CLICKED + BUTTON5_CLICKED ))" "$BUTTON_CLICKED"
check "BUTTON_DOUBLE sum"     "$(( BUTTON1_DOUBLE_CLICKED + BUTTON2_DOUBLE_CLICKED + BUTTON3_DOUBLE_CLICKED + BUTTON4_DOUBLE_CLICKED + BUTTON5_DOUBLE_CLICKED ))" "$BUTTON_DOUBLE_CLICKED"
check "BUTTON_TRIPLE sum"     "$(( BUTTON1_TRIPLE_CLICKED + BUTTON2_TRIPLE_CLICKED + BUTTON3_TRIPLE_CLICKED + BUTTON4_TRIPLE_CLICKED + BUTTON5_TRIPLE_CLICKED ))" "$BUTTON_TRIPLE_CLICKED"

# --- B. mousemask2 expansion ---
check "mask2 ALL"      "268435455" "$( ( _bc_mouse_mask2 268435455;   printf '%d' "$BC_MOUSE_MASK2" ) )"
check "mask2 CLICK1"   "7"         "$( ( _bc_mouse_mask2 4;           printf '%d' "$BC_MOUSE_MASK2" ) )"
check "mask2 DCLK1"    "15"        "$( ( _bc_mouse_mask2 8;           printf '%d' "$BC_MOUSE_MASK2" ) )"
check "mask2 TCLK1"    "31"        "$( ( _bc_mouse_mask2 16;          printf '%d' "$BC_MOUSE_MASK2" ) )"
check "mask2 REPORT"   "268435456" "$( ( _bc_mouse_mask2 268435456;   printf '%d' "$BC_MOUSE_MASK2" ) )"

# --- C. SGR 1006 decode ---
sgr() { ( _BC_SGR_B=$1 _BC_SGR_X=$2 _BC_SGR_Y=$3 _BC_SGR_FINAL=$4 _bc_mouse_decode_sgr
          printf '%s %s %s' "$_BC_EVT_BSTATE" "$_BC_EVT_X" "$_BC_EVT_Y" ); }
check "sgr left press"     "2 4 5"         "$(sgr 0 5 6 M)"
check "sgr middle press"   "64 4 5"        "$(sgr 1 5 6 M)"
check "sgr right press"    "2048 4 5"      "$(sgr 2 5 6 M)"
check "sgr wheel up press" "65536 4 5"     "$(sgr 64 5 6 M)"
check "sgr wheel dn press" "2097152 4 5"   "$(sgr 65 5 6 M)"
check "sgr left+alt press" "134217730 4 5" "$(sgr 8 5 6 M)"
check "sgr drag(b=3) M"    "268435456 4 5" "$(sgr 3 5 6 M)"
check "sgr left release (pressed)" "1 4 5" "$(
  ( _BC_SGR_B=0; _BC_SGR_X=5; _BC_SGR_Y=6; _BC_SGR_FINAL=M; _bc_mouse_decode_sgr
    _BC_SGR_FINAL=m; _bc_mouse_decode_sgr
    printf '%s %s %s' "$_BC_EVT_BSTATE" "$_BC_EVT_X" "$_BC_EVT_Y" ) )"
check "sgr left release (nothing pressed)" "268435456 4 5" "$(sgr 0 5 6 m)"
check "sgr wheel release (nothing pressed)" "268435456 4 5" "$(sgr 64 5 6 m)"
check "sgr wheel dn release (nothing pressed)" "268435456 4 5" "$(sgr 65 5 6 m)"

# --- D. X10 decode ---
x10() { ( _BC_X10_CB=$1 _BC_X10_CX=$2 _BC_X10_CY=$3 _bc_mouse_decode_x10
          printf '%s %s %s' "$_BC_EVT_BSTATE" "$_BC_EVT_X" "$_BC_EVT_Y" ); }
check "x10 left press"   "2 4 5"         "$(x10 32 37 38)"
check "x10 middle press" "64 4 5"        "$(x10 33 37 38)"
check "x10 right press"  "2048 4 5"      "$(x10 34 37 38)"
check "x10 wheel up"     "65536 4 5"     "$(x10 96 37 38)"
check "x10 wheel down"   "2097152 4 5"   "$(x10 97 37 38)"
check "x10 button>5"     "268435456 4 5" "$(x10 192 37 38)"
check "x10 release (nothing pressed)" "268435456 4 5" "$(x10 35 37 38)"
check "x10 left release (pressed)" "1 4 5" "$(
  ( _BC_X10_CB=32; _BC_X10_CX=37; _BC_X10_CY=38; _bc_mouse_decode_x10
    _BC_X10_CB=35; _bc_mouse_decode_x10
    printf '%s %s %s' "$_BC_EVT_BSTATE" "$_BC_EVT_X" "$_BC_EVT_Y" ) )"

# --- E. mouse run merging (process-substitution stdin, no tty) ---
# First event is decoded in-shell; the rest is fed to _bc_mouse_run via
# process substitution so BC_MEVENTS/BC_PENDING_IN stay in this subshell.
check "run click" "[0 4 5 4]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_SGR_B=0 _BC_SGR_X=5 _BC_SGR_Y=6 _BC_SGR_FINAL=M _bc_mouse_decode_sgr
    _bc_mouse_run < <(printf '%s' "$E[<0;5;6m")
    printf '[%s]' "${BC_MEVENTS[*]}" ) )"
check "run double" "[0 4 5 8]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_SGR_B=0 _BC_SGR_X=5 _BC_SGR_Y=6 _BC_SGR_FINAL=M _bc_mouse_decode_sgr
    _bc_mouse_run < <(printf '%s' "$E[<0;5;6m$E[<0;5;6M$E[<0;5;6m")
    printf '[%s]' "${BC_MEVENTS[*]}" ) )"
check "run triple" "[0 4 5 16]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_SGR_B=0 _BC_SGR_X=5 _BC_SGR_Y=6 _BC_SGR_FINAL=M _bc_mouse_decode_sgr
    _bc_mouse_run < <(printf '%s' "$E[<0;5;6m$E[<0;5;6M$E[<0;5;6m$E[<0;5;6M$E[<0;5;6m")
    printf '[%s]' "${BC_MEVENTS[*]}" ) )"
check "run double diff-pos" "[0 8 9 8]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_SGR_B=0 _BC_SGR_X=5 _BC_SGR_Y=6 _BC_SGR_FINAL=M _bc_mouse_decode_sgr
    _bc_mouse_run < <(printf '%s' "$E[<0;5;6m$E[<0;9;10M$E[<0;9;10m")
    printf '[%s]' "${BC_MEVENTS[*]}" ) )"
check "run wheel" "[0 4 5 65536]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_SGR_B=64 _BC_SGR_X=5 _BC_SGR_Y=6 _BC_SGR_FINAL=M _bc_mouse_decode_sgr
    _bc_mouse_run < <(printf '')
    printf '[%s]' "${BC_MEVENTS[*]}" ) )"
check "run x10 click" "[0 4 5 4]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_X10_CB=32 _BC_X10_CX=37 _BC_X10_CY=38 _bc_mouse_decode_x10
    _bc_mouse_run < <(printf '\x1bM\x23\x25\x26')
    printf '[%s]' "${BC_MEVENTS[*]}" ) )"
check "run ends on key, pushback" "[0 4 5 4] P=[a]" "$(
  ( _bc_mouse_mask2 268435455
    _BC_SGR_B=0 _BC_SGR_X=5 _BC_SGR_Y=6 _BC_SGR_FINAL=M _bc_mouse_decode_sgr
    _bc_mouse_run < <(printf '%s' "$E[<0;5;6ma")
    printf '[%s] P=[%s]' "${BC_MEVENTS[*]}" "$BC_PENDING_IN" ) )"

# --- F. terminfo key table ---
kt() { ( TERM=$1
          source "$REPO/lib/bc.sh"
          _bc_load_keytable
          _bc_ti_lookup "$2" && printf '%s' "$_BC_TI_KEY" || printf 'none' ) }
ktp() { ( TERM=$1
          source "$REPO/lib/bc.sh"
          _bc_load_keytable
          _bc_ti_prefix "$2" && printf yes || printf no ) }
check "xterm UP"    "259" "$(kt xterm-256color "${E}OA")"
check "xterm DOWN"  "258" "$(kt xterm-256color "${E}OB")"
check "xterm LEFT"  "260" "$(kt xterm-256color "${E}OD")"
check "xterm RIGHT" "261" "$(kt xterm-256color "${E}OC")"
check "xterm HOME"  "262" "$(kt xterm-256color "${E}OH")"
check "xterm END"   "360" "$(kt xterm-256color "${E}OF")"
check "xterm F1"    "265" "$(kt xterm-256color "${E}OP")"
check "xterm F10"   "274" "$(kt xterm-256color "${E}[21~")"
check "xterm F12"   "276" "$(kt xterm-256color "${E}[24~")"
check "xterm IC"    "331" "$(kt xterm-256color "${E}[2~")"
check "xterm DC"    "330" "$(kt xterm-256color "${E}[3~")"
check "xterm PPAGE" "339" "$(kt xterm-256color "${E}[5~")"
check "xterm NPAGE" "338" "$(kt xterm-256color "${E}[6~")"
check "xterm HOME-not-CSI" "none" "$(kt xterm-256color "${E}[1~")"
check "screen HOME"  "262" "$(kt screen-256color "${E}[1~")"
check "screen END"   "360" "$(kt screen-256color "${E}[4~")"
check "screen LEFT"  "260" "$(kt screen-256color "${E}OD")"
check "screen HOME-not-ESC" "none" "$(kt screen-256color "${E}OH")"
check "prefix CSI"  "yes" "$(ktp xterm-256color "${E}[")"
check "prefix CSI5" "yes" "$(ktp xterm-256color "${E}[5")"
check "prefix CSI-A" "no"  "$(ktp xterm-256color "${E}[A")"
check "prefix ESC-OA" "no"  "$(ktp xterm-256color "${E}OA")"

# --- G. new API: ACS constants (Unicode convention) ---
check "ACS ULCORNER" "┌" "$ACS_ULCORNER"
check "ACS LLCORNER" "└" "$ACS_LLCORNER"
check "ACS URCORNER" "┐" "$ACS_URCORNER"
check "ACS LRCORNER" "┘" "$ACS_LRCORNER"
check "ACS HLINE"    "─" "$ACS_HLINE"
check "ACS VLINE"    "│" "$ACS_VLINE"
check "ACS PLUS"     "┼" "$ACS_PLUS"
check "ACS S3"       "│" "$ACS_S3"
check "ACS S7"       "─" "$ACS_S7"
check "ACS CKBOARD"  "▒" "$ACS_CKBOARD"
check "ACS DEGREE"   "°" "$ACS_DEGREE"
check "ACS PLMINUS"  "±" "$ACS_PLMINUS"
check "ACS BULLET"   "•" "$ACS_BULLET"
check "ACS LARROW"   "←" "$ACS_LARROW"
check "ACS RARROW"   "→" "$ACS_RARROW"
check "ACS DARROW"   "↓" "$ACS_DARROW"
check "ACS UARROW"   "↑" "$ACS_UARROW"
check "ACS BOARD"    "▒" "$ACS_BOARD"
check "ACS LANTERN"  "▓" "$ACS_LANTERN"
check "ACS BLOCK"    "█" "$ACS_BLOCK"
check "ACS LEQUAL"   "≤" "$ACS_LEQUAL"
check "ACS GEQUAL"   "≥" "$ACS_GEQUAL"
check "ACS PI"       "π" "$ACS_PI"
check "ACS NEQUAL"   "≠" "$ACS_NEQUAL"
check "ACS STERLING" "£" "$ACS_STERLING"

# --- H. new API: window-state functions (headless) ---
# run $1 in a fresh subshell with stdscr (24x80) initialised at the origin
scr() { ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; BC_WKEYPAD[0]=1
          BC_CURR=0; eval "$1"; ); }
# read a run of cells from a window's buffer (default space)
row() { local w=$1 y=$2 x0=$3 len=$4 out="" x buf
        buf=${BC_WBUF[$w]}
        for (( x = x0; x < x0 + len; x++ )); do out+="${BC_C["$buf/$y $x"]- }"; done
        printf '%s' "$out"; }

check "getyx"              "5 7"         "$(scr 'wmove 0 5 7; getyx 0; printf "%s %s" "$BC_GCY" "$BC_GCX"')"
check "keypad on"          "1"           "$(scr 'keypad 0 1; printf "%s" "${BC_WKEYPAD[0]}"')"
check "keypad off"         "0"           "$(scr 'keypad 0 0; printf "%s" "${BC_WKEYPAD[0]}"')"
check "printw fmt"         "Hello World" "$(scr 'printw "Hello %s" World; row 0 0 0 11')"
check "mvprintw fmt"       "Value 42"    "$(scr 'mvprintw 2 3 "Value %d" 42; row 0 2 3 8')"
check "mvwprintw offset"   "X7"          "$( ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; _bc_init_window 5 2 3 10 20; BC_CURR=0; mvwprintw 5 1 2 "X%d" 7; row 5 3 5 2 ) )"
check "mvhline"            "#####"       "$(scr 'mvhline 0 0 "#" 5; row 0 0 0 5')"
check "mvvline"            "****"        "$(scr 'mvvline 0 0 "*" 4; for (( y = 0; y < 4; y++ )); do printf "%s" "${BC_C["0/$y 0"]- }"; done')"
check "clrtoeol before"    "C"           "$(scr 'addstr "ABCDEFGHIJ"; wmove 0 0 3; clrtoeol; printf "%s" "${BC_C["0/0 2"]}"')"
check "clrtoeol at cursor" " "           "$(scr 'addstr "ABCDEFGHIJ"; wmove 0 0 3; clrtoeol; printf "%s" "${BC_C["0/0 3"]}"')"
check "clrtoeol after"     " "           "$(scr 'addstr "ABCDEFGHIJ"; wmove 0 0 3; clrtoeol; printf "%s" "${BC_C["0/0 9"]}"')"
check "mvchgat char kept"  "B"           "$(scr 'addstr "ABCDE"; mvchgat 0 1 -1 8 5; printf "%s" "${BC_C["0/0 1"]}"')"
check "mvchgat attr set"   "8"           "$(scr 'addstr "ABCDE"; mvchgat 0 1 -1 8 5; printf "%s" "${BC_A["0/0 1"]}"')"
check "mvchgat pair set"   "5"           "$(scr 'addstr "ABCDE"; mvchgat 0 1 -1 8 5; printf "%s" "${BC_P["0/0 1"]}"')"
check "mvchgat pre-range"  "0"           "$(scr 'addstr "ABCDE"; mvchgat 0 1 -1 8 5; printf "%s" "${BC_A["0/0 0"]:-0}"')"
check "mvchgat no cursor mv" "0 1"       "$(scr 'addstr "ABCDE"; mvchgat 0 1 -1 8 5; printf "%s %s" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "wchgat from cursor" "8"           "$(scr 'addstr "ABCDE"; wmove 0 0 2; wchgat 0 -1 8 3; printf "%s" "${BC_A["0/0 2"]}"')"
check "chgat bounded n"    "8 0"         "$(scr 'addstr "ABCDE"; wmove 0 0 0; chgat 2 8 2; printf "%s %s" "${BC_A["0/0 1"]}" "${BC_A["0/0 2"]:-0}"')"
check "_bc_mark_all count" "1920"        "$(scr '_bc_mark_all 0; n=0; for k in "${!BC_MK[@]}"; do [[ $k == "0/"* ]] && n=$((n+1)); done; printf "%s" "$n"')"
check "def_prog_mode rc"   "0"           "$( ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; def_prog_mode; printf "%s" "$?" ) )"
check "reset_prog_mode redraw" "1920"    "$( ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; reset_prog_mode >/dev/null 2>&1; n=0; for k in "${!BC_MK[@]}"; do [[ $k == "0/"* ]] && n=$((n+1)); done; printf "%s" "$n" ) )"

# --- H2. mouse coordinate API (headless) ---
win5() { ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; _bc_init_window 5 2 3 10 20; BC_CURR=0; eval "$1"; ); }
check "wenclose stdscr inside"   "yes"     "$(scr 'wenclose 0 23 79 && echo yes || echo no')"
check "wenclose stdscr outside"  "no"      "$(scr 'wenclose 0 24 79 && echo yes || echo no')"
check "wenclose win inside"      "yes"     "$(win5 'wenclose 5 11 22 && echo yes || echo no')"
check "wenclose win outside"     "no"      "$(win5 'wenclose 5 12 22 && echo yes || echo no')"
check "wenclose honors yoffset"  "yes"     "$(win5 'BC_WYOFF[5]=1; wenclose 5 12 22 && echo yes || echo no')"
check "wmouse_trafo to screen"   "2 3"     "$(win5 'wmouse_trafo 5 0 0 1; printf "%s %s" "$BC_MT_Y" "$BC_MT_X"')"
check "wmouse_trafo to screen br" "11 22"  "$(win5 'wmouse_trafo 5 9 19 1; printf "%s %s" "$BC_MT_Y" "$BC_MT_X"')"
check "wmouse_trafo to screen out" "no"    "$(win5 'wmouse_trafo 5 10 0 1 && echo yes || echo no')"
check "wmouse_trafo from screen" "0 0"     "$(win5 'wmouse_trafo 5 2 3 0; printf "%s %s" "$BC_MT_Y" "$BC_MT_X"')"
check "wmouse_trafo from screen br" "9 19" "$(win5 'wmouse_trafo 5 11 22 0; printf "%s %s" "$BC_MT_Y" "$BC_MT_X"')"
check "wmouse_trafo from screen out" "no"  "$(win5 'wmouse_trafo 5 1 3 0 && echo yes || echo no')"
check "wmouse_trafo false keeps vars" "keep keep" "$(win5 'BC_MT_Y=keep BC_MT_X=keep; wmouse_trafo 5 10 0 1; printf "%s %s" "$BC_MT_Y" "$BC_MT_X"')"
check "mouse_trafo stdscr"       "5 7"     "$(scr 'mouse_trafo 5 7 1; printf "%s %s" "$BC_MT_Y" "$BC_MT_X"')"

# --- H3. core API batch (headless) ---
check "wclrtobot keeps before"   "C"       "$(scr 'addstr "ABCDEFGHIJ"; wmove 0 0 3; wclrtobot; printf "%s" "${BC_C["0/0 2"]}"')"
check "wclrtobot clears cursor"  " "       "$(scr 'addstr "ABCDEFGHIJ"; wmove 0 0 3; wclrtobot; printf "%s" "${BC_C["0/0 3"]}"')"
check "wclrtobot clears line"    " "       "$(scr 'addstr "ABCDEFGHIJ"; wmove 0 0 3; wclrtobot; printf "%s" "${BC_C["0/0 9"]}"')"
check "wclrtobot clears below"   " "       "$(scr 'addstr "ABCDEFGHIJ"; mvaddstr 1 0 "XYZ"; wmove 0 0 3; wclrtobot; printf "%s" "${BC_C["0/1 0"]}"')"
check "wclrtobot cursor kept"    "0 3"     "$(scr 'addstr "ABC"; wmove 0 0 3; wclrtobot; getyx 0; printf "%s %s" "$BC_GCY" "$BC_GCX"')"
check "erase clears"             " "       "$(scr 'addstr A; erase; printf "%s" "${BC_C["0/0 0"]}"')"
check "getcury"                  "5"       "$(scr 'wmove 0 5 7; getcury 0; printf "%s" "$BC_GCY"')"
check "getcurx"                  "7"       "$(scr 'wmove 0 5 7; getcurx 0; printf "%s" "$BC_GCX"')"
check "getbegy win"              "2"       "$(win5 'getbegy 5; printf "%s" "$BC_GBY"')"
check "getbegx win"              "3"       "$(win5 'getbegx 5; printf "%s" "$BC_GBX"')"
check "getmaxy win"              "9"       "$(win5 'getmaxy 5; printf "%s" "$BC_GMY"')"
check "getmaxx win"              "19"      "$(win5 'getmaxx 5; printf "%s" "$BC_GMX"')"
check "getattrs"                 "8"       "$(scr 'wattron 0 8; getattrs 0; printf "%s" "$BC_GA"')"
check "getbkgd"                  "x 1 2"   "$(scr 'wbkgd 0 x 1 2; getbkgd 0; printf "%s %s %s" "$BC_GBKG" "$BC_GBKG_A" "$BC_GBKG_P"')"
check "wattr_set get"            "8 3"     "$(scr 'wattr_set 0 8 3; wattr_get 0; printf "%s %s" "$BC_AG" "$BC_AP"')"
check "wattr_on"                 "12"      "$(scr 'wattr_set 0 8 0; wattr_on 0 4; wattr_get 0; printf "%s" "$BC_AG"')"
check "wattr_off"                "8"       "$(scr 'wattr_set 0 12 0; wattr_off 0 4; wattr_get 0; printf "%s" "$BC_AG"')"
check "attr_on stdscr"           "4"       "$(scr 'attr_on 4; getattrs 0; printf "%s" "$BC_GA"')"
check "touchwin touched"         "1"       "$(scr 'touchwin 0; is_wintouched 0 && echo 1 || echo 0')"
check "untouchwin clean"         "0"       "$(scr 'touchwin 0; untouchwin 0; is_wintouched 0 && echo 1 || echo 0')"
check "touchline touched"        "1"       "$(scr 'touchline 0 1 1; is_linetouched 0 1 && echo 1 || echo 0')"
check "touchline other clean"    "0"       "$(scr 'touchline 0 1 1; is_linetouched 0 2 && echo 1 || echo 0')"
check "wtouchln untouch"         "0"       "$(scr 'touchwin 0; wtouchln 0 1 1 0; is_linetouched 0 1 && echo 1 || echo 0')"
check "wtouchln keeps other"     "1"       "$(scr 'touchwin 0; wtouchln 0 1 1 0; is_linetouched 0 2 && echo 1 || echo 0')"
check "wtimeout nonblocking"     "1"       "$(scr 'wtimeout 0 0; printf "%s" "${BC_WDELAY[0]}"')"
check "wtimeout blocking"        "0"       "$(scr 'wtimeout 0 -1; printf "%s" "${BC_WDELAY[0]}"')"
check "wtimeout stores delay"    "250"     "$(scr 'wtimeout 0 250; printf "%s" "${BC_WTIMEOUT[0]}"')"
check "wtimeout delay blocking"  "0"       "$(scr 'wtimeout 0 250; printf "%s" "${BC_WDELAY[0]}"')"
check "halfdelay sets tenths"    "5"       "$(scr 'halfdelay 5; printf "%s" "$BC_HALFTENTHS"')"
check "halfdelay sets timeout"   "500"     "$(scr 'halfdelay 5; printf "%s" "${BC_WTIMEOUT[0]}"')"
check "halfdelay not nodelay"    "0"       "$(scr 'halfdelay 5; printf "%s" "${BC_WDELAY[0]}"')"
check "halfdelay new window"     "500"     "$(scr 'halfdelay 5; newwin 5 5 1 1; printf "%s" "${BC_WTIMEOUT[$bc_win]}"')"
check "wresize maxy"             "9"       "$(scr 'wresize 0 10 20; getmaxy 0; printf "%s" "$BC_GMY"')"
check "wresize maxx"             "19"      "$(scr 'wresize 0 10 20; getmaxx 0; printf "%s" "$BC_GMX"')"
check "resize_term maxy"         "9"       "$(scr 'resize_term 10 20; getmaxy 0; printf "%s" "$BC_GMY"')"
check "is_term_resized true"     "yes"     "$(scr 'is_term_resized 10 20 && echo yes || echo no')"
check "is_term_resized false"    "no"      "$(scr 'is_term_resized 24 80 && echo yes || echo no')"
check "wresize touches"          "1"       "$(scr 'untouchwin 0; wresize 0 10 20; is_wintouched 0 && echo 1 || echo 0')"
check "border corners"           "┌┐└┘"    "$(scr 'border; row 0 0 0 1; row 0 0 79 1; row 0 23 0 1; row 0 23 79 1')"
check "border custom hline"      "-"       "$(scr 'border "#" "#" "-" "-"; row 0 0 1 1')"
check "box_set custom corners"   "LRBT"    "$(scr 'box_set 0 "#" "-" "L" "R" "B" "T"; row 0 0 0 1; row 0 0 79 1; row 0 23 0 1; row 0 23 79 1')"
check "mvwborder moves cursor"   "5 7"     "$(scr 'mvwborder 0 5 7; getyx 0; printf "%s %s" "$BC_GCY" "$BC_GCX"')"
check "wgetnstr limit"           "abc"     "$(scr 'BC_PENDING_IN=$'"'"'abc\r'"'"'; wgetnstr 0 3 >/dev/null; printf "%s" "$bc_str"')"
check "wgetnstr pushback"        "d"       "$(scr 'BC_PENDING_IN=$'"'"'abcd'"'"'; wgetnstr 0 3 >/dev/null; printf "%s" "$BC_PENDING_IN"')"
check "wgetnstr echoes"          "abc"     "$(scr 'BC_PENDING_IN=$'"'"'abc\r'"'"'; wgetnstr 0 3 >/dev/null; row 0 0 0 3')"
check "wgetnstr no echo beyond"  "abc "    "$(scr 'BC_PENDING_IN=$'"'"'abcd\r'"'"'; wgetnstr 0 3 >/dev/null; row 0 0 0 4')"
check "mvwgetnstr moves reads"   "abc"     "$(scr 'BC_PENDING_IN=$'"'"'abc\r'"'"'; mvwgetnstr 0 2 3 3 >/dev/null; row 0 2 3 3')"

# --- H4. window/chtype/string API (headless) ---
check "winch at cursor"          "B"       "$(scr 'mvaddstr 0 0 AB; wmove 0 0 1; winch 0; printf "%s" "$wch"')"
check "inch stdscr"              "B"       "$(scr 'mvaddstr 0 0 AB; move 0 1; inch; printf "%s" "$wch"')"
check "instr to end"             "79"      "$(scr 'mvaddstr 0 0 ABC; move 0 1; instr 0; printf "%s" "${#bc_str}"')"
check "innstr bounded"           "BC"      "$(scr 'mvaddstr 0 0 ABCD; move 0 1; innstr 0 2; printf "%s" "$bc_str"')"
check "mvwinstr moves reads"     "79"      "$(scr 'mvaddstr 0 0 ABC; mvwinstr 0 0 1; printf "%s" "${#bc_str}"')"
check "mvwinnstr moves reads"    "BC"      "$(scr 'mvaddstr 0 0 ABCD; mvwinnstr 0 0 1 2; printf "%s" "$bc_str"')"
check "inchnstr array"           "BC C"    "$(scr 'mvaddstr 0 0 ABC; move 0 1; inchnstr 0 2; printf "%s %s" "$bc_str" "${bc_chstr[1]}"')"
check "inchstr to end"           "79"      "$(scr 'mvaddstr 0 0 ABC; move 0 1; inchstr 0; printf "%s" "${#bc_str}"')"
check "mvwinchstr moves reads"   "79"      "$(scr 'mvaddstr 0 0 ABC; mvwinchstr 0 0 1; printf "%s" "${#bc_str}"')"
check "addchstr"                 "ABC"     "$(scr 'addchstr ABC; row 0 0 0 3')"
check "addchnstr bounded"        "ABC"     "$(scr 'addchnstr ABCD 3; row 0 0 0 3')"
check "mvwaddchstr moves writes" "XY"      "$(scr 'mvwaddchstr 0 1 2 XY; row 0 1 2 2')"
check "mvwaddchnstr bounded"     "XY"      "$(scr 'mvwaddchnstr 0 1 2 XYZ 2; row 0 1 2 2')"
check "insch shifts right"       "AXBC"    "$(scr 'mvaddstr 0 0 ABC; wmove 0 0 1; insch X; row 0 0 0 4')"
check "delch shifts left"        "AC "     "$(scr 'mvaddstr 0 0 ABC; wmove 0 0 1; delch; row 0 0 0 3')"
check "winsnstr inserts"         "AXYB"    "$(scr 'mvaddstr 0 0 ABC; wmove 0 0 1; winsnstr 0 2 XY; row 0 0 0 4')"
check "winsstr inserts"          "AXYB"    "$(scr 'mvaddstr 0 0 ABC; wmove 0 0 1; winsstr 0 XY; row 0 0 0 4')"
check "mvwinsnstr moves inserts" "AXYB"    "$(scr 'mvaddstr 0 0 ABC; mvwinsnstr 0 0 1 2 XY; row 0 0 0 4')"
check "mvwinsstr moves inserts"  "AXYB"    "$(scr 'mvaddstr 0 0 ABC; mvwinsstr 0 0 1 XY; row 0 0 0 4')"
check "deleteln removes line"    "C"       "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; wmove 0 1 0; deleteln; row 0 1 0 1')"
check "insertln inserts line"    "B"       "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; wmove 0 1 0; insertln; row 0 2 0 1')"
check "insdelln inserts"         "B"       "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; wmove 0 1 0; insdelln 1; row 0 2 0 1')"
check "insdelln deletes"         "C"       "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; wmove 0 1 0; insdelln -1; row 0 1 0 1')"
check "copywin copies"           "AB"      "$(scr 'newwin 2 2 0 0; src=$bc_win; newwin 2 2 5 5; dst=$bc_win; mvwaddstr $src 0 0 AB; copywin $src $dst 0 0 0 0 1 1 0; row $dst 5 5 2')"
check "copywin overlay skips blank" "AC"   "$(scr 'newwin 2 2 0 0; src=$bc_win; newwin 2 2 5 5; dst=$bc_win; mvwaddch $src 0 0 A; mvwaddstr $dst 0 0 BC; copywin $src $dst 0 0 0 0 1 1 1; row $dst 5 5 2')"
check "copywin overwrite blanks" "A "      "$(scr 'newwin 2 2 0 0; src=$bc_win; newwin 2 2 5 5; dst=$bc_win; mvwaddch $src 0 0 A; mvwaddstr $dst 0 0 BC; copywin $src $dst 0 0 0 0 1 1 0; row $dst 5 5 2')"
check "overlay copies nonblank"  "AC"      "$(scr 'newwin 2 2 0 0; src=$bc_win; newwin 2 2 5 5; dst=$bc_win; mvwaddch $src 0 0 A; mvwaddstr $dst 0 0 BC; overlay $src $dst; row $dst 5 5 2')"
check "overwrite copies all"     "A "      "$(scr 'newwin 2 2 0 0; src=$bc_win; newwin 2 2 5 5; dst=$bc_win; mvwaddch $src 0 0 A; mvwaddstr $dst 0 0 BC; overwrite $src $dst; row $dst 5 5 2')"
check "mvwin moves origin"       "5 5"     "$(scr 'newwin 3 3 0 0; w=$bc_win; mvwin $w 5 5; getbegy $w; getbegx $w; printf "%s %s" "$BC_GBY" "$BC_GBX"')"
check "getpary parent"           "2"       "$(scr 'newwin 5 5 2 3; p=$bc_win; derwin $p 2 2 4 5; c=$bc_win; getpary $c; printf "%s" "$BC_GPY"')"
check "getparx parent"           "3"       "$(scr 'newwin 5 5 2 3; p=$bc_win; derwin $p 2 2 4 5; c=$bc_win; getparx $c; printf "%s" "$BC_GPX"')"
check "getpary stdscr"           "-1"      "$(scr 'getpary 0; printf "%s" "$BC_GPY"')"
check "wgetparent subwin"        "1 2"     "$(scr 'newwin 5 5 2 3; p=$bc_win; derwin $p 2 2 4 5; c=$bc_win; wgetparent $c; printf "%s %s" "$bc_parent" "$c"')"
check "is_subwin true"           "yes"     "$(scr 'newwin 5 5 2 3; p=$bc_win; derwin $p 2 2 4 5; c=$bc_win; is_subwin $c && echo yes || echo no')"
check "is_subwin false"          "no"      "$(scr 'newwin 5 5 2 3; p=$bc_win; is_subwin $p && echo yes || echo no')"
check "wgetscrreg set"           "2 5"     "$(scr 'wsetscrreg 0 2 5; wgetscrreg 0; printf "%s %s" "$bc_top" "$bc_bottom"')"
check "wgetscrreg unset"         "1 0 23"  "$(scr 'wgetscrreg 0; printf "%s %s %s" "$?" "$bc_top" "$bc_bottom"')"
check "wgetdelay nodelay"        "1"       "$(scr 'nodelay 0 1; wgetdelay 0; printf "%s" "$bc_delay"')"
check "is_nodelay true"          "yes"     "$(scr 'nodelay 0 1; is_nodelay 0 && echo yes || echo no')"
check "is_notimeout true"        "yes"     "$(scr 'notimeout 0 1; is_notimeout 0 && echo yes || echo no')"
check "is_notimeout not nodelay" "no"      "$(scr 'notimeout 0 1; is_nodelay 0 && echo yes || echo no')"
check "is_scrollok true"         "yes"     "$(scr 'scrollok 0 1; is_scrollok 0 && echo yes || echo no')"
check "clearok flag"             "yes"     "$(scr 'clearok 0 1; is_cleared 0 && echo yes || echo no')"
check "idcok flag"               "yes"     "$(scr 'idcok 0 1; is_idcok 0 && echo yes || echo no')"
check "idlok flag"               "yes"     "$(scr 'idlok 0 1; is_idlok 0 && echo yes || echo no')"
check "immedok flag"             "yes"     "$(scr 'immedok 0 1; is_immedok 0 && echo yes || echo no')"
check "leaveok flag"             "yes"     "$(scr 'leaveok 0 1; is_leaveok 0 && echo yes || echo no')"
check "syncok flag"              "yes"     "$(scr 'syncok 0 1; is_syncok 0 && echo yes || echo no')"

# --- H5. graphics/background/color/misc API (headless) ---
check "whline at cursor"         "#####"   "$(scr 'wmove 0 0 0; whline 0 "#" 5; row 0 0 0 5')"
check "wvline at cursor"         "***"     "$(scr 'wmove 0 0 0; wvline 0 "*" 3; row 0 0 0 1; row 0 1 0 1; row 0 2 0 1')"
check "hline stdscr"             "#####"   "$(scr 'move 0 0; hline "#" 5; row 0 0 0 5')"
check "vline stdscr"             "***"     "$(scr 'move 0 0; vline "*" 3; row 0 0 0 1; row 0 1 0 1; row 0 2 0 1')"
check "mvwhline moves writes"    "###"     "$(scr 'mvwhline 0 1 2 "#" 3; row 0 1 2 3')"
check "mvwvline moves writes"    "***"     "$(scr 'mvwvline 0 1 2 "*" 3; row 0 1 2 1; row 0 2 2 1; row 0 3 2 1')"
check "hline_set"                "#####"   "$(scr 'move 0 0; hline_set "#" 5; row 0 0 0 5')"
check "mvwhline_set moves"       "###"     "$(scr 'mvwhline_set 0 1 2 "#" 3; row 0 1 2 3')"
check "mvwvline_set moves"       "***"     "$(scr 'mvwvline_set 0 1 2 "*" 3; row 0 1 2 1; row 0 2 2 1; row 0 3 2 1')"
check "wbkgdset get"             "x 1 2"   "$(scr 'wbkgdset 0 x 1 2; getbkgd 0; printf "%s %s %s" "$BC_GBKG" "$BC_GBKG_A" "$BC_GBKG_P"')"
check "bkgdset get"              "x 1 2"   "$(scr 'bkgdset x 1 2; getbkgd 0; printf "%s %s %s" "$BC_GBKG" "$BC_GBKG_A" "$BC_GBKG_P"')"
check "bkgrnd get"               "x 1 2"   "$(scr 'bkgrnd 0 x 1 2; getbkgd 0; printf "%s %s %s" "$BC_GBKG" "$BC_GBKG_A" "$BC_GBKG_P"')"
check "bkgrndset get"            "x 1 2"   "$(scr 'bkgrndset 0 x 1 2; getbkgd 0; printf "%s %s %s" "$BC_GBKG" "$BC_GBKG_A" "$BC_GBKG_P"')"
check "getbkgrnd"                "x 1 2"   "$(scr 'wbkgd 0 x 1 2; getbkgrnd 0; printf "%s %s %s" "$wch" "$wcha" "$wchp"')"
check "init_color content"       "100 200 300" "$(scr 'BC_COLORS=16; init_color 1 100 200 300; color_content 1; printf "%s %s %s" "$BC_CR" "$BC_CG" "$BC_CB"')"
check "init_color invalid"       "1"       "$(scr 'BC_COLORS=16; init_color 16 0 0 0; printf "%s" "$?"')"
check "color_content invalid"    "1"       "$(scr 'BC_COLORS=16; color_content 16; printf "%s" "$?"')"
check "extended_color_content"   "100 200 300" "$(scr 'BC_COLORS=16; init_extended_color 1 100 200 300; extended_color_content 1; printf "%s %s %s" "$BC_CR" "$BC_CG" "$BC_CB"')"
check "can_change_color false"   "no"      "$(scr 'can_change_color && echo yes || echo no')"
check "can_change_color true"    "yes"     "$(scr 'BC_CAN_CHANGE_COLOR=1; can_change_color && echo yes || echo no')"
check "assume_default_colors"    "8 -1"    "$(scr 'assume_default_colors 8 -1; printf "%s %s" "$BC_DEFAULT_FG" "$BC_DEFAULT_BG"')"
check "pair_content"             "1 2"     "$(scr 'BC_PAIRS=16; init_pair 3 1 2; pair_content 3; printf "%s %s" "$BC_CPF" "$BC_CPB"')"
check "pair_content invalid"     "1"       "$(scr 'BC_PAIRS=16; pair_content 17; printf "%s" "$?"')"
check "extended_pair_content"    "1 2"     "$(scr 'BC_PAIRS=16; init_extended_pair 3 1 2; extended_pair_content 3; printf "%s %s" "$BC_EPF" "$BC_EPB"')"
check "find_pair"                "3"       "$(scr 'BC_PAIRS=16; init_pair 3 1 2; find_pair 1 2')"
check "find_pair missing"        "no"      "$(scr 'BC_PAIRS=16; find_pair 1 2 && echo yes || echo no')"
check "alloc_pair"               "1 1 2"   "$(scr 'BC_PAIRS=16; alloc_pair 1 2 >/dev/null; pair_content $bc_pair; printf "%s %s %s" "$bc_pair" "$BC_CPF" "$BC_CPB"')"
check "alloc_pair full"          "1"       "$(scr 'BC_PAIRS=1; init_pair 1 1 2; alloc_pair 3 4 >/dev/null; printf "%s" "$?"')"
check "free_pair"                "no"      "$(scr 'BC_PAIRS=16; init_pair 3 1 2; free_pair 3; find_pair 1 2 && echo yes || echo no')"
check "free_pair invalid"        "1"       "$(scr 'BC_PAIRS=16; free_pair 3; printf "%s" "$?"')"
check "color_set"                "5"       "$(scr 'BC_PAIRS=16; color_set 5; printf "%s" "${BC_WCURP[0]}"')"
check "color_set invalid"        "1"       "$(scr 'BC_PAIRS=16; color_set 17; printf "%s" "$?"')"
check "PAIR_NUMBER"              "3"       "$(scr 'PAIR_NUMBER 515')"
check "isendwin before start"    "yes"     "$(scr 'isendwin && echo yes || echo no')"
check "use_window switches"      "1 0"     "$(scr 'newwin 2 2 1 1; w=$bc_win; use_window $w; printf "%s %s" "$BC_CURR" "$bc_win"')"
check "use_window sets newscr"   "1"       "$(scr 'newwin 2 2 1 1; w=$bc_win; use_window $w; printf "%s" "$newscr"')"
check "has_ic"                   "yes"     "$(scr 'has_ic && echo yes || echo no')"
check "has_il"                   "yes"     "$(scr 'has_il && echo yes || echo no')"
check "erasechar"                "127"     "$(scr 'erasechar')"
check "killchar"                 "21"      "$(scr 'killchar')"
check "erasewchar"               "127"     "$(scr 'erasewchar; printf "%s" "$BC_ERASEWCHAR"')"
check "killwchar"                "21"      "$(scr 'killwchar; printf "%s" "$BC_KILLWCHAR"')"
check "meta on"                  "1"       "$(scr 'meta 0 1; printf "%s" "$BC_META"')"
check "meta off"                 "0"       "$(scr 'meta 0 1; meta 0 0; printf "%s" "$BC_META"')"
check "filter"                   "1"       "$(scr 'filter; printf "%s" "$BC_FILTER"')"
check "nofilter"                 "0"       "$(scr 'filter; nofilter; printf "%s" "$BC_FILTER"')"
check "intrflush rc"             "0"       "$(scr 'intrflush 0 1; printf "%s" "$?"')"
check "qiflush rc"               "0"       "$(scr 'qiflush; printf "%s" "$?"')"
check "noqiflush rc"             "0"       "$(scr 'noqiflush; printf "%s" "$?"')"
check "dupwin copies"            "AB"      "$(scr 'newwin 2 2 5 5; src=$bc_win; mvwaddstr $src 0 0 AB; dupwin $src; dst=$bc_win; row $dst 5 5 2')"
check "dupwin independent"       "AB"      "$(scr 'newwin 2 2 5 5; src=$bc_win; mvwaddstr $src 0 0 AB; dupwin $src; dst=$bc_win; mvwaddstr $src 0 0 C; row $dst 5 5 2')"
check "dupwin cursor"            "1 1"     "$(scr 'newwin 2 2 5 5; src=$bc_win; wmove $src 1 1; dupwin $src; dst=$bc_win; printf "%s %s" "${BC_WAY[$dst]}" "${BC_WAX[$dst]}"')"

# --- H6. pad API (headless) ---
check "newpad size"              "30 100"  "$(scr 'newpad 30 100; printf "%s %s" "${BC_WH[$bc_win]}" "${BC_WW[$bc_win]}"')"
check "newpad invalid"           "1"       "$(scr 'newpad 0 10; printf "%s" "$?"')"
check "is_pad true"              "yes"     "$(scr 'newpad 3 3; is_pad $bc_win && echo yes || echo no')"
check "is_pad false"             "no"      "$(scr 'newwin 3 3 0 0; is_pad $bc_win && echo yes || echo no')"
check "is_pad uninitialized"     "no"      "$(scr 'is_pad 99 && echo yes || echo no')"
check "subpad is pad"            "yes"     "$(scr 'newpad 5 5; p=$bc_win; subpad $p 2 2 1 1; c=$bc_win; is_pad $c && echo yes || echo no')"
check "subpad parent"            "1 1"     "$(scr 'newpad 5 5; p=$bc_win; subpad $p 2 2 1 1; c=$bc_win; wgetparent $c; printf "%s %s" "$bc_parent" "$p"')"
check "subpad invalid"           "1"       "$(scr 'newpad 5 5; p=$bc_win; subpad $p 2 2 5 5; printf "%s" "$?"')"
check "pnoutrefresh copies"      "ABC"     "$(scr 'newpad 3 3; p=$bc_win; mvwaddstr $p 0 0 ABC; mvwaddstr $p 1 0 DEF; mvwaddstr $p 2 0 GHI; pnoutrefresh $p 0 0 1 1 3 3; row 0 1 1 3')"
check "pnoutrefresh clips right" "AB"      "$(scr 'newpad 3 3; p=$bc_win; mvwaddstr $p 0 0 ABC; pnoutrefresh $p 0 0 0 78 0 79; row 0 0 78 2')"
check "pnoutrefresh clips bottom" "A"      "$(scr 'newpad 3 3; p=$bc_win; mvwaddstr $p 0 0 ABC; mvwaddstr $p 1 0 DEF; pnoutrefresh $p 0 0 23 0 23 2; row 0 23 0 1')"
check "pnoutrefresh invalid"     "1"       "$(scr 'pnoutrefresh 99 0 0 0 0 0 0; printf "%s" "$?"')"
check "prefresh copies"          "ABC"     "$(scr 'newpad 3 3; p=$bc_win; mvwaddstr $p 0 0 ABC; mvwaddstr $p 1 0 DEF; mvwaddstr $p 2 0 GHI; prefresh $p 0 0 1 1 3 3 >/dev/null; row 0 1 1 3')"
check "prefresh invalid"         "1"       "$(scr 'prefresh 99 0 0 0 0 0 0 >/dev/null; printf "%s" "$?"')"
check "pechochar writes"         "A"       "$(scr 'newpad 3 3; p=$bc_win; pechochar $p A >/dev/null; row 0 0 0 1')"
check "pechochar not pad"        "1"       "$(scr 'newwin 3 3 0 0; pechochar $bc_win A >/dev/null; printf "%s" "$?"')"

# --- H7. key, sync, and window serialization API (headless) ---
check "has_key KEY_UP"           "yes"     "$(scr 'has_key $KEY_UP && echo yes || echo no')"
check "has_key KEY_RESIZE"       "yes"     "$(scr 'has_key $KEY_RESIZE && echo yes || echo no')"
check "has_key unknown"          "no"      "$(scr 'has_key 9999 && echo yes || echo no')"
check "keyname KEY_UP"           "KEY_UP"  "$(scr 'keyname $KEY_UP')"
check "keyname KEY_F1"           "KEY_F1"  "$(scr 'keyname $KEY_F1')"
check "keyname printable"        "A"       "$(scr 'keyname 65')"
check "keyname control"          "^A"      "$(scr 'keyname 1')"
check "keyname del"              "^?"      "$(scr 'keyname 127')"
check "keyname nul"              "@@"      "$(scr 'keyname 0')"
check "keyname high"             ""        "$(scr 'keyname 128')"
check "key_defined defined"      "259"     "$(scr 'seq=$(printf "\033X"); define_key "$seq" 259; key_defined "$seq"')"
check "key_defined missing"      "1"       "$(scr 'seq=$(printf "\033Y"); key_defined "$seq"; printf "%s" "$?"')"
check "keybound defined"         "259"     "$(scr 'seq=$(printf "\033X"); define_key "$seq" 259; keybound "$seq" 0')"
check "define_key new"           "260"     "$(scr 'seq=$(printf "\033Z"); define_key "$seq" 260; key_defined "$seq"')"
check "define_key ERR removes"   "no"      "$(scr 'seq=$(printf "\033["); define_key "$seq" 261; define_key "$seq" $ERR; key_defined "$seq" && echo yes || echo no')"
check "keyok previous enabled"   "1"       "$(scr 'keyok 259 0; printf "%s" "$bc_key"')"
check "keyok previous disabled"  "0"       "$(scr 'keyok 259 0; keyok 259 1; printf "%s" "$bc_key"')"
check "keyok disables lookup"    "no"      "$(scr 'seq=$(printf "\033X"); define_key "$seq" 259; keyok 259 0; _bc_ti_lookup "$seq" && echo yes || echo no')"
check "mvderwin moves relative"  "3 4"     "$(scr 'newwin 5 5 2 3; p=$bc_win; derwin $p 2 2 4 5; c=$bc_win; mvderwin $c 1 1; getbegy $c; getbegx $c; printf "%s %s" "$BC_GBY" "$BC_GBX"')"
check "wsyncup rc"               "0"       "$(scr 'wsyncup 0; printf "%s" "$?"')"
check "wsyncdown rc"             "0"       "$(scr 'wsyncdown 0; printf "%s" "$?"')"
check "syncup rc"                "0"       "$(scr 'syncup; printf "%s" "$?"')"
check "syncdown rc"              "0"       "$(scr 'syncdown; printf "%s" "$?"')"
check "putwin getwin roundtrip"  "AB"      "$(scr 'newwin 2 2 5 5; w=$bc_win; mvwaddstr $w 0 0 AB; f="$TMP/getwin_test.$$"; putwin $w "$f"; getwin "$f"; r=$bc_win; row $r 5 5 2; rm -f "$f"')"
check "putwin getwin attrs"      "8 3"     "$(scr 'newwin 1 1 5 5; w=$bc_win; mvwaddch $w 0 0 A 8 3; f="$TMP/getwin_attr.$$"; putwin $w "$f"; getwin "$f"; r=$bc_win; printf "%s %s" "${BC_A["$r/5 5"]}" "${BC_P["$r/5 5"]}"; rm -f "$f"')"
check "putwin getwin background" "X 8 3"   "$(scr 'newwin 1 1 5 5; w=$bc_win; wbkgdset $w X 8 3; f="$TMP/getwin_bg.$$"; putwin $w "$f"; getwin "$f"; r=$bc_win; printf "%s %s %s" "${BC_WBG[$r]}" "${BC_WBGA[$r]}" "${BC_WBGP[$r]}"; rm -f "$f"')"
check "putwin invalid"           "1"       "$(scr 'putwin 99 "$TMP/nope.$$"; printf "%s" "$?"')"
check "getwin missing"           "1"       "$(scr 'getwin "$TMP/missing.$$"; printf "%s" "$?"')"
check "getwin invalid"           "1"       "$(scr 'printf "nope\n" > "$TMP/bad.$$"; getwin "$TMP/bad.$$"; printf "%s" "$?"; rm -f "$TMP/bad.$$"')"

# --- H8. wide-character and misc input API (headless) ---
check "echochar writes"          "A"       "$(scr 'echochar A >/dev/null; row 0 0 0 1')"
check "wechochar writes"         "A"       "$(scr 'wechochar 0 A >/dev/null; row 0 0 0 1')"
check "wadd_wch"                 "A"       "$(scr 'wadd_wch 0 A; row 0 0 0 1')"
check "add_wch"                  "A"       "$(scr 'add_wch A; row 0 0 0 1')"
check "mvwadd_wch moves writes"  "A"       "$(scr 'mvwadd_wch 0 1 2 A; row 0 1 2 1')"
check "mvadd_wch moves writes"   "A"       "$(scr 'mvadd_wch 1 2 A; row 0 1 2 1')"
check "wadd_wchnstr"             "AB"      "$(scr 'wadd_wchnstr 0 ABC 2; row 0 0 0 2')"
check "add_wchnstr"              "AB"      "$(scr 'add_wchnstr ABC 2; row 0 0 0 2')"
check "mvwadd_wchnstr bounded"   "AB"      "$(scr 'mvwadd_wchnstr 0 1 2 ABC 2; row 0 1 2 2')"
check "mvadd_wchnstr bounded"    "AB"      "$(scr 'mvadd_wchnstr 1 2 ABC 2; row 0 1 2 2')"
check "wadd_wchstr"              "ABC"     "$(scr 'wadd_wchstr 0 ABC; row 0 0 0 3')"
check "add_wchstr"               "ABC"     "$(scr 'add_wchstr ABC; row 0 0 0 3')"
check "mvwadd_wchstr moves"      "ABC"     "$(scr 'mvwadd_wchstr 0 1 2 ABC; row 0 1 2 3')"
check "mvadd_wchstr moves"       "ABC"     "$(scr 'mvadd_wchstr 1 2 ABC; row 0 1 2 3')"
check "wecho_wchar writes"       "A"       "$(scr 'wecho_wchar 0 A >/dev/null; row 0 0 0 1')"
check "echo_wchar writes"        "A"       "$(scr 'echo_wchar A >/dev/null; row 0 0 0 1')"
check "wget_wch pending"         "A"       "$(scr 'BC_PENDING_IN=A; wget_wch 0 >/dev/null; printf "%s" "$wch"')"
check "get_wch pending"          "A"       "$(scr 'BC_PENDING_IN=A; get_wch >/dev/null; printf "%s" "$wch"')"
check "mvwget_wch moves reads"   "A 1 2"   "$(scr 'BC_PENDING_IN=A; mvwget_wch 0 1 2 >/dev/null; printf "%s %s %s" "$wch" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "mvget_wch moves reads"    "A 1 2"   "$(scr 'BC_PENDING_IN=A; mvget_wch 1 2 >/dev/null; printf "%s %s %s" "$wch" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "win_wch"                  "A 8 3"   "$(scr 'mvwaddch 0 0 0 A 8 3; wmove 0 0 0; win_wch 0; printf "%s %s %s" "$wch" "$wcha" "$wchp"')"
check "in_wch"                   "A 8 3"   "$(scr 'mvwaddch 0 0 0 A 8 3; wmove 0 0 0; in_wch; printf "%s %s %s" "$wch" "$wcha" "$wchp"')"
check "mvwin_wch moves reads"    "B 0 0"   "$(scr 'mvwaddstr 0 0 0 AB; mvwin_wch 0 0 1; printf "%s %s %s" "$wch" "$wcha" "$wchp"')"
check "mvin_wch moves reads"     "B 0 0"   "$(scr 'mvwaddstr 0 0 0 AB; mvin_wch 0 1; printf "%s %s %s" "$wch" "$wcha" "$wchp"')"
check "win_wchnstr"              "AB"      "$(scr 'mvwaddstr 0 0 0 ABC; wmove 0 0 0; win_wchnstr 0 2; printf "%s" "$bc_str"')"
check "in_wchnstr"               "AB"      "$(scr 'mvwaddstr 0 0 0 ABC; wmove 0 0 0; in_wchnstr 2; printf "%s" "$bc_str"')"
check "mvwin_wchnstr moves"      "BC"      "$(scr 'mvwaddstr 0 0 0 ABC; mvwin_wchnstr 0 0 1 2; printf "%s" "$bc_str"')"
check "mvin_wchnstr moves"       "BC"      "$(scr 'mvwaddstr 0 0 0 ABC; mvin_wchnstr 0 1 2; printf "%s" "$bc_str"')"
check "win_wchstr"               "ABC"     "$(scr 'mvwaddstr 0 0 0 ABC; wmove 0 0 0; win_wchstr 0; printf "%s" "${bc_str:0:3}"')"
check "in_wchstr"                "ABC"     "$(scr 'mvwaddstr 0 0 0 ABC; wmove 0 0 0; in_wchstr; printf "%s" "${bc_str:0:3}"')"
check "mvwin_wchstr moves"       "BC"      "$(scr 'mvwaddstr 0 0 0 ABC; mvwin_wchstr 0 0 1; printf "%s" "${bc_str:0:2}"')"
check "mvin_wchstr moves"        "BC"      "$(scr 'mvwaddstr 0 0 0 ABC; mvin_wchstr 0 1; printf "%s" "${bc_str:0:2}"')"
check "wins_wch inserts"         "XA"      "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; wins_wch 0 X; row 0 0 0 2')"
check "ins_wch inserts"          "XA"      "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; ins_wch X; row 0 0 0 2')"
check "mvwins_wch moves inserts" "XA"      "$(scr 'mvwaddstr 0 0 0 A; mvwins_wch 0 0 0 X; row 0 0 0 2')"
check "mvins_wch moves inserts"  "XA"      "$(scr 'mvwaddstr 0 0 0 A; mvins_wch 0 0 X; row 0 0 0 2')"
check "winsn_wch inserts"        "XYA"     "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; winsn_wch 0 XY 2; row 0 0 0 3')"
check "insn_wch inserts"         "XYA"     "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; insn_wch XY 2; row 0 0 0 3')"
check "mvwinsn_wch moves inserts" "XYA"    "$(scr 'mvwaddstr 0 0 0 A; mvwinsn_wch 0 0 0 XY 2; row 0 0 0 3')"
check "mvinsn_wch moves inserts" "XYA"     "$(scr 'mvwaddstr 0 0 0 A; mvinsn_wch 0 0 XY 2; row 0 0 0 3')"
check "wins_wchstr inserts"      "XYZA"    "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; wins_wchstr 0 XYZ; row 0 0 0 4')"
check "ins_wchstr inserts"       "XYZA"    "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; ins_wchstr XYZ; row 0 0 0 4')"
check "mvwins_wchstr moves inserts" "XYZA" "$(scr 'mvwaddstr 0 0 0 A; mvwins_wchstr 0 0 0 XYZ; row 0 0 0 4')"
check "mvins_wchstr moves inserts" "XYZA"  "$(scr 'mvwaddstr 0 0 0 A; mvins_wchstr 0 0 XYZ; row 0 0 0 4')"
check "wins_wchnstr inserts"     "XYA"     "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; wins_wchnstr 0 XYZ 2; row 0 0 0 3')"
check "ins_wchnstr inserts"      "XYA"     "$(scr 'mvwaddstr 0 0 0 A; wmove 0 0 0; ins_wchnstr XYZ 2; row 0 0 0 3')"
check "mvwins_wchnstr moves inserts" "XYA" "$(scr 'mvwaddstr 0 0 0 A; mvwins_wchnstr 0 0 0 XYZ 2; row 0 0 0 3')"
check "mvins_wchnstr moves inserts" "XYA"  "$(scr 'mvwaddstr 0 0 0 A; mvins_wchnstr 0 0 XYZ 2; row 0 0 0 3')"
check "unget_wch"                "A"       "$(scr 'unget_wch A; wgetch 0 >/dev/null; printf "%s" "$key"')"
check "ungetch function key"     "$KEY_F3" "$(scr 'ungetch "$KEY_F3"; wgetch 0 >/dev/null; printf "%s" "$key"')"
check "napms rc"                 "0"       "$(scr 'napms 1; printf "%s" "$?"')"
check "mcprint rc"               "1"       "$(scr 'mcprint hello; printf "%s" "$?"')"
check "setcchar getcchar"        "A 8 3"   "$(scr 'setcchar c A 8 3; getcchar "$bc_cchar"; printf "%s %s %s" "$wch" "$wcha" "$wchp"')"
check "wcwidth printable"        "1"       "$(scr 'wcwidth A; printf "%s" "$?"')"
check "wcwidth control"          "0"       "$(scr 'wcwidth "$(printf "\001")"; printf "%s" "$?"')"

# --- H9. scanw / printw / input wrappers (headless) ---
check "wprintw fmt"              "X7"      "$(win5 'wmove 5 1 2; wprintw 5 "X%d" 7; row 5 3 5 2')"
check "vwprintw fmt"             "Hello"   "$(scr 'vwprintw 0 "Hello %s" World; row 0 0 0 5')"
check "vw_printw fmt"            "Hello"   "$(scr 'vw_printw 0 "Hello %s" World; row 0 0 0 5')"
check "mvwgetch moves reads"     "A 1 2"   "$(scr 'BC_PENDING_IN=A; mvwgetch 0 1 2 >/dev/null; printf "%s %s %s" "$key" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "mvgetch moves reads"      "A 1 2"   "$(scr 'BC_PENDING_IN=A; mvgetch 1 2 >/dev/null; printf "%s %s %s" "$key" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "mvgetstr moves reads"     "abc"     "$(scr 'BC_PENDING_IN=$'"'"'abc\r'"'"'; mvgetstr 2 3 >/dev/null; row 0 2 3 3')"
check "wscanw int"               "42"      "$(scr 'BC_PENDING_IN=$'"'"'42\r'"'"'; wscanw 0 "%d" n >/dev/null; printf "%s" "$n"')"
check "wscanw count"             "2"       "$(scr 'BC_PENDING_IN=$'"'"'42 abc\r'"'"'; wscanw 0 "%d %s" n s >/dev/null; printf "%s" "$?"')"
check "wscanw assigns"           "42 abc"  "$(scr 'BC_PENDING_IN=$'"'"'42 abc\r'"'"'; wscanw 0 "%d %s" n s >/dev/null; printf "%s %s" "$n" "$s"')"
check "wscanw echoes"            "42"      "$(scr 'BC_PENDING_IN=$'"'"'42\r'"'"'; wscanw 0 "%d" n >/dev/null; row 0 0 0 2')"
check "wscanw width"             "123"     "$(scr 'BC_PENDING_IN=$'"'"'12345\r'"'"'; wscanw 0 "%3d" n >/dev/null; printf "%s" "$n"')"
check "wscanw suppress"          "abc 1"   "$(scr 'BC_PENDING_IN=$'"'"'42 abc\r'"'"'; wscanw 0 "%*d %s" s >/dev/null; printf "%s %s" "$s" "$bc_scanw_count"')"
check "wscanw char"              "a"       "$(scr 'BC_PENDING_IN=$'"'"'ab\r'"'"'; wscanw 0 "%c" c >/dev/null; printf "%s" "$c"')"
check "wscanw hex"               "31"      "$(scr 'BC_PENDING_IN=$'"'"'0x1f\r'"'"'; wscanw 0 "%x" x >/dev/null; printf "%s" "$x"')"
check "wscanw octal"             "10"      "$(scr 'BC_PENDING_IN=$'"'"'12\r'"'"'; wscanw 0 "%o" o >/dev/null; printf "%s" "$o"')"
check "wscanw auto"              "10"      "$(scr 'BC_PENDING_IN=$'"'"'012\r'"'"'; wscanw 0 "%i" i >/dev/null; printf "%s" "$i"')"
check "wscanw float"             "1.25"    "$(scr 'BC_PENDING_IN=$'"'"'1.25\r'"'"'; wscanw 0 "%f" f >/dev/null; printf "%s" "$f"')"
check "wscanw range"             "123"     "$(scr 'BC_PENDING_IN=$'"'"'123abc\r'"'"'; wscanw 0 "%[0-9]" r >/dev/null; printf "%s" "$r"')"
check "wscanw n"                 "abc 3 1" "$(scr 'BC_PENDING_IN=$'"'"'abc\r'"'"'; wscanw 0 "%s%n" s n >/dev/null; printf "%s %s %s" "$s" "$n" "$bc_scanw_count"')"
check "wscanw literal"           "42"      "$(scr 'BC_PENDING_IN=$'"'"'x=42\r'"'"'; wscanw 0 "x=%d" n >/dev/null; printf "%s" "$n"')"
check "wscanw mismatch"          "0"       "$(scr 'BC_PENDING_IN=$'"'"'abc\r'"'"'; wscanw 0 "x%s" s >/dev/null; printf "%s" "$bc_scanw_count"')"
check "wscanw no input"          "0 0"     "$(scr 'BC_PENDING_IN=$'"'"'\r'"'"'; wscanw 0 "%d" n >/dev/null; printf "%s %s" "$?" "$bc_scanw_count"')"
check "wscanw esc err"           "1"       "$(scr 'BC_PENDING_IN=$'"'"'\x1b'"'"'; wscanw 0 "%d" n >/dev/null; printf "%s" "$?"')"
check "mvwscanw moves"           "7 2 4"   "$(scr 'BC_PENDING_IN=$'"'"'7\r'"'"'; mvwscanw 0 2 3 "%d" n >/dev/null; printf "%s %s %s" "$n" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "scanw stdscr"             "9 1"     "$(scr 'BC_PENDING_IN=$'"'"'9\r'"'"'; scanw "%d" n >/dev/null; printf "%s %s" "$n" "${BC_WAX[0]}"')"
check "mvscanw moves"            "9 1 3"   "$(scr 'BC_PENDING_IN=$'"'"'9\r'"'"'; mvscanw 1 2 "%d" n >/dev/null; printf "%s %s %s" "$n" "${BC_WAY[0]}" "${BC_WAX[0]}"')"
check "vwscanw"                  "9"       "$(scr 'BC_PENDING_IN=$'"'"'9\r'"'"'; vwscanw 0 "%d" n >/dev/null; printf "%s" "$n"')"
check "vw_scanw"                 "9"       "$(scr 'BC_PENDING_IN=$'"'"'9\r'"'"'; vw_scanw 0 "%d" n >/dev/null; printf "%s" "$n"')"

# --- I. wchgat window x-offset (regression: changed cell must land at the
#        window's absolute X, not at X=0 of the buffer) ---
check "wchgat win x-offset attr" "9 0" "$( ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; _bc_init_window 5 2 3 10 20; BC_CURR=0; wmove 5 0 0; wchgat 5 -1 9 4; printf "%s %s" "${BC_A["5/2 3"]:-0}" "${BC_A["5/2 0"]:-0}" ) )"
check "wchgat win x-offset pair" "4 0" "$( ( source "$REPO/lib/bc.sh"; _bc_init_window 0 0 0 24 80; _bc_init_window 5 2 3 10 20; BC_CURR=0; wmove 5 0 0; wchgat 5 -1 9 4; printf "%s %s" "${BC_P["5/2 3"]:-0}" "${BC_P["5/2 0"]:-0}" ) )"

# --- J. examples/mc.sh headless regressions (sourced, no tty) ---
# run $1 in a fresh subshell with mc.sh sourced and a 100x30 stdscr at origin
mc() { ( source "$REPO/examples/mc.sh"; COLS=100 LINES=30
         _bc_init_window 0 0 0 30 100; BC_CURR=0; eval "$1"; ); }
# run $1 with mc.sh sourced plus a 26x50 panel window (WIN[0]) holding 50 entries
mcnav() { ( source "$REPO/examples/mc.sh"; COLS=100 LINES=30
            _bc_init_window 0 0 0 30 100; _bc_init_window 10 1 0 26 50;
            WIN[0]=10; CUR=0; NAMES_0=( $(seq 0 49) ); eval "$1"; ); }

# J1. closed menu bar is cyan (pair 22, black-on-cyan) across the full row width
check "mc menu bar full-width cyan" "100" "$(mc 'menu_open=0; draw_menu; n=0; for (( x = 0; x < COLS; x++ )); do p=${BC_P["0/0 $x"]:-0}; [[ $p == 22 ]] && n=$((n+1)); done; printf "%s" "$n"')"
# J2. PageUp/PageDown must clamp POS into [0, count-1] (page_rows = 26-5 = 21)
check "mc pgup at top"   "0"  "$(mcnav 'POS[0]=0;  POS[0]=$((POS[0]-$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgup mid"      "0"  "$(mcnav 'POS[0]=5;  POS[0]=$((POS[0]-$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgup within"   "19" "$(mcnav 'POS[0]=40; POS[0]=$((POS[0]-$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgdn mid"      "21" "$(mcnav 'POS[0]=0;  POS[0]=$((POS[0]+$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgdn bottom"   "49" "$(mcnav 'POS[0]=40; POS[0]=$((POS[0]+$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc clamp high"    "49" "$(mcnav 'POS[0]=999; clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc clamp low"     "0"  "$(mcnav 'POS[0]=-5;  clamp_pos 0; printf "%s" "${POS[0]}"')"

# --- K. scrolling API ---
check "wscrl requires scrollok" "1" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; wscrl 0 1; printf "%s" "$?"')"
check "wscrl up moves chars"    "B" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wscrl 0 1; printf "%s" "${BC_C["0/0 0"]}"')"
check "wscrl down moves chars"  "A" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wscrl 0 -1; printf "%s" "${BC_C["0/1 0"]}"')"
check "wscrl blank attr pair"   "0 0" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wscrl 0 1; printf "%s %s" "${BC_A["0/2 0"]:-0}" "${BC_P["0/2 0"]:-0}"')"
check "wsetscrreg bad bottom"   "1" "$(scr 'wsetscrreg 0 0 24; printf "%s" "$?"')"
check "wsetscrreg scrolls region" "A| " "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; mvaddstr 3 0 D; scrollok 0 1; wsetscrreg 0 1 2; wscrl 0 1; printf "%s|%s" "${BC_C["0/0 0"]}" "${BC_C["0/2 0"]}"')"
check "doupdate emits DECSTBM" "yes" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wsetscrreg 0 0 2; wscrl 0 1; out=$(doupdate); pat=$(printf "\033[1;3r"); [[ $out == *"$pat"* ]] && echo yes || echo no')"
check "doupdate emits SU" "yes" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wsetscrreg 0 0 2; wscrl 0 1; out=$(doupdate); pat=$(printf "\033[1S"); [[ $out == *"$pat"* ]] && echo yes || echo no')"
check "doupdate emits SD" "yes" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wsetscrreg 0 0 2; wscrl 0 -1; out=$(doupdate); pat=$(printf "\033[1T"); [[ $out == *"$pat"* ]] && echo yes || echo no')"
check "doupdate honors BC_NO_SCROLLREG" "no" "$(scr 'BC_NO_SCROLLREG=1; mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wsetscrreg 0 0 2; wscrl 0 1; out=$(doupdate); pat=$(printf "\033[1;3r"); [[ $out == *"$pat"* ]] && echo yes || echo no')"
check "wrefresh after wscrl repaints region" "yes" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wsetscrreg 0 0 2; wscrl 0 1; out=$(wrefresh 0); pat=$(printf "\033[1;3r"); [[ $out != *"$pat"* ]] && echo yes || echo no')"
check "wscrl twice marks net new rows" "1" "$(scr 'mvaddstr 0 0 A; mvaddstr 1 0 B; mvaddstr 2 0 C; scrollok 0 1; wsetscrreg 0 0 2; wscrl 0 1; wscrl 0 1; [[ -n ${BC_MK["0/1 0"]+set} ]] && echo 1 || echo 0')"

# J3. status-line free space uses rounded G/M like mc (not floor division)
check "mc hum rounds G" "25G" "$(mc 'hum 25969664')"
check "mc hum rounds M" "1024M" "$(mc 'hum 1048575')"

# J3b. hintbar can be disabled like mc's Layout/message_visible=false
check "mc hintbar enabled layout" "26 27 28 29" "$(mc 'MC_HINTBAR=1; layout_bottom; printf "%s %s %s %s" "$PH" "$HINTY" "$CMY" "$BTNY"')"
check "mc hintbar disabled layout" "27 -1 28 29" "$(mc 'MC_HINTBAR=0; layout_bottom; printf "%s %s %s %s" "$PH" "$HINTY" "$CMY" "$BTNY"')"
check "mc hintbar disabled skips hint" "X" "$(mc 'HINTBAR=0; HINTY=27; mvaddstr 27 0 X; redraw_hint; printf "%s" "${BC_C["0/27 0"]}"')"
check "mc viewer fits shows total pct" "5/5 100%" "$(mc 'V_PATH=TREE/a.txt; V_TOTAL=5; V_N=1; V_OFF=0; V_BTOFF=(0); view_metrics; view_title 0; line=""; for ((x=0;x<COLS;x++)); do line+="${BC_C["0/0 $x"]:- }"; done; printf "%s" "$line" | tr -s " " | grep -o "5/5 100%"')"

# J4. list_dir: parent first, directories before files, hidden filtering, exec marker
check "list_dir sorts dirs first and marks executables" "/..|/dir|/zzz|*exe| file|0" "$(
  d="$REPO/tmp/list_dir_test.$$"
  rm -rf "$d"; mkdir -p "$d/dir" "$d/zzz"; : > "$d/file"; : > "$d/.hidden"; : > "$d/exe"; chmod +x "$d/exe"
  ( source "$REPO/examples/mc.sh"; DIR[0]="$d"; HIDE[0]=1; FILTERS[0]=''; SORT[0]=name; REV[0]=0
    list_dir 0; hid=0; [[ " ${NAMES_0[*]} " == *" .hidden "* ]] && hid=1
    IFS='|'; printf '%s|%s' "${NAMES_0[*]}" "$hid" )
  rm -rf "$d"
)"
check "list_dir applies filter" "/..| file.txt" "$(
  d="$REPO/tmp/list_dir_test.$$"
  rm -rf "$d"; mkdir -p "$d"; : > "$d/file.txt"; : > "$d/file.md"
  ( source "$REPO/examples/mc.sh"; DIR[0]="$d"; HIDE[0]=0; FILTERS[0]='*.txt'; SORT[0]=name; REV[0]=0
    list_dir 0; IFS='|'; printf '%s' "${NAMES_0[*]}" )
  rm -rf "$d"
)"

echo
if (( fail == 0 )); then echo "unit: $pass passed"; else echo "unit: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
