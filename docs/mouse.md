# Mouse support

Mouse support is implemented in `lib/bc.sh`. Apps enable it with
`mousemask`, read `KEY_MOUSE` from `wgetch`, then call `getmouse` to get the
event fields.

## API

- `mousemask(newmask [, oldvar])`
  - Sets the active mouse mask.
  - The old mask is written to the variable named by `oldvar`, or to
    `BC_MOUSE_MASK` if `oldvar` is omitted.
  - Returns `0`; ncurses returns the previous mask, so do not use the return
    value.
  - Enables or disables terminal mouse reporting only after `initscr`.
- `mouseinterval(ms)`
  - Sets the click-composition window.
  - The old value is written to `BC_OLD_MAXCLICK`.
  - Returns `0`.
- `getmouse()`
  - Returns `0` when an event was available, `1` otherwise.
  - Fills `BC_ME_ID`, `BC_ME_X`, `BC_ME_Y`, and `BC_ME_BSTATE`.
  - `BC_ME_ID` is always `"0"` in this library.
- `ungetmouse()`
  - Pushes the current `BC_ME_*` event back so the next `wgetch` can return
    it again.
- `has_mouse()`
  - True when mouse mode is available or `TERM` contains `xterm`.

Coordinates in `BC_ME_X` and `BC_ME_Y` are 0-based.

## Event behavior

- `wgetch` returns `KEY_MOUSE` (`409`) when a mouse event matching the active
  mask is available.
- A press followed by a release at the same position becomes `BUTTON_CLICKED`.
- Repeated clicks become `BUTTON_DOUBLE_CLICKED`, then `BUTTON_TRIPLE_CLICKED`.
- Wheel up and wheel down are buttons 4 and 5.
- Events are filtered by the active mask. Requesting `BUTTON_CLICKED` also
  allows the underlying press/release events; requesting double-click also
  allows clicks; requesting triple-click also allows double-clicks.

## bstate encoding

This library uses ncurses `NCURSES_MOUSE_VERSION 2` encoding: a 5-bit slot per
button, with `MASK(button, m) = m << ((button-1)*5)`.

`m` values:

| event | value |
|---|---:|
| RELEASED | 1 |
| PRESSED | 2 |
| CLICKED | 4 |
| DOUBLE | 8 |
| TRIPLE | 16 |

Button slots:

| button | RELEASED | PRESSED | CLICKED | DOUBLE | TRIPLE |
|---|---:|---:|---:|---:|---:|
| 1 | 1 | 2 | 4 | 8 | 16 |
| 2 | 32 | 64 | 128 | 256 | 512 |
| 3 | 1024 | 2048 | 4096 | 8192 | 16384 |
| 4 | 32768 | 65536 | 131072 | 262144 | 524288 |
| 5 | 1048576 | 2097152 | 4194304 | 8388608 | 16777216 |

Modifier bits:

| modifier | value |
|---|---:|
| `BUTTON_CTRL` | 33554432 |
| `BUTTON_SHIFT` | 67108864 |
| `BUTTON_ALT` | 134217728 |
| `REPORT_MOUSE_POSITION` | 268435456 |

Aggregate masks:

| macro | value |
|---|---:|
| `BUTTON_PRESSED` | 2164802 |
| `BUTTON_RELEASED` | 1082401 |
| `BUTTON_CLICKED` | 4329604 |
| `BUTTON_DOUBLE_CLICKED` | 8659208 |
| `BUTTON_TRIPLE_CLICKED` | 17318416 |
| `ALL_MOUSE_EVENTS` | 268435455 |

## Accepted deviations

- `mousemask` and `mouseinterval` return `0`; previous values are exposed
  through out-variables/globals.
- `getmouse` returns a status and stores the event in globals.
- `BC_ME_ID` is always `"0"`.
- A failed partial mouse-report read loses the bytes consumed so far.
- The mouse enable sequence is written to stdout.
