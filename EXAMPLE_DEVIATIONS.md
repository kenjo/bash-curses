# Example parity deviations

This file records accepted differences between the bash examples/library and
the C `ncursesw` reference binaries. The automated comparison runner is
`tests/example_compare.sh`; it compares plain character captures by default and
SGR/color captures with `--strict`.

## Skipped examples

- `08-attributes-main`: requires a C source file argument.
- `12-mouse`: requires mouse click coordinates.
- `14-leave-ncurses`: spawns an interactive shell.

## Path normalization

`13-screen-dump` and `66-screen-dump-sp` display the screen dump path. The bash
example uses a path relative to the script directory, while the C reference uses
`tmp/...`. `tests/example_compare.sh` normalizes these paths in plain captures
instead of changing the examples.

## `21-color-content`

The C reference queries the terminal palette with `color_content()`. The bash
library does not have a reliable way to query the host terminal palette, so it
returns zeroed RGB values for default colors. Accepted deviation.

## `25-background`

The C reference renders the window background character in blank cells after
`wbkgdset()`. The bash library only renders background characters for cells that
are explicitly written or erased, so untouched blank screen cells remain blank.
Accepted deviation.

## `31-subwin`

The bash library models subwindows with shared parent buffers but does not fully
model ncurses `mvderwin()` shared-buffer movement semantics. The C reference and
bash agree on the parent and most of the child, but differ in how the moved
subwindow's borders are clipped. Accepted deviation.

## `71-stdscr-del-ins`

The bash `mvwinsnstr()` path intermittently omits the final inserted row in the
tmux comparison harness. The C reference renders it deterministically. Accepted
deviation until the dirty-cell race is isolated.

## `76-panel-bottom`

The bash panel stack does not fully match ncurses panel z-order and
`replace_panel()` cleanup. The C reference now matches the bash z-order used by
the example, but one residual vertical border from the replaced panel remains in
the bash capture. Accepted deviation.

## SGR-only differences

These examples match in plain character captures but differ in SGR/color or
attribute captures:

- `09-windows-border`
- `10-colors`
- `13-screen-dump`
- `15-window-dump`
- `16-panels-moving-resizing`
- `16-panels-window-browsing`
- `45-color-pair`
- `60-attr-get`
- `64-slk-extra`

The default parity gate treats plain captures as authoritative.
