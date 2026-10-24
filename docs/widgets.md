# `lib/widgets.sh` — interactive widgets

Widgets sit on top of [the layout layer](layout.md). A widget owns an area: it
draws it (through the area's `draw_NAME`) and takes its keys (when the area
has focus) and mouse events. You describe what to show through callbacks and
react through callbacks; you never track scroll offsets or hit-test
coordinates.

```bash
source lib/widgets.sh   # pulls in layout.sh and bc.sh
```

Widget state lives in `BCW_*` arrays keyed by area name. Callbacks you don't
define are simply skipped. Area names are usually dotted (`left.list`) so a
panel's parts don't collide — remember the dotted token must appear in the
`bc_grid` template, and the draw/callback names use the full area name
(`draw_left.list`, `row_left.list`).

---

## Tutorial

### A list

`bc_list NAME ARRAY` puts a scrolling list over the items of the array named
ARRAY. The array is read at every redraw, so to change the list you just
update the array and call `bc_dirty NAME`.

```bash
bc_grid body "
  body.list
  body.status
" rows="* 1"

items=(alpha beta gamma delta)
bc_list body.list items
bc_focus body.list          # the list only takes keys when focused

row_body.list() {           # IDX Y SEL — draw one row at content row Y
  local t=" ${items[$1]} "
  if (( $3 )); then bc_print body.list "$2" 0 "$t" pair=4
  else bc_print body.list "$2" 0 "$t"; fi
}
select_body.list() { sel=$1; bc_dirty body.status; }   # selection moved
enter_body.list()  { ... }                             # Enter / double click
```

Keys: Up Down Home End PgUp PgDn; anything else is passed on (`bc_pass`).
Mouse: click selects, double click enters, wheel moves, press-drag selects —
and the event is always passed on afterwards, so your `click_NAME` still sees
it (e.g. to activate a panel).

### A dialog

`bc_dialog NAME TITLE HxW [style]` makes a centred float with a border and
title. Lay it out with `bc_grid`, fill the areas with the field widgets, then
`bc_dialog_run NAME`.

```bash
name="world"
open_dialog() {
  bc_dialog dlg "Edit" 7x30 margin=1 shadow=mc
  bc_grid dlg "
    dlg.lbl  dlg.fld
    .        .
    dlg.ok   dlg.cancel
  " rows="auto 1 auto" cols="auto *"
  bc_label dlg.lbl "Name:"
  bc_input dlg.fld name          # edits the variable named 'name'
  bc_button dlg.ok "OK" ok
  bc_button dlg.cancel "Cancel" cancel
  if bc_dialog_run dlg focus=dlg.fld; then
    bc_dirty body.status         # a non-cancel button closed it
  fi
}
```

`bc_dialog_run` returns 0 when a button other than a `cancel` button closed
the dialog; the button's area name is in `BCL_RESULT`. Keys: Tab next control
(wrapping), Down/Up next/previous, Enter presses the focused button or else
the first `ok` button, Esc cancels.

### A menu bar

`bc_menubar NAME "Title:X …"` puts a menu bar in the one-row area NAME; each
title sits at column X and its items come from the array `MENU_<Title>`.

```bash
MENU_File=("Open||O" "---" "Quit|F10|Q")
bc_menubar menu "File:2" pairs="2 3 4 5 6"

pick_menu() {                    # TITLE LABEL
  case $2 in
    Open) open_dialog ;;
    Quit) bc_quit ;;
  esac
}

on_key() { [[ $key == "$KEY_F9" ]] && bc_menubar_run menu; }
```

Entries are `"LABEL|SHORTCUT|MNEMONIC"`; `---` is a separator. The mnemonic
letter is highlighted in the label (first occurrence), or use `"letter:pos"`
to highlight another position. `bc_menubar_run NAME [INDEX] [DROPDOWN]` opens
it modally; callbacks `open_NAME` / `close_NAME` fire when it opens/closes
(e.g. to dim the rest of the screen).

### Pens

Dialog controls get their colours from `BCW_PENS="FOCUS FOCUSHOT FIELD
FIELDBUTTON"` — the focused control, its hotkey letter, input fields and
their `[^]` button. Hotkey letters of unfocused controls use the dialog's
title pair (`tpair=`).

### The whole example

```bash
#!/usr/bin/env bash
source lib/widgets.sh

items=(alpha beta gamma delta)
name="world"
sel=0
BCW_PENS="3 4 5 6"

bc_screen "
  menu
  body
  keys
" rows="1 * 1" cols="*"

bc_style menu pair=2
bc_style body border
bc_style keys pair=6

bc_grid body "
  body.list
  body.status
" rows="* 1"

bc_list body.list items
bc_focus body.list
row_body.list() { # idx y sel
  local t=" ${items[$1]} "
  if (( $3 )); then bc_print body.list "$2" 0 "$t" pair=4
  else bc_print body.list "$2" 0 "$t"; fi
}
select_body.list() { sel=$1; bc_dirty body.status; }
enter_body.list()  { bc_list_sel body.list; bc_print body.status 0 0 " entered: ${items[$1]} "; }

draw_body.status() { bc_print body.status 0 0 " selected: ${items[sel]}  name: $name"; }
draw_keys()        { bc_print keys 0 1 "F9=menu  e=edit  q=quit"; }
bc_dirty body.status

MENU_File=("Open||O" "---" "Quit|F10|Q")
bc_menubar menu "File:2" pairs="2 3 4 5 6"
pick_menu() {
  case $2 in
    Open) open_dialog ;;
    Quit) bc_quit ;;
  esac
}

open_dialog() {
  bc_dialog dlg "Edit" 7x30 margin=1 shadow=mc
  bc_grid dlg "
    dlg.lbl  dlg.fld
    .        .
    dlg.ok   dlg.cancel
  " rows="auto 1 auto" cols="auto *"
  bc_label dlg.lbl "Name:"
  bc_input dlg.fld name
  bc_button dlg.ok "OK" ok
  bc_button dlg.cancel "Cancel" cancel
  if bc_dialog_run dlg focus=dlg.fld; then
    bc_dirty body.status
  fi
}

on_key() {
  case $key in
    "$KEY_F9") bc_menubar_run menu ;;
    e) open_dialog ;;
    q) bc_quit ;;
  esac
}

bc_init mouse
bc_run
```

