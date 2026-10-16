#!/bin/bash
# Parity probe: run real Midnight Commander and the bash clone in identical
# controlled trees, feed identical keys/menu selections, and record GUI/action
# mismatches. This script is intentionally discovery-only: it does not patch
# examples/mc.sh.
#
# Usage:
#   PARITY_RESET=1 bash tests/parity_probe.sh
#   bash tests/parity_probe.sh initial nav_down menu_left
#
# Output:
#   tmp/p/{mc,clone}/NN_<label>.{plain,sgr}
#   tmp/p/REPORT.txt
#   PARITY_FINDINGS.md (append unless PARITY_RESET=1)

set -u

REPO="$(cd "$(dirname "$0")/.." && pwd)"
source "$REPO/tests/lib/screen.sh"

ROOT="$REPO/tmp/p"
TREE="$ROOT/t"
TREE_M="$ROOT/t0"
TREE_C="$ROOT/t1"
CACHE="$ROOT/cache"
SOCKM="$ROOT/mc.sock"
SOCKC="$ROOT/cl.sock"
SESSM=parity_mc
SESSC=parity_clone
X=100
Y=30
FINDINGS="$REPO/PARITY_FINDINGS.md"
REPORT="$ROOT/REPORT.txt"

RUN_LABELS=("$@")
pass=0
fail=0
STEP_IDX=0
NOTES=()

ok()  { printf 'ok   %s\n' "$1"; pass=$((pass + 1)); }
bad() { printf 'FAIL %s\n' "$1"; fail=$((fail + 1)); }
add_note() { NOTES+=("$1"); }

