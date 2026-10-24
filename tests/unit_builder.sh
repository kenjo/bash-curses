#!/bin/bash
# Headless tests for the builder model (tools/bcbuild.sh). No tty needed:
# BCB_TEST=1 makes the render/UI functions no-ops so the pure model logic
# (split, delete, rename, styles, tags, floats, serialise, undo) can run.
REPO="$(cd "$(dirname "$0")/.." && pwd)"
pass=0 fail=0
ok()  { printf 'ok   %s\n' "$1"; pass=$((pass+1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail+1)); }

BCB_TEST=1
source "$REPO/tools/bcbuild.sh"

# the load stubs must never shadow the real library functions
for fn in bc_screen bc_grid bc_float bc_style; do
  declare -F "$fn" >/dev/null && ok "$fn not shadowed" || bad "$fn not shadowed"
done

bb_new
[[ $BCB_SEL == main && ${BB_KIND[main]} == area && ${BB_PARENT[main]} == @ ]] \
  && ok "new: single main area" || bad "new: single main area"

bb_split h
[[ ${BB_TPL[main]} == "main.0 main.1" && ${BB_ROWSPEC[main]} == "*" && ${BB_COLSPEC[main]} == "* *" \
   && ${BB_KIND[main.0]} == area && ${BB_PARENT[main.0]} == main && $BCB_SEL == main.0 ]] \
  && ok "split h: nested grid, side by side" || bad "split h: nested grid, side by side"

bb_select main.1
bb_split v
[[ ${BB_TPL[main.1]} == "main.1.0|main.1.1" && ${BB_ROWSPEC[main.1]} == "* *" ]] \
  && ok "split v: nested grid" || bad "split v: nested grid"
[[ "$(_bb_tpl_e main.1)" == "c.main.1.0
c.main.1.1" ]] && ok "engine template: rows on separate lines" \
  || bad "engine template: rows on separate lines (got '$(_bb_tpl_e main.1)')"

bb_select main.0
bb_grow 0 1
[[ ${BB_ROWSPEC[main]} == "9" ]] && ok "grow: row track becomes 9" || bad "grow: row track becomes 9 (got '${BB_ROWSPEC[main]}')"
bb_grow 1 -2
[[ ${BB_COLSPEC[main]} == "6 *" ]] \
  && ok "grow: col track shrinks" || bad "grow: col track shrinks (got '${BB_COLSPEC[main]}')"

bb_toggle_auto 1
[[ ${BB_COLSPEC[main]} == "auto *" ]] && ok "auto: track toggles" || bad "auto: track toggles"
bb_toggle_auto 1
[[ ${BB_COLSPEC[main]} == "8 *" ]] && ok "auto: toggles back to measured" || bad "auto: toggles back (got '${BB_COLSPEC[main]}')"

bb_set_style pair 3
[[ ${BB_PAIR[main.0]} == 3 ]] && ok "style: pair set" || bad "style: pair set"
bb_set_style pair ""
[[ -z ${BB_PAIR[main.0]+set} ]] && ok "style: pair cleared" || bad "style: pair cleared"
bb_cycle_pair PAIR
[[ ${BB_PAIR[main.0]} == 1 ]] && ok "style: pair cycles" || bad "style: pair cycles"

bb_cycle_tag
[[ ${BB_TAG[main.0]} == label ]] && ok "tag: cycles to label" || bad "tag: cycles to label"

bb_set_style title "My Title"
[[ ${BB_TITLE[main.0]} == "My Title" ]] && ok "style: title set" || bad "style: title set"

bb_rename main.0 left
[[ ${BB_TPL[main]} == "left main.1" && ${BB_KIND[left]} == area && ${BB_PAIR[left]} == 1 \
   && ${BB_TAG[left]} == label && $BCB_SEL == left ]] \
  && ok "rename: model follows" || bad "rename: model follows"

bb_add_float
[[ ${BB_KIND[dlg]} == float && ${BB_FIN[dlg]} == @ && " $BB_FLOATS " == *" dlg "* ]] \
  && ok "float: added" || bad "float: added"

# serialise -> load -> serialise must be stable
s1=$(bb_serialize)
bb_load_text "$s1"
s2=$(bb_serialize)
[[ $s1 == "$s2" ]] && ok "round-trip: serialise/load stable" || bad "round-trip: serialise/load stable"
[[ ${BB_TAG[left]} == label && ${BB_KIND[dlg]} == float ]] \
  && ok "round-trip: tags and floats survive" || bad "round-trip: tags and floats survive"

# undo / redo
bb_undo
[[ -z ${BB_KIND[dlg]+set} ]] && ok "undo: float removed" || bad "undo: float removed"
bb_undo
[[ ${BB_TPL[main]} == "main.0 main.1" ]] && ok "undo: rename reverted" || bad "undo: rename reverted"
bb_redo
[[ ${BB_TPL[main]} == "left main.1" ]] && ok "redo: rename back" || bad "redo: rename back"

# delete collapses a parent left with a single kid
bb_select main.1.0
bb_delete
[[ ${BB_TPL[main]} == "left main.1.1" && -z ${BB_KIND[main.1]+set} && -z ${BB_KIND[main.1.0]+set} ]] \
  && ok "delete: parent collapsed" || bad "delete: parent collapsed"
bb_select main.1.1
bb_delete
[[ ${BB_TPL[@]} == "left" && $BCB_SEL == left ]] \
  && ok "delete: last kid collapses root" || bad "delete: last kid collapses root"

# bad templates are rejected
bb_load_text 'bc_screen "a b
c d e" rows="*" cols="* *"'
[[ $? -ne 0 && -n $BCB_ERR ]] && ok "parse: ragged rows rejected" || bad "parse: ragged rows rejected"
bb_load_text 'bc_screen "a b" rows="*" cols="* * *"'
[[ $? -eq 0 && ${BB_KIND[a]} == area ]] && ok "parse: simple grid accepted" || bad "parse: simple grid accepted"

# export produces a syntactically valid app
mkdir -p "$REPO/tmp"
bb_new; bb_split h; bb_select main.0; bb_cycle_tag; bb_cycle_tag
bb_export "$REPO/tmp/bcbuild_export.sh"
bash -n "$REPO/tmp/bcbuild_export.sh" && ok "export: valid bash" || bad "export: valid bash"
grep -q 'bc_list main.0' "$REPO/tmp/bcbuild_export.sh" && ok "export: tagged widget emitted" || bad "export: tagged widget emitted"
grep -q '^BB_TAG' "$REPO/tmp/bcbuild_export.sh" && bad "export: BB_TAG leaked" || ok "export: BB_TAG stripped"

echo
if (( fail == 0 )); then echo "unit_builder: $pass passed"; else echo "unit_builder: $pass passed, $fail FAILED"; fi
(( fail == 0 ))
