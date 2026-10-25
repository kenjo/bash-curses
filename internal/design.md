# bc — a bash terminal UI library

An ncurses-flavoured API implemented in pure bash. Not a 1:1 reimplementation:
it covers the areas of the ncurses API that the reference corpora actually
exercise (see `api-matrix.md`), excludes wide characters and the
terminfo API (impractical in bash, no real consumer in the corpora), and
makes a small number of deliberate API deviations listed below. `wgetch`
key decoding consults the terminal's terminfo keycaps via `infocmp` (see
Input).

## Layout

- `lib/bc.sh` — the library. Source it: `source ./lib/bc.sh`. Requires bash
  >= 4.3 (associative arrays), `stty`, `tput`. ASCII only.
- `examples/*.sh` — ports of the ncurses test-suite demos, used as smoke
  tests. Most examples are C-faithful; current accepted differences are
  listed in `example-deviations.md`.

## Testing

Interactive programs need a real tty. `tmux` is installed on the host and is
the standard way to run the examples (and reference TUI apps such as `mc`),
feed them keys, and inspect the rendered screen:

- `tmux new-session -d -s bc -x 100 -y 30 ./apps/newdemo.sh`
- `tmux capture-pane -t bc -p` — pane contents as text
- `tmux send-keys -t bc Down Enter q` — feed keys
- `tmux kill-session -t bc`

Notes for driving tmux panes programmatically:

- launch scripts as `bash <script>` (files may not be executable);
- inject raw byte sequences with `tmux send-keys -H -t <pane> <hex...>`
  (e.g. `1b 5b 3c 30 3b 35 3b 36 4d` for `\E[<0;5;6M`);
- a lone ESC makes a blocking reader wait `ESCDELAY` (1000 ms) — sleep
  >= 1.5 s after injecting one;
- mouse click runs: reports 50 ms apart (< `BC_MAXCLICK`=166 ms),
  >= 0.6 s between runs;
- panes inherit the host default `TERM=screen-256color` — export
  `TERM=xterm-256color` in the app when injecting xterm key sequences.

## Testing

`tests/run.sh` runs the full suite. See `testing.md` for the current groups,
app-level tests, parity tools, and tmux caveats.

## Scope (from api-matrix.md)

Implemented now:
init, window, pad (minimal), output, input, mouse, color, attr,
box/bkgd, macros (COLS/LINES/COLORS/COLOR_PAIRS/SP/ESCDELAY/TABSIZE/PC/BC/UP),
vid (vidattr/vidputs), screen (scr_dump/scr_init/scr_restore/scr_set),
slk (slk_init/slk_set/slk_label/slk_refresh/slk_noutrefresh/slk_clear/
slk_restore/slk_touch/slk_color/slk_attr* family, 16 base symbols).

Planned (in scope per the matrix, not yet implemented):
panels, menus, forms.

Out of scope: the wide-character cell model (77 symbols; only thin
single-cell wrappers are provided), and the terminfo API (85 symbols; keycap
lookup via `infocmp` is used for key decoding).

## Slk implementation notes
- The slk window is a 1x80 (fmt 0..2) or 2x80 (fmt 3) window created by
  `initscr` after `slk_init` when the pending flag is set, at
  (LINES - SLK_LINES, 0) — matching ncurses `newwin(SLK_LINES, COLS,
  LINES - SLK_LINES, 0)`.
- Label geometry follows ncurses' slk_intern: stored fmt 1,2 -> 8 labels of
  8 cols, fmt 3,4 -> 12 labels of 5 cols, with gaps of
  (COLS - n*len - extra)/2 inserted (fmt 1 after labels 3,5; fmt 2 after
  label 4; fmt 3/4 one gap of 5 between labels 4 and 5).
- `slk_set` justification: 0 left, 1 centred, 2 right; non-printable
  characters (byte < 32 or > 126) truncate the label.
- `slk_clear` copies stdscr's bkgd into the slk window, then werase's it.
- For the 2-line (fmt 3) slk, the info line is an HLINE row (`mvwhline`
  with 0,0 draws ACS_HLINE) with `F1`..`F12` over the label positions,
  matching ncurses' `slk_paint_info`.

## Data model

One global character grid of absolute `(y, x)` cells, plus per-window state.
Cells are stored in three parallel associative arrays keyed `"$y $x"`:

- desired state: `BC_C` (char), `BC_A` (attr bits), `BC_P` (color pair)
- last-sent state: `BC_S`, `BC_SA`, `BC_SP` (the diff source for wrefresh)

A *window* is an integer handle (`stdscr` = 0) with origin, size, background,
per-window cursor and current attr/pair in the `BC_W*` arrays. Windows are
viewports over the shared grid (this is what makes overlapping `subwin`s
work). Each window keeps a dirty-key list (`BC_WD[win]`); writers mark cells
dirty, `wrefresh` only visits dirty cells and emits CUP+SGR+char for cells
that actually differ from the last-sent state.

## Attribute bits

| macro | value | SGR |
|---|---|---|
| A_NORMAL | 0 | 0 |
| A_BOLD | 1 | 1 |
| A_DIM | 2 | 2 |
| A_REVERSE | 4 | 7 |
| A_BLINK | 8 | 5 |
| A_UNDERLINE | 16 | 4 |
| A_INVIS | 32 | 8 |
| A_PROTECT | 64 | 73 |

Colour pairs: registered pairs (`init_pair`) emit standard SGR
(`30+fg` / `40+bg`, falling back to `38;5;` / `48;5;` for colours 8+);
unregistered pairs use `38;5;fg;48;5;bg`. `COLOR_PAIR(n)` is not a bitmask
here — the pair travels as a separate argument (see deviations).

## Key codes

ncurses values (all defined in `lib/bc.sh`, verified against the installed
ncurses 6.6 `/usr/include/ncurses.h` by the unit tests):

KEY_CODE_YES=256, KEY_BREAK=257, KEY_DOWN=258, KEY_UP=259, KEY_LEFT=260,
KEY_RIGHT=261, KEY_HOME=262, KEY_BACKSPACE=263, KEY_F0=264,
KEY_F1=265 ... KEY_F12=276, KEY_DL=328, KEY_DC=330 (KEY_DELETE alias),
KEY_IC=331, KEY_CLEAR=333, KEY_NPAGE=338, KEY_PPAGE=339, KEY_BEGIN=354,
KEY_END=360, KEY_MOUSE=409, KEY_RESIZE=410, KEY_MAX=511.

## Input

Raw mode via `stty raw -echo` (previous setting saved for `endwin`).
`wgetch` polls stdin with `read -rsn1 -t 0.001` when the window is in
`nodelay` mode, blocks otherwise. The result lands in the global variable
`key`; return status is 0 (a key was read) or 1 (ERR / timeout).

Key decoding is terminfo-driven. `initscr` builds a sequence -> KEY_* table
from `infocmp -1 -x "$TERM"` (`_bc_load_keytable`): the caps
kcuu1/kcud1/kcul1/kcub1/kcuf1 (cursor arrows), khome, kend, kf1-kf12,
kdl1, kich1, kppage, knpage, kclr are mapped to KEY_UP/DOWN/LEFT/RIGHT,
KEY_HOME/KEY_END, KEY_F1-F12, KEY_DC, KEY_IC, KEY_PPAGE/KEY_NPAGE,
KEY_CLEAR. `wgetch` reads one byte; on ESC it keeps reading (up to an
`ESCDELAY` timeout of one byte at a time) and then:

- exact table match -> that KEY_*;
- bare ESC on timeout -> ESC (27);
- a table entry has the partial sequence as a prefix -> keep waiting;
- otherwise -> ESC now, rest of the sequence pushed to the pending queue.

The pending queue (bytes pushed back from unknown sequences) is drained
before stdin is read again, so an unknown multi-byte sequence comes out as
its raw bytes, one per `wgetch` call — exactly what C ncurses does for
unknown keys under the same TERM. Consequence: key decoding is
TERM-dependent. tmux panes inherit the host default
`TERM=screen-256color`, whose keycaps differ from `xterm-256color`
(e.g. `khome=\E[1~` vs `\EOH`, no `kcub1`), so tests/batteries that inject
raw sequences must set `TERM=xterm-256color` in the app.

Mouse reports (SGR 1006 / X10) are intercepted by `wgetch` before the key
table; see Mouse.

bash 5.3 notes: `select` is a keyword only (the fd-waiting form is gone) and
`read -t 0` is unreliable (returns success with no data), hence the 1 ms
poll.

