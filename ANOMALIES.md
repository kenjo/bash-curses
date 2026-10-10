# ANOMALIES

Divergences between real `mc` (4.8.33) and the bash clone (`examples/mc.sh`),
found by `tests/visual_diff.sh`: both apps are driven in tmux with an identical
key sequence over a controlled tree (`tmp/vd/tree`), and each step is compared
per-cell (character + fg + bg + attributes) via `tests/lib/screen.sh`.

Capture artefacts: `tmp/vd/{mc,clone}/NN_<label>.{plain,sgr}`; full report
`tmp/vd/REPORT.txt`. Steps: initial, F9 menu bar (menu_f9*), F2 (menu_f2*),
panel_tab, nav_down2, open_alpha, viewer_txt, f1_help.

> **Reading caveat — 16-colour SGR.** Both `mc` and the clone now emit 16-colour
> ANSI codes (`\e[30m`, `\e[9x`, `\e[46m`, …) for palette colours 0-15, so the
> per-cell diff no longer inflates on encoding differences. (This was the old
> "256-colour" gap, now resolved — see R6.)

---

## Resolved

Items closed since the original discovery pass. Each was verified per-cell
(`tests/lib/screen.sh`) against a real-`mc` capture to **0 differing cells**, or
by direct text inspection.

### R1. F2 (User menu) — was H1
F2 now opens the centred **"User menu"** dialog (`examples/mc.sh` `user_menu`),
geometry x=18 y=4 w=64 h=18, items and title matching `mc`. Cursor-item
highlighting matches: leading margin space (window-col 1) stays pair 16, the
mnemonic + description padded to `w-4` (window-cols 2..79) is pair 19, and the
trailing margin cell (window-col 62) stays pair 16. The **dialog body** matches
`mc` (span y4-21 x17-65). (The surrounding `..`-row/empty-row rendering is a
separate, `mc`-side quirk — see open item O1.)

### R2. F1 (Help) — was H2
F1 now opens the large centred **"Help"** main screen (`examples/mc.sh`
`fkey_help`): ASCII MC logo, "Commander 4.8.33", help text, keybar `2Index`.
Geometry x=9 y=3 w=82 h=22. Emphasised words match `mc`'s colours: the "Enter"
key is bright-cyan/blue (pair 21); "contents", "authors", "WARRANTY",
"GNU General " (incl. its trailing end-of-line space), and "Public License" are
black-on-cyan (pair 6); the logo "Commander" and first "GNU Midnight Commander"
are blue (pair 20). The **dialog body** matches `mc` (span y3-24 x9-90).

### R3. `[^]` command-line cursor marker — was M4
The subshell/command-line row now renders `[^]` at the far right, matching `mc`.

### R4. Context-sensitive hint line — was L3
The bottom hint line now rotates context-sensitive hints (`redraw_hint`),
e.g. "Hint: Tab changes your current panel.", matching `mc`'s *style* instead of
one static line. (The *exact* hint at a given step is redraw-count dependent —
see open item O2.)

### R5. Exact mnemonic letters in menu dropdowns
Dropdown hot-key letters now match `mc`'s choices (commit `77f13bb`).

### R6. 16-colour SGR encoding — was L1
`lib/bc.sh` `_bc_sgr` emits 16-colour codes for palette 0-15 (`30+fg` /
`90+(fg-8)` / `40+bg` / `100+(bg-8)`), matching `mc`. The clone no longer emits
`\e[38;5;N` for in-range colours. Verified: `initial` is a **per-cell exact
match** (`tests/visual_diff.sh`, 0 differing cells).

### R7. Panel status line names the entry — was H3
Both redraw paths now show the selected entry's listing name (with its type
prefix: `/beta`, ` a.txt`, `*c.sh`) or `UP--DIR` for the parent:
`draw_panel` (full redraw) **and** `update_selection` (incremental selection
move). Previously the incremental path hardcoded `dir` / `file N bytes`.
Verified: `nav_down2` is a **plain-text exact match**.

### R8. Menu-bar colour — was M1
The **closed** menu bar is now uniform **black-on-cyan** (pair 22), matching
`mc` (`\e[30m` on `\e[46m`); the old bright-white base + bright-yellow mnemonics
is only used when a menu is **open** (where `mc` shows bright-white text,
yellow mnemonics, and the selected item on a black background — pairs
16/17/18/19, which already matched). Verified: `initial` row 0 is a
per-cell exact match.

### R9. File-entry colours — was M2 + M3
Listing entries are coloured by **type**, not extension, matching `mc`:
directory → bright white (pair 2); regular file → **yellow** (pair 11);
executable → **bright green** (pair 3, fg 10); symlinks/specials → bright white.
The whole row (name + size + time) takes the type colour; dividers stay white.
Verified: `initial` listing rows are per-cell exact matches (`a.txt` yellow,
`c.sh` bright green, dirs bright white).

### R10. Dropdown keyboard shortcuts
`menu_dd_row` was dropping each item's shortcut (`C-x q`, `C-x i`, `M-e`,
`C-r`, …) because `local sc=${e#*|} sc=${sc%|*}` read the *previous* (empty)
`sc` in a single `local` statement. Split into two statements; shortcuts now
render. Verified: `menu_f9_down`/`_down2`/`_right_down` are **plain-text exact
matches**.