---

## Reference

### `bc_list NAME ARRAY`

A scrolling list over the items of the array named ARRAY (read at every
redraw). Registers `draw_NAME`, a key handler and a click handler.

Callbacks:

| Callback | When |
|---|---|
| `row_NAME IDX Y SEL` | draw item IDX at content row Y; SEL is 1 for the selected item. IDX runs past the item count for empty rows below the list — draw the whole row (padded). |
| `select_NAME IDX` | the selection moved (keys, click, wheel, drag) |
| `enter_NAME IDX` | Enter or a double click on an item; `bc_pass` from it to let Enter go on to the next key handler |

Keys: Up Down Home End PgUp PgDn; others are passed on. Mouse: click selects,
double click enters, wheel moves, press-drag selects; the event is then
passed on.

#### `bc_list_sel NAME [IDX]`
Set the selection (clamped to the item count), or read it into `BCL_SEL`.

#### `bc_list_redraw_sel NAME`
Redraw just the selected row — for when the highlight depends on something
outside the list (e.g. which panel is active). A no-op if a full redraw is
already pending.

### `bc_menubar NAME "Title:X …" [pairs="BAR OPEN MNEM SEL SELMNEM"] [reserve=N]`

A menu bar in the one-row area NAME with drop-down menus.

- `Title:X` — the title shown at column X; its items are the array
  `MENU_<Title>`: `"LABEL|SHORTCUT|MNEMONIC"` entries, `---` for a separator.
  MNEMONIC is the hotkey letter (first occurrence in the label highlighted)
  or `"letter:pos"`.
- `pairs=` — five colour pairs: bar background, open/active background,
  mnemonic letter, selected item background, selected mnemonic letter.
- `reserve=N` — keep N rows free below a drop-down.

#### `bc_menubar_run NAME [INDEX] [DROPDOWN]`
Open the bar (F9, a click on a title); modal until an item is picked or it is
closed (Esc, a click outside). `INDEX` selects the starting menu, `DROPDOWN`
opens it immediately.

Callbacks: `open_NAME` / `close_NAME` when it opens and closes;
`pick_NAME TITLE LABEL` after an item was picked.

Keys: Left/Right switch menus, Down/Up/Enter open and move, letters jump to a
menu (bar) or an item (drop-down), Esc closes.

### `bc_dialog NAME TITLE HxW [style options]`

A centred float with a border and title (`bc_float` under the hood; style
options as for `bc_float`/`bc_style`, e.g. `margin=1 shadow=mc pair=N
tpair=N nudge=DY,DX`). Lay it out with `bc_grid NAME "…"`, fill the areas with
the widgets below, then `bc_dialog_run NAME`. A `keys=FN` option replaces the
key handler; FN can call `_bcw_dialog_key` for the default behaviour.

`BCW_PENS="FOCUS FOCUSHOT FIELD FIELDBUTTON"` — pen pairs for the focused
control, its hotkey letter, input fields and their `[^]` button.

#### `bc_dialog_run NAME [focus=AREA|-] [order="AREA …"]`
Run the dialog (modal). `focus=-` starts with no control focused; `order=`
overrides the focus order (default: tree order of the controls). Status 0 when
a button other than a `cancel` button closed it; the button's area name is in
`BCL_RESULT`.

### Field widgets

#### `bc_label NAME TEXT [align=…] [pair=N]`
Static text — `bc_text` with the widget's defaults.

#### `bc_input NAME VAR [button]`
A one-line text field editing the variable named VAR. `button` draws mc's
`[^]` history button at its right end. Keys: printable characters,
Backspace, Delete, Left, Right, Home, End; `M-H` (`KEY_ALT_SH`) calls
`history_NAME`. A click places the caret.

#### `bc_check NAME VAR LABEL [hot=N]`
`[x] LABEL` toggling VAR (0/1) with Space, Left, Right or a click. `hot=N`
highlights LABEL's N-th letter.

#### `bc_button NAME LABEL [ok] [cancel] [hot=N]`
`[ LABEL ]`, or mc's default-button style `[< LABEL >]` with `ok`. Pressing it
(Space, Enter, click) calls `press_NAME` if defined, else closes the dialog
with NAME as the result — a `cancel` button closes with no result.

#### `bc_cycle NAME VAR PREFIX VALUE…`
`PREFIX value` that steps VAR through the values with Space, Enter, Left,
Right or a click.

---

## Globals you may read

| Global | Meaning |
|---|---|
| `BCL_SEL` | set by `bc_list_sel` |
| `BCL_RESULT` | dialog/modal result (button area name) |
| `BCW_PENS` | dialog control pen pairs (set once) |
| `BCW_SEL` `BCW_TOP` | per-list selection / scroll offset (read-only) |

`BCW_*` arrays are keyed by area name; treat them as read-only.
