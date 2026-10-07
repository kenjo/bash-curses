# ANOMALIES — Midnight Commander (reference) vs. this bash clone

This is the persistent log of visual/behavioural differences between the
reference `mc` and `examples/mc.sh`, discovered by the discovery harness
(`tests/visual_diff.sh`, run manually — it is slow and not part of
`tests/run.sh`). Each entry: what MC does, what the clone does, and status.

Reproduce:
    bash tests/visual_diff.sh                 # full run -> tmp/vd/REPORT.txt
    bash tests/visual_diff.sh menu_f9 menu_f9_down   # a subset

## Fixed

### F9/F2 auto-opened the wrong dropdown
- **MC:** F9 highlights the first menu-bar item ("Left") and opens no
  dropdown; Down (or Enter) opens the dropdown for the highlighted item.
- **Clone (was):** F9 and F2 both immediately opened the *File* dropdown.
- **Status:** FIXED — F9/F2 now highlight "Left" with no dropdown; Down/Enter
  opens the dropdown for the highlighted item.

### Menu dropdown position, transparency and colors
- **MC:** dropdown is drawn directly under its menu-bar item (Left at col 0,
  File at col 11, ...), fully opaque, bright-white-on-cyan (SGR 97/46) border
  and text, with the mnemonic letter in bright yellow (SGR 93).
- **Clone (was):** dropdown always at col 11, overlapping the panel,
  semi-transparent (panel text showed through), wrong colors.
- **Status:** FIXED — positioned under the bar item, opaque, cyan/white/yellow.

### Menu groups, separators, shortcuts, mnemonics
- **MC:** each dropdown groups related items with `├────┤` separators,
  right-aligns the keyboard shortcut, and colors the mnemonic letter yellow.
  All five menus (Left, File, Command, Options, Right) are present.
- **Clone (was):** no separators, shortcuts glued to the label, no mnemonic
  coloring, and only 3 of the 5 bar items were functional.
- **Status:** FIXED — separators, right-aligned shortcuts, yellow mnemonics,
  all five menus present and navigable.

### Menu bar not always shown; Esc did not close the dropdown
- **MC:** the menu bar (Left File Command Options Right) is always visible
  on row 0; the highlight only appears once the menu is active (F9). Esc
  closes the active dropdown.
- **Clone (was):** `draw_menu` returned early unless the menu was open, so
  the bar was invisible until F9; and a lone Esc sometimes failed to close
  the dropdown because the test sent the literal string "Esc" (three chars)
  instead of the 0x1b byte.
- **Status:** FIXED — bar is always drawn (all cyan), highlight only when
  active, and Esc (0x1b) closes the dropdown. Regressed by `tests/mc_menu.sh`.

### Modify-time column format
- **MC:** `MON  DD  YYYY` for files older than ~6 months, `MON  DD HH:MM`
  for recent files (e.g. `jan  2  2020` vs `okt  7 20:31`).
- **Clone (was):** always `MON  DD HH:MM` (showed the time, never the year).
- **Status:** FIXED — age-based, matches MC (year for old, time for recent).

### Executable name marker
- **MC:** executable regular files are prefixed `*` in the Name column
  (e.g. `*c.sh`); plain files have a leading space.
- **Clone (was):** always a leading space (no `*` for executables).
- **Status:** FIXED — executables now show `*name`.

## Open (known differences, not yet matched)

### F2 = User menu
- **MC:** F2 opens a separate "User menu" dialog (a configurable custom
  menu), distinct from the F9 menu bar.
- **Clone:** F2 opens the menu bar (same as F9).
- **Status:** OPEN — user-menu dialog not implemented.

### Context-dependent hint line
- **MC:** the bottom hint line changes with context (e.g. "Tab changes your
  current panel", "To change directory halfway through typing a command,
  use M-c", "Are some of your keys not working? Look at Options/Learn
  keys?").
- **Clone:** a single static hint ("Tab switch panel, Enter open, F2 menu,
  F10 quit, or type 'quit'+Enter (no F-key).").
- **Status:** OPEN — hint is static.

### Command-line cursor indicator
- **MC:** the focused command line shows a `[^]` cursor marker at its end.
- **Clone:** no cursor marker on the command line.
- **Status:** OPEN — minor cosmetic difference.

### F1 help dialog
- **MC:** F1 shows a large "Help" dialog containing the MC logo and version
  ("4.8.33").
- **Clone:** F1 shows a small "F-keys" reference dialog.
- **Status:** OPEN — different help content.

### Exact mnemonic letter choice
- **MC:** mnemonic letters are the per-item hotkeys and are not always the
  first letter (e.g. "FTP link" highlights the P).
- **Clone:** mnemonics are the first letter of each item.
- **Status:** OPEN — structurally present, exact letters may differ.
