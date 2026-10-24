# `lib/bc.sh` — the core layer

`bc.sh` is an ncurses-flavoured terminal UI library written in bash. It keeps
a per-cell model of every window and of the physical screen, and emits only
the differences on refresh — like ncurses, but with no compiled dependency.
Requires bash ≥ 4.3, `stty` and `tput`.

```bash
source lib/bc.sh
```

Run the file directly instead of sourcing it and it acts as the bundling CLI
(`bash lib/bc.sh bundle|unbundle`), which embeds the libraries into an app
script for single-file distribution — see
[distributing.md](distributing.md).

It is a working subset of ncurses, not a 1:1 port. The
[deviations](#deviations-and-gaps) section lists every place where behaviour
differs. For the higher layers see [layout.md](layout.md) and
[widgets.md](widgets.md).

---

## Quick start

```bash
#!/usr/bin/env bash
source lib/bc.sh

initscr
start_color
init_pair 1 COLOR_YELLOW COLOR_BLUE
init_pair 2 COLOR_BLACK COLOR_CYAN

mvaddstr 1 2 "hello from bc.sh"
attron A_BOLD
mvaddstr 2 2 "bold"
attroff A_BOLD
attr_set 0 1
mvaddstr 3 2 "yellow on blue"
attr_set 0 0
mvaddstr 4 2 "press a key, q to quit"

keypad "$BC_STDSCR" 1
mousemask ALL_MOUSE_EVENTS
nodelay "$BC_STDSCR" 0

while :; do
  wrefresh "$BC_STDSCR"
  wgetch "$BC_STDSCR" || break
  case $key in
    q) break ;;
    "$KEY_UP") mvaddstr 6 2 "up          " ;;
    "$KEY_DOWN") mvaddstr 6 2 "down        " ;;
    "$KEY_MOUSE")
      if getmouse; then
        mvaddstr 6 2 "click at $BC_ME_Y,$BC_ME_X   "
      fi ;;
    "$KEY_RESIZE") clear ;;
    *) mvaddstr 6 2 "key $key ($key)  " ;;
  esac
done
endwin
```

`initscr` enters the alternate screen, puts the terminal in raw mode and
installs an EXIT trap that calls `endwin`, so the terminal is restored even if
your script dies.

---

## Conventions

- **Status, not output.** Functions return 0 on success, 1 on failure
  (`ERR=-1` is the ncurses failure value). Nothing is printed to stdout
  except where a function is documented to `printf` a value.
- **Results come back in globals.** `wgetch` sets `key`, `winch` sets
  `wch`/`wcha`/`wchp`, `getyx` sets `BC_GCY`/`BC_GCX`, and so on. Never use
  command substitution — `$(wgetch)` runs the call in a subshell and loses
  all state.
- **Window ids are small integers.** `BC_STDSCR=0` is the whole screen;
  `newwin`/`derwin`/`subwin`/`dupwin`/`newpad`/`getwin` store the new id in
  the global `bc_win`. `BC_CURR` is the window used by the non-`w` variants.
- **Coordinates are `y x`**, 0-based, inside the window.

---

## Init and teardown

| Function | Meaning |
|---|---|
| `initscr` | Query size/colours via `tput`, save the `stty` settings, enter the alternate screen, hide the cursor, load the key table, create `stdscr` (id 0, keypad on), install the EXIT trap. Sets `BC_STARTED=1`, `LINES`, `COLS`, `COLORS`, `COLOR_PAIRS`. |
| `endwin` | Leave the alternate screen, restore `stty`, disable the mouse. Idempotent. |
| `isendwin` | True when not started. |
| `def_prog_mode` | Save the current `stty` settings (`BC_PROG_STTY`). |
| `reset_prog_mode` | Restore them and force a full redraw on the next refresh. |
| `use_window WIN` | Make WIN current; previous id in `bc_win`. |

## Terminal modes

`cbreak`, `noecho`, `raw`, `noraw` are thin `stty` wrappers. `keypad WIN BF`
enables function-key decoding per window (stdscr starts with it on).
`filter`/`nofilter` set `BC_FILTER` (no clear-screen optimisations).
`meta WIN BF` sets `BC_META`. `intrflush`, `qiflush`, `noqiflush` are
accepted no-ops. `has_ic`/`has_il` are always true. `erasechar`/`killchar`
`printf` the current codes (127/21); `erasewchar`/`killwchar` copy them into
`BC_ERASEWCHAR`/`BC_KILLWCHAR`.

---

## Windows

| Function | Meaning |
|---|---|
| `newwin NLINES NCOLS Y X` | New top-level window at screen position; id in `bc_win`. |
| `derwin WIN NLINES NCOLS Y X` | Descendant, origin relative to parent. `0` size means “rest of parent”. |
| `subwin WIN NLINES NCOLS Y X` | Same, but Y/X are absolute screen coordinates. Shares the parent's buffer. |
| `dupwin WIN` | Deep copy; id in `bc_win`. |
| `delwin WIN` | Free the window. |
| `mvwin WIN Y X`, `mvderwin WIN Y X` | Move (absolute / parent-relative). |
| `wresize WIN LINES COLS` | Resize a window. |
| `wmove WIN Y X`, `move Y X` | Move the window cursor. |
| `mvcur Y X` | Move the *physical* cursor (move + refresh). |
| `copywin SRC DST sminy sminx dminy dminx dmaxy dmaxx OVERLAY` | Copy a rectangle; `OVERLAY=1` skips source blanks. |
| `overlay SRC DST`, `overwrite SRC DST` | Whole-window copywin. |
| `putwin WIN FILE`, `getwin FILE` | Serialise/restore a window (library's own `BCWIN` format). |

Geometry and state:

| Function | Result |
|---|---|
| `getyx WIN` | `BC_GCY BC_GCX` (cursor) |
| `getcury WIN` / `getcurx WIN` | `BC_GCY` / `BC_GCX` |
| `getbegyx WIN` | `BC_GBY BC_GBX` |
| `getbegy WIN` / `getbegx WIN` | `BC_GBY` / `BC_GBX` |
| `getmaxyx WIN` | `BC_GMY BC_GMX` (height/width) |
| `getmaxy WIN` / `getmaxx WIN` | `BC_GMY` / `BC_GMX` |
| `getpary WIN` / `getparx WIN` | `BC_GPY` / `BC_GPX` (parent-relative origin; -1 for top-level) |
| `getattrs WIN` | `BC_GA` (current attr) |
| `getbkgd WIN` | `BC_GBKG BC_GBKG_A BC_GBKG_P` |
| `wgetdelay WIN` | `bc_delay` |
| `wgetparent WIN` | `bc_parent` |
| `wgetscrreg WIN` | `bc_top bc_bottom` |
| `is_subwin`, `is_pad`, `is_cleared`, `is_idcok`, `is_idlok`, `is_immedok`, `is_leaveok`, `is_syncok`, `is_scrollok`, `is_nodelay`, `is_notimeout` | Predicates on the window flags. |

Scrolling and flags: `scrollok WIN BF`, `wsetscrreg WIN TOP BOTTOM` /
`setscrreg`, `wscrl WIN N` / `scrl N` / `scroll [WIN]`, and the per-window
flags `clearok`, `idlok`, `idcok`, `immedok`, `leaveok`, `syncok` (each with
an `is_*` predicate above). `syncup`, `syncdown`, `wsyncup`, `wsyncdown` are
accepted but no-ops — compositing is done at refresh time.

---

## Output and drawing

All `w*` forms take the window as the first argument; the plain forms act on
`BC_CURR` (or `stdscr` where ncurses does). The `mv*` forms move the cursor
first.

| Function | Meaning |
|---|---|
| `waddstr WIN STR`, `waddnstr WIN STR N` | Write text at the cursor with the window's current attr/pair. |
| `waddch WIN CH [A P]`, `winsch WIN CH [A P]` | Write/insert one cell; optional attr/pair override. |
| `waddchstr WIN STR`, `waddchnstr WIN STR N` (+ `addchstr`, `addchnstr`) | Write a string as cells. |
| `wprintw WIN FMT ARGS…` and the `mv*`/plain forms | `printf`-style output. |
| `winsnstr WIN N STR`, `winsstr`, `winsn WIN Y X N STR` (+ `insnstr`, `insstr`, `insch`, `mv*`) | Insert text/cells (shifting). |
| `wdelch`, `wdeleteln`, `winsertln`, `winsdelln N` (+ `delch`, `deleteln`, `insertln`, `insdelln`, `mv*`) | Delete/insert cells and lines. |
| `wclrtoeol`, `wclrtobot` (+ `clrtoeol`, `clrtobot`) | Clear from cursor. |
| `werase`, `wclear`, `erase`, `clear` | Erase the window (`clear` also forces a full repaint). |
| `wborder WIN LS RS TS BS [TL TR BL BR]`, `box WIN [V H]`, `border`, `mvborder` | Draw a border with ACS characters. |
| `whline WIN CH N`, `wvline WIN CH N` (+ `h*`/`v*`/`mv*` forms) | Horizontal/vertical runs. |
| `wchgat WIN N ATTR PAIR`, `chgat N ATTR PAIR`, `mvchgat Y X N ATTR PAIR` | Restyle N cells from the cursor (`N<0` = to end of line); characters preserved, cursor unchanged. |
| `wbkgd WIN CH A P`, `wbkgdset`, `bkgd`, `bkgdset` | Background: `bkgd` also repaints, `bkgdset` only sets. |
| `bkgrnd WIN CCHAR [A P]`, `bkgrndset`, `getbkgrnd` | cchar-style background API. |
| `wechochar WIN CH [A P]`, `echochar`, `wecho_wchar`, `echo_wchar` | Write a cell and refresh immediately. |
| `beep` | Ring the terminal bell. |
| `flash` | No-op. |

Reading cells:

| Function | Result |
|---|---|
| `winch WIN` / `inch` / `mvwinch WIN Y X` / `mvinch` | `wch wcha wchp` |
| `in_wch WIN` / `in_wchnstr WIN N` / `in_wchstr WIN` and the `win_*`/`mv*` forms (`win_wch`, `win_wchnstr`, `win_wchstr`, `mvin_wch`, `mvin_wchnstr`, `mvin_wchstr`, `mvwin_wch`, `mvwin_wchnstr`, `mvwin_wchstr`) | same, cchar flavour |
| `inchnstr WIN N` / `inchstr WIN` / `mvwinchnstr` / `mvwinchstr` | arrays `bc_chstr bc_chattr bc_chpair` plus `bc_str` |
| `instr WIN N` / `innstr` / `mvwinstr` / `mvwinnstr` | `bc_str` |

---

## Attributes and colour

Attribute bits (combinable): `A_NORMAL=0`, `A_BOLD=1`, `A_DIM=2`,
`A_REVERSE=4`, `A_BLINK=8`, `A_UNDERLINE=16`, `A_INVIS=32`, `A_PROTECT=64`,
`A_ALTCHARSET=128`, `A_COLOR=256`, `A_ITALIC=512`.

| Function | Meaning |
|---|---|
| `wattrset WIN A P`, `attrset A P` | Set attr and pair outright. |
| `wattron WIN A` / `wattroff WIN A`, `attron`/`attroff` | Toggle attr bits. |
| `wattr_on`/`wattr_off`/`wattr_set`/`wattr_get` and `attr_on`/`attr_off`/`attr_set`/`attr_get` | ncurses-style attr API; `wattr_get`/`attr_get` → `BC_AG BC_AP`. |
| `color_set PAIR [OPTS]` | Set the pair (ncurses extended API). |
| `standout`, `standend` | `standout` turns on `A_ITALIC` (see deviations); `standend` resets attr and pair. |
| `start_color` | Enable colour; pair 0 becomes `(7,0)`. |
| `has_colors`, `has_named_color` | Colour availability. |
| `use_default_colors` | Pair 0 becomes the terminal default (`-1`). |
| `assume_default_colors FG BG` | Same, with explicit defaults. |
| `init_pair N FG BG` | Define pair N (1..`COLOR_PAIRS`). |
| `free_pair N` | Free a pair (colour retained for reuse). |
| `find_pair FG BG` | Existing pair with that colour, printed and in `bc_pair`. |
| `alloc_pair FG BG` | Find or allocate a pair; printed and in `bc_pair`. |
| `pair_content PAIR` | `BC_CPF BC_CPB`. |
| `COLOR_PAIR N` / `PAIR_NUMBER ATTR` | `printf` the pair number. |
| `init_color C R G B` | Redefine a colour (0–1000 scale). |
| `can_change_color` | False unless the terminal says otherwise. |
| `color_content C` | `BC_CR BC_CG BC_CB`. |
| `vidattr A [P]` / `vid_attr` | `printf` the SGR sequence for that attr/pair. |
| `vidputs STR A [P]` / `vid_puts` | `printf` the SGR sequence followed by STR. |

Colours: `COLOR_BLACK=0` … `COLOR_WHITE=7`; 16/256-colour terminals use the
numeric values directly. `BC_COLORS`/`COLORS` is the terminal's colour count,
`BC_PAIRS`/`COLOR_PAIRS` is 65536.

---

## Input and keys

| Function | Meaning |
|---|---|
| `wgetch WIN` | Read one key into the global `key`; 0 if read, 1 on timeout/`ERR`. Refreshes the window first. |
| `getch`, `getkey`, `mvwgetch WIN Y X`, `mvgetch Y X` | `getkey` is a library alias for `getch`. |
| `wget_wch WIN` / `get_wch` / `mv*` | cchar flavour: `wch wcha wchp`. |
| `wgetstr WIN [N]` / `wgetnstr WIN N` / `getstr` / `getnstr` / `mvgetstr` / `mvgetnstr` / `mvwgetstr` / `mvwgetnstr` | Line input into `bc_str`; ESC returns 1. |
| `wscanw WIN FMT VAR…` / `scanw` / `mv*` | Read a line and `scanf` it into VARs; count in `bc_scanw_count`. |
| `nodelay WIN BF` | Non-blocking reads. |
| `wtimeout WIN DELAY` / `timeout` | `-1` blocking, `0` non-blocking, `N` ms. |
| `halfdelay TENTHS` | Blocking with a tenths-of-second timeout. |
| `notimeout WIN BF` | ESC handling. |
| `flushinp` | Discard pending input. |
| `ungetch CH` | Push back a character, or a key code when `CH>255`. |
| `unget_wch WCH` | cchar flavour. |
| `napms MS`, `delay_output MS` | Sleep. |
| `curs_set VIS` | `0` hides the cursor, anything else shows it. |

Key values are the ncurses numbers: `KEY_DOWN=258`, `KEY_UP=259`,
`KEY_LEFT=260`, `KEY_RIGHT=261`, `KEY_HOME=262`, `KEY_BACKSPACE=263`,
`KEY_F0=264`…`KEY_F12=276`, `KEY_NPAGE=338`, `KEY_PPAGE=339`, `KEY_IC=331`,
`KEY_DC=330`, `KEY_BTAB=353`, `KEY_MOUSE=409`, `KEY_RESIZE=410`, plus the
full `KEY_*` table in `lib/bc.sh`. `ESCDELAY=1000` ms bounds ESC
disambiguation.

Key introspection: `has_key KEY`, `keyname KEY` (prints the `KEY_` name),
`key_defined DEF` (prints the code, also in `bc_key`), `keybound` (alias),
`keyok KEY BF` (previous in `bc_key`), `define_key DEF KEY` (bind a sequence;
`KEY=ERR` unbinds).

`KEY_RESIZE` is produced by `wgetch` after a `SIGWINCH` (`BC_WINCH`); call
`resizeterm` to adopt the new size.

---

## Mouse

Enable with `mousemask ALL_MOUSE_EVENTS`; `wgetch` then returns `KEY_MOUSE`
and the event sits in a queue. Full semantics in `MOUSE.md`.

| Function | Meaning |
|---|---|
| `mousemask NEWMASK [OLDVAR]` | Set the mask; the old mask is written into the variable named by `OLDVAR` (deviation). |
| `mouse_set [MASK]` | Library alias: `mousemask` with a default of `ALL_MOUSE_EVENTS`. |
| `mouseinterval MS` | Click-composition window; old value in `BC_OLD_MAXCLICK`. Default `BC_MAXCLICK=166`. |
| `getmouse` | Pop one event into `BC_ME_ID BC_ME_X BC_ME_Y BC_ME_BSTATE`; 1 when the queue is empty. |
| `ungetmouse` | Push the current `BC_ME_*` event back. |
| `has_mouse` | Whether a mouse is available. |
| `wenclose WIN Y X` | Are screen coords inside WIN? |
| `wmouse_trafo WIN Y X TOSCREEN` | Screen↔window coords → `BC_MT_Y BC_MT_X`. |
| `mouse_trafo Y X TOSCREEN` | Same for stdscr. |

`bstate` bits: `BUTTON1_PRESSED/RELEASED/CLICKED/DOUBLE_CLICKED/TRIPLE_CLICKED`
(buttons 1–5, button 4/5 = wheel up/down), the `BUTTON_*` all-button unions,
`BUTTON_CTRL`, `BUTTON_SHIFT`, `BUTTON_ALT`, `REPORT_MOUSE_POSITION`,
`ALL_MOUSE_EVENTS`.

---

## Refresh and dirty tracking

`wrefresh WIN` composites the window and emits the diff; `refresh` does
stdscr; `wnoutrefresh` updates the model without emitting; `doupdate` emits.
The usual ncurses `wnoutrefresh`-many-then-`doupdate` pattern works.

Dirty marks: `touchwin`, `untouchwin`, `is_wintouched`, `touchline WIN START
COUNT`, `wtouchln WIN Y COUNT CHANGED`, `is_linetouched WIN LINE`.

---

## Pads

`newpad NLINES NCOLS` (id in `bc_win`), `subpad`, `is_pad`. A pad is not
clipped to the screen; you blit a window of it with
`prefresh PAD pminrow pmincol sminrow smincol smaxrow smaxcol` (or
`pnoutrefresh` + `doupdate`). `pechochar PAD CH` writes and re-blits.

---

## Screen save/restore

`SCR_FILE` (default `SCR.SAV`) holds one line per row, cells separated by
US, each cell `"attr pair char"`.

| Function | Meaning |
|---|---|
| `scr_dump` | Write the current screen image to `SCR_FILE`. |
| `scr_init` | Load it into the library's model of the *physical* screen — nothing is emitted, so the next refresh only redraws what differs. |
| `scr_restore` | Load it as the new desired screen (redrawn on the next `doupdate`). |
| `scr_set` | Both. |

`use_screen` is not implemented (always returns 1).

---

## Soft labels (SLK)

`slk_init FMT` (0–3) before `initscr` defers, after it applies. Labels are
`slk_set I STR FMT` (FMT 0 left, 1 centre, 2 right); `slk_label N` prints the
text. `slk_refresh` / `slk_noutrefresh` paint them; `slk_clear` hides,
`slk_restore` shows, `slk_touch` marks dirty. Colour via `slk_color PAIR`;
attributes via `slk_attrset A`, `slk_attron A`, `slk_attroff A`,
`slk_attr_set A P OPTS`, `slk_attr_on A OPTS`, `slk_attr_off A OPTS`
(`OPTS` must be empty); `slk_attr` prints the current attribute.

---

## Panels

Panels order overlapping windows; compositing happens at refresh time, so
`update_panels` is a no-op.

| Function | Meaning |
|---|---|
| `new_panel WIN` | New panel; id in `bc_panel`. |
| `del_panel P` | Remove it (the window is not touched). |
| `top_panel P` / `bottom_panel P` | Reorder. |
| `show_panel P` / `hide_panel P` | Visibility. |
| `move_panel P NY NX` | Move its window. |
| `replace_panel P WIN` | Swap the window. |
| `panel_window P` / `panel_userptr P` / `set_panel_userptr P PTR` | Accessors. |
| `panel_tint P ON` | Library extension: force the panel's rectangle to repaint. |

---

## Resize

`resizeterm` re-reads the size from `tput`, resizes stdscr and forces a full
repaint. `resize_term LINES COLS` / `resizestdscr` set it explicitly;
`is_term_resized LINES COLS` asks. `wresize WIN LINES COLS` resizes one
window. `KEY_RESIZE` arrives from `wgetch` after a `SIGWINCH`.

---

## Wide characters and cchars

The model is single-width: a `cchar` is the first character of the string.
The ncurses cchar API exists in full: `wadd_wch`/`wadd_wchnstr`/`wadd_wchstr`,
`wins_wch`/`wins_wchnstr`/`wins_wchstr`, `winsn_wch`, `wget_wch`,
`unget_wch`, and their plain/`mv*`/`mvw*` forms (`add_wch`, `add_wchnstr`,
`add_wchstr`, `ins_wch`, `ins_wchnstr`, `ins_wchstr`, `insn_wch`,
`mvadd_wch`, `mvwadd_wchnstr`, `mvins_wchnstr`, `mvins_wchstr`,
`mvwins_wchnstr`, `mvwins_wchstr`, `mvwget_wch`, …).
`setcchar CCHAR WCH ATTRS PAIR EXT` → `bc_cchar bc_cchar_a bc_cchar_p`;
`getcchar CCHAR` → `wch wcha wchp`.
`wcwidth WCH` returns *status* 0 for zero-width/control characters and 1 for
printable ones (deviation: ncurses returns the width as a value). The
`*_set` line/border variants (`whline_set`, `wborder_set`, `box_set`, …) use
the first character of the cchar.

---

## Constants

- Attributes: `A_*` above.
- ACS box characters: `ACS_UL UR LL LR HLINE VLINE TTEE BTEE LTEE RTEE PLUS`,
  `ACS_S1 S9 DIAMOND CHECK STARS ATEER`, plus the ncurses long names
  (`ACS_ULCORNER`, `ACS_LLCORNER`, `ACS_URCORNER`, `ACS_LRCORNER`, `ACS_S3`,
  `ACS_S7`, `ACS_CKBOARD`, `ACS_DEGREE`, `ACS_PLMINUS`, `ACS_BULLET`,
  `ACS_LARROW RARROW DARROW UARROW`, `ACS_BOARD`, `ACS_LANTERN`, `ACS_BLOCK`,
  `ACS_LEQUAL GEQUAL PI NEQUAL STERLING`). Glyphs are Unicode, not the
  terminal's ACS charset.
- Keys: the `KEY_*` table; `KEY_BEGIN=354`, `KEY_DELETE=330` aliases.
- Mouse: the `BUTTON*_*` bits above.
- Colours: `COLOR_BLACK`…`COLOR_WHITE`; `SP=32`.

---

## Globals you may read

| Global | Meaning |
|---|---|
| `BC_STDSCR` | stdscr's id (0) |
| `BC_CURR` | current window for the plain forms |
| `bc_win` | last window created / previous window from `use_window` |
| `bc_panel` | last panel created |
| `LINES COLS COLORS COLOR_PAIRS` | terminal geometry and capabilities |
| `BC_LINES BC_COLS BC_COLORS BC_PAIRS` | same, library-prefixed |
| `ESCDELAY` | ESC/sequence disambiguation timeout (ms) |
| `key` | last key read by `wgetch` |
| `wch wcha wchp` | last cchar read (`winch`, `wget_wch`, …) |
| `bc_str` | last string read (`getstr`, `instr`, …) |
| `bc_chstr bc_chattr bc_chpair` | last cell run (`inchnstr`, …) |
| `bc_pair` | result of `find_pair`/`alloc_pair` |
| `bc_key` | result of `key_defined`/`keybound`/`keyok` |
| `BC_ME_ID BC_ME_X BC_ME_Y BC_ME_BSTATE` | last mouse event |
| `BC_MEVENTS` | pending mouse events (`"id x y bstate"`) |
| `BC_MOUSE_MASK` | current mousemask (0 = off) |
| `BC_MAXCLICK` | click-composition interval (ms) |
| `BC_MOUSE_TYPE` | 1 when a mouse is known to be available |
| `BC_DEFAULT_COLORS BC_DEFAULT_FG BC_DEFAULT_BG` | default-colour state |
| `BC_DEFAULT_FG/BG` | `-1` when the terminal default is used |
| `bc_top bc_bottom` | result of `wgetscrreg` |
| `bc_delay bc_parent` | results of `wgetdelay`/`wgetparent` |
| `bc_scanw_count` | fields matched by `wscanw` |
| `BC_GMY BC_GMX BC_GBY BC_GBX BC_GPY BC_GPX BC_GCY BC_GCX BC_GA` | geometry/attr results |
| `BC_AG BC_AP` | result of `wattr_get` |
| `BC_MT_Y BC_MT_X` | result of `wmouse_trafo` |
| `BC_CR BC_CG BC_CB BC_CPF BC_CPB` | colour/pair contents |
| `BC_PROG_STTY` | saved `stty` settings |
| `SCR_FILE` | screen-save file name |
| `TABSIZE PC BC UP` | termcap-flavoured values |

---

## Aliases

The ncurses alias families all exist and behave like their base form:

- `addch`/`addstr`/`printw`/`inch`/`instr`/… act on stdscr; `addnstr`,
  `addchstr`, `addchnstr`, `insch`, `insnstr`, `delch`, `deleteln`,
  `insertln`, `insdelln`, `insstr`, `scrl`, `hline`, `vline`, `chgat`,
  `attron`/`attroff`/`attr_set`/… on `BC_CURR` (matching ncurses).
- **`mv*`/`mvw*` forms** exist for every output/input routine:
  `mvaddch`/`mvwaddch`, `mvaddstr`/`mvwaddstr`, `mvaddnstr`/`mvwaddnstr`,
  `mvaddchstr`/`mvwaddchstr`, `mvaddchnstr`/`mvwaddchnstr`,
  `mvprintw`/`mvwprintw`, `mvinsch`/`mvwinsch`, `mvinsnstr`/`mvwinsnstr`,
  `mvinsstr`/`mvwinsstr`, `mvdelch`/`mvwdelch`, `mvhline`/`mvwhline`,
  `mvvline`/`mvwvline`, `mvborder`/`mvwborder`, `mvgetch`/`mvwgetch`,
  `mvgetstr`/`mvwgetstr`, `mvgetnstr`/`mvwgetnstr`, `mvscanw`/`mvwscanw`,
  and the cchar equivalents (`mvadd_wch`/`mvwadd_wch`,
  `mvadd_wchstr`/`mvwadd_wchstr`, `mvadd_wchnstr`/`mvwadd_wchnstr`,
  `mvins_wch`/`mvwins_wch`, `mvinsn_wch`/`mvwinsn_wch`,
  `mvget_wch`/`mvwget_wch`).
- **`*_set` cchar variants**: `hline_set`, `vline_set`, `whline_set`,
  `wvline_set`, `mvhline_set`, `mvvline_set`, `mvwhline_set`, `mvwvline_set`,
  `wborder_set`, `box_set`.
- `vwprintw`/`vw_printw`, `vwscanw`/`vw_scanw` → the `wprintw`/`wscanw` forms.
- `scr_init_sp`, `scr_restore_sp`, `scr_set_sp` → the plain `scr_*`.
- `slk_attron`/`slk_attr_on`, `slk_attroff`/`slk_attr_off`,
  `slk_attrset`/`slk_attr_set`.
- `wbkgset` → `wbkgdset`; `init_extended_color`/`init_extended_pair` →
  `init_color`/`init_pair`; `extended_color_content` → `color_content`;
  `extended_pair_content` → `pair_content`; `has_named_color` → `has_colors`;
  `resizestdscr` → `resizeterm`; `keybound` → `key_defined`;
  `vid_attr`/`vid_puts` → `vidattr`/`vidputs`; `getkey` → `getch`.

---

## Deviations and gaps

- **`mousemask`'s old mask** goes into the variable named by the second
  argument, not into the return value.
- **Pair 0 is a real pair**: after `start_color` it is `(7,0)`;
  `use_default_colors`/`assume_default_colors` turn it into the terminal
  default. It is not “unset”.
- **`curs_set` does not return the previous visibility** (ncurses does).
- **`erasechar`/`killchar` print numeric codes**, not characters.
- **`wcwidth` returns a status** (0 = zero width, 1 = width 1), not a width.
- **`standout` maps to italic** (`A_ITALIC`), because this library renders
  `smso` as italics.
- **Single-width model.** Wide CJK characters occupy one cell; `wch` is the
  first character of a cchar.
- **Not implemented:** `mcprint` (returns 1), `use_screen` (returns 1),
  `flash` (no-op), `intrflush`/`qiflush`/`noqiflush` (no-ops),
  `wsyncup`/`wsyncdown`/`syncup`/`syncdown`/`syncok` (accepted, no effect),
  `update_panels` (no-op — compositing happens at refresh).
- **`putwin`/`getwin` use the library's own format**, not ncurses'.
- **ACS glyphs are Unicode**, so `A_ALTCHARSET` does not switch character
  sets.

---

## See also

- `MOUSE.md` — mouse semantics and the bstate table.
- `DESIGN.md` — internals of all three layers.
- `references/API-MATRIX.md` — ncurses coverage.
- `examples/newdemo.sh` — this layer, frame-diffed against the C reference.
