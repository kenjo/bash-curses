# bc — terminal UI for bash

An ncurses-flavoured TUI library written in pure bash. Source `lib/bc.sh`,
then write terminal apps with the familiar `initscr` / `waddstr` / `wgetch` /
`wrefresh` API. On top of it sit three optional layers — `lib/layout.sh`
(describe the screen in a template, draw by area name), `lib/widgets.sh`
(lists, menu bars, dialogs) and `lib/dialog.sh` (`dialog`-style msgbox / yesno
/ menu prompts) — so most apps never compute coordinates.

It is not a 1:1 reimplementation: it covers the parts of the ncurses API the
reference corpora actually exercise (see `references/API-MATRIX.md`), includes
thin single-cell wide-character wrappers but excludes the terminfo API, and
makes a small number of deliberate API deviations (see
[docs/bc.md](docs/bc.md#deviations-and-gaps) — read them before porting C
code).

**Documentation lives in [`docs/`](docs/README.md)**: a tutorial and full API
reference for each layer.

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

## Examples

`examples/` holds ports of ncurses test-suite demos. `tests/examples.sh`
smoke-tests them in tmux. The current example set also exercises every public
wrapper in `lib/bc.sh` at least once. `examples/newdemo.sh` was frame-diffed
against the C reference: 0 differing cells of 672 written (see DESIGN.md
"Verification").

Run any of them in a terminal:

```sh
bash examples/newdemo.sh
```

Layout-layer examples: `examples/90-layout.sh` (mc-like file manager with a
modal Copy dialog), `examples/91-shining-layout.sh` (`shining.sh` redone with
floats), `examples/92-mc-layout.sh` (the full `mc` clone rebuilt on
`lib/layout.sh` + `lib/widgets.sh`).

## Mouse

`wgetch` intercepts SGR 1006 and X10 mouse reports, merges press+release into
CLICK and CLICK runs into DOUBLE/TRIPLE, filters by the `mousemask`, and
returns `KEY_MOUSE`; `getmouse` then drains the queue into
`BC_ME_ID`/`BC_ME_X`/`BC_ME_Y`/`BC_ME_BSTATE`. `bstate` uses the ncurses
mouse-version-2 encoding; wheel up/down are buttons 4/5. Full semantics,
ground-truth evidence, and the bstate table: `MOUSE.md`.

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

- `tests/unit.sh` — headless (no tty): key-table lookup, SGR/X10 mouse decode,
  mask expansion, click/double/triple merge runs, and KEY_*/mouse constants vs
  the installed ncurses header.
- `tests/unit_screen.sh` — headless: SGR capture parser, per-cell grid model,
  and raw cursor tracker.
- `tests/unit_layout.sh` — headless: `lib/layout.sh` template parsing and
  errors, track sizing, window binding/rebuilds, floats, and the event loop
  (with a fake key source).
- `tests/unit_widgets.sh` — headless: `lib/widgets.sh` lists (partial redraw,
  selection hooks, clamping), menubar, and dialog widgets.
- `tests/unit_dialog.sh` — headless: `lib/dialog.sh` text prep/wrapping and
  button sizing.
- `tests/unit_builder.sh` — headless: `tools/bcbuild.sh` model operations
  (split, delete/collapse, rename, styles, tags, floats, serialise
  round-trip, undo/redo, export).
- `tests/builder.sh` — tmux-driven: drives the builder UI, saves a project
  and exports a runnable app.
- `tests/dialog_app.sh` — tmux-driven: drives the ported
  `/home/kenjo/proj/ai/start_local_ai_bc.sh` with fake tools (skipped if the
  app is absent).
- `tests/layout_demo.sh`, `tests/layout_shining.sh` — tmux-driven: the two
  layout examples, incl. dialogs, shadows, clicks and resizes.
  (`tests/bench_layout.sh` is a benchmark, not part of `run.sh`.)
- `tests/integration.sh` — tmux-driven: runs `tests/battery_app.sh` in a pane,
  injects key and mouse bytes via `send-keys -H`, and asserts the decoded
  `KEY`/`EV` output.
- `tests/examples.sh` — tmux-driven: runs `examples/*.sh` smoke tests in a real
  tty, feeds keys (including raw SGR mouse bytes), and requires clean exits.
- `tests/mc_*.sh` — tmux-driven regression tests for the `mc` clone: navigation,
  menus, viewer, resize, dialogs, actions, and MC-vs-clone parity checks.
  `tests/mc_layout.sh` runs the same suite against `examples/92-mc-layout.sh`
  (known diffs listed in `tests/mc_layout.xfail`).

## Layout

```
lib/bc.sh        the library (source it)
lib/layout.sh    optional layout layer: templates, floats, draw by name, bc_run
lib/widgets.sh   optional widgets on top of layout: lists, menubar, dialogs
lib/dialog.sh    optional dialog layer on top of widgets: msgbox, yesno, menu
docs/            tutorials + API reference for each layer (start at docs/README.md)
examples/        ports of ncurses test-suite demos (smoke tests)
tests/           run.sh, unit.sh, unit_screen.sh, integration.sh, mc_* tests
references/      read-only vendored ncurses corpus (do not edit)
DESIGN.md        architecture, data model, input/mouse, verification, deviations
MOUSE.md         mouse semantics, ground truth, debugging record
AGENTS.md        working conventions for this repo
```
