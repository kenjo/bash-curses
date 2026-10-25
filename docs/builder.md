# Layout builder — `tools/bcbuild.sh`

`bcbuild` is an interactive designer for the layout layer: you draw the
`bc_screen`/`bc_grid`/`bc_float`/`bc_style` skeleton with the mouse and keys,
then save it as a replayable project file or export it as a runnable app
skeleton. It is a normal `bc_screen` app itself, built on `lib/widgets.sh`.

```bash
tools/bcbuild.sh [project.bcl]
```

It needs a terminal of at least **110x32**.

## The three panes

```text
+---------------------------+--------------------------------+----------------+
| menu bar (F9)             |                                |                |
| [Split-H][Split-V][Del]…  |   canvas (live design)         | Properties     |
| Areas          tree       |                                |  name/rect/    |
|  main                     |                                |  tracks/[-][+] |
|   main.0                  |                                |  style rows    |
|  [dlg]                    |                                |                |
| status / key help         |                                |                |
+---------------------------+--------------------------------+----------------+
```

- **Areas** — the design tree; floats are listed with `*`. Click a row (or the
  canvas) to select. `Tab` cycles the selection.
- **Toolbar** — buttons under the menu bar: `Split-H`, `Split-V`, `Delete`,
  `Float`, `Undo`, `Redo`, `Save`, `Export`, and a green `Preview` button with a
  red `Quit` button on the right. Click to press.
- **Canvas** — the design rendered live, exactly as the layout engine will
  lay it out. The selected area gets a highlighted border. Preview outlines are
  shown by default; `o` or the `Preview` button toggles them.
- **Properties** — name, kind, parent, current rect, tracks, style and tag of
  the selection. Most rows are clickable: click `border`, `divider`, `t-left`
  to toggle them, `pair`, `shadow`, `margin`, `tag` to cycle them, `title` to
  edit it, and the `[-]`/`[+]` buttons on the track and gap rows to resize.

## Editing

| key | action |
|-----|--------|
| `h` / `v` | split the selected area into two (side by side / stacked) |
| `d` | delete the selected area (a parent left with one kid collapses) |
| `r` | rename the selected area |
| `t` | set the border title |
| `b` | toggle border |
| `o` | toggle the canvas preview outlines (same as the `Preview` button) |
| `p` | cycle the colour pair (8 design pairs) |
| `s` | cycle shadow (`1` → `mc` → off) |
| `l` | toggle title-left |
| `D` | toggle divider |
| `m` | cycle margin (0–2) |
| `w` | cycle the widget tag (`label list input button check cycle menubar`) |
| `f` | add a visible float (`9x25`, centred) |
| `+` `-` | grow / shrink the selected area's row track, or a float's height |
| `<` `>` | grow / shrink the column track, or a float's width |
| `a` / `A` | toggle `auto` on the row / column track |
| `[` `]` | gap − / + in the parent grid |
| `u`, `Ctrl-Y` | undo / redo |
| `Ctrl-S` / `Ctrl-O` / `Ctrl-E` | save / open / export |
| `?` | key help |
| `q` | quit (asks if there are unsaved changes) |

Mouse: click selects; click the toolbar buttons or the property rows (see
above) to act; **drag a track boundary** between two areas to resize the two
tracks; **drag a float** to move it, drag its bottom-right corner to resize.
When canvas outlines are on, a yellow `+` marks the middle of each draggable
boundary. While dragging a boundary, a red `#` line shows the proposed edge in
real time; the layout is applied when the button is released. The menu bar
(`F9`) mirrors all of the above.

Handlers act on the button **press**, so click speed does not matter. Drag
(button-event) tracking is switched on only while a drag is in progress —
some terminals stop reporting the mouse entirely when it is on from startup.
The status line echoes the last mouse event (`mouse: y,x press area`); if it
says `no mouse events yet`, your terminal is not reporting the mouse to the
app — inside tmux enable it with `set -g mouse on`.

## Project files

A `.bcl` file is plain replayable bash — the same calls the layout layer
takes — so it is readable, diffable and hand-editable:

```text
bc_screen "  main" rows="*" cols="*" gap=0 border=0
bc_grid main "  main.0 main.1" rows="*" cols="* *" gap=0 border=0
bc_style main.0 border title="left" pair=2
BB_TAG[main.0]=list
```

`BB_TAG[...]` lines record which widget each leaf should get on export.

`examples/dtail.bcl` is a saved two-pane project; `examples/dtail.sh` is the
filled-in dual-tail app built from that layout.
→ **[docs/tutorial-dtail.md](tutorial-dtail.md)**

## Export

`Ctrl-E` writes a runnable skeleton app: the layout calls, `init_pair` lines
for the design colours, and a stub per leaf based on its tag (`bc_list` +
`row_…` for `list`, `bc_input` for `input`, a `draw_…` placeholder otherwise).
Fill in the stubs and run it.

## Tests

- `tests/unit_builder.sh` — headless model tests (split, delete/collapse,
  rename, styles, tags, floats, serialise round-trip, undo/redo, export).
- `tests/builder.sh` — tmux-driven: renders the UI, splits, prompts, saves,
  exports and checks the exported app parses.
