#!/bin/bash
# Runs the mc.sh tmux tests (tests/mc_*.sh) against examples/92-mc-layout.sh,
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
for t in "${TESTS[@]}"; do
  MC_SCRIPT="$REPO/examples/92-mc-layout.sh" MC_TAG="lay_" \
    timeout 600 bash "$REPO/tests/$t.sh" > "$LOG/$t.log" 2>&1 &
  pids+=("$!")
  while (( $(jobs -rp | wc -l) >= JOBS )); do wait -n; done
done
wait

# is "<test>: <text>" covered by an xfail entry (prefix match on the text)?
xfailed() { # test text
  local k
  for k in "${!XF[@]}"; do
    [[ ${k%%: *} == "$1" ]] || continue
    [[ $2 == "${k#*: }"* ]] && return 0
  done
  return 1
}

npass=0 nxfail=0 nfail=0 nxpass=0
declare -A SEEN=()
newx=()
for t in "${TESTS[@]}"; do
  while IFS= read -r line; do
    case $line in
      'ok   '*)
        name=${line#ok   }
        if xfailed "$t" "$name"; then
          printf 'XPASS %s: %s   (remove it from tests/mc_layout.xfail)\n' "$t" "$name"; nxpass=$(( nxpass + 1 ))
        else
          npass=$(( npass + 1 ))
        fi ;;
      'FAIL '*)
        name=${line#FAIL }
        newx+=("$t: $name")
        if xfailed "$t" "$name"; then
          nxfail=$(( nxfail + 1 ))
        else
          printf 'FAIL  %s: %s\n' "$t" "$name"; nfail=$(( nfail + 1 ))
        fi ;;
    esac
  done < "$LOG/$t.log"
done

if [[ -n ${MC_LAYOUT_UPDATE:-} ]]; then
  {
    printf '# Checks expected to fail for examples/92-mc-layout.sh (features not built\n'
    printf '# yet). Format: "<test>: <check name prefix>". See tests/mc_layout.sh.\n'
    printf '%s\n' "${newx[@]}" | sed -E 's/ *(\(want|\(got|\[|: want|: got| got ).*$//' | sort -u
  } > "$XFAIL"
  echo "rewrote $XFAIL ($(grep -cv '^#' "$XFAIL") entries)"
fi

echo "mc_layout: $npass passed, $nxfail expected failures, $nfail FAILED, $nxpass XPASS"
(( nfail == 0 && nxpass == 0 ))
