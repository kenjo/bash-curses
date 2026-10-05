# bc — a bash terminal UI library

An ncurses-flavoured API implemented in pure bash. Not a 1:1 reimplementation:
it covers the areas of the ncurses API that the reference corpora actually
exercise (see `references/API-MATRIX.md`), excludes wide characters and the
terminfo API (impractical in bash, no real consumer in the corpora), and
makes a small number of deliberate API deviations listed below. `wgetch`
key decoding consults the terminal's terminfo keycaps via `infocmp` (see
Input).

## Layout

- `lib/bc.sh` — the library. Source it: `source ./lib/bc.sh`. Requires bash
  >= 4.3 (associative arrays), `stty`, `tput`. ASCII only.
- `examples/*.sh` — ports of the ncurses test-suite demos, used as smoke
  tests. Each example is C-faithful to its source program.

## Testing

Interactive programs need a real tty. `tmux` is installed on the host and is
the standard way to run the examples (and reference TUI apps such as `mc`),
feed them keys, and inspect the rendered screen:

- `tmux new-session -d -s bc -x 100 -y 30 ./examples/newdemo.sh`
- `tmux capture-pane -t bc -p` — pane contents as text
- `tmux send-keys -t bc Down Enter q` — feed keys
- `tmux kill-session -t bc`

Verified working with Midnight Commander (`mc`) on this host.

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

## Test suite

`tests/run.sh` runs both suites:

- `tests/unit.sh` — headless (no tty): mouse decode/merge semantics,
  SGR/X10 battery, key-table lookup, and KEY_*/mouse-mask constants
  compared against `/usr/include/ncurses.h`.
- `tests/integration.sh` — tmux-based: runs the key + mouse battery app
  in a pane, injects keys and mouse reports with `send-keys -H`, and
  asserts the expected KEY_*/bstate output (the app writes to
  `tmp/bc_out.txt`; panes are created/killed by the test).

## Scope (from references/API-MATRIX.md)

Implemented now:
init, window, pad (minimal), output, input, mouse, color, attr,
box/bkgd, macros (COLS/LINES/COLORS/COLOR_PAIRS/SP/ESCDELAY/TABSIZE/PC/BC/UP),
vid (vidattr/vidputs), screen (scr_dump/scr_init/scr_restore/scr_set),
slk (slk_init/slk_set/slk_label/slk_refresh/slk_noutrefresh/slk_clear/
slk_restore/slk_touch/slk_color/slk_attr* family, 16 base symbols).

Planned (in scope per the matrix, not yet implemented):
panels, menus, forms.

Out of scope: wide (77 symbols), terminfo API (85 symbols; keycap lookup
via `infocmp` is used for key decoding).

## Verification (examples/newdemo.sh vs C newdemo)

Headless frame-diff harness: run each under a 24x80 pty with `script`,
no input, capture the byte stream, decode it to an 80x24 cell grid
(char + SGR attrs + colour pair), and diff.

- Captures: C `references/ncurses/test/newdemo` (timeout 34, ends mid first
  wait) vs `bash examples/newdemo.sh` (timeout 43, same point).
- Result: **0 differing cells of 672 written cells** — the rendered frame
  (window, border, colours, subwindows, Ausmap, PDCurses line) matches the
  C reference pixel-for-pixel.
- The random-char and bouncing-ball phases use different RNGs (C `rand()`
  vs bash `RANDOM`), so they match structurally, not pixel-for-pixel.

Slk parity: a 7-frame demo (`/tmp/opencode/slkdemo.c` / `slkdemo_sh.sh`)
exercises slk_init(0) + 8 slk_set labels + per-frame slk_refresh/refresh
(frames 0-5), and frame 6 uses slk_init(3): 2-line slk, 12 labels, and the
info line. Each frame decodes to 0 differing cells of 1920 (C capture vs
bash).

Caveat: every capture must be run with `TERM=xterm-256color` explicitly.
The host default TERM is screen-256color, whose smacs/rmacs are SO/SI
(`\016`/`\017`) instead of the A9 charset switch; ACS characters then
appear in the byte stream as plain `l`/`q`/`x`/... with no `\x1b(0`.

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

Implemented (see `MOUSE.md` for the full semantics, ground-truth evidence,
and debugging record):

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
- `PAIR_NUMBER` is not provided: the pair is a separate argument, so there
  is no packed chtype to extract it from.
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
