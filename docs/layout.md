# `lib/layout.sh` — the layout layer

The layout layer turns a *description* of your screen into windows. You name
the areas in an ASCII template, the library sizes them, keeps them correct
across resizes, and redraws only what changed. Your app draws by area name and
never computes coordinates.

```bash
source lib/layout.sh   # pulls in lib/bc.sh
```

- **Tutorial** — build a small app step by step.
- **Reference** — every public function, option, callback and global.
- **Pitfalls** — the handful of rules that bite.

For interactive building blocks (lists, menus, dialogs) see
[docs/widgets.md](widgets.md), which sits on top of this layer.

---

## Tutorial

### 1. Describe the screen

`bc_screen` takes an ASCII template: each token is an area name, repeated
tokens mean the area spans several cells, `.` is empty space. Every area must
be a rectangle.

```bash
bc_screen "
  menu  menu
  left  right
  keys  keys
" rows="1 * 1" cols="* *"
```

`rows=`/`cols=` give one *track size* per template row/column:

| Size | Meaning |
|---|---|
| `N` | exactly N cells |
| `*` | one share of the leftover space |
| `N*` | N shares (e.g. `2* 1*` is a 2:1 split) |
| `auto` | fit the content (`bc_text` / `bc_content` / nested grids) |
| `0` | hidden (no window, takes no space) |

`gap=N` puts N blank cells between tracks; `border=N` insets the whole grid.
Omit `rows=`/`cols=` and every track is `*`.

### 2. Start up and run the loop

`bc_init` does `initscr` plus the usual modes (cbreak, noecho, keypad, hidden
cursor, colours, `endwin` on exit, `SIGWINCH` → `KEY_RESIZE`). `bc_run` owns
the event loop: it updates the screen, reads a key, and calls your handlers
until you call `bc_quit`.

```bash
bc_init mouse          # bc_run would call this for you if you skipped it
bc_run                 # blocks until bc_quit
```

### 3. Draw by area name

Define a `draw_NAME` function per area. It is called with the area name and
should describe the area's *whole* content, as if the area had just been
cleared — the layer figures out which cells actually changed and only writes
those.

```bash
draw_left() {
  local i
  for i in "${!items[@]}"; do
    bc_print left "$i" 0 "${items[i]}"
  done
}
```

`bc_print NAME Y X TEXT` writes at content coordinates (0,0 is the top-left of
the drawable content, inside any border), clipped to the area, no wrap. When
you change something, ask for a redraw with `bc_dirty NAME`, then the loop
repaints on the next update.

```bash
on_key() {
  case $key in
    n) items+=("new item"); bc_dirty left ;;
    q) bc_quit ;;
  esac
}
```

### 4. Style the areas

`bc_style NAME [options]` sets colours, borders, titles and shadows. A
container's `pair=`/`attr=` are inherited by everything inside it, so styling
`screen` sets the background of the whole app.

```bash
bc_style screen pair=1
bc_style menu  pair=2 border
bc_style left  border title="Files"
bc_style keys  pair=6
```

`pair=N` is a colour pair from `init_pair` (see `docs/bc.md`). `pair=0` is a
real pair, not "unset" — pass no `pair=` option to inherit.

### 5. A complete small app

```bash
#!/usr/bin/env bash
source lib/layout.sh

items=(one two three)
sel=0

bc_screen "
  menu menu
  left right
  keys keys
" rows="1 * 1" cols="* *"

bc_style screen pair=1
bc_style menu pair=2
bc_style left border title="Files"
bc_style right border title="Preview"
bc_style keys pair=6

draw_menu() { bc_print menu 0 2 " Files   Preview "; }
draw_left() {
  local i
  for i in "${!items[@]}"; do
    if (( i == sel )); then
      bc_print left "$i" 0 "${items[i]}" pair=4
    else
      bc_print left "$i" 0 "${items[i]}"
    fi
  done
}
draw_right() { bc_print right 0 1 "${items[sel]}"; }
draw_keys()  { bc_print keys 0 1 "n=new  q=quit"; }

on_key() {
  case $key in
    n) items+=("item ${#items[@]}"); bc_dirty left ;;
    q) bc_quit ;;
  esac
}

bc_init
bc_run
```

Run it in tmux:

```sh
tmux new-session -d -s bc-doc -x 80 -y 24 bash tmp/docs/layout-1.sh
tmux capture-pane -t bc-doc -p
tmux send-keys -t bc-doc n n q
tmux kill-session -t bc-doc
```

