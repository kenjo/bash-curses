# AGENTS.md

## What this repo is
This is a reimplentation of something like ncurses but in bash.

## Host tools for testing
`tmux` is installed on the host. Use it to run and test interactive terminal
apps (the examples, or reference TUIs like `mc`), which need a real tty:

- start:   `tmux new-session -d -s t -x 100 -y 30 ./examples/newdemo.sh`
- see:     `tmux capture-pane -t t -p` — rendered screen as text
- drive:   `tmux send-keys -t t Down Enter q`
- cleanup: `tmux kill-session -t t`

Verified working with Midnight Commander (`mc`) on this host.

### CRITICAL: never `tmux kill-server`
This agent runs INSIDE a tmux session. `tmux kill-server` (and any command
that tears down the whole server) kills the agent's own session and breaks the
run. ALWAYS:

- create your own uniquely-named session: `tmux new-session -d -s <name> ...`
- only ever destroy that session: `tmux kill-session -t <name>`
- NEVER run `tmux kill-server`, `tmux kill-session` on a session you did not
  create, or any global server teardown.
- pick a session name unlikely to collide (e.g. `bc-<task>`), and clean up
  only your own session when done.

## Test suite
- `bash tests/run.sh` — full suite: headless unit tests, then tmux integration.
  This is what you run after changes. Individual files can be run directly.
- Headless (no tmux, fast): `tests/unit.sh` (library behaviour), `tests/unit_screen.sh`
  (the SGR parser, per-cell grid model, and the raw cursor tracker),
  `tests/unit_bundle.sh` (the bundle/unbundle CLI in `lib/bc.sh`).
- tmux (need a real tty): `tests/integration.sh`, `tests/mc_nav.sh`,
  `tests/mc_menu.sh`, `tests/mc_view.sh`, `tests/mc_resize.sh`,
  `tests/mc_dialog.sh`, `tests/mc_actions.sh`, `tests/mc_parity.sh`,
  `tests/mc_mouse.sh`, `tests/mouse_click.sh`.

### Per-cell screen model — `tests/lib/screen.sh`
Source it to parse `tmux capture-pane -e` (SGR) captures into a per-cell grid
(char + fg + bg + attributes), for assertions and rich diffs:

```bash
source tests/lib/screen.sh
screen_load <file> <W> <H>          # fill the grid from an SGR capture
cell <row> <col>                   # -> "char<TAB>fg<TAB>bg<TAB>attrs"
screen_diff <a> <b> <W> <H>        # per-cell diff; rc 0 iff identical
```

Color/attr tokens: fg/bg are `16:N`, `256:N`, `rgb:R,G,B`, or `d` (default);
attrs are comma-joined (`bold,dim,reverse,underline,blink,conceal,strike,italic`).
It tracks cumulative SGR state across lines (tmux re-asserts per line).
For raw PTY streams captured via `script`, use `cursor_from_raw <raw> <W> <H>`.

### MC-vs-clone discovery — `tests/visual_diff.sh`
Slow interactive harness (NOT in run.sh): drives real `mc` and the clone in the
same controlled tree, feeds identical keys, and reports per-cell divergences to
`tmp/vd/REPORT.txt`. Run one step: `bash tests/visual_diff.sh initial`. Record
findings in `ANOMALIES.md`.

### MC-vs-clone parity probe — `tests/parity_probe.sh`
Cached interactive harness (NOT in run.sh): drives real `mc` and the clone in
parallel controlled trees, feeds identical keys/menu selections, and records
mismatches to `PARITY_FINDINGS.md` plus captures under `tmp/p`. Run one step:
`bash tests/parity_probe.sh nav_left`. Use `PARITY_RESET=1` to start a fresh
findings file; real `mc` captures are cached under `tmp/p/cache` unless
`PARITY_REFRESH_MC=1`.

## Temporary files
 - /tmp is not to be used. Use tmp in workspace insterad.
  
## git
 commit often and use good descriptions.
 