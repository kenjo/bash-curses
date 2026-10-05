# Mouse support in bc — semantics, evidence, debugging record

## Status

- **Implemented** in `lib/bc.sh` (SGR 1006 + X10 decode, event queue,
  `wgetch`/`getmouse`, `mousemask`/`mouseinterval`, click/double/triple
  merge, wheel handling).
- **Verified headless** (piped input, no tty): SGR battery 10/10, edge
  battery 6/6, click-merge sequences, wheel decode.
- **Verified against C ncurses ground truth** (cmouse under `strace`, see
  "Ground-truth methodology"): click-merge semantics, including the no
  x/y comparison in the double/triple pass, and the ~166 ms click window.
- **Live tmux verification: pending** — the first live battery runs were
  corrupted by bugs in the *battery script* (see "Debugging record"); the
  battery is now fixed and the live re-run is the remaining step.

## bstate encoding

ncurses `NCURSES_MOUSE_VERSION 2` encoding: a 5-bit slot per button,
`MASK(button, m) = m << ((button-1)*5)`, with `m` in
{RELEASED=1, PRESSED=2, CLICKED=4, DOUBLE=8, TRIPLE=16}. Button 4 is wheel
up, button 5 is wheel down.

| button | RELEASED | PRESSED | CLICKED | DOUBLE | TRIPLE |
|---|---|---|---|---|---|
| 1 | 1 | 2 | 4 | 8 | 16 |
| 2 | 32 | 64 | 128 | 256 | 512 |
| 3 | 1024 | 2048 | 4096 | 8192 | 16384 |
| 4 | 32768 | 65536 | 131072 | 262144 | 524288 |
| 5 | 1048576 | 2097152 | 4194304 | 8388608 | 16777216 |

Modifier bits (from bit 25): `BUTTON_CTRL=1<<25=33554432`,
`BUTTON_SHIFT=2<<25=67108864`, `BUTTON_ALT=4<<25=134217728`,
`REPORT_MOUSE_POSITION=8<<25=268435456`.

Aggregate masks are defined **programmatically** as ORs of the per-button
constants (`lib/bc.sh:184-188`), not hard-coded numbers:

| macro | value |
|---|---|
| BUTTON_PRESSED | 2164802 |
| BUTTON_RELEASED | 1082401 |
| BUTTON_CLICKED | 4329604 |
| BUTTON_DOUBLE_CLICKED | 8659208 |
| BUTTON_TRIPLE_CLICKED | 17318416 |
| ALL_MOUSE_EVENTS | 268435455 |

These match the installed ncurses 6.6 `NCURSES_MOUSE_MASK` values in
`/usr/include/ncurses.h` (checked by the unit tests).

## Wire formats

- **SGR 1006**: `\E[<b;x;yM` (press / drag) and `\E[<b;x;ym` (release);
  `x`,`y` are 1-based (decoded 0-based). Button field `b`: 0/1/2 = buttons
  1/2/3, 3 = release, 64/65 = wheel up/down, 64-131 = button 4 press,
  132-195 = button 5 press, plus modifier bits in `b`: `4`=shift,
  `8`=alt, `16`=ctrl (the wheel bits 64/65 are separate).
- **X10** (fallback): `\EM Cb Cx Cy`; `x=Cx-32`, `y=Cy-32`, button from
  `Cb` (`Cb&3` for 0-3, `-32` for the press range, wheel when `Cb>=96`
  style per ncurses `handle_wheel`); `Cb` may be NUL (button 0) — read via
  `read -d ''` because bash `read` silently drops NUL bytes.

Decoding entry points: `_bc_mouse_read_sgr` / `_bc_mouse_read_x10`
(payload readers), `_bc_mouse_decode_sgr` / `_bc_mouse_decode_x10`
(-> `_BC_EVT_BSTATE/_BC_EVT_X/_BC_EVT_Y`), `_bc_mouse_handle_wheel`
(ncurses `handle_wheel` port, tracks `BC_MOUSE_PRESSED`).

## Decode + merge semantics

`wgetch` intercepts mouse reports **before** the key table
(`lib/bc.sh:1681-1706`), requires `mousemask()` to be non-zero. On a
report it calls `_bc_mouse_run`, which:

1. Queues the first event (`_bc_mouse_push_event`).
2. Keeps reading stdin until a quiet period of `BC_MAXCLICK` ms (166, the
   ncurses `DEFAULT_MAXCLICK`) or a non-mouse byte (pushed back via
   `BC_PENDING_IN`) — i.e. it consumes a whole *run* of consecutive
   reports, like ncurses.
