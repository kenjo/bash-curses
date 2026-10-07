# ANOMALIES

Divergences between real `mc` (4.8.33) and the bash clone (`examples/mc.sh`),
found by `tests/visual_diff.sh`: both apps are driven in tmux with an identical
key sequence over a controlled tree (`tmp/vd/tree`), and each step is compared
per-cell (character + fg + bg + attributes) via `tests/lib/screen.sh`.

Capture artefacts: `tmp/vd/{mc,clone}/NN_<label>.{plain,sgr}`; full report
`tmp/vd/REPORT.txt`. Steps: initial, F9 menu bar (menu_f9*), F2 (menu_f2*),
panel_tab, nav_down2, open_alpha, viewer_txt, f1_help.

> **Reading caveat — 16-colour vs 256-colour SGR.** `mc` emits 16-colour ANSI
> codes (`\e[30m`, `\e[9x`); the clone emits 256-colour codes (`\e[38;5;N`).
> For N=0..15 the two render to the *same* colour, so the per-cell diff counts
> are inflated by pure SGR-encoding differences that are visually identical
> (directories, command line, panel header, most listing cells). Findings below
> are only those where the rendered colour/content actually differs, or where
> the behaviour differs. The encoding gap itself is tracked as LOW #8.

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
trailing margin cell (window-col 62) stays pair 16. Verified **0 differing
cells** (span y4-21 x18-81). Down/Up move the highlight correctly.

### R2. F1 (Help) — was H2
F1 now opens the large centred **"Help"** main screen (`examples/mc.sh`
`fkey_help`): ASCII MC logo, "Commander 4.8.33", help text, keybar `2Index`.
Geometry x=9 y=3 w=82 h=22. Emphasised words match `mc`'s colours: the "Enter"
key is bright-cyan/blue (pair 21); "contents", "authors", "WARRANTY",
"GNU General " (incl. its trailing end-of-line space), and "Public License" are
black-on-cyan (pair 6); the logo "Commander" and first "GNU Midnight Commander"
are blue (pair 20). Verified **0 differing cells** (span y3-24 x9-90).

### R3. `[^]` command-line cursor marker — was M4
The subshell/command-line row now renders `[^]` at the far right, matching `mc`.

### R4. Context-sensitive hint line — was L3
The bottom hint line now rotates context-sensitive hints (`redraw_hint`),
e.g. "Hint: Tab changes your current panel.", matching `mc`'s style instead of
one static line.

### R5. Exact mnemonic letters in menu dropdowns
Dropdown hot-key letters now match `mc`'s choices (commit `77f13bb`).

---

## HIGH — wrong content / behaviour

### H3. Panel status line shows a type label, not the entry name
The panel's status row (just above the disk-usage row) should name the selected
entry.
- **mc**: `..` → `UP--DIR`; a directory → its **name** (`/beta`); a file → its
  name.
- **clone**: `..` → `UP--DIR` (matches); a directory → literal **`dir`**; a
  file → `file <N> bytes` (does **not** match).
- Source: `examples/mc.sh:348-353` (`status="dir"` / `"file N bytes"`).
- Evidence: `tmp/vd/{mc,clone}/10.nav_down2.plain` (cursor on `/beta`).

---

## MEDIUM — visible colour differences

### M1. Menu bar colour
- **mc**: entire bar is **black on cyan** (`\e[30m` + `\e[46m`), uniform.
- **clone**: hot-key letters (L/F/C/O/R) in **bright yellow** (`38;5;11`) and
  the rest in **bright white** (`38;5;15`), on cyan.
- Raw: `tmp/vd/mc/01.initial.sgr` line 0 vs `tmp/vd/clone/01.initial.sgr` line 0.

### M2. Regular-file colour
- **mc**: **yellow** (`\e[33m`, index 3).
- **clone**: **default/white** foreground (no explicit yellow).
- Raw: grep `a.txt` in `tmp/vd/{mc,clone}/01.initial.sgr`.

### M3. Executable colour
- **mc**: **bright green** (`\e[92m`, index 10).
- **clone**: **cyan** (`\e[36m`, index 6).
- Raw: grep `c.sh` in `tmp/vd/{mc,clone}/01.initial.sgr`.

---

## LOW — systematic / cosmetic / known simplifications

### L1. SGR encoding: 16-colour (mc) vs 256-colour (clone)
Visually identical for indices 0-15 but changes the emitted bytes, inflates the
per-cell diff, and reduces terminal fidelity/efficiency. Affects directories,
command line, panel header, and most listing cells. (See reading caveat.)

### L2. Parent entry (`..`) size column: `DIR` (mc) vs `UP--DIR` (clone).
Minor wording difference in the size field. Evidence: `07.menu_f2.plain`.

---

## No divergence (verified matching)

- **F9 menu-bar navigation** (menu_f9, _down, _down2, _right, _right_down):
  menu-bar text and highlight *position* are identical; only SGR/colour differs
  (M1/L1).
- **F2 (User menu)** and **F1 (Help)**: now match `mc` exactly (see R1/R2).
- **panel_tab** (Tab): panel activation matches; only SGR/colour differs (L1).
- **open_alpha** (Enter on `/alpha`): both navigate into `…/tree/alpha$`;
  only SGR/colour differs (L1).
- **viewer_txt**: viewer content and prompt (`…/tree/beta$`) match; only
  SGR/colour differs (L1).
- **initial**: file listing content, columns, `..` status row (`UP--DIR`),
  `[^]`, and hint line all match; differences are M1-M3 + L1-L2.