### 6. Split an area: `bc_grid` and `bc_cells`

Any area can become its own grid. `bc_grid AREA TEMPLATE …` splits it; the
area itself then has no window (its children do).

```bash
bc_grid left "
  list
  status
" rows="* 1"
bc_dirty left.list      # draw_left is now draw_left.list
```

`bc_cells AREA N` splits an area into N roughly square cells named
`AREA.0 … AREA.N-1`; the rows×cols shape follows the area's aspect ratio and
is recomputed on every relayout (a terminal cell is about twice as tall as it
is wide).

```bash
bc_cells right 6        # right.0 … right.5, tiled like a grid of tiles
```

### 7. Floats: dialogs and popups

A *float* is a window on top of the tiled screen, placed relative to a parent
and kept inside it. It can hold text (`bc_text`, auto-sized) or a grid of its
own (a dialog).

```bash
bc_float confirm in=screen at=center size=5x20 border title="Sure?" shadow
bc_text confirm "Really?" align=center
```

`at=` accepts `center top bottom left right topleft topright bottomleft
bottomright random below:X above:X right:X left:X Y,X` (offset in the parent).
`size=HxW` dimensions are `N`, `N%`, `auto`, or `A..B` (random in range,
chosen once). `in=` is what it is placed relative to and what `N%` refers to;
`within=` is what it must stay inside (default: the `in=` parent).

Calling `bc_float` again for an existing float updates it in place.
`bc_raise NAME` brings it (and floats inside it) to the top; `bc_close NAME`
removes it.

### 8. Focus, keys and modals

Keys go to the focused area's handler first, then to floats top-down, then to
`on_key`. A handler that doesn't want a key calls `bc_pass` to let it go on.

```bash
bc_focus left          # left's key handler (or its widget's) sees keys first
```

`bc_modal NAME` runs a nested loop in which only NAME (and what is inside it)
sees keys and clicks, until it is closed. It returns 0 if a result was set,
left in `BCL_RESULT`.

```bash
draw_confirm() { bc_print confirm 1 2 "yes   no"; }
key_confirm() {
  case $key in
    y) bc_close confirm yes ;;
    n|"$'\e'") bc_close confirm no ;;
    *) bc_pass ;;
  esac
}

on_key() {
  [[ $key == d ]] && {
    bc_float confirm in=screen at=center size=5x20 border title="Sure?" \
      keys=key_confirm
    bc_text confirm "Delete item?" align=center
    if bc_modal confirm; then
      [[ $BCL_RESULT == yes ]] && { unset 'items[sel]'; bc_dirty left; }
    fi
  }
}
```

`bc_modal_done [RESULT]` ends the innermost modal from anywhere; `bc_quit`
leaves `bc_run` (and any modal inside it).

### 9. Mouse