3. Merges the run (ncurses `_nc_mouse_parse` semantics):
   - **pass 1**: a same-(x,y) press+release pair becomes a CLICK (when the
     mask requests CLICK);
   - **pass 2**: a CLICK run becomes DOUBLE, then TRIPLE, per button —
     **with no x/y comparison** (verified against C ground truth: a
     double click at two different positions yields one DOUBLE at the
     second position).
4. Filters the queue: an event survives iff `bstate & BC_MOUSE_MASK2` is
   non-zero. `BC_MOUSE_MASK2` expands the mask: CLICK implies
   PRESSED|RELEASED, DOUBLE implies CLICK, TRIPLE implies DOUBLE
   (`_bc_mouse_mask2`).

After the run, if the queue is non-empty `wgetch` returns `KEY_MOUSE`
(409) and peeks the head event into `BC_ME_ID/_BC_ME_X/_BC_ME_Y/
_BC_ME_BSTATE`; the queue is consumed only by `getmouse()`. If the run was
entirely filtered out, `wgetch` loops and reads the next key.

## API and accepted deviations

- `mousemask(newmask [, oldvar])` — returns 0 (always); old mask in
  `oldvar`/`BC_MOUSE_MASK`; enables/disables the terminal's SGR mouse
  mode (`\e[?1006;1000h`/`l`) only after `initscr`.
- `mouseinterval(ms)` — returns 0; old value in `BC_OLD_MAXCLICK`.
- `getmouse()` — 0/1; event in `BC_ME_ID` (always "0"), `BC_ME_X`,
  `BC_ME_Y`, `BC_ME_BSTATE`.
- `ungetmouse()` — pushes the current `BC_ME_*` event back and queues a
  `KEY_MOUSE` in `BC_PENDING_IN`.
- `has_mouse()` — true if mouse mode is on or `TERM` contains `xterm`.
- Deviations: a failed *partial* SGR read loses the bytes consumed so far
  (no push-back); the enable sequence goes to stdout (to the output file
  in tests).

## Ground-truth methodology

- C reference program `cmouse.c`: `wgetch`/`getmouse` loop printing
  `EV <EPOCHREALTIME> x=.. y=.. bstate=..`, run under `strace` in a tmux
  session; ground truth = the `write(1, ...)` records (e.g.
  `cm9_strace.txt`), not the rendered pane.
- Input injected with `tmux send-keys -H -t <pane> <hex...>`:
  - within a click run: reports 50 ms apart (< 166 ms window);
  - between runs: >= 0.6 s;
  - a lone ESC makes the reader wait `ESCDELAY` (1000 ms) — sleep >= 1.5 s
    after injecting one.
- **TERM matters**: tmux panes inherit the host default
  `TERM=screen-256color`. Its keycaps differ from `xterm-256color`
  (Home/End are `\E[1~`/`\E[4~`, and it has no `kcub1`), so both the bash
  app and the C reference must run with `TERM=xterm-256color` for the
  key battery to be meaningful.

## Verified results

Headless (piped bytes, `lib/bc.sh` sourced, no tty):

- SGR battery 10/10, edge battery 6/6 (button 0-3, wheel 64/65, drag,
  modifiers, X10 forms).
- double click (2,1,2,1 same pos) -> single event `bstate=8` (DOUBLE).
- triple click (2,1,2,1,2,1) -> `bstate=16` (TRIPLE).
- double at different positions -> single DOUBLE at the second pos (the
  pending CLICK is replaced, never emitted; pass 2 has no x/y check).
- wheel up SGR `b=64` -> `bstate=65536` (BUTTON4_PRESSED).

C ground truth (cmouse under strace):

- fast press+release same position -> CLICK (bstate 4).
- double click, different positions -> one DOUBLE (8) at the **second**
  position (pass 2 ignores x/y) — `EV x=7 y=8 bstate=8`.
- click window: press/release < 166 ms apart merge to CLICK; > 166 ms do
  not (boundary measured ≈ 166 ms = `DEFAULT_MAXCLICK`).

## Debugging record — the three "live anomalies" (all battery-script bugs)

The first live tmux battery runs produced three apparent library bugs.
All three turned out to be bugs in the battery script
(`/tmp/opencode/battery.sh` + the app); the library decoded exactly what
ncurses would decode for the bytes actually received.