### R11. F9 → Down → Right corrupted the screen (arithmetic errors)
Closing and reopening the menu dropdown (the `delwin` on a menu transition)
corrupted the **IFS** that the composite `doupdate` uses to split its changed-
cell keys: `saved_ifs=$IFS` captured `""` when IFS was *unset*, and
`IFS=$saved_ifs` then set IFS to an *explicitly empty* string (not unset). An
empty-IFS `read -r ay ax` does not split `"25 33"`, so the coordinate pair was
fed whole into arithmetic → `((: 25 33: arithmetic syntax error)` and a garbled
screen. Fixed in `lib/bc.sh` by replacing the persistent-IFS save/restore with a
scoped split — `IFS='|' read -r -a delrects <<< "$BC_DELRECTS"` (and the same
`old=$IFS; IFS=…; IFS=$old` pattern in `scr_set`/`scr_restore` → scoped
`read -r -a`) — so the persistent IFS is never clobbered. Verified: F9→Down→
Right now renders **identically to `mc`** with 0 arithmetic errors.

### R12. Copy/Move dialog focus navigation
The Copy/Move dialog now matches `mc`'s focus model: Up/Down/Tab move focus
among the source field, "Using shell patterns", destination field, the five
checkboxes, and the buttons. The initial focus is the destination field, and
the checkbox order is column-major (Follow, Preserve, Dive, Stable). The
focused checkbox/button is drawn black-on-cyan (pairs 29/30); Left/Right toggle
the focused checkbox, and Space activates a focused button. Verified by
`tests/mc_dialog.sh` using the per-cell SGR grid.

### R13. Terminal resize (SIGWINCH) is now handled
The clone previously ignored SIGWINCH, so the terminal just clipped the old
render. Now: `main` traps `WINCH` (sets `BC_WINCH`); `wgetch` reads the first
char with a 0.05 s timeout (bash defers a trapped WINCH until a `read` builtin
completes, so a blocking read could never see it) and reports `KEY_RESIZE` when
the flag is set; `resizeterm` re-reads the size and resizes the standard window;
`do_resize` rebuilds both panels at the new geometry and forces a full repaint
(`BC_FORCEFULL`). Resizing in the main loop, the menu, the viewer, and the help
dialog all reflow (the modals close and the main UI is redrawn at the new size).
Verified: `tests/mc_resize.sh` (shrink 100x30→80x24, grow →120x40; button bar
stays on the last row, hint line reflows).

### R14. Modal close key no longer leaks into the command line (was O3)
The old note said pressing `q` to close the F3 viewer left a `q` in the
command line. The normal F3→`q` and F3→Esc flows no longer reproduce this.
`tests/mc_view.sh` now asserts that the command line remains clean after the
viewer closes.

---

## Open

Remaining differences found by the full `visual_diff` pass. Neither affects the
core listing/navigation/menu behaviour; both are subtle `mc`-side rendering
behaviours that the clone intentionally renders *consistently* instead.

### O1. F1/F2 dialog: surrounding `..`-row and empty rows render differently
With the F1 (Help) or F2 (User menu) dialog open, `mc` renders the panel rows
that are *not* covered by the dialog — the `..` row and the empty rows below
the listing — as a **single wide panel** (the right panel's name/size area is
left blank/stale; the `..` size shows `DIR` at the far-right size column). The
clone renders those same rows as **two consistent 50-col panels** (`UP--DIR` in
each), which matches the initial state, the top border, and the column header
row (all of which show two panels in `mc` too).

- `mc` is internally inconsistent here (top border + header = two panels, but
  `..`-row + empty rows = one wide panel). This looks like a `mc` redraw/clear
  quirk around centred dialogs, not a layout the clone should imitate.
- This also explains the old "L2" note (`..` size `DIR` vs `UP--DIR`): it is the
  same `..`-row rendering, not a separate size-column difference.
- Evidence: `tmp/vd/{mc,clone}/07.menu_f2.plain` (rows 4, 23) and
  `tmp/vd/{mc,clone}/13.f1_help.plain` (rows 3, 25-26).

### O2. Hint line: exact text at a step differs
The hint line rotates in both, but the *specific* hint shown at a given step
differs because it depends on how many times the hint has been redrawn (which
depends on redraw timing). E.g. after `open_alpha` / `viewer_txt`:
`mc` shows "Want to do complex searches?…" / "M-t changes quickly the listing
mode.", the clone shows "Tab changes your current panel." The rotation *style*
matches `mc` (R4); the exact per-step text does not.

---

## No divergence (verified matching, full screen)

- **initial**: full per-cell exact match (listing, columns, `..` status row,
  `[^]`, hint, menu bar, colours).
- **F9 menu-bar navigation** (menu_f9, _down, _down2, _right, _right_down):
  plain-text exact match, including dropdown items **and their keyboard
  shortcuts** (R10).
- **nav_down2** (Down Down): status line names the entry (`/beta`) — exact
  match (R7).
- **panel_tab** (Tab): plain-text exact match.
