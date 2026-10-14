# bc — terminal UI for bash

An ncurses-flavoured TUI library written in pure bash. Source `lib/bc.sh`,
then write terminal apps with the familiar `initscr` / `waddstr` / `wgetch` /
`wrefresh` API.

It is not a 1:1 reimplementation: it covers the parts of the ncurses API the
reference corpora actually exercise (see `references/API-MATRIX.md`), includes
thin single-cell wide-character wrappers but excludes the terminfo API, and
makes a small number of deliberate API deviations (below — read them before
porting C code). `DESIGN.md` has the full architecture and `MOUSE.md` the mouse
semantics.

## Requirements

- bash >= 4.3, `stty`, `tput`, `infocmp`
- a real tty for running apps
- `tmux` (to run/drive interactive apps on a headless host, and for the
  integration tests)

## Quick start

```bash
#!/bin/bash
source /path/to/bash_curses/lib/bc.sh

initscr || exit 1
if has_colors; then
  start_color
  init_pair 1 $COLOR_RED $COLOR_BLACK
fi
curs_set 0

wattrset $BC_STDSCR 0 1
mvwaddstr $BC_STDSCR 0 0 "Hello, bc!"
wattrset $BC_STDSCR 0 0
mvwaddstr $BC_STDSCR 2 0 "Press any key to quit."
refresh

wgetch
endwin
```

Run it with `bash quickstart.sh`. `endwin` also runs from an EXIT trap, so the
terminal is restored even if the script dies.

## Examples

`examples/` holds ports of ncurses test-suite demos. `tests/examples.sh`
smoke-tests them in tmux. The current example set also exercises every public
wrapper in `lib/bc.sh` at least once. `examples/newdemo.sh` was frame-diffed
against the C reference: 0 differing cells of 672 written (see DESIGN.md
"Verification").

```sh
tmux new-session -d -s bc -x 100 -y 30 bash examples/newdemo.sh
tmux capture-pane -t bc -p      # rendered screen as text
tmux send-keys -t bc q          # feed a key
tmux kill-session -t bc
```

## Mouse

```bash
mousemask $(( ALL_MOUSE_EVENTS | REPORT_MOUSE_POSITION )) oldmask
while wgetch; do
  if (( key == KEY_MOUSE )); then
    while getmouse; do
      # $BC_ME_X $BC_ME_Y $BC_ME_BSTATE
    done
  fi
done
```

`wgetch` intercepts SGR 1006 and X10 mouse reports, consumes a whole run of
consecutive reports (quiet period 166 ms), merges press+release into CLICK and
CLICK runs into DOUBLE/TRIPLE, filters by the mask, and returns `KEY_MOUSE`;
`getmouse` then drains the queue into `BC_ME_ID`/`BC_ME_X`/`BC_ME_Y`/
`BC_ME_BSTATE`. `bstate` uses the ncurses mouse-version-2 encoding
(`MASK(button, m) = m << ((button-1)*5)`); wheel up/down are buttons 4/5.
Full semantics, ground-truth evidence, and the bstate table: `MOUSE.md`.

## API deviations from ncurses (must-read)

Bash has no return values, pointers, or out-parameters, so:

- `wgetch [win]` returns status 0/1 and puts the character or `KEY_*` in the
  global `key`.
- Window handles are integers (`stdscr` = `BC_STDSCR` = 0). `newwin`, `newpad`,
  `derwin`/`subwin` store the new handle in the global `bc_win` — capture it
  with `win=$bc_win`. Never use command substitution (`win=$(newwin ...)`):
  the function would run in a subshell and all library state would be lost.
- `wattrset win attr pair` — the color pair is a separate 3rd argument
  (ncurses packs it into the chtype). Same for `wbkgd win ch attr pair`.
  `COLOR_PAIR(n)` just prints `n`.
- `getmaxyx win` sets globals `BC_GMY` (height) and `BC_GMX` (width);
  `getbegyx win` sets `BC_GBY`, `BC_GBX`.
- `mvwinch win y x` sets globals `wch`, `wcha`, `wchp` (char, attr, pair).
- `getmouse` puts the event in `BC_ME_*`; `BC_ME_ID` is always 0.
- `mousemask`/`mouseinterval` always return 0; the previous value goes to the
  optional `oldvar` argument / `BC_OLD_MAXCLICK`.
- `ACS_*` are single Unicode box-drawing characters, not alt-charset escapes.
- Key decoding is terminfo-driven via `infocmp` keycaps, so which sequences
  decode to which `KEY_*` depends on `$TERM` (exactly as in C ncurses).

