#!/bin/bash
# Headless tests for the dialog layer (lib/dialog.sh). No tty needed: these
# exercise the pure helpers and the load guard only.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

source "$REPO/lib/dialog.sh"
source "$REPO/lib/dialog.sh"   # load guard must make this a no-op

for fn in bc_msgbox bc_yesno bc_menu _bcd_prep _bcd_bwidths; do
  if declare -F "$fn" >/dev/null; then ok "$fn defined"; else bad "$fn defined"; fi
done

# _bcd_prep: literal \n becomes a real break, every line is indented one space
_bcd_prep 'one\ntwo' 40
[[ $BCD_TEXT == $' one\n two' ]] && ok "prep: literal \\n -> newline" || bad "prep: literal \\n -> newline"

# _bcd_prep: long line wraps at maxw, words kept whole
_bcd_prep 'aaa bbb ccc ddd' 7
[[ $BCD_TEXT == $' aaa bbb\n ccc ddd' ]] && ok "prep: wraps at maxw" || bad "prep: wraps at maxw"

# _bcd_bwidths: one button
BCD_BTNS=("OK"); _bcd_bwidths
[[ $BCD_BW == 4 && $BCD_BTOT == 4 ]] && ok "bwidths: single OK" || bad "bwidths: single OK"

# _bcd_bwidths: two buttons, gap of 2
BCD_BTNS=("Yes" "No"); _bcd_bwidths
[[ $BCD_BW == 5 && $BCD_BTOT == 12 ]] && ok "bwidths: Yes/No" || bad "bwidths: Yes/No"

# _bcd_bwidths: unequal labels size to the longest
BCD_BTNS=("OK" "Cancel"); _bcd_bwidths
[[ $BCD_BW == 8 && $BCD_BTOT == 18 ]] && ok "bwidths: OK/Cancel" || bad "bwidths: OK/Cancel"

echo
if (( fail == 0 )); then echo "unit_dialog: $pass passed"; else echo "unit_dialog: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
