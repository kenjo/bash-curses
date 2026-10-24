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

### R15. File selection group actions
The File menu's **Select group**, **Unselect group**, and **Invert selection**
items now operate on the active panel. Selected entries are drawn in bright
yellow on the panel background (pair 31), matching the real `mc` selection
colour observed with `Insert`. Verified by `tests/mc_actions.sh` using SGR
captures of the listing rows.

### R16. `pair=0` was indistinguishable from "no pair" — was O4
The pair fallback chain used arithmetic truthiness (`(( rp ))`), so pair 0
silently became the window background pair and `mc.sh`'s `wattrset 0 0 0`
full-row repaints could not be expressed through the layout layer. An unset
current pair is now the empty string in `bc.sh` (`wattrset`, `wattr_set`,
`wbkgdset`, `wbkgd`, `_bc_render`, the `mvwaddstr` fast path) and in
`layout.sh` (`_bcl_eff` leaves `BCL_EP` empty, `_bcl_put` falls back only for
an empty pen pair). A literal `0` passed as a *character* pair still means
"use the window pair", so existing callers are unaffected. `92`'s `draw_hint`
now paints its full row with pair 0 like `mc.sh`.

### R17. The 191x74 parity diffs were harness timing, not app behaviour — was O3
With a fixed 0.55s key spacing, `mc.sh` and `92` at 191x74 had not finished
processing a key before the next capture, so steps 5/7/9/10 showed phantom
menu-bar and active-panel divergences. `tmp/lat/parity191.sh` now waits for
quiescence (1.2s, then two consecutive equal `capture-pane -e` md5s). All 22
steps then match except the hint/keys trailing-padding cells, which are a
`tmux capture-pane -e` artifact: the raw PTY streams are byte-identical in
shape (full-width `(37,40)` padding + `39;49m`), but tmux strips the clone's
trailing run and keeps `mc.sh`'s. Behavioural parity at 191x74 is clean.

### R18. The F1/F2 dialog rows already match `mc` — was O1
Re-checked with fresh per-cell SGR diffs of `mc.sh` vs real `mc` (100x30, F1
Help and F2 User menu open). The single-wide `UP--DIR` row, the merged
`├──…└──┘──┤` border, and the `DIR` size column are all identical; the only
differing cells are the wall-clock minute in the timestamp and the `[^]` prompt
marker. The original note (clone rendering "two consistent 50-col panels") was
stale — `mc.sh` already imitates `mc`'s single-wide rendering. No code change.

### R19. `mc`'s hint rotation is non-deterministic; per-step text is not matchable — was O2
Real `mc`'s initial hint is always "Tab changes your current panel.", but after
a full-screen redraw (e.g. F3 viewer open/close) it advances **exactly once** to
a tip that varies between sessions ("Key frequently visited ftp sites…", "You
may specify the editor for F4…", "FTP is built in…", "You can disable all
requests for confirmation…"), then freezes. There is no reproducible per-step
schedule to imitate. The clone's deterministic context hints (including the VFS
hint on directory entry, asserted by `tests/mc_parity.sh`) match `mc`'s *style*
(R4); the exact per-step text cannot be made to match. No code change.

---

## Open

None. The two items that remained after the full `visual_diff` pass were
re-checked against current `mc.sh` and closed (see R18/R19): O1 already matches
`mc` exactly, and O2's per-step hint text is non-deterministic in `mc` itself.

### O1. F1/F2 dialog: surrounding `..`-row and empty rows render differently — RESOLVED, see R18

### O2. Hint line: exact text at a step differs — RESOLVED, see R19

### O3. Full-screen SGR parity at 191x74 (odd width) — RESOLVED, see R17

### O4. `bc_print pair=0` cannot request pair 0 — RESOLVED, see R16

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
