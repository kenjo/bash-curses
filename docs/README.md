# Using the libraries

`lib/` holds four layers. Each builds on the one below it; you can use any of
them directly, but most apps should start at the top.

| Layer | File | What it gives you | Start here if |
|---|---|---|---|
| Dialog | `lib/dialog.sh` | `dialog`-style msgbox / yesno / menu prompts | you just want a quick interactive prompt |
| Widgets | `lib/widgets.sh` | lists, menu bars, dialogs, input fields, buttons | you want interactive building blocks |
| Layout | `lib/layout.sh` | named screen areas, floats/dialogs, event loop | you want to describe the screen, not compute coordinates |
| Core | `lib/bc.sh` | ncurses-style API: windows, attributes, keys, mouse | you want full control, or are porting C ncurses code |

Source the topmost layer you need — each one sources the layers below it
automatically:

```bash
source lib/dialog.sh   # pulls in widgets.sh, layout.sh and bc.sh
```

## Which layer?

- **`lib/dialog.sh`** is the quickest way in: `bc_msgbox`, `bc_yesno` and
  `bc_menu` give you `dialog`-style prompts that take over the terminal, run,
  and hand it back — so you can interleave normal shell commands between them.
  It's also the drop-in path for porting an existing `dialog`/`whiptail` script.
  → **[docs/dialog.md](dialog.md)**

- **`lib/layout.sh` (+ `lib/widgets.sh`)** is the recommended way in. You name
  the areas of your screen in a template, the library sizes them, keeps them
  laid out across resizes, and redraws only what changed. Your app draws by
  area name and never computes coordinates.
  → **[docs/layout.md](layout.md)** and **[docs/widgets.md](widgets.md)**

- **`lib/bc.sh`** is the ncurses-flavoured core: `initscr`/`waddstr`/`wgetch`/
  `wrefresh` with windows, attributes, colour pairs, keys and mouse. It is a
  working subset of ncurses, not a 1:1 port — read the deviations section.
  → **[docs/bc.md](bc.md)**

- **`tools/bcbuild.sh`** is not a layer but a tool: an interactive designer
  for layout files. Draw the grid/float/style skeleton with mouse and keys,
  save it as a replayable `.bcl` project, or export a runnable app skeleton.
  → **[docs/builder.md](builder.md)**

## Examples

- `examples/newdemo.sh` — core layer, frame-diffed against the C reference.
- `examples/90-layout.sh` — layout layer: mc-like file manager with a modal
  Copy dialog.
- `examples/91-shining-layout.sh` — the `shining.sh` demo redone with floats.
- `examples/92-mc-layout.sh` — the full `mc` clone (`examples/mc.sh`) rebuilt
  on `layout.sh` + `widgets.sh`.
- `examples/dtail.sh` — dual tail: two commands in stacked bordered panes,
  with each command shown in its top border.
  → **[docs/tutorial-dtail.md](tutorial-dtail.md)**

Run any of them in a terminal:

```sh
bash examples/90-layout.sh
```

## Distributing your app

Bundle the libraries into your script for a single-file release, and split it
back out again later:

```sh
bash lib/bc.sh bundle myapp.sh -o myapp      # one self-contained file
bash lib/bc.sh unbundle myapp -o outdir/     # script + lib files again
```

→ **[docs/distributing.md](distributing.md)**

## Related documents

- `MOUSE.md` — mouse semantics, ground truth, and the bstate table.
- `DESIGN.md` — architecture and internals of all three layers.
- `references/API-MATRIX.md` — which ncurses API surface is covered.
