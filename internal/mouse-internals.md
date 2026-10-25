# Mouse internals and testing

User-facing mouse API documentation lives in [`../docs/mouse.md`](../docs/mouse.md).

## Current status

- Implemented in `lib/bc.sh`: SGR 1006 and X10 decoding, event queue,
  `wgetch`/`getmouse`, `mousemask`/`mouseinterval`, click/double/triple merge,
  and wheel handling.
- Current coverage:
  - `tests/unit.sh`: constants, SGR/X10 decode, click/double/triple merge,
    wheel decode, and mask expansion.
  - `tests/integration.sh`: live tmux battery for key and mouse event streams.
  - `tests/mouse_click.sh` and `tests/mc_mouse.sh`: app-level click, drag,
    wheel, menu, dialog, viewer, and command-line behavior.
- Known open mouse issues: none.

## Wire formats

- **SGR 1006**: `\E[<b;x;yM` for press/drag and `\E[<b;x;ym` for release.
  `x` and `y` are 1-based on the wire and decoded to 0-based.
  Button field `b`:
  - `0`, `1`, `2`: buttons 1, 2, 3
  - `3`: release
  - `64`, `65`: wheel up/down
  - `64-131`: button 4 press range
  - `132-195`: button 5 press range
  - modifier bits in `b`: `4` shift, `8` alt, `16` ctrl
- **X10 fallback**: `\EM Cb Cx Cy`.
  `x = Cx - 32`, `y = Cy - 32`.
  Button is derived from `Cb`; `Cb` may be NUL for button 0, so the reader uses
  `read -d ''` because bash `read` silently drops NUL bytes.

Decoding entry points:

- `_bc_mouse_read_sgr` / `_bc_mouse_read_x10`: payload readers.
- `_bc_mouse_decode_sgr` / `_bc_mouse_decode_x10`: fill
  `_BC_EVT_BSTATE`, `_BC_EVT_X`, and `_BC_EVT_Y`.
- `_bc_mouse_handle_wheel`: ncurses `handle_wheel` port; tracks
  `BC_MOUSE_PRESSED`.

## Decode and merge internals

`wgetch` intercepts mouse reports before the key table and requires a non-zero
`mousemask`. On a report it calls `_bc_mouse_run`, which:

1. Queues the first event with `_bc_mouse_push_event`.
2. Keeps reading stdin until a quiet period of `BC_MAXCLICK` ms, default 166,
   or a non-mouse byte. Non-mouse bytes are pushed back through
   `BC_PENDING_IN`.
3. Merges the run using ncurses `_nc_mouse_parse` semantics:
   - pass 1: a same-position press+release pair becomes a CLICK when the mask
     requests CLICK;
   - pass 2: a CLICK run becomes DOUBLE, then TRIPLE, per button, with no x/y
     comparison.
4. Filters the queue: an event survives iff `bstate & BC_MOUSE_MASK2` is
   non-zero. `BC_MOUSE_MASK2` expands the mask so CLICK implies
   PRESSED|RELEASED, DOUBLE implies CLICK, and TRIPLE implies DOUBLE.

After the run, if the queue is non-empty, `wgetch` returns `KEY_MOUSE` and
peeks the head event into `BC_ME_ID`, `BC_ME_X`, `BC_ME_Y`, and
`BC_ME_BSTATE`. The queue is consumed only by `getmouse()`. If the run was
entirely filtered out, `wgetch` loops and reads the next key.

Aggregate masks are defined programmatically as ORs of the per-button constants
in `lib/bc.sh`, not hard-coded numbers. These match the installed ncurses 6.6
`NCURSES_MOUSE_MASK` values checked by the unit tests.

## Testing notes

- tmux panes inherit the host default `TERM=screen-256color`. Its keycaps
  differ from `xterm-256color`, so tests that inject xterm key sequences should
  export `TERM=xterm-256color` in the app.
- Mouse click runs should be injected with reports 50 ms apart, below the
  166 ms click window; separate runs should be at least 0.6 s apart.
- A lone ESC makes a blocking reader wait `ESCDELAY` (1000 ms); sleep at least
  1.5 s after injecting one.
