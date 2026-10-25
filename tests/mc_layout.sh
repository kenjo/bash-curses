#!/bin/bash
# Runs the mc.sh tmux tests (tests/mc_*.sh) against apps/mc-layout.sh,
# the rewrite on lib/layout.sh + lib/widgets.sh, while it is being built.
#
# Every check must pass except those listed in tests/mc_layout.xfail
# ("<test>: <check name prefix>", one per line) — checks for features not
# built yet. A listed check that now passes is reported as XPASS and fails the
# run too, so the list only shrinks: remove the line when the feature lands.
#
#   bash tests/mc_layout.sh [mc_nav ...]      (default: all)
#   MC_LAYOUT_UPDATE=1 bash tests/mc_layout.sh  rewrite the xfail list from
#                                              this run's failures (review it!)
#   MC_LAYOUT_NORUN=1 ...                      judge the last run's logs again
REPO="$(cd "$(dirname "$0")/.." && pwd)"
XFAIL="$REPO/tests/mc_layout.xfail"
LOG="$REPO/tmp/logs/mc_layout"
TESTS=(mc_nav mc_resize mc_menu mc_dialog mc_actions mc_view mc_mouse mc_parity)
(( $# )) && TESTS=("$@")
JOBS=${MC_LAYOUT_JOBS:-3}
mkdir -p "$LOG"

declare -A XF=()
if [[ -f $XFAIL ]]; then
  while IFS= read -r line; do
    [[ $line =~ ^[[:space:]]*(#|$) ]] && continue
    XF["$line"]=1
  done < "$XFAIL"
fi

pids=()
[[ -n ${MC_LAYOUT_NORUN:-} ]] && TORUN=() || TORUN=("${TESTS[@]}")   # NORUN: re-judge old logs
for t in "${TORUN[@]}"; do
  MC_SCRIPT="$REPO/apps/mc-layout.sh" MC_TAG="lay_" \
    timeout 600 bash "$REPO/tests/$t.sh" > "$LOG/$t.log" 2>&1 &
  pids+=("$!")
  while (( $(jobs -rp | wc -l) >= JOBS )); do wait -n; done
done
wait

# is "<test>: <text>" covered by an xfail entry (prefix match on the text)?
declare -A USED=()
xfailed() { # test text
  local k
  for k in "${!XF[@]}"; do
    [[ ${k%%: *} == "$1" ]] || continue
    [[ $2 == "${k#*: }"* ]] && { USED[$k]=1; return 0; }
  done
  return 1
}

# drop the run-specific detail from a failure message (got/want values, paths)
strip_detail() { # text
  local t=$1 m
  for m in " (want" " (got" ": want" ": got" " got " ": '" " ["; do
    [[ $t == *"$m"* ]] && t=${t%%"$m"*}
  done
  printf '%s' "$t"
}

npass=0 nxfail=0 nfail=0 nxpass=0
declare -A SEEN=()
newx=()
for t in "${TESTS[@]}"; do
  while IFS= read -r line; do
    case $line in
      'ok   '*) npass=$(( npass + 1 )) ;;
      'FAIL '*)
        name=${line#FAIL }
        newx+=("$t: $(strip_detail "$name")")
        if xfailed "$t" "$name"; then
          nxfail=$(( nxfail + 1 ))
        else
          printf 'FAIL  %s: %s\n' "$t" "$name"; nfail=$(( nfail + 1 ))
        fi ;;
    esac
  done < "$LOG/$t.log"
done

# an expected failure that did not fail this time is fixed: the list must shrink
declare -A RAN=()
for t in "${TESTS[@]}"; do RAN[$t]=1; done
for k in "${!XF[@]}"; do
  [[ -n ${RAN[${k%%: *}]:-} && -z ${USED[$k]:-} ]] || continue
  printf 'XPASS %s   (no longer fails: remove it from tests/mc_layout.xfail)\n' "$k"
  nxpass=$(( nxpass + 1 ))
done

if [[ -n ${MC_LAYOUT_UPDATE:-} ]]; then
  {
    printf '# Checks expected to fail for apps/mc-layout.sh (features not built\n'
    printf '# yet). Format: "<test>: <check name prefix>". See tests/mc_layout.sh.\n'
    printf '%s\n' "${newx[@]}" | sort -u
  } > "$XFAIL"
  echo "rewrote $XFAIL ($(grep -cv '^#' "$XFAIL") entries)"
fi

echo "mc_layout: $npass passed, $nxfail expected failures, $nfail FAILED, $nxpass XPASS"
(( nfail == 0 && nxpass == 0 ))