## Mouse

Implemented (see `../docs/mouse.md` for user-facing semantics and
`mouse-internals.md` for wire formats, test coverage, and implementation
notes):

- API: `mousemask`, `mouseinterval`, `getmouse`, `ungetmouse`,
  `has_mouse`.
- `wgetch` intercepts SGR 1006 (`\E[<b;x;yM|m`) and X10 (`\EM Cb Cx Cy`)
  reports, decodes button/x/y/modifiers, consumes a whole run of
  consecutive reports (quiet period `BC_MAXCLICK`=166 ms, the ncurses
  `DEFAULT_MAXCLICK`), merges press+release pairs into CLICK and CLICK runs
  into DOUBLE/TRIPLE (no x/y comparison in the second pass, matching
  ncurses), filters by mask, queues the surviving events and returns
  `KEY_MOUSE` (409). Events are consumed by `getmouse` (fields in
  `BC_ME_ID`/`BC_ME_X`/`BC_ME_Y`/`BC_ME_BSTATE`).
- `bstate` uses the NCURSES_MOUSE_VERSION 2 encoding
  (`MASK(button, m) = m << ((button-1)*5)`); aggregate masks are computed
  as ORs of the per-button constants. Wheel up/down are buttons 4/5.

## Terminal setup

`initscr` detects size/colors with `tput lines/cols/colors` (fallback
24x80, no color), enters raw mode, switches to the alternate screen
(`ESC[?1049h`), clears it, hides the cursor. `endwin` shows the cursor,
leaves the alternate screen and restores the saved `stty` settings.
`endwin` also runs from an EXIT trap, so a killed script still leaves the
terminal usable.

## API deviations from ncurses

- `wattrset(win, attr, pair)` — pair is a separate 3rd argument (ncurses
  packs it into the chtype). Same for `wbkgd(win, ch, attr, pair)`.
- `wgetch(win)` returns status 0/1 and puts the character/key in the global
  `key` (bash has no out-parameters).
- `getmaxyx(win)` sets globals `BC_GMY` (height) and `BC_GMX` (width);
  `getbegyx(win)` sets `BC_GBY`, `BC_GBX`.
- `mvwinch(win, y, x)` sets globals `wch`, `wcha`, `wchp` (char, attr,
  pair); it prints nothing, since bash cannot return a struct.
- Window handles are obtained through the global `bc_win`: `newwin`,
  `newpad`, `derwin`/`subwin` set it to the new handle. Never use command
  substitution (`win=$(newwin ...)`) — the function would run in a
  subshell and all library state (arrays, `BC_WN`) would be lost.
- `subwin(win, h, w, y, x)` uses absolute screen coordinates (verified
  against the system ncurses 6.6: parent (5,16) + args (8,21) gives origin
  (8,21)); `derwin` is an alias.
- `ACS_*` are single Unicode box-drawing characters, not alt-charset
  escapes.
- No wide characters; no terminfo API (only keycap lookup via `infocmp`
  for key decoding); no pads beyond `newpad`/`werase`/`prefresh` stubs
  (phase 2).
- `mousemask`/`mouseinterval` always return 0 (ncurses returns
  OK/ERR); the previous value is written to the optional `oldvar`
  argument / `BC_OLD_MAXCLICK`.
- `getmouse` puts the event in `BC_ME_*`; `BC_ME_ID` is always "0"
  (ncurses uses the window id).
- `ungetmouse` re-queues the current `BC_ME_*` event and a pending
  `KEY_MOUSE`, so the event comes back through `wgetch`.
- A failed partial mouse-read loses the bytes consumed so far (no
  push-back of partial SGR payloads).
- `beep()` emits `ESC [ bel` via `\a`.
- `PAIR_NUMBER` is provided as a compatibility wrapper; because this library
  keeps attributes and color pairs separate, it simply masks the low 9 bits of
  the value passed to it.
- `ESCDELAY` (default 1000 ms) is the timeout used when `wgetch` decides
  whether an ESC is a key-sequence leader or a bare ESC.
- `use_screen` is not implemented (bash cannot run a second curses context
  in the same process); it returns ERR.