should_run() {
  local want=$1 x
  (( ${#RUN_LABELS[@]} == 0 )) && return 0
  for x in "${RUN_LABELS[@]}"; do
    [[ $x == "$want" ]] && return 0
  done
  return 1
}

sanitize() {
  printf '%s' "$1" | tr -cs 'A-Za-z0-9._-' '_'
}

build_root() {
  mkdir -p "$ROOT/home" "$ROOT/home/.config/mc" "$ROOT/mcconf" "$ROOT/mccache" "$ROOT/mc" "$ROOT/clone" "$CACHE"
  printf '[Layout]\nmessage_visible=false\n' > "$ROOT/home/.config/mc/ini"
  MC_CFG_HASH=$(sha256sum "$ROOT/home/.config/mc/ini" 2>/dev/null | cut -c1-12)
  MC_CFG_HASH=${MC_CFG_HASH:-none}
  CAP_VER=2
  # The controlled tree's ".." (parent) and symlink mtimes are the run date, so
  # cached mc captures only stay valid within the same calendar day.
  CACHE_DAY=$(date +%F)
}

make_tree_at() {
  local dir=$1
  rm -rf "$dir"
  mkdir -p "$dir/alpha" "$dir/beta" "$dir/gamma" "$dir/empty"
  printf 'aaaa\n' > "$dir/a.txt"
  printf 'bb\n'   > "$dir/b.md"
  printf '#!/bin/sh\necho hi\n' > "$dir/c.sh"
  chmod +x "$dir/c.sh"
  printf 'sample\n' > "$dir/sample.txt"
  ln -s a.txt "$dir/link.txt"
  printf 'one\n' > "$dir/alpha/one.txt"
  printf 'two\n' > "$dir/beta/two.txt"
  printf 'three\n' > "$dir/gamma/three.txt"
  local f
  for f in "$dir"/* "$dir"/*/*; do
    touch -d '2020-01-02 03:04:05' "$f" 2>/dev/null || true
  done
}

make_tree() {
  make_tree_at "$TREE"
}

reset_tree() {
  make_tree
}

sock_for() {
  if [[ $1 == mc ]]; then printf '%s' "$SOCKM"; else printf '%s' "$SOCKC"; fi
}
sess_for() {
  if [[ $1 == mc ]]; then printf '%s' "$SESSM"; else printf '%s' "$SESSC"; fi
}

kill_app() {
  local which=$1 sock sess
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  if [[ -S $sock ]]; then
    tmux -S "$sock" kill-session -t "$sess" 2>/dev/null || true
  fi
}

start_app() {
  local which=$1 sock sess cmd tree
  if [[ $which == mc ]]; then
    sock=$SOCKM; sess=$SESSM; tree=$TREE_M; cmd="exec /usr/bin/mc"
  else
    sock=$SOCKC; sess=$SESSC; tree=$TREE_C; cmd="exec bash '$REPO/examples/mc.sh'"
  fi
  kill_app "$which"
  rm -f "$sock"
  local -a extra_env=()
  if [[ $which == clone ]]; then
    mkdir -p "$ROOT/clone_test"
    rm -f "$ROOT/clone_test/seq"
    extra_env=(BC_TEST_DIR="$ROOT/clone_test" MC_HINTBAR=0)
  fi
  tmux -S "$sock" new-session -d -s "$sess" -x "$X" -y "$Y" \
    env HOME="$ROOT/home" MC_CONFIG_DIR="$ROOT/mcconf" MC_CACHE_DIR="$ROOT/mccache" \
    EDITOR=true VISUAL=true ESCDELAY=100 "${extra_env[@]}" bash -c "cd '$tree' && $cmd"
  local ready=0
  for _ in $(seq 1 120); do
    if tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | grep -q 'Name'; then
      ready=1
      break
    fi
    sleep 0.05
  done
  if (( ready )); then
    if [[ $which == clone ]]; then
      for _ in $(seq 1 100); do
        [[ -s "$ROOT/clone_test/seq" ]] && break
        sleep 0.01
      done
    else
      sleep "${PARITY_READY_SLEEP:-0.5}"
    fi
  fi
  return $((1 - ready))
}

cleanup() {
  kill_app mc
  kill_app clone
  rm -f "$SOCKM" "$SOCKC"
}
trap cleanup EXIT

SEQ_FILE="$ROOT/clone_test/seq"
get_seq() {
  local v
  v=$(cat "$SEQ_FILE" 2>/dev/null)
  printf '%s' "${v:-0}"
}
wait_seq() {
  local before=$1 i
  for ((i = 0; i < 300; i++)); do
    if (( $(get_seq) > before )); then return 0; fi
    sleep 0.01
  done
  return 1
}
after_key() {
  local which=$1 before=$2 k=$3
  if [[ $which == clone ]]; then
    wait_seq "$before" || true
    if [[ $k == Escape ]]; then sleep "${PARITY_ESC_SLEEP:-0.15}"; else sleep "${PARITY_KEY_SLEEP:-0.1}"; fi
  else
    if [[ $k == Escape ]]; then sleep "${PARITY_ESC_SLEEP:-0.15}"; else sleep "${PARITY_KEY_SLEEP:-0.02}"; fi
  fi
}

send_named() {
  local which=$1; shift
  local sock sess k before
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  for k in "$@"; do
    [[ $k == Esc ]] && k=Escape
    before=$(get_seq)
    tmux -S "$sock" send-keys -t "$sess" "$k" 2>/dev/null || true
    after_key "$which" "$before" "$k"
  done
}

send_hex() {
  local which=$1; shift
  local sock sess before
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  before=$(get_seq)
  tmux -S "$sock" send-keys -H -t "$sess" "$@" 2>/dev/null || true
  if [[ $which == clone ]]; then
    wait_seq "$before" || sleep "${PARITY_HEX_SLEEP:-0.15}"
  else
    sleep "${PARITY_HEX_SLEEP:-0.15}"
  fi
}

send_text() {
  local which=$1 text=$2
  local sock sess before
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  before=$(get_seq)
  tmux -S "$sock" send-keys -l -t "$sess" "$text" 2>/dev/null || true
  if [[ $which == clone ]]; then
    wait_seq "$before" || sleep "${PARITY_TEXT_SLEEP:-0.15}"
  else
    sleep "${PARITY_TEXT_SLEEP:-0.15}"
  fi
}

send_token() {
  local which=$1 token=$2
  case $token in
    hex:*)
      local IFS=,
      # shellcheck disable=SC2206
      local hx=(${token#hex:})
      send_hex "$which" "${hx[@]}"
      ;;
    lit:*)
      send_text "$which" "${token#lit:}"
      ;;
    *)
      send_named "$which" "$token"
      ;;
  esac
}

send_keys_to() {
  local which=$1; shift
  local token
  for token in "$@"; do
    [[ -n $token ]] && send_token "$which" "$token"
  done
}

send_keys_to_both() {
  local token
  for token in "$@"; do
    [[ -n $token ]] && send_token mc "$token"
    [[ -n $token ]] && send_token clone "$token"
  done
}

capture_plain() {
  tmux -S "$(sock_for "$1")" capture-pane -t "$(sess_for "$1")" -p 2>/dev/null
}

wait_settled() {
  local which=$1 base=$2 prev cur stable=0 i
  prev=$(capture_plain "$which")
  for ((i = 0; i < 120; i++)); do
    sleep 0.05
    cur=$(capture_plain "$which")
    if [[ $cur == "$prev" ]]; then
      stable=$((stable + 1))
      if [[ $cur != "$base" ]] && (( stable >= 10 )); then return 0; fi
    else
      stable=0
      prev=$cur
    fi
  done
  return 0
}

cap_step() {
  local which=$1 label=$2 idx=$3
  local sock sess
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  tmux -S "$sock" capture-pane -t "$sess" -e -p 2>/dev/null |
    sed -E -e "s|$TREE_M|TREE|g" -e "s|$TREE_C|TREE|g" -e 's|/t0|/tX|g' -e 's|/t1|/tX|g' -e 's/[0-9]{2}:[0-9]{2}/00:00/g' -e '/[MG] \/ /s/[0-9]/0/g' -e 's/\x1b\[39m\x1b\[49m$//' > "$ROOT/$which/$idx.$label.sgr" || true
  tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null |
    sed -E -e "s|$TREE_M|TREE|g" -e "s|$TREE_C|TREE|g" -e 's|/t0|/tX|g' -e 's|/t1|/tX|g' -e 's/[0-9]{2}:[0-9]{2}/00:00/g' -e '/[MG] \/ /s/[0-9]/0/g' > "$ROOT/$which/$idx.$label.plain" || true
}

fs_snapshot() {
  local dir=$1
  (cd "$dir" 2>/dev/null && find . -mindepth 1 -printf '%P|%y|%s|%m\n' | LC_ALL=C sort)
}

cache_valid() {
  local sl=$1 desc=$2
  [[ -f "$CACHE/$sl.meta" && "$(cat "$CACHE/$sl.meta")" == "$desc|$MC_CFG_HASH|$CAP_VER|$CACHE_DAY" &&
     -f "$CACHE/$sl.plain" && -f "$CACHE/$sl.sgr" && -f "$CACHE/$sl.fs" ]]
}

cache_store() {
  local n=$1 sl=$2 desc=$3 fs=$4
  printf '%s\n' "$desc|$MC_CFG_HASH|$CAP_VER|$CACHE_DAY" > "$CACHE/$sl.meta"
  cp "$ROOT/mc/$n.$sl.plain" "$CACHE/$sl.plain" 2>/dev/null || true
  cp "$ROOT/mc/$n.$sl.sgr" "$CACHE/$sl.sgr" 2>/dev/null || true
  printf '%s\n' "$fs" > "$CACHE/$sl.fs"
}

cache_load() {
  local n=$1 sl=$2
  cp "$CACHE/$sl.plain" "$ROOT/mc/$n.$sl.plain" 2>/dev/null || true
  cp "$CACHE/$sl.sgr" "$ROOT/mc/$n.$sl.sgr" 2>/dev/null || true
  cat "$CACHE/$sl.fs" 2>/dev/null
}

menu_highlight_row() {
  local which=$1
  local sock sess tmps r c bg
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  tmps=$(mktemp "$ROOT/menu.XXXXXX")
  tmux -S "$sock" capture-pane -t "$sess" -e -p > "$tmps" 2>/dev/null || { rm -f "$tmps"; return 1; }
  screen_load "$tmps" "$X" "$Y"
  rm -f "$tmps"
  for ((r = 2; r <= 25; r++)); do
    for ((c = 2; c <= 24; c++)); do
      bg=$(cell "$r" "$c" | cut -f3)
      if [[ $bg == 16:0 ]]; then
        printf '%s' "$r"
        return 0
      fi
    done
  done
  return 1
}

menu_select() {
  local which=$1 idx=$2 item=$3
  local PARITY_KEY_SLEEP=${PARITY_MENU_KEY_SLEEP:-0.2}
  local sock sess i found=0 row line
  sock=$(sock_for "$which"); sess=$(sess_for "$which")
  send_named "$which" F9
  for ((i = 0; i < idx; i++)); do send_named "$which" Right; done
  send_named "$which" Down
  for ((i = 0; i < 30; i++)); do
    row=$(menu_highlight_row "$which") || break
    line=$(tmux -S "$sock" capture-pane -t "$sess" -p 2>/dev/null | sed -n "$((row + 1))p")
    if [[ $line == *"$item"* ]]; then
      found=1
      break
    fi
    send_named "$which" Down
  done
  if (( found )); then
    send_named "$which" Enter
    sleep "${PARITY_MENU_ACTION_SLEEP:-0.3}"
  else
    add_note "$which: menu item '$item' not found"
  fi
}

append_diff() {
  local title=$1 text=$2
  [[ -z $text ]] && return
  printf '\n%s\n' "$title" >> "$FINDINGS"
  printf '```text\n%s\n```\n' "$text" >> "$FINDINGS"
}

compare_step() {
  local label=$1 keys_desc=$2 fs_mc=$3 fs_cl=$4
  local n sl
  printf -v n '%02d' "$STEP_IDX"
  sl=$(sanitize "$label")
  local mcp="$ROOT/mc/$n.$sl.plain" ccp="$ROOT/clone/$n.$sl.plain"
  local mps="$ROOT/mc/$n.$sl.sgr" cps="$ROOT/clone/$n.$sl.sgr"
  local plain_msg="identical" sgr_msg="identical" fs_msg="identical"
  local plain_diff="" sgr_diff="" fs_diff=""

  if [[ ! -s $mcp || ! -s $ccp ]]; then
    plain_msg="missing capture"
  elif diff -q "$mcp" "$ccp" >/dev/null 2>&1; then
    plain_msg="identical"
  else
    plain_msg="differs"
    plain_diff=$(diff "$mcp" "$ccp" | head -80)
  fi

  if [[ -s $mps && -s $cps ]]; then
    sgr_diff=$(screen_diff "$mps" "$cps" "$X" "$Y" 2>&1)
    if [[ $? -ne 0 ]]; then
      sgr_msg="differs"
      sgr_diff=$(printf '%s\n' "$sgr_diff" | head -80)
    else
      sgr_msg="identical"
      sgr_diff=""
    fi
  else
    sgr_msg="missing capture"
  fi

  if [[ $fs_mc == "$fs_cl" ]]; then
    fs_msg="identical"
  else
    fs_msg="differs"
    fs_diff=$(diff <(printf '%s\n' "$fs_mc") <(printf '%s\n' "$fs_cl") | head -80)
  fi

  local note_text=""
  if (( ${#NOTES[@]} > 0 )); then
    note_text=$(printf '%s\n' "${NOTES[@]}")
  fi

  if [[ $plain_msg == identical && $sgr_msg == identical && $fs_msg == identical && -z $note_text ]]; then
    ok "$label"
    printf 'ok %s: plain/sgr/fs identical\n' "$label" >> "$REPORT"
    return
  fi

  bad "$label"
  {
    printf '\n### %s\n\n' "$label"
    printf -- '- keys/menu: `%s`\n' "$keys_desc"
    printf -- '- plain: %s\n' "$plain_msg"
    printf -- '- sgr: %s\n' "$sgr_msg"
    printf -- '- filesystem: %s\n' "$fs_msg"
    printf -- '- mc capture: `tmp/p/mc/%s.%s.plain`, `tmp/p/mc/%s.%s.sgr`\n' "$n" "$sl" "$n" "$sl"
    printf -- '- clone capture: `tmp/p/clone/%s.%s.plain`, `tmp/p/clone/%s.%s.sgr`\n' "$n" "$sl" "$n" "$sl"
    if [[ -n $note_text ]]; then
      printf -- '- notes:\n'
      while IFS= read -r line; do
        printf '  - %s\n' "$line"
      done <<< "$note_text"
    fi
  } >> "$FINDINGS"
  append_diff "plain diff (mc < vs clone >)" "$plain_diff"
  append_diff "per-cell SGR diff (mc < vs clone >)" "$sgr_diff"
  append_diff "filesystem diff (mc < vs clone >)" "$fs_diff"
  {
    printf '\n== %s ==\n' "$label"
    printf 'plain=%s sgr=%s fs=%s\n' "$plain_msg" "$sgr_msg" "$fs_msg"
    if [[ -n $note_text ]]; then printf 'notes:\n%s\n' "$note_text"; fi
  } >> "$REPORT"
}

run_keys() {
  local label=$1; shift
  should_run "$label" || return 0
  local keys=("$@")
  STEP_IDX=$((STEP_IDX + 1))
  NOTES=()
  local n sl
  printf -v n '%02d' "$STEP_IDX"
  sl=$(sanitize "$label")
  printf '\n== %s: %s ==\n' "$label" "${keys[*]:-(none)}"

  local mcok=1 clok=1 fs_mc="" fs_cl="" base_mc base_cl pidm pidc
  local desc="${keys[*]:-(none)}" use_mc_cache=0
  if [[ -z ${PARITY_REFRESH_MC:-} ]] && cache_valid "$sl" "$desc"; then
    use_mc_cache=1
  fi
  make_tree_at "$TREE_C"
  if (( ! use_mc_cache )); then
    make_tree_at "$TREE_M"
    start_app mc & pidm=$!
  fi
  start_app clone & pidc=$!
  if (( ! use_mc_cache )); then wait "$pidm"; mcok=$?; fi
  wait "$pidc"; clok=$?
  (( clok != 0 )) && add_note "clone failed to start"
  if (( ! use_mc_cache )); then
    (( mcok != 0 )) && add_note "mc failed to start"
    if (( mcok == 0 )); then base_mc=$(capture_plain mc); fi
  fi
  if (( clok == 0 )); then base_cl=$(capture_plain clone); fi
  if (( ! use_mc_cache )); then
    send_keys_to_both "${keys[@]}"
    if (( mcok == 0 )); then wait_settled mc "$base_mc"; fi
  else
    send_keys_to clone "${keys[@]}"
  fi
  if (( clok == 0 )); then wait_settled clone "$base_cl"; fi
  if (( ! use_mc_cache )); then cap_step mc "$sl" "$n"; fi
  cap_step clone "$sl" "$n"
  if (( ! use_mc_cache )); then
    fs_mc=$(fs_snapshot "$TREE_M")
    cache_store "$n" "$sl" "$desc" "$fs_mc"
    kill_app mc
  else
    fs_mc=$(cache_load "$n" "$sl")
  fi
  fs_cl=$(fs_snapshot "$TREE_C")
  kill_app clone

  compare_step "$label" "$desc" "$fs_mc" "$fs_cl"
}

run_menu() {
  local label=$1 idx=$2 item=$3; shift 3
  should_run "$label" || return 0
  local extra=("$@")
  STEP_IDX=$((STEP_IDX + 1))
  NOTES=()
  local n sl
  printf -v n '%02d' "$STEP_IDX"
  sl=$(sanitize "$label")
  printf '\n== %s: menu %s %s %s ==\n' "$label" "$idx" "$item" "${extra[*]:-}"

  local mcok=1 clok=1 fs_mc="" fs_cl="" base_mc base_cl pidm pidc
  local desc="menu idx=$idx item=$item extra=${extra[*]:-}" use_mc_cache=0
  if [[ -z ${PARITY_REFRESH_MC:-} ]] && cache_valid "$sl" "$desc"; then
    use_mc_cache=1
  fi
  make_tree_at "$TREE_C"
  if (( ! use_mc_cache )); then
    make_tree_at "$TREE_M"
    start_app mc & pidm=$!
  fi
  start_app clone & pidc=$!
  if (( ! use_mc_cache )); then wait "$pidm"; mcok=$?; fi
  wait "$pidc"; clok=$?
  (( clok != 0 )) && add_note "clone failed to start"
  if (( ! use_mc_cache )); then
    (( mcok != 0 )) && add_note "mc failed to start"
    if (( mcok == 0 )); then
      menu_select mc "$idx" "$item"
      base_mc=$(capture_plain mc)
      send_keys_to mc "${extra[@]}"
      wait_settled mc "$base_mc"
    fi
  fi
  if (( clok == 0 )); then
    menu_select clone "$idx" "$item"
    base_cl=$(capture_plain clone)
    send_keys_to clone "${extra[@]}"
    wait_settled clone "$base_cl"
  fi
  if (( ! use_mc_cache )); then cap_step mc "$sl" "$n"; fi
  cap_step clone "$sl" "$n"
  if (( ! use_mc_cache )); then
    fs_mc=$(fs_snapshot "$TREE_M")
    cache_store "$n" "$sl" "$desc" "$fs_mc"
    kill_app mc
  else
    fs_mc=$(cache_load "$n" "$sl")
  fi
  fs_cl=$(fs_snapshot "$TREE_C")
  kill_app clone

  compare_step "$label" "$desc" "$fs_mc" "$fs_cl"
}

build_root
if [[ -n ${PARITY_RESET:-} ]]; then
  {
    printf '# MC vs Clone Parity Findings\n\n'
    printf 'Generated by `tmp/parity_probe.sh`. This file records observed mismatches only; it does not fix them.\n\n'
    printf 'Environment: real mc `%s`, tmux `%s`, terminal `%sx%s`, isolated HOME/config/cache under `tmp/p`.\n\n' \
      "$(/usr/bin/mc --version 2>/dev/null | head -1)" "$(tmux -V 2>/dev/null)" "$X" "$Y"
  } > "$FINDINGS"
  : > "$REPORT"
else
  mkdir -p "$ROOT"
  if [[ ! -e $FINDINGS ]]; then
    printf '# MC vs Clone Parity Findings\n\n' > "$FINDINGS"
  fi
  printf '\n## Additional run\n\n' >> "$FINDINGS"
fi

# ------------------------------------------------------------------ baseline/navigation
run_keys initial
run_keys nav_down Down
run_keys nav_up Down Up
run_keys nav_home Down Down Home
run_keys nav_end End
run_keys nav_pgdn PageDown
run_keys nav_pgup PageDown PageUp
run_keys nav_left Left
run_keys nav_right Right
run_keys nav_tab Tab
run_keys open_alpha Down Enter
run_keys esc Escape
run_keys space_select Down Down Down Down Down Space
run_keys insert_select Down Down Down Down Down Insert
run_keys plus_select Down Down Down Down Down hex:2b
run_keys minus_select Down Down Down Down Down hex:2d Enter
run_keys star_select Down Down Down Down Down hex:2a
run_keys delete_key Down Down Down Down Down Delete

# ------------------------------------------------------------------ menu bar/dropdowns
run_keys menu_f9 F9
run_keys menu_left F9 Down
run_keys menu_file F9 Right Down
run_keys menu_command F9 Right Right Down
run_keys menu_options F9 Right Right Right Down
run_keys menu_right F9 Right Right Right Right Down
run_keys menu_left_esc F9 Down Esc
run_keys menu_file_esc F9 Right Down Esc

# ------------------------------------------------------------------ function keys
run_keys f1_help F1
run_keys f2_user_menu F2
run_keys f3_view_a Down Down Down Down Down F3
run_keys f4_edit_a Down Down Down Down Down F4
run_keys f5_copy_a Down Down Down Down Down F5
run_keys f6_move_a Down Down Down Down Down F6
run_keys f7_mkdir F7 lit:newdir Enter
run_keys f8_delete_a Down Down Down Down Down F8 Enter
run_keys f9_menu F9

# ------------------------------------------------------------------ command line
run_keys cmd_cd "lit:cd alpha" Enter
run_keys cmd_echo "lit:echo hi" Enter
run_keys cmd_history "lit:echo hi" Enter hex:1b,68
run_keys cmd_quick_cd hex:1b,63

# ------------------------------------------------------------------ panel/view actions
run_keys view_a Down Down Down Down Down F3
run_menu view_file_a 1 "View file..." lit:a.txt Enter
run_menu filtered_view_ls 1 "Filtered view" lit:ls Enter
run_keys file_history Down Down Down Down Down F3 q hex:1b,45
run_keys hotlist_alpha Down Enter hex:1c
run_keys rescan hex:12
run_keys swap_panels hex:15
run_keys switch_panels hex:0f
run_keys show_sizes hex:00
run_keys compare_dirs hex:18,64
run_keys compare_files Down Down Down Down Down hex:18,04
run_keys external_panelize hex:18,21
run_keys vfs_list hex:18,61
run_keys background_jobs hex:18,6a
run_keys screen_list hex:1b,60
run_keys encoding hex:1b,65
run_keys find_file hex:1b,3f
run_keys filtered_view_m hex:1b,21

# ------------------------------------------------------------------ file operations
run_keys chmod_a Down Down Down Down Down hex:18,63 lit:0600 Enter
run_keys link_a Down Down Down Down Down hex:18,6c lit:hardlink Enter
run_keys symlink_a Down Down Down Down Down hex:18,73 lit:symlink Enter
run_keys relative_symlink_a Down Down Down Down Down hex:18,76 lit:relsymlink Enter
run_keys edit_symlink_link Down Down Down Down Down Down Down Down hex:18,13 lit:b.md Enter
run_keys edit_symlink_not_link Down Down Down Down Down hex:18,13 Enter
run_keys chown_a Down Down Down Down Down hex:18,6f Enter
run_keys chattr_a Down Down Down Down Down hex:18,65 Enter

# ------------------------------------------------------------------ menu actions
run_menu left_file_listing 0 "File listing"
run_menu left_quick_view 0 "Quick view"
run_menu left_info 0 "Info"
run_menu left_tree 0 "Tree"
run_menu left_listing_format 0 "Listing format..."
run_menu left_sort_order 0 "Sort order..."
run_menu left_filter_a 0 "Filter..." lit:a* Enter
run_menu left_encoding 0 "Encoding..."
run_menu left_ftp_link 0 "FTP link..."
run_menu left_shell_link 0 "Shell link..."
run_menu left_sftp_link 0 "SFTP link..."
run_menu left_panelize 0 "Panelize"
run_menu left_rescan 0 "Rescan"

run_menu file_view_dot 1 "View"
run_menu file_view_file 1 "View file..."
run_menu file_filtered_view 1 "Filtered view"
run_menu file_edit_dot 1 "Edit"
run_menu file_copy_dot 1 "Copy"
run_menu file_chmod_dot 1 "Chmod"
run_menu file_link_dot 1 "Link"
run_menu file_symlink_dot 1 "Symlink"
run_menu file_relative_symlink_dot 1 "Relative symlink"
run_menu file_edit_symlink_dot 1 "Edit symlink"
run_menu file_chown_dot 1 "Chown"
run_menu file_advanced_chown_dot 1 "Advanced chown"
run_menu file_chattr_dot 1 "Chattr"
run_menu file_rename_move_dot 1 "Rename/Move"
run_menu file_mkdir 1 "Mkdir" lit:newdir Enter
run_menu file_delete_dot 1 "Delete"
run_menu file_quick_cd 1 "Quick cd"
run_menu file_select_group 1 "Select group" Enter
run_menu file_unselect_group 1 "Unselect group" Enter
run_menu file_invert_selection 1 "Invert selection"

run_menu command_user_menu 2 "User menu"
run_menu command_directory_tree 2 "Directory tree"
run_menu command_find_file 2 "Find file" lit:a* Enter
run_menu command_swap_panels 2 "Swap panels"
run_menu command_switch_panels 2 "Switch panels on/off"
run_menu command_compare_dirs 2 "Compare directories"
run_menu command_compare_files 2 "Compare files"
run_menu command_external_panelize 2 "External panelize"
run_menu command_show_sizes 2 "Show directory sizes"
run_menu command_command_history 2 "Command history"
run_menu command_file_history 2 "Viewed/edited files history"
run_menu command_hotlist 2 "Directory hotlist"
run_menu command_vfs_list 2 "Active VFS list"
run_menu command_background_jobs 2 "Background jobs"
run_menu command_screen_list 2 "Screen list"
run_menu command_undelete 2 "Undelete files (ext2fs only)"
run_menu command_edit_extension 2 "Edit extension file"
run_menu command_edit_menu 2 "Edit menu file"
run_menu command_edit_highlight 2 "Edit highlighting group file"

run_menu options_configuration 3 "Configuration..."
run_menu options_layout 3 "Layout..."
run_menu options_panel_options 3 "Panel options..."
run_menu options_confirmation 3 "Confirmation..."
run_menu options_appearance 3 "Appearance..."
run_menu options_display_bits 3 "Display bits..."
run_menu options_learn_keys 3 "Learn keys..."
run_menu options_virtual_fs 3 "Virtual FS..."
run_menu options_save_setup 3 "Save setup"

run_menu right_quick_view 4 "Quick view"
run_menu right_info 4 "Info"
run_menu right_tree 4 "Tree"
run_menu right_sort_order 4 "Sort order..."
run_menu right_filter_a 4 "Filter..." lit:a* Enter
run_menu right_rescan 4 "Rescan"

printf '\nprobe: %s identical, %s differing\n' "$pass" "$fail"
printf 'findings: %s\n' "$FINDINGS"
printf 'captures: %s/mc/ %s/clone/\n' "$ROOT" "$ROOT"
exit 0
