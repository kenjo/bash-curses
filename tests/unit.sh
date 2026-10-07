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

# J1. menu bar is black-on-cyan (pair 6) across the full row width
check "mc menu bar full-width cyan" "100" "$(mc 'MENU_ACTIVE=-1; draw_menu; n=0; for (( x = 0; x < COLS; x++ )); do [[ ${BC_P["0/0 $x"]:-0} == 6 ]] && n=$((n+1)); done; printf "%s" "$n"')"
# J2. PageUp/PageDown must clamp POS into [0, count-1] (page_rows = 26-5 = 21)
check "mc pgup at top"   "0"  "$(mcnav 'POS[0]=0;  POS[0]=$((POS[0]-$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgup mid"      "0"  "$(mcnav 'POS[0]=5;  POS[0]=$((POS[0]-$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgup within"   "19" "$(mcnav 'POS[0]=40; POS[0]=$((POS[0]-$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgdn mid"      "21" "$(mcnav 'POS[0]=0;  POS[0]=$((POS[0]+$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc pgdn bottom"   "49" "$(mcnav 'POS[0]=40; POS[0]=$((POS[0]+$(page_rows 0))); clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc clamp high"    "49" "$(mcnav 'POS[0]=999; clamp_pos 0; printf "%s" "${POS[0]}"')"
check "mc clamp low"     "0"  "$(mcnav 'POS[0]=-5;  clamp_pos 0; printf "%s" "${POS[0]}"')"

echo
if (( fail == 0 )); then echo "unit: $pass passed"; else echo "unit: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
