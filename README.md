# bash_curses — ncurses clone in bash

A pure-bash ncurses clone plus optional layout, widgets, and dialog layers.
Source `lib/bc.sh`, then write terminal apps with the familiar `initscr` /
`waddstr` / `wgetch` / `wrefresh` API. On top of it sit three optional layers —
`lib/layout.sh` (describe the screen in a template, draw by area name),
`lib/widgets.sh` (lists, menu bars, dialogs) and `lib/dialog.sh`
(`dialog`-style msgbox / yesno / menu prompts) — so most apps never compute
coordinates.

The repo also includes finished showcase apps in `apps/`, including a Midnight
Commander clone, and small API demos in `examples/`.

It is not a 1:1 reimplementation: it covers the parts of the ncurses API the
reference corpora actually exercise (see `internal/api-matrix.md`), includes
thin single-cell wide-character wrappers but excludes the terminfo API, and
makes a small number of deliberate API deviations (see
[docs/bc.md](docs/bc.md#deviations-and-gaps) — read them before porting C
code).

**User documentation lives in [`docs/`](docs/README.md)**: a tutorial and full
API reference for each layer. Contributor notes live in
[`internal/`](internal/README.md).

## Requirements

- bash >= 4.3, `stty`, `tput`, `infocmp`
- a real tty for running apps
- `tmux` for running/driving interactive apps and the integration tests

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

## The three layers

| Layer | File | What it gives you |
|---|---|---|
| Dialog | `lib/dialog.sh` | `dialog`-style msgbox / yesno / menu prompts |
| Widgets | `lib/widgets.sh` | lists, menu bars, dialogs, input fields, buttons |
| Layout | `lib/layout.sh` | named screen areas, floats/dialogs, event loop |
| Core | `lib/bc.sh` | ncurses-style API: windows, attributes, keys, mouse |
| Builder | `tools/bcbuild.sh` | interactive layout designer → [docs/builder.md](docs/builder.md) |

Source the topmost layer you need; each sources the layers below it. The
layout layer turns a template of area names into windows, keeps them laid out
across resizes, and redraws only what changed:

```bash
source lib/layout.sh
bc_init mouse
init_pair 1 7 4; init_pair 2 0 6

bc_screen "
  menu  menu
  left  right
  keys  keys
" rows="1 * 1" cols="* *"

bc_style menu pair=2
bc_style left  pair=1 border title=Left
bc_style right pair=1 border title=Right
bc_text  menu  " File  Command  Options"

draw_left() { bc_print left 0 0 "drawn by name, no coordinates"; }
on_key()    { [[ $1 == q ]] && bc_quit; }
bc_run
```

→ Tutorials and full references: [docs/dialog.md](docs/dialog.md),
[docs/layout.md](docs/layout.md), [docs/widgets.md](docs/widgets.md),
[docs/bc.md](docs/bc.md), [docs/builder.md](docs/builder.md).

## Apps and examples

`apps/` holds finished showcase programs:

- `apps/newdemo.sh` — color/window demo ported from ncurses `newdemo`.
- `apps/shining.sh` — overlapping windows typing the same sentence.
- `apps/shining-layout.sh` — `shining.sh` rebuilt with `lib/layout.sh`.
- `apps/mc.sh` — Midnight Commander clone built on `lib/bc.sh`.
- `apps/mc-layout.sh` — the same clone rebuilt on `lib/layout.sh` +
  `lib/widgets.sh`.
- `apps/dtail.sh` — dual tail app built with `lib/layout.sh`.

Run one in a terminal:

```sh
bash apps/newdemo.sh
```

`examples/` holds small ports of ncurses test-suite demos, plus
`examples/90-layout.sh` as a layout-layer example. The numbered examples are
smoke-tested in tmux by `tests/examples.sh`. Current accepted differences from
the C reference binaries are listed in `internal/example-deviations.md`.

## Mouse

`wgetch` intercepts SGR 1006 and X10 mouse reports, merges press+release into
CLICK and CLICK runs into DOUBLE/TRIPLE, filters by the `mousemask`, and
returns `KEY_MOUSE`; `getmouse` then drains the queue into
`BC_ME_ID`/`BC_ME_X`/`BC_ME_Y`/`BC_ME_BSTATE`. `bstate` uses the ncurses
mouse-version-2 encoding; wheel up/down are buttons 4/5. Full user-facing
semantics and the bstate table: [docs/mouse.md](docs/mouse.md).

## API deviations from ncurses (must-read)

Bash has no return values, pointers, or out-parameters, so results come back
in globals (`wgetch` → `key`, `newwin` → `bc_win`, `getmaxyx` → `BC_GMY`/
`BC_GMX`, …) and the pair is a separate argument to `wattrset`/`wbkgd`. Never
use command substitution for library calls. The full list — including
`mousemask`'s old-mask argument, pair 0 being a real pair, `wcwidth`'s status
return, and what is not implemented — is in
[docs/bc.md](docs/bc.md#deviations-and-gaps).

## Distributing your app

Ship a single self-contained script by embedding the libraries into it, and
split it back apart whenever you want:

```sh
bash lib/bc.sh bundle myapp.sh -o myapp      # one file to distribute
bash lib/bc.sh unbundle myapp -o outdir/     # script + lib files again
```

Details: [docs/distributing.md](docs/distributing.md).

## Testing

```sh
bash tests/run.sh
```

The suite includes headless unit tests, tmux integration tests, example smoke
tests, and app regression tests. Details:
[internal/testing.md](internal/testing.md).

## Layout

```
lib/bc.sh        the library (source it)
lib/layout.sh    optional layout layer: templates, floats, draw by name, bc_run
lib/widgets.sh   optional widgets on top of layout: lists, menubar, dialogs
lib/dialog.sh    optional dialog layer on top of widgets: msgbox, yesno, menu
docs/            user tutorials + API reference for each layer (start at docs/README.md)
internal/        contributor notes: design, testing, mouse internals, parity, API matrix
apps/            finished showcase apps: mc, newdemo, shining, dtail
examples/        small ncurses API demos and layout examples
tests/           run.sh, unit*.sh, integration.sh, examples, mc_*, app tests
AGENTS.md        working conventions for this repo
```