Not implemented (out of scope or not feasible in bash): full wide-character
semantics (the `*_wch*` wrappers treat each argument as one cell), terminfo API,
`use_screen`, `slk_wset`.

## API overview

| Group | Functions |
|---|---|
| Init/teardown | `initscr`, `endwin`, `curs_set`, `delay_output`, `flushinp` |
| Windows | `newwin`, `newpad`, `derwin`/`subwin`, `delwin`, `move`/`wmove`/`mvcur`, `getmaxyx`, `getbegyx`, `werase`/`wclear`/`clear` |
| Output | `waddch`/`waddstr`/`waddnstr` (+ `mvw*`/`mv*`/plain variants), `mvwinch`, `wborder`/`box`/`hline`/`vline`, `wbkgd`/`bkgd`/`wbkgset`/`bkgdset`, `winsn` |
| Refresh | `wrefresh`/`wnoutrefresh`/`refresh`/`doupdate` |
| Attributes | `wattrset`/`attrset`, `wattron`/`attron`, `wattroff`/`attroff`, `standout`/`standend` |
| Color | `start_color`, `has_colors`, `init_pair`, `init_color`, `use_default_colors`, `COLOR_PAIR`, `PAIR_NUMBER` |
| Input | `wgetch`/`getch`/`getkey`/`echochar`, `ungetch`, `nodelay`, `halfdelay`, `cbreak`, `raw`/`noraw`, `noecho`, `beep`, `flash` |
| Mouse | `mousemask`/`mouse_set`, `mouseinterval`, `getmouse`, `ungetmouse`, `has_mouse` |
| Screen save | `scr_init`/`scr_init_sp`, `scr_dump`, `scr_set`/`scr_set_sp`, `scr_restore`/`scr_restore_sp` |
| SLK | `slk_init`, `slk_set`, `slk_label`, `slk_refresh`, `slk_noutrefresh`, `slk_clear`, `slk_restore`, `slk_touch`, `slk_color`, `slk_attr*` family |
| Misc | `vidattr`/`vidputs` (and `vid_attr`/`vid_puts`) |
| Wide chars | `wadd_wch`, `wget_wch`, `win_wch`, `wins_wch`, `setcchar`, `getcchar`, `wcwidth` (single-cell wrappers) |

Constants match ncurses and are checked against `/usr/include/ncurses.h` by the
unit tests: all `KEY_*` (KEY_F1=265 … KEY_MOUSE=409, KEY_MAX=511), `A_BOLD`=1 …
`A_PROTECT`=64, `COLOR_*`, `COLOR_PAIRS`, screen macros `COLS`/`LINES`/
`COLORS` (and `BC_*` variants), `ESCDELAY`, and the mouse bstate/mask constants
(`BUTTON1_PRESSED`=1 … `BUTTON5_TRIPLE_CLICKED`), `ALL_MOUSE_EVENTS`,
`REPORT_MOUSE_POSITION`.

## Testing

```sh
bash tests/run.sh
```

- `tests/unit.sh` — headless (no tty): key-table lookup, SGR/X10 mouse decode,
  mask expansion, click/double/triple merge runs, and KEY_*/mouse constants vs
  the installed ncurses header.
- `tests/unit_screen.sh` — headless: SGR capture parser, per-cell grid model,
  and raw cursor tracker.
- `tests/integration.sh` — tmux-driven: runs `tests/battery_app.sh` in a pane,
  injects key and mouse bytes via `send-keys -H`, and asserts the decoded
  `KEY`/`EV` output.
- `tests/examples.sh` — tmux-driven: runs `examples/*.sh` smoke tests in a real
  tty, feeds keys (including raw SGR mouse bytes), and requires clean exits.
- `tests/mc_*.sh` — tmux-driven regression tests for the `mc` clone: navigation,
  menus, viewer, resize, dialogs, actions, and MC-vs-clone parity checks.

## Layout

```
lib/bc.sh        the library (source it)
examples/        ports of ncurses test-suite demos (smoke tests)
tests/           run.sh, unit.sh, unit_screen.sh, integration.sh, mc_* tests
references/      read-only vendored ncurses corpus (do not edit)
DESIGN.md        architecture, data model, input/mouse, verification, deviations
MOUSE.md         mouse semantics, ground truth, debugging record
AGENTS.md        working conventions for this repo
```
