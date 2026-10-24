# Dialog layer — `lib/dialog.sh`

`lib/dialog.sh` gives you `dialog`/`whiptail`-style boxes — message boxes,
yes/no prompts and scrolling menus — built on top of `lib/widgets.sh`. It is
meant for scripts that want a quick interactive prompt without writing any
screen code, and for porting existing `dialog`-based scripts.

```bash
source lib/dialog.sh   # pulls in widgets.sh, layout.sh and bc.sh
```

## The three boxes

```bash
bc_msgbox TITLE TEXT        # an OK box; status 0
bc_yesno  TITLE TEXT        # Yes/No; status 0 = Yes
bc_menu   TITLE TEXT TAG ITEM…   # scrolling menu; chosen TAG left in REPLY
```

`bc_menu` takes any number of `TAG`/`ITEM` description pairs. The tag you pick
is left in `REPLY`; pressing Esc or Cancel returns status `1` and leaves
`REPLY` empty:

```bash
bc_menu "Pick one" "Choose a fruit:" apple "Apple" banana "Banana"
case $REPLY in
  apple)  echo "you like apples" ;;
  banana) echo "you like bananas" ;;
  *)      echo "cancelled" ;;
esac
```

`TEXT` may contain literal `\n` sequences (exactly as `dialog` passes them);
they become line breaks, and long lines are wrapped to fit the box.

## Taking over the terminal

Each call takes over the terminal, runs, and hands it back again — just like
`dialog` does. Between calls you can run normal shell commands and print
normal output:

```bash
bc_msgbox "Update" "Starting the update ..."
make -j8 2>&1 | tee build.log
bc_msgbox "Update" "Done."
```

The first call starts the screen (raw mode, mouse, colour); later calls reuse
it. When the script exits the terminal is restored automatically.

## Porting a `dialog` script

A `dialog` script usually wraps the calls and captures their output:

```bash
choice=$(dialog --title "Pick" --menu "Choose:" 0 0 0 a "Apple" b "Banana" 2>&1 >&3)
```

Command substitution runs in a subshell, which would lose the screen state, so
the wrappers set `REPLY` instead:

```bash
menu() { bc_menu "$1" "$2" "${@:3}"; }   # chosen tag in REPLY
yesno() { bc_yesno "$1" "$2"; }          # status 0 = Yes
msg()   { bc_msgbox "$1" "$2"; }

menu "Pick" "Choose:" a "Apple" b "Banana"
choice=$REPLY
```

## Keys

| Key | Effect |
|---|---|
| Up / Down | move the selection (or between buttons) |
| PgUp / PgDn / Home / End | jump in a menu |
| a letter | jump to the next tag starting with it |
| Enter | choose the selection / press the focused button |
| Esc | cancel (a message box closes as OK) |
| Tab, Left, Right | move between the menu and the buttons |

## Mouse

Click a menu item to select it, double-click to choose it, click a button to
press it, and use the wheel to scroll a menu.

## Colours

The look mimics `dialog`'s default palette: cyan-on-blue screen, grey boxes
with a black shadow, white borders, blue titles, `< OK >` style buttons with
the default one highlighted, and a blue selection bar in menus. The colour
pairs are allocated with `alloc_pair` on first use, so they won't clash with
pairs your own app has allocated.

## Distributing

`lib/dialog.sh` is the fourth bundler layer. An app that sources it bundles
with all four libraries embedded:

```sh
bash lib/bc.sh bundle myapp.sh -o myapp
```

→ **[docs/distributing.md](distributing.md)**