1. **"Wheel reported 134217730 instead of 65536".**
   The battery's wheel-up hex was not `\E[<64;5;6M` (36 34) but a typo:
   an early run sent button code `8` (`\E[<8;5;6M`), the current battery
   sends `40` (`\E[<40;5;6M`). `b=8` = button 1 + ALT modifier ->
   `BUTTON1_PRESSED|BUTTON_ALT = 2|134217728 = 134217730`, which is
   exactly what C ncurses reports for that input; `b=40` decodes as a
   plain left press (bstate 2). Headless, `b=64` decodes correctly to
   65536. Not a library bug.

2. **"Every mouse report delivered only a lone ESC (27) to the app."**
   The battery's send helper was `s(){ tmux send-keys -H -t $t $1; }`
   called as `s $Lp` where `Lp='1b 5b 3c 30 3b 35 3b 36 4d'`. The unquoted
   `$Lp` word-splits **at the call site** into 9 words, so only `$1`
   (`1b`, a single ESC byte) was ever sent — the other 8 bytes of every
   report never left the battery. Count check: 19 SGR reports -> 19 bare
   ESCs, +1 (the injected bare-ESC key) +1 (the ESC of the `\E[A` probe)
   = **21 lone 27s**, exactly what the app printed, with no EV lines and
   no leftover bytes. Fixed: `s(){ tmux send-keys -H -t $t "$@"; }`.
   (tmux/pty delivery itself was verified fine: a raw-mode reader app
   receives all 9 bytes of an SGR report; note canonical-mode ptys
   line-buffer input, so a newline-free hex sequence never reaches a
   reader — the app's `initscr` puts the tty in raw mode, which is why
   this only ever worked in the raw path.)

3. **"HOME/END/LEFT arrived raw (27,79,70 / 27,79,72 / 27,79,68)."**
   The battery injected the `xterm-256color` sequences
   (`\EOH`, `\EOF`, `\EOD`), but the tmux pane inherited
   `TERM=screen-256color`, whose key table has `khome=\E[1~`,
   `kend=\E[4~` and **no** `kcub1`. No match, no prefix -> `wgetch`
   returns ESC and pushes the rest to pending, i.e. three raw keys per
   sequence — exactly the observed `27,79,70` / `27,79,72` / `27,79,68`.
   C ncurses under the same TERM behaves identically (key decoding is
   terminfo-driven). Fixed: the battery app now exports
   `TERM=xterm-256color`. (UP/DOWN/RIGHT/F1/F10/F12 decoded correctly in
   those runs because `screen-256color` shares those exact sequences.)

## Real library bugs found (and fixed)

- **`BUTTON_CLICKED` aggregate was `4329608`** — the hand-computed OR
  missed bit 4 (button 1 CLICKED). The pass-2 gate
  `(( bstate & BUTTON_CLICKED ))` was therefore false for button-1
  clicks, so DOUBLE/TRIPLE never merged. Fixed to 4329604, and all five
  aggregates are now computed as `$(( BUTTON1_X | ... | BUTTON5_X ))`
  from the per-button constants (`lib/bc.sh:184-188`) so a typo cannot
  recur. Verified: double -> 8, triple -> 16 headless.
- **Key table mapped `kcul1` for the left arrow, but the terminfo
  capability is `kcub1`** (`xterm-256color`: `kcub1=\EOD`). LEFT never
  decoded under any terminfo. Fixed: `kcub1` added to the cap map
  (`lib/bc.sh`, `_bc_load_keytable`).
- `_bc_ti_prefix` had its operands reversed (fixed earlier): it must test
  that a *longer* table entry starts with the partial sequence.

## Open items

- ~~Live re-verification (the last step)~~ — **done**: the C reference
  (`cmouse` under strace) diff was recorded above ("C ground truth"), and
  the fixed battery now runs headlessly against the bash app in a tmux
  pane (`TERM=xterm-256color`) via `tests/integration.sh`, asserting the
  whole EV stream — click 4, slow press/release 2/1, double 8, triple 16,
  middle click 128, wheel up 65536, double-diff-pos 8 at the second
  position — plus the key battery (UP 259, DOWN 258, LEFT 260, RIGHT 261,
  HOME 262, END 360, F1 265, F10 274, F12 276, PPAGE/NPAGE raw, bare CSI
  `\E[A` raw). 24/24 green.
