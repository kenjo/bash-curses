#!/bin/bash
# unit_screen.sh -- headless unit tests for the SGR parser, grid model and the
# raw cursor tracker. No tmux needed: feeds synthetic byte streams and checks the
# resulting per-cell grid / cursor. Run: bash tests/unit_screen.sh
set -u
cd "$(dirname "$0")/.."
source tests/lib/screen.sh

pass=0; fail=0
ok()   { pass=$((pass+1)); }
bad()  { fail=$((fail+1)); printf 'FAIL %-26s got [%s] want [%s]\n' "$1" "$2" "$3"; }
chk()  { if [[ "$2" == "$3" ]]; then ok; else bad "$1" "$2" "$3"; fi; }

# write a fixture file from a printf format (real ESC bytes)
fx() { printf '%b' "$1" > tmp/u_$2; }

echo "=== SGR parser ==="

# basic 16 colours
fx '\e[31mR\e[32mG\e[34mB' a
screen_load tmp/u_a 10 1
chk "a c0 red"    "$(cell 0 0)" "R	16:1	d	"
chk "a c1 green"  "$(cell 0 1)" "G	16:2	d	"
chk "a c2 blue"   "$(cell 0 2)" "B	16:4	d	"
chk "a c3 pad"    "$(cell 0 3)" " 	d	d	"

# bright (90s) + bg (40s)
fx '\e[91mX\e[44mY' b
screen_load tmp/u_b 10 1
chk "b c0 brightfg" "$(cell 0 0)" "X	16:9	d	"
chk "b c1 bluebg"   "$(cell 0 1)" "Y	16:9	16:4	"

# 256-colour and truecolour
fx '\e[38;5;195mA\e[48;5;235mB\e[38;2;10;20;30mC' c
screen_load tmp/u_c 10 1
chk "c c0 256fg"     "$(cell 0 0)" "A	256:195	d	"
chk "c c1 256bg"     "$(cell 0 1)" "B	256:195	256:235	"
chk "c c2 truecol"   "$(cell 0 2)" "C	rgb:10,20,30	256:235	"

# attributes: multi on, then selective off
fx '\e[1;4;31mAB\e[24mC\e[0mD' d
screen_load tmp/u_d 10 1
chk "d c0 bold+ul"   "$(cell 0 0)" "A	16:1	d	bold,underline"
chk "d c1 bold+ul"   "$(cell 0 1)" "B	16:1	d	bold,underline"
chk "d c2 bold only" "$(cell 0 2)" "C	16:1	d	bold"
chk "d c3 reset"     "$(cell 0 3)" "D	d	d	"

# reverse / blink / dim / italic / strike / conceal (reset between each)
fx '\e[7mR\e[m\e[5mB\e[m\e[2mD\e[m\e[3mI\e[m\e[9mS\e[m\e[8mC' e
screen_load tmp/u_e 10 1
chk "e c0 reverse"  "$(cell 0 0)" "R	d	d	reverse"
chk "e c1 blink"    "$(cell 0 1)" "B	d	d	blink"
chk "e c2 dim"      "$(cell 0 2)" "D	d	d	dim"
chk "e c3 italic"   "$(cell 0 3)" "I	d	d	italic"
chk "e c4 strike"   "$(cell 0 4)" "S	d	d	strike"
chk "e c5 conceal"  "$(cell 0 5)" "C	d	d	conceal"

# ESC[m full reset mid-stream
fx '\e[1;31mX\e[mY' f
screen_load tmp/u_f 10 1
chk "f c0 styled" "$(cell 0 0)" "X	16:1	d	bold"
chk "f c1 reset"  "$(cell 0 1)" "Y	d	d	"

# cumulative: attr added without reset keeps colour (tmux-style)
fx '\e[31m\e[1mAB' g
screen_load tmp/u_g 10 1
chk "g c0 red+bold" "$(cell 0 0)" "A	16:1	d	bold"
chk "g c1 red+bold" "$(cell 0 1)" "B	16:1	d	bold"

# multiline with colour persisting across lines (tmux re-asserts)
fx '\e[31mA\nB\n' h
screen_load tmp/u_h 3 2
chk "h r0c0 A" "$(cell 0 0)" "A	16:1	d	"
chk "h r1c0 B" "$(cell 1 0)" "B	16:1	d	"
chk "h r1c1 pad" "$(cell 1 1)" " 	d	d	"

# multiline: second line different colour
fx 'X\n\e[32mY\n' i
screen_load tmp/u_i 3 2
chk "i r0c0 X" "$(cell 0 0)" "X	d	d	"
chk "i r1c0 Y" "$(cell 1 0)" "Y	16:2	d	"

# UTF-8 box drawing char occupies one cell, neighbours intact
fx 'AB\xe2\x94\x82C' j
screen_load tmp/u_j 4 1
chk "j c0 A"     "$(cell 0 0)" "A	d	d	"
chk "j c1 B"     "$(cell 0 1)" "B	d	d	"
chk "j c2 box"   "$(cell 0 2)" "│	d	d	"
chk "j c3 C"     "$(cell 0 3)" "C	d	d	"

# non-CSI escapes are skipped (OSC title, then a CUP, then text)
fx '\e]0;title\e\\Z' k
screen_load tmp/u_k 10 1
chk "k c0 Z (OSC skipped)" "$(cell 0 0)" "Z	d	d	"

echo "=== cursor tracker ==="

cur() { printf '%b' "$1" | od -An -tx1 | LC_ALL=C awk -v W="${2:-20}" -v H="${3:-10}" -f tests/lib/cursor.awk; }

chk "cur CUP 5;7"        "$(cur '\e[5;7H')"            "5 7"
chk "cur CUP2;3 CUD2"    "$(cur '\e[2;3H\e[2B')"       "4 3"
chk "cur CUP1;1 ABC"     "$(cur '\e[1;1HABC')"         "1 4"
chk "cur wrap W20 10A"   "$(cur '\e[1;1HABCDEFGHIJ')"  "1 11"
chk "cur CUP2;2 CRLF"    "$(cur '\e[2;2H\r\n')"        "3 1"
chk "cur OSC then CUP"   "$(cur '\e]0;hi\e\\\e[3;4H')" "3 4"
chk "cur SGR then CUP"   "$(cur '\e[1;31mX\e[4;5H')"   "4 5"
chk "cur CUP then home"  "$(cur '\e[1;1H\e[H')"        "1 1"
chk "cur CUU 3;1 by2"    "$(cur '\e[3;1H\e[2A')"       "1 1"
chk "cur CUB 1;5 by3"    "$(cur '\e[1;5H\e[3D')"       "1 2"
chk "cur CUF 1;1 by4"    "$(cur '\e[1;1H\e[4C')"       "1 5"
chk "cur CHA G col9"     "$(cur '\e[1;1H\e[9G')"       "1 9"
chk "cur clamp row H3"   "$(cur '\e[5;7H' 20 3)"       "3 7"
chk "cur RI ESC M"       "$(cur '\e[3;1H\eM')"         "2 1"
chk "cur CUP empty home" "$(cur '\e[1;1H\e[H')"        "1 1"

echo
if (( fail == 0 )); then
  echo "unit_screen: PASS ($pass checks)"
  exit 0
else
  echo "unit_screen: $fail FAILED, $pass passed"
  exit 1
fi