- `scr_dump` writes `$SCR_FILE` (default `SCR.SAV`): one line per row, cells
  separated by US (`\x1f`), each cell `attr pair char`. `scr_set` clears the
  screen first, `scr_restore` does not.
- `PC`, `BC`, `UP` are termcap constants (padding char, backspace char,
  cursor-up string) provided as fixed values.
- `slk_wset` is not provided: there is exactly one slk window (ncurses
  allows a per-window slk context via WINDOW*); slk state is global.

## Layout layer (lib/layout.sh)

An optional layer sourced after (or instead of) `lib/bc.sh`; the ncurses API is
untouched. Public names are `bc_*`, internal state is `BCL_*` (associative
arrays keyed by area name), results come back in globals as in `bc.sh`.

Model:

- **Grids.** `bc_screen` defines the root grid `screen`; `bc_grid AREA` gives an
  area its own grid; `bc_cells AREA N` is a grid whose template is generated
  (and re-shaped on every relayout from the area's aspect ratio, with cells
  about twice as wide as tall). A template is parsed once into per-area track
  spans (`BCL_R0/R1/C0/C1`); every area must fill its bounding box, and errors
  name the line, column and area.
- **Track sizing** (`_bcl_tracks`): fixed and `auto` tracks first (shrinking
  from the last track when they overflow), then the rest is split by weight
  with rounding leftovers going to the first weighted tracks, so tracks tile
  exactly. `auto` is the largest minimum of the areas spanning only that track:
  measured `bc_text` content, or a nested grid's fixed+auto sum, plus insets.
  `0` hides a track (no gap is spent on it).
