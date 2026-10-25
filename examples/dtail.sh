#!/usr/bin/env bash
# dtail — dual tail: run two commands side-by-side in their own bordered
# windows, with the command shown in each window's top border.
#
#   examples/dtail.sh 'tail -f /var/log/syslog' 'journalctl -f'
#
# The layout is the one exported from tools/bcbuild.sh (examples/dtail.bcl):
# a two-row screen, top and bot, each with a left-aligned border title.

source "${BASH_SOURCE[0]%/*}/../lib/layout.sh"

usage() {
  printf 'usage: %s "command" "command"\n' "${0##*/}" >&2
  exit 2
}

(( $# == 2 )) || usage
[[ -n $1 && -n $2 ]] || usage

declare -A CMD=([top]="$1" [bot]="$2")
declare -A FD=() PID=() DONE=() PART=()
declare -a LINES_top=() LINES_bot=()

MAX_LINES=2000
TRIM_LINES=1000

cleanup() {
  local a
  for a in top bot; do
    if [[ -n ${PID[$a]:-} ]]; then
      kill "${PID[$a]}" 2>/dev/null
    fi
    if [[ -n ${FD[$a]:-} ]]; then
      exec {FD[$a]}<&-
    fi
  done
  endwin
}

add_line() { # side line
  local -n buf=LINES_$1
  local line=$2
  line=${line%$'\r'}
  line=${line//$'\t'/    }
  line=${line:0:4096}
  buf+=("$line")
  if (( ${#buf[@]} > MAX_LINES )); then
    buf=("${buf[@]:TRIM_LINES}")
  fi
}

poll_side() { # side -> 0 if the pane changed
  local a=$1 fd=${FD[$a]} line part=${PART[$a]} rc dirty=0 n=0
  [[ -n ${DONE[$a]:-} ]] && return 1

  while (( n < 100 )); do
    if ! read -u "$fd" -t 0; then
      break
    fi

    if read -u "$fd" -t 0.05 line; then
      add_line "$a" "$part$line"
      part=""
      dirty=1
      n=$(( n + 1 ))
    else
      rc=$?
      if (( rc > 128 )); then
        if [[ -n $line ]]; then
          part+="$line"
          dirty=1
        fi
        break
      fi

      if [[ -n $part ]]; then
        add_line "$a" "$part"
        part=""
        dirty=1
      fi
      DONE[$a]=1
      add_line "$a" "[exited]"
      dirty=1
      break
    fi
  done

  PART[$a]=$part
  (( dirty ))
}

draw_pane() { # side
  local a=$1
  local -n buf=LINES_$a
  bc_size "$a"
  local n=${#buf[@]} start=0 i y

  if (( n > BCL_H )); then
    start=$(( n - BCL_H ))
  fi

  for (( i = start; i < n && i < start + BCL_H; i++ )); do
    y=$(( i - start ))
    bc_print "$a" "$y" 0 "${buf[i]}" pair=1
  done
}

draw_top() { draw_pane top; }
draw_bot() { draw_pane bot; }

on_tick() {
  local a
  for a in top bot; do
    poll_side "$a" && bc_dirty "$a"
  done
}

on_key() {
  case $1 in
    q|Q) bc_quit ;;
  esac
}

bc_init || exit 1
trap cleanup EXIT INT TERM

if has_colors; then
  init_pair 1 7 0
  init_pair 2 6 0
fi

bc_screen "
  top
  bot
" rows="* *" cols="*" gap=0 border=0 || exit 1

bc_style top border tleft pair=1 bpair=2 title="${CMD[top]}" || exit 1
bc_style bot border tleft pair=1 bpair=2 title="${CMD[bot]}" || exit 1

for a in top bot; do
  exec {FD[$a]}< <(eval "${CMD[$a]}" 2>&1)
  PID[$a]=$!
done

bc_dirty top bot
bc_run fps=10
