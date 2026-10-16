#!/bin/bash
# Headless regression test for examples/mc.sh do_swap_panels (C-u "Swap panels").
#
# Regression guard: the old action only toggled CUR, so the panel *contents*
# never swapped and C-u was not bound at all. do_swap_panels must swap every
# per-panel array/assoc between the two positions and toggle CUR so the active
# panel follows its content to the other side.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

# shellcheck source=../examples/mc.sh
source "$REPO/examples/mc.sh"   # main() is guarded, so this only defines state+funcs

eq() { # desc got want
  if [[ "$2" == "$3" ]]; then ok "$1"; else bad "$1 (want [$3] got [$2])"; fi
}

# ---- set up two clearly different panels ----
NAMES_0=(a b);        NAMES_1=(c d e)
TYPES_0=(f f);        TYPES_1=(f f f)
SIZES_0=(1 2);        SIZES_1=(3 4 5)
TIMES_0=(t1 t2);      TIMES_1=(t3 t4 t5)
REALS_0=(a b);        REALS_1=(c d e)
EXEC_0=(0 1);         EXEC_1=(0 0 1)
DIR[0]=/left;         DIR[1]=/right
POS[0]=1;             POS[1]=2
OFF[0]=10;            OFF[1]=20
SORT[0]=name;         SORT[1]=size
REV[0]=0;             REV[1]=1
HIDE[0]=0;            HIDE[1]=1
FILTERS[0]="";        FILTERS[1]="*.c"
FREE[0]="1G / 2G";    FREE[1]="3G / 4G"
SELSET_0=([a]=1);     SELSET_1=([c]=1 [d]=1)
CUR=1

do_swap_panels

# ---- contents swapped between positions ----
eq "NAMES_0 swapped"  "${NAMES_0[*]}"  "c d e"
eq "NAMES_1 swapped"  "${NAMES_1[*]}"  "a b"
eq "REALS_0 swapped"  "${REALS_0[*]}"  "c d e"
eq "REALS_1 swapped"  "${REALS_1[*]}"  "a b"
eq "TYPES_0 swapped"  "${TYPES_0[*]}"  "f f f"
eq "SIZES_1 swapped"  "${SIZES_1[*]}"  "1 2"
eq "TIMES_0 swapped"  "${TIMES_0[*]}"  "t3 t4 t5"
eq "EXEC_1 swapped"   "${EXEC_1[*]}"   "0 1"

# ---- per-panel scalars swapped ----
eq "DIR swapped"      "${DIR[0]}|${DIR[1]}"  "/right|/left"
eq "POS swapped"      "${POS[0]}|${POS[1]}"  "2|1"
eq "OFF swapped"      "${OFF[0]}|${OFF[1]}"  "20|10"
eq "SORT swapped"     "${SORT[0]}|${SORT[1]}" "size|name"
eq "REV swapped"      "${REV[0]}|${REV[1]}"  "1|0"
eq "HIDE swapped"     "${HIDE[0]}|${HIDE[1]}" "1|0"
eq "FILTERS swapped"  "${FILTERS[0]}|${FILTERS[1]}" "*.c|"
eq "FREE swapped"     "${FREE[0]}|${FREE[1]}" "3G / 4G|1G / 2G"

# ---- selection sets swapped ----
eq "SELSET_0 now has c,d" "$(printf '%s\n' "${!SELSET_0[@]}" | LC_ALL=C sort | tr '\n' ' ')" "c d "
eq "SELSET_1 now has a"   "$(printf '%s\n' "${!SELSET_1[@]}" | LC_ALL=C sort | tr '\n' ' ')" "a "

# ---- active panel follows its content to the other side ----
eq "CUR toggled" "$CUR" "0"

echo
echo "unit_mc_swap: $pass passed, $fail FAILED"
exit $(( fail > 0 ))