`bc_init mouse` enables mouse reporting (`motion` also reports movement, for
drags; `clickms=N` sets the click interval). In `bc_run`, a mouse event
arrives as `KEY_MOUSE` and is dispatched for you: the topmost area under the
pointer is found, and `click_NAME Y X BSTATE` is called (or `on_click NAME Y X
BSTATE` if you don't define one). `Y X` are content coordinates of that area;
`BSTATE` is the button state (see `docs/bc.md` and `MOUSE.md`).

```bash
click_left() { sel=$1; bc_dirty left; }   # Y is the row clicked
```

For your own loops, `bc_getkey` fills `BCL_AREA` / `BCL_MY` / `BCL_MX` /
`BCL_MB` for the clicked area. `bc_hit Y X` does the hit-test directly.

### 10. Hooks `bc_run` calls

| Hook | When |
|---|---|
| `draw_NAME` | NAME is dirty; describe its whole content |
| `on_draw` | once per update, after all pending `draw_NAME`s |
| `on_key KEY` | keys no float/focus handler took |
| `key_NAME` | key handler for area/float NAME (or `keys=FN` on `bc_float`) |
| `click_NAME Y X BSTATE` | mouse on area NAME (content coords) |
| `on_click NAME Y X BSTATE` | mouse on any area without `click_NAME` |
| `outclick_NAME Y X BSTATE` | click outside a modal NAME (screen coords) |
| `on_tick MS` | every frame when `bc_run fps=N` (MS since last tick) |
| `on_resize` | after a resize has been handled |

---

## Reference

### Startup and loop

#### `bc_init [mouse] [motion] [clickms=N]`
`initscr` + cbreak/noecho/keypad/hidden cursor, `start_color` if available
(plus a shadow pair `BCL_SHADOW_PAIR`), `endwin` on exit, `SIGWINCH` →
`KEY_RESIZE`. `motion` adds `REPORT_MOUSE_POSITION`; `clickms=N` sets
`mouseinterval`. Sets `BCL_STARTED=1`. `bc_run` calls it (with `mouse`) if you
didn't.

#### `bc_run [fps=N]`
The event loop, until `bc_quit`. Each pass: update the screen, read a key,
dispatch it. With `fps=N` the read times out per frame and `on_tick MS` fires
about N times a second.

#### `bc_getkey`
For app-owned loops. Flushes pending drawing, reads one key into `$key`.
`KEY_RESIZE` is handled (relayout + full repaint) before it is returned;
`KEY_MOUSE` consumes the event into `BC_ME_*` and sets `BCL_AREA` / `BCL_MY` /
`BCL_MX` / `BCL_MB`.

#### `bc_quit`
Leave `bc_run` (and any `bc_modal` inside it).

### Defining the layout

#### `bc_screen TEMPLATE [rows=…] [cols=…] [gap=N] [border=N]`
Define the root grid. `screen` is reserved as its name.

#### `bc_grid AREA TEMPLATE [rows=…] [cols=…] [gap=N] [border=N]`
Split an existing area into its own template. The area gets no window; its
children do.

#### `bc_cells AREA N [gap=N]`
Split an area into N roughly square cells `AREA.0 … AREA.N-1`. Shape follows
the aspect ratio and is recomputed on every relayout.

#### `bc_relayout`
Recompute every rectangle and rebuild only the windows whose rectangle
changed. Called for you by `bc_update` when the layout is dirty.

#### `bc_rect NAME`
The area's outer rectangle (including border/shadow) in screen coordinates →
`BCL_Y BCL_X BCL_H BCL_W`.

### Styling

#### `bc_style NAME [pair=N] [attr=N] [border|border=0] [title=TEXT] [bpair=N] [tpair=N] [margin=N] [shadow|shadow=mc|shadow=0] [spair=N] [divider] [tleft]`
- `pair=`/`attr=` — the area's pen; inherited by children.
- `border` — draw a box; `bpair=` its colour (default: the area's pair).
- `title=` — text in the top border; `tpair=` its colour; `tleft` puts it at
  the left instead of centred. A title too long keeps its end.
- `margin=N` — N cells of background between the window edge and the border.
- `shadow` — solid strip one cell right and below; `shadow=mc` is Midnight
  Commander's see-through shadow (2 columns, 1 row); `spair=` its colour.
- `divider` — the (one-row) area is a rule `├───┤` joined to the enclosing
  border.
- `bc_style screen …` styles the background (stdscr).

### Drawing

#### `bc_print NAME Y X TEXT [pair=N] [attr=N]`
Write TEXT at content coordinates, clipped to the area (no wrap). Immediate:
the cell changes now; the layer skips it if the cells already hold exactly
this text and pen.

#### `bc_text NAME TEXT [pair=N] [attr=N] [align=left|center|right]`
Set the area's *retained* content. It is measured (so `auto` tracks and
auto-sized floats fit it) and drawn at the next update — and again whenever
the window is rebuilt. Prefer it over `bc_print` for content that should
survive a resize.

#### `bc_content NAME H W`
Tell the layout how big NAME's content is (for `auto` tracks and auto-sized
floats). Widgets use this.

#### `bc_clear NAME`
Erase the content to the area background.

#### `bc_dirty NAME…` / `bc_dirty all`
Ask for NAME to be redrawn (`draw_NAME` / retained text) before the next
update.

#### `bc_update`
Relayout if needed, redraw what is pending, push to the terminal. `bc_run`
calls it every pass.

#### `bc_win NAME`
`bc_win` = the area's content window handle, so you can call any `lib/bc.sh`
function on it. Returns 1 if the area is currently hidden. **Caveat:** using
this marks the area *raw* — the layer no longer knows what you drew, so it
falls back to a full clear before each redraw of that area.

#### `bc_size NAME`
Drawable content size → `BCL_H BCL_W` (`0 0` when hidden).

#### `bc_cursor NAME Y X` / `bc_cursor`
Show the terminal cursor at Y,X of NAME's content (it follows the area across
relayouts). No arguments hides it.

### Input and hit-testing

#### `bc_hit Y X`
Topmost area at screen cell Y,X → `BCL_AREA BCL_MY BCL_MX` (content coords);
`BCL_AREA=""` and status 1 if none.

