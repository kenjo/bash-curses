# Using the libraries

`lib/` holds three layers. Each builds on the one below it; you can use any of
them directly, but most apps should start at the top.

| Layer | File | What it gives you | Start here if |
|---|---|---|---|
| Widgets | `lib/widgets.sh` | lists, menu bars, dialogs, input fields, buttons | you want interactive building blocks |
| Layout | `lib/layout.sh` | named screen areas, floats/dialogs, event loop | you want to describe the screen, not compute coordinates |
| Core | `lib/bc.sh` | ncurses-style API: windows, attributes, keys, mouse | you want full control, or are porting C ncurses code |

Source the topmost layer you need — each one sources the layers below it
automatically:

```bash
source lib/widgets.sh   # pulls in layout.sh and bc.sh
```

## Which layer?

- **`lib/layout.sh` (+ `lib/widgets.sh`)** is the recommended way in. You name
  the areas of your screen in a template, the library sizes them, keeps them
  laid out across resizes, and redraws only what changed. Your app draws by
  area name and never computes coordinates.
  → **[docs/layout.md](layout.md)** and **[docs/widgets.md](widgets.md)**

- **`lib/bc.sh`** is the ncurses-flavoured core: `initscr`/`waddstr`/`wgetch`/
  `wrefresh` with windows, attributes, colour pairs, keys and mouse. It is a
  working subset of ncurses, not a 1:1 port — read the deviations section.
  → **[docs/bc.md](bc.md)**

## Examples

- `examples/newdemo.sh` — core layer, frame-diffed against the C reference.
- `examples/90-layout.sh` — layout layer: mc-like file manager with a modal
  Copy dialog.
- `examples/91-shining-layout.sh` — the `shining.sh` demo redone with floats.
- `examples/92-mc-layout.sh` — the full `mc` clone (`examples/mc.sh`) rebuilt
  on `layout.sh` + `widgets.sh`.

Run any of them in a terminal:

```sh
bash examples/90-layout.sh
```

## Related documents

- `MOUSE.md` — mouse semantics, ground truth, and the bstate table.
- `DESIGN.md` — architecture and internals of all three layers.
- `references/API-MATRIX.md` — which ncurses API surface is covered.