- **Floats** are placed after the tiled tree, in float order (parents first):
  size from `N`/`N%`/`auto`/`A..B`/`A%..B%` (random picks and the random
  position fraction are made once, in `BCL_FRND`, so a float keeps its size
  and relative position across resizes), position relative to `in=`, clamped
  inside `within=` (default: the `in=` parent's content rect).
- **Insets.** A `border` insets content by 1; a `shadow` adds one row/column
  to the rectangle. Grids inside a framed area lay out in its inset rect.

Windows (`bc_relayout`):

- Each leaf area and each container with something to show (float, border,
  colour, title) is bound to a frame window `F` with its own panel. A bordered
  leaf draws into a derwin `C` inset by 1, which is its own panel right above
  `F` because `doupdate` only collects dirty cells from panel windows. A
  shadow is two more strip windows (right of and below the box), leaving the
  two outer corners uncovered so the screen shows through.
- Only windows whose rectangle changed are rebuilt (`delwin` + `newwin`; much
  cheaper than `wresize`/`mvwin`, which re-mark or move every cell). Panels are
  restacked: tiled areas at the bottom (a container's frame below its kids),
  panels the app created itself in the middle, floats on top.
- Content colours (`pair`/`attr`) are inherited through enclosing grids, so a
  dialog's fields take the dialog's colours.
- `bc_text` content is retained and redrawn at the next update (and when a
  window is rebuilt); it only triggers a relayout when an `auto` track or
  auto-sized float depends on it. Redraws repeat until nothing is pending, so
  a `draw_NAME` that sets another area's text shows up in the same update.
- **Change-only drawing.** A `draw_NAME` sees its area as if freshly cleared,
  but clearing it for real would mark every cell dirty and `doupdate` pays
  ~23 us per dirty cell (a Down in `90-layout.sh` at 191x74 took ~290 ms).
  Instead `_bcl_put` writes only the differing part of a string (comparing
  rendered char/attr/pair against the window's cells, or the owner row cache;
  skipped outright when it equals the last write to that row, `BCL_LAST`),
  records what each redraw wrote (`BCL_SPAN`) and how far text may extend per
  row (`BCL_EXT`), and after the redraw blanks only the old text that was not
  rewritten. A Down now dirties two rows: ~35 ms, the same as `mc.sh`.
  Clears, frame repaints and rebuilds forget that per-row state; an area the
  app drew with raw `bc.sh` calls (`bc_win`) is fully cleared before redraws.

Input: `bc_getkey` flushes (`bc_update`: relayout if needed, pending draws,
`doupdate` — so `wgetch`'s implicit `wrefresh(stdscr)` finds nothing dirty)
and reads a key; on `KEY_RESIZE` it runs `resizeterm`, relayouts and forces a
full repaint, dropping `BC_DELRECTS` because the old rectangles may lie
off-screen after a shrink; on `KEY_MOUSE` it maps the event to the topmost
area (`BCL_AREA`, content-relative `BCL_MY/BCL_MX`). `bc_run` uses one loop
(`_bcl_loop`) for itself and for `bc_modal NAME`; keys go to the topmost
float with a handler (`keys=FN` / `key_NAME`, restricted to the modal float's
sub-tree), else `on_key`; frame timing uses `wtimeout` on stdscr with the time
left until the next `on_tick`. `_bcl_readkey` is the only input call, so tests
replace it with a fake key source.

Cost (tests/bench_layout.sh, this host): solving the mc-like screen is ~1.9 ms
and a no-op `bc_relayout` ~2.5 ms; a real resize of it is ~130 ms, mostly
painting the rebuilt windows. The shining-like stress case (136 floats, 566
panels) solves in ~18 ms and rebuilds in ~0.9 s. Measured in a real 191x74
terminal: `apps/shining-layout.sh` shows its first frame after ~1.9 s and runs
at ~3.9 frames/s (`apps/shining.sh`: ~1.5 s, ~1.1 frames/s); a Down in
`90-layout.sh` takes ~35 ms, like `mc.sh`. Startup and frame
times must be measured in a real terminal (tmux + `BC_TEST_DIR` frame
counter); headless runs that send `doupdate` to /dev/null hide its cost.

**Widgets and the `92` case study.** `lib/widgets.sh` builds named widgets on
top of the layout layer: `bc_list` (with `row_`/`select_`/`enter_NAME` hooks),
`bc_menubar`, `bc_dialog`/`bc_input`/`bc_check`/`bc_button`/`bc_cycle`/
`bc_label`. A list's draw is itself partial: `_bcw_list_draw` redraws only the
old and new selected rows when the scroll top is unchanged (`BCW_PSEL`/
`BCW_PSEQ`/`BCW_PTOP`), and `bc_list_redraw_sel NAME` redraws just the selected
row when the highlight depends on state outside the list (which panel is
active, whether the menu bar is open) — so a Tab or an F9 dirties two rows
instead of two whole panels. `apps/mc-layout.sh` rewrites the full `mc`
clone (3829 lines) as 1526 lines of template + draw callbacks + widgets, and
`tests/mc_layout.sh` runs the entire `mc_*` regression suite against it.
Current layout behavior:

- A `"* *"` grid rounds the extra column into the first track. For exact
  panel splits at odd widths, use explicit fixed tracks plus a filler column
  and rebuild the template from `on_resize`.
- `_bcl_put` treats `pair=0` as "no pair". Full-row repaints that need a
  literal pair 0 must use the window background pair or raw `bc.sh` calls.

Current core behavior:

- The uniform row cache is used only by the window that owns the buffer.
- `delwin` of a derwin walks only its own rectangle.
- Clearing a window's dirty marks walks that window's dirty list.
- `doupdate` composites through a cached owner map (`BC_OWN`), rebuilt when
  the panel stack or a panel rectangle changes.
- `werase` does not call a function per cell.
- `cbreak` re-enables signal keys as in ncurses.

## Bash 5.3 implementation pitfalls

- Unbraced `$arr[sub]` inside an unquoted `for` word corrupts the split
  fields: the literal subscript text is appended to the last field (e.g.
  `$V[0]` with value `a b,c d` and `IFS=','` yields tokens `""`, `a b`,
  `c d[0]`; with subscript `5` the value vanishes entirely). Always write
  `${arr[sub]}` when the expansion feeds a word list. (Plain variables and
  braced expansions are unaffected.)
- `read -t` returns 142 (SIGALRM) on timeout, not 1; treat any non-zero as
  "no data".
- `[[ a < b ]]` / `[[ a > b ]]` string comparisons use the locale collation
  order (strcoll). Under en_US.UTF-8 punctuation sorts below letters, so
  `[[ L > '~' ]]` is TRUE. For byte-range checks (e.g. printable-ASCII
  scans) use `printf -v o '%d' "'$c"` and compare the numeric value; an
  env-assignment prefix (`LC_ALL=C [[ ... ]]`) does not affect builtins.

## Concurrency / signals

None. Single process, cooperative.