#### `bc_focus NAME` / `bc_focus ""`
The area whose key handler sees keys first.

#### `bc_pass`
Called by a key or click handler: "not mine", so the event goes on to the next
handler (focus → floats top-down → `on_key` / `on_click`).

### Floats

#### `bc_float NAME [in=PARENT] [within=AREA] [at=PLACE] [size=HxW] [nudge=DY,DX] [keys=FN] [style…]`
Create or update a float. Style options are as for `bc_style`.
- `in=` — parent it is placed relative to and that `N%` sizes refer to
  (default `screen`).
- `within=` — what it must stay inside (default: the `in=` parent). A float
  placed in a small cell but kept within the whole screen can overhang it.
- `at=` — `center top bottom left right topleft topright bottomleft
  bottomright random below:X above:X right:X left:X Y,X`. `random` puts the
  top-left corner anywhere it fits (choices fixed at creation).
- `size=HxW` — each dimension `N`, `N%`, `auto`, `A..B`, `A%..B%` (random in
  range, chosen once).
- `nudge=DY,DX` — added to the position before clamping.
- `keys=FN` — key handler used by `bc_run` / `bc_modal`.

#### `bc_raise NAME`
Bring a float (with the floats inside it) to the top.

#### `bc_close NAME [RESULT]`
Remove a float, the floats inside it, and all their windows. RESULT is handed
to a waiting `bc_modal` (in `BCL_RESULT`).

### Modals

#### `bc_modal NAME`
Nested loop: only NAME (and what is inside it — its grid, floats placed in it)
sees keys and clicks, until NAME is closed (`bc_close NAME [RESULT]` for a
float) or `bc_modal_done [RESULT]` is called. A click outside goes to
`outclick_NAME Y X BSTATE` (screen coordinates) if defined, else nowhere.
Returns 0 if it ended with a result, left in `BCL_RESULT`.

#### `bc_modal_done [RESULT]`
End the innermost `bc_modal`.

---

## Globals you may read

| Global | Meaning |
|---|---|
| `BCL_ERR` | last layout error message (also printed to stderr) |
| `BCL_AREA` `BCL_MY` `BCL_MX` `BCL_MB` | last hit-test / mouse event |
| `BCL_SEL` | set by `bc_list_sel` |
| `BCL_RESULT` | result of the last `bc_modal` |
| `BCL_Y` `BCL_X` `BCL_H` `BCL_W` | output of `bc_rect` / `bc_size` |
| `BCL_FOCUS` | focused area name (`""` = none) |
| `BCL_FLOATS` | float names, bottom → top |
| `BCL_SHADOW_PAIR` | pair used for shadows |
| `BCL_PARTIAL` | set to 1 inside `draw_NAME` for a partial redraw |

Internal state uses the `BCL_` prefix (windows, rectangles, spans); apps
should not touch it.

---

## Pitfalls

- **Areas must be rectangles.** A name's cells must fill their bounding box
  exactly; `bc_screen`/`bc_grid` reject anything else.
- **Names come from the template.** A child area's name is the token you wrote
  in the template — `bc_grid body …` does *not* prefix children with `body.`.
  If you want dotted names (`body.list`), write them in the template, and use
  the full name in hooks: `draw_body.list`, not `draw_list`.
- **Track count must match the template.** `rows=`/`cols=` need exactly one
  size per template row/column.
- **Odd-width rounding.** When weighted tracks don't divide evenly, the extra
  cells go to the *first* weighted tracks. `bc_grid`/`bc_screen` with
  `"* *"` on an odd width gives the left track the extra column. If you need
  exact columns, use explicit sizes.
- **`pair=0` is a real pair.** Passing `pair=0` sets pair 0 (which normally
  renders as white-on-black); omit the option to inherit the parent's pen.
- **`bc_print` is not retained.** After a resize the window is rebuilt and
  `bc_print` output is gone unless a `draw_NAME` redraws it. Use `bc_text`
  for content that must survive.
- **`draw_NAME` describes the whole area.** The layer compares against what it
  remembers, so always draw the full content. If only some rows changed, set
  `BCL_PARTIAL=1` in the draw function: rows you didn't write are left alone
  instead of blanked.
- **`bc_win` makes an area raw.** The change-only optimisation is disabled for
  that area (full clear before each redraw).
- **`bc_text` on a container** (an area split by `bc_grid`) has no window of
  its own to draw into; put the text in a leaf area.
